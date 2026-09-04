import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../app/config.dart';
import '../auth/auth_controller.dart';
import '../player/profile_repository.dart';
import 'match_models.dart';

/// Live multiplayer match controller (M1.7).
///
/// Connects to the STOMP endpoint (/ws) with the JWT in the CONNECT frame,
/// subscribes to the room topic plus the private hand/error queues, and turns
/// every broadcast into a [LiveMatchState] update. The client is a thin
/// renderer: it sends intents (draw/discard/show/endTurn), the engine on the
/// server validates, and the resulting events come back over the wire.
///
/// Destinations (see MatchController / MatchBroadcaster / WsUserMessenger):
///   SEND  /app/room/{code}/start    {} — host only
///   SEND  /app/room/{code}/move     {"type":...,"cardId":N?}
///   SEND  /app/room/{code}/replay   {"sinceSeq":N}
///   SUB   /topic/room.{code}        events + {"type":"state",state:{…}}
///   SUB   /user/queue/hand          private full hand snapshot
///   SUB   /user/queue/errors        rejected moves
///   SUB   /user/queue/replay        replayed events (M1.8)
class LiveMatchController extends Notifier<LiveMatchState?> {
  StompClient? _client;
  String? _code;

  @override
  LiveMatchState? build() => null;

  bool get isConnected => state?.connected ?? false;

  /// Connect (or reuse the live connection) and join room [code].
  void connect(String code) {
    final current = state;
    if (current != null && current.code == code && current.connected) return;
    disconnect();
    _code = code;
    state = LiveMatchState.initial(code);

    final config = ref.read(appConfigProvider);
    final tokens = ref.read(tokenStoreProvider);
    final wsUrl = config.apiBaseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    _client = StompClient(
      config: StompConfig(
        url: '$wsUrl/ws',
        stompConnectHeaders: {
          if (tokens.accessToken != null)
            'Authorization': 'Bearer ${tokens.accessToken}',
        },
        webSocketConnectHeaders: {
          if (tokens.accessToken != null)
            'Authorization': 'Bearer ${tokens.accessToken}',
        },
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 3),
        onConnect: (frame) => _onConnect(code),
        onWebSocketError: (e) => _setError('connection error'),
        onStompError: (f) => _setError(f.body ?? 'session error'),
        onDisconnect: (_) {
          final s = state;
          if (s != null) state = s.copyWith(connected: false);
        },
      ),
    );
    _client!.activate();
  }

  void _onConnect(String code) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(connected: true, error: () => null);

    _client!.subscribe(
      destination: '/topic/room.$code',
      callback: (frame) {
        if (frame.body != null) {
          _onRoomMessage(jsonDecode(frame.body!) as Map<String, dynamic>);
        }
      },
    );
    _client!.subscribe(
      destination: '/user/queue/hand',
      callback: (frame) {
        if (frame.body == null) return;
        final j = jsonDecode(frame.body!) as Map<String, dynamic>;
        final hand = (j['hand'] as List? ?? [])
            .map((c) => LiveCard.fromJson(c as Map<String, dynamic>))
            .toList();
        final turns = (j['specialTurnsRemaining'] as num?)?.toInt() ?? 0;
        final pinned = j['specialPinnedRank'] as String?;
        final pairs = (j['validPairRanks'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        final cardBack = j['equippedCardBack'] as String? ?? 'cb_classic';
        final cur = state;
        if (cur != null) {
          state = cur.copyWith(
            myHand: hand,
            selectedCardId: () => null,
            specialTurnsRemaining: turns,
            specialPinnedRank: () => pinned,
            validPairRanks: pairs,
            myCardBackId: cardBack,
          );
        }
      },
    );
    _client!.subscribe(
      destination: '/user/queue/errors',
      callback: (frame) {
        if (frame.body == null) return;
        final j = jsonDecode(frame.body!) as Map<String, dynamic>;
        _setError(j['error'] as String? ?? 'rejected');
      },
    );
    _client!.subscribe(
      destination: '/user/queue/replay',
      callback: (frame) {
        if (frame.body == null) return;
        final j = jsonDecode(frame.body!) as Map<String, dynamic>;
        final cur = state;
        if (cur == null) return;
        final seq = (j['seq'] as num?)?.toInt() ?? cur.lastSeq;
        state = cur.copyWith(
          lastSeq: seq > cur.lastSeq ? seq : cur.lastSeq,
          lastEvents: _pushEvent(cur.lastEvents,
              _describe(j['type'] as String? ?? '', j['payload'])),
        );
      },
    );

    // Ask for anything we missed (sinceSeq=0 → full history) — the server
    // streams replayed events then a fresh hand snapshot (M1.3/M1.8).
    _send('/app/room/$code/replay', {'sinceSeq': state?.lastSeq ?? 0});
  }

  void _onRoomMessage(Map<String, dynamic> j) {
    final cur = state;
    if (cur == null) return;
    final type = j['type'] as String? ?? '';
    if (type == 'state') {
      state = cur.applyPublicView(j['state'] as Map<String, dynamic>);
      return;
    }
    if (type == 'rematch_state') {
      state = cur.copyWith(
        rematchVotes: (j['votes'] as num?)?.toInt() ?? 0,
        rematchSeats: (j['seats'] as num?)?.toInt() ?? 0,
        rematchVoters: (j['voters'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
      return;
    }
    if (type == 'streak_bonus') {
      state = cur.copyWith(lastStreakBonus: () => j);
      // Refresh the local profile so header coin/streak values update.
      final me = ref.read(authControllerProvider).userId;
      if (me != null && j['userId'] == me) {
        ref.invalidate(profileProvider);
      }
      return;
    }
    final seq = (j['seq'] as num?)?.toInt() ?? cur.lastSeq;
    var next = cur.copyWith(
      lastSeq: seq > cur.lastSeq ? seq : cur.lastSeq,
      lastEvents: _pushEvent(cur.lastEvents, _describe(type, j)),
    );
    if (type == 'round_started') {
      // Fresh session (may be a rematch) — clear any lingering match-over UI.
      next = next.copyWith(
        over: false,
        roundResult: () => null,
        matchResult: () => null,
        rematchVotes: 0,
        rematchSeats: 0,
        rematchVoters: const [],
        lastStreakBonus: () => null,
      );
    } else if (type == 'round_ended') {
      next = next.copyWith(roundResult: () => j);
    } else if (type == 'match_ended') {
      next = next.copyWith(matchResult: () => j, over: true);
    }
    state = next;
  }

  // ---- commands ----------------------------------------------------------

  /// Host starts the match from the lobby.
  void startMatch() {
    final code = _code;
    if (code != null) _send('/app/room/$code/start', const {});
  }

  void drawStock() => _move({'type': 'drawStock'});
  void drawDiscard() => _move({'type': 'drawDiscard'});
  void discardSelected() {
    final id = state?.selectedCardId;
    if (id != null) _move({'type': 'discard', 'cardId': id});
  }

  void show() => _move({'type': 'show'});
  void endTurn() => _move({'type': 'endTurn'});

  /// Cast a rematch vote. When every seated player has voted, the server
  /// starts a fresh match automatically.
  void voteRematch() {
    final code = _code;
    if (code != null) _send('/app/room/$code/rematch', const {});
  }

  /// "Choose your Zero" — pin the local player's Special to a specific rank.
  void pinSpecial(String rankLabel) {
    final code = _code;
    if (code != null) _send('/app/room/$code/pin-special', {'rank': rankLabel});
  }

  /// Clear a previously placed pin, if any.
  void clearSpecialPin() {
    final code = _code;
    if (code != null) _send('/app/room/$code/pin-special', {'clear': true});
  }

  void selectCard(int cardId) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
        selectedCardId: () => s.selectedCardId == cardId ? null : cardId);
  }

  void _move(Map<String, dynamic> body) {
    final code = _code;
    final s = state;
    if (code == null || s == null) return;
    _send('/app/room/$code/move', body);
    state = s.copyWith(error: () => null, selectedCardId: () => null);
  }

  void _send(String dest, Map<String, dynamic> body) {
    _client?.send(destination: dest, body: jsonEncode(body));
  }

  void _setError(String message) {
    final s = state;
    if (s != null) state = s.copyWith(error: () => message);
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }

  // ---- helpers -----------------------------------------------------------

  static List<String> _pushEvent(List<String> log, String line) {
    if (line.isEmpty) return log;
    final next = [...log, line];
    return next.length > 6 ? next.sublist(next.length - 6) : next;
  }

  /// Human-readable one-liner for an event JSON (topic or replay shape).
  static String _describe(String type, dynamic payload) {
    final p = payload is Map<String, dynamic> ? payload : const <String, dynamic>{};
    String who() {
      final idx = (p['playerIdx'] ?? p['player'] ?? '') .toString();
      return idx.isEmpty ? '' : 'P$idx ';
    }

    return switch (type) {
      'round_started' => 'Round ${p['round'] ?? '?'} begins',
      'drew_stock' => '${who()}drew from the deck',
      'drew_discard' => '${who()}took the discard',
      'discarded' => '${who()}discarded ${p['card']?['rank'] ?? ''}',
      'special_discarded' => '${who()}special card expired',
      'special_pinned' => '${who()}locked Special to ${p['rank'] ?? '?'}',
      'special_unpinned' => '${who()}unlocked Special',
      'turn_passed' => '${who()}ended the turn',
      'showed' => '${who()}called SHOW!',
      'stock_recycled' => 'Discard pile reshuffled',
      'round_ended' => 'Round over',
      'match_ended' => 'Match over',
      'rematch_state' => 'Rematch — ${p['votes'] ?? 0}/${p['seats'] ?? 0} ready',
      'streak_bonus' => '🔥 Win streak ×${p['streak'] ?? 0} → +${p['bonusCoins'] ?? 0} coins',
      'stalemate_forced' => 'Stalemate — round forced',
      'player_disconnected' => 'A player disconnected',
      'player_reconnected' => 'A player reconnected',
      'player_forfeited' => 'A player forfeited',
      'turn_timeout' => 'Turn timed out — auto-played',
      _ => type,
    };
  }
}

/// Family-keyed by room code so each room gets its own controller.
final liveMatchProvider =
    NotifierProvider<LiveMatchController, LiveMatchState?>(
        LiveMatchController.new);
