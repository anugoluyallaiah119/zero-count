import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/zc_cosmetics.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/avatar_catalog.dart';
import '../game/game_screen.dart' show MatchCompletedScreen;
import '../game/play_area_table.dart';
import '../game/play_area_theme.dart';
import '../room/room_repository.dart';
import '../../shared/sfx/sfx_service.dart';
import '../../shared/widgets/mini_card.dart' show CardSuit;
import '../../ui/zc_playing_card.dart';
import '../../ui/zc_theme.dart';
import 'live_match_controller.dart';
import 'match_models.dart';

/// Live multiplayer game (M1.7) — now rendered with the same immersive,
/// mockup-matched play area as the local game. Card-flight animations and
/// reconnect banners are preserved.
class LiveGameScreen extends ConsumerStatefulWidget {
  const LiveGameScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<LiveGameScreen> createState() => _LiveGameScreenState();
}

class _LiveGameScreenState extends ConsumerState<LiveGameScreen> {
  bool _startSent = false;
  bool _sorted = false;
  bool _grouping = true;
  int _target = 100;
  int _handSize = 7;
  int? _pickerShownForCardId;
  late final LiveMatchController _controller;
  // Theme is updated from the handView once the socket delivers cosmetics.
  PlayAreaTheme _theme = PlayAreaTheme.brazilCarnival;

  /// Active card flight overlay (draw/take reveal or discard fly).
  _CardFlight? _flight;
  /// Short-lived effect overlay fired on draw events.
  Widget? _effectOverlay;
  bool _stickerPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(liveMatchProvider.notifier);
    Future.microtask(() => _controller.connect(widget.code));
  }

  @override
  void dispose() {
    _controller.disconnect();
    super.dispose();
  }

  Future<void> _maybeStart() async {
    if (_startSent) return;
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) return;
    try {
      final lobby = await ref.read(roomRepositoryProvider).get(widget.code);
      _target = lobby.target;
      _handSize = lobby.handSize;
      if (lobby.isHost(userId)) {
        _startSent = true;
        _controller.startMatch();
      }
    } catch (_) {}
  }

  void _watchFlights(LiveMatchState? prev, LiveMatchState? next) {
    if (prev == null || next == null || !prev.connected) return;
    if (_flight != null) return;
    final prevIds = {for (final c in prev.myHand) c.id};
    final nextIds = {for (final c in next.myHand) c.id};
    final added = next.myHand.where((c) => !prevIds.contains(c.id)).toList();
    if (added.isNotEmpty) {
      final card = added.last;
      final fromDiscard = prev.topDiscard?.id == card.id;
      final flight = _CardFlight(
        rank: card.rank,
        suit: _zcSuit(card.suit),
        value: card.value,
        isSpecial: card.isSpecial,
        kind: fromDiscard ? _FlightKind.take : _FlightKind.draw,
        onDone: () {
          if (mounted) setState(() => _flight = null);
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _flight == null) setState(() => _flight = flight);
      });
      return;
    }
    final removed = prev.myHand.where((c) => !nextIds.contains(c.id)).toList();
    if (removed.isNotEmpty && next.topDiscard?.id == removed.last.id) {
      final card = removed.last;
      final flight = _CardFlight(
        rank: card.rank,
        suit: _zcSuit(card.suit),
        value: card.value,
        isSpecial: card.isSpecial,
        kind: _FlightKind.discard,
        onDone: () {
          if (mounted) setState(() => _flight = null);
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _flight == null) setState(() => _flight = flight);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(liveMatchProvider);
    final userId = ref.read(authControllerProvider).userId;

    ref.listen(liveMatchProvider, (prev, next) {
      if (next == null) return;
      _watchFlights(prev, next);
      // Apply the player's equipped theme when we first receive cosmetics.
      if ((prev == null || prev.myThemeId != next.myThemeId)) {
        final equipped = PlayAreaTheme.forId(next.myThemeId);
        if (equipped != _theme) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) { if (mounted) setState(() => _theme = equipped); });
        }
      }
      final newEvents = next.lastEvents.length > (prev?.lastEvents.length ?? 0)
          ? next.lastEvents.sublist(prev?.lastEvents.length ?? 0)
          : const <String>[];
      final sfx = ref.read(sfxServiceProvider);
      for (final e in newEvents) {
        if (e.contains('SHOW')) sfx.show();
        if (e.contains('drew') || e.contains('took')) {
          sfx.draw();
          // Fire the equipped effect overlay on my own draw events.
          final myIdx = userId == null ? -1 : next.mySeatIndex(userId);
          if (next.currentPlayerIdx == myIdx && _effectOverlay == null) {
            final effectId = next.myEffectId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _effectOverlay == null) {
                setState(() {
                  _effectOverlay = buildEffectOverlay(
                    effectId: effectId,
                    onDone: () { if (mounted) setState(() => _effectOverlay = null); },
                  );
                });
              }
            });
          }
        }
        if (e.contains('discarded')) sfx.discard();
        if (e.contains('Match over')) sfx.win();
      }
      _maybeOfferPicker(next);
    });

    if (match == null || (!match.connected && !match.reconnecting)) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
          child: const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: ZcColors.gold),
              SizedBox(height: 16),
              Text('Connecting to the table…',
                  style: TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
      );
    }

    _maybeStart();

    final myIdx = userId == null ? -1 : match.mySeatIndex(userId);
    final isMyTurn =
        match.connected && myIdx >= 0 && match.currentPlayerIdx == myIdx;
    debugPrint('LIVE userId=$userId myIdx=$myIdx isMyTurn=$isMyTurn phase=${match.phase}');
    final phase = match.over
        ? 'OVER'
        : match.phase.toUpperCase().startsWith('POST')
            ? 'POST'
            : match.phase.toUpperCase();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          PlayAreaTable(
            theme: _theme,
            players: [
              for (var i = 0; i < match.seats.length; i++)
                PlayAreaPlayer(
                  name: i == myIdx ? 'You' : 'Player ${i + 1}',
                  score: match.seats[i].matchScore,
                  cards: match.seats[i].cards,
                  order: i + 1,
                  // Use equipped avatar id; the play area will render it via ZcAvatars.
                  avatarAsset: match.seats[i].equippedAvatar,
                  isActive: match.currentPlayerIdx == i && !match.over,
                  isYou: i == myIdx,
                ),
            ],
            hand: [
              for (final c in _sortedHand(match.myHand))
                PlayAreaHandCard(
                  id: c.id,
                  rank: c.rank,
                  suit: _zcSuit(c.suit),
                  value: c.value,
                  isSpecial: c.isSpecial,
                ),
            ],
            topDiscard: match.topDiscard == null
                ? null
                : ZcPlayingCard(
                    key: ValueKey(match.topDiscard!.id),
                    rank: match.topDiscard!.rank,
                    suit: _zcSuit(match.topDiscard!.suit),
                    value: match.topDiscard!.value,
                    isSpecial: match.topDiscard!.isSpecial,
                    // Show the back of a face-down discard using my equipped back.
                    cardBackId: match.myCardBackId,
                    width: 74,
                  ),
            isMyTurn: isMyTurn,
            phase: phase,
            canDraw: isMyTurn && match.phase.toUpperCase() == 'DRAW',
            canDiscard: isMyTurn && match.phase.toUpperCase() == 'DISCARD',
            selectedCardId: match.selectedCardId,
            round: match.round,
            target: _target,
            modeLabel: 'LIVE ROOM',
            sorted: _sorted,
            grouping: _grouping,
            specialHint: _specialHint(match, isMyTurn),
            specialHintUrgent: match.mySpecial != null &&
                !match.specialUsable &&
                match.specialTurnsRemaining > 0 &&
                match.specialTurnsRemaining <= 2,
            onBack: () => context.go('/home'),
            onSort: () => setState(() => _sorted = !_sorted),
            onToggleGrouping: () => setState(() => _grouping = !_grouping),
            onSettings: () => _showRules(context),
            onChat: () => setState(() => _stickerPanelOpen = true),
            onEmoji: () => _soon('Reactions'),
            onHint: () => _soon('Hint'),
            onGroup: () => setState(() => _grouping = !_grouping),
            onCardTap: (id) {
              if (isMyTurn && match.phase.toUpperCase() == 'DISCARD') {
                _controller.selectCard(id);
              }
            },
            onDrawStock: () => _controller.drawStock(),
            onDrawDiscard: () => _controller.drawDiscard(),
            onDiscard: () => _controller.discardSelected(),
            onShow: () => _controller.show(),
            onEndTurn: () => _controller.endTurn(),
          ),
          if (match.reconnecting || match.error != null)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (match.reconnecting) _reconnectBanner(),
                  if (match.error != null) _errorBanner(match.error!),
                ],
              ),
            ),
          if (_flight != null) IgnorePointer(child: _flight!),
          if (_effectOverlay != null) IgnorePointer(child: _effectOverlay!),
          if (_stickerPanelOpen)
            Positioned(
              left: 8,
              right: 8,
              bottom: 80,
              child: _StickerPanel(
                stickerSetId: match.myStickerSetId,
                onClose: () => setState(() => _stickerPanelOpen = false),
                onSend: (sticker) {
                  setState(() => _stickerPanelOpen = false);
                  // Broadcast emote over STOMP.
                  _controller.sendEmote(sticker);
                },
              ),
            ),
          if (match.over && match.matchResult != null)
            _LiveMatchOverOverlay(
              result: match.matchResult!,
              seats: match.seats,
              myUserId: userId,
              rematchVotes: match.rematchVotes,
              rematchSeats: match.rematchSeats == 0
                  ? match.seats.length
                  : match.rematchSeats,
              iVoted: userId != null && match.iVotedRematch(userId),
              streakBonus: match.lastStreakBonus,
              onRematch: () => _controller.voteRematch(),
              onLeave: () => context.go('/home'),
            ),
        ],
      ),
    );
  }

  List<LiveCard> _sortedHand(List<LiveCard> hand) {
    if (!_sorted) return hand;
    final copy = [...hand];
    copy.sort((a, b) => a.value != b.value
        ? a.value - b.value
        : a.suit.index - b.suit.index);
    return copy;
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$what arrive with the social update'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZcColors.panelPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String? _specialHint(LiveMatchState match, bool isMyTurn) {
    if (match.mySpecial == null) return null;
    final pinned = match.specialPinnedRank;
    if (pinned != null) return 'LOCKED — $pinned PAIR = ZERO';
    if (match.specialUsable) return 'READY — PAIR TO ZERO';
    final n = match.specialTurnsRemaining;
    if (n <= 0) return 'WAITING FOR PAIR';
    return 'WAITING • $n ${n == 1 ? 'TURN' : 'TURNS'} LEFT';
  }

  void _maybeOfferPicker(LiveMatchState next) {
    final sp = next.mySpecial;
    if (sp == null) {
      _pickerShownForCardId = null;
      return;
    }
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) return;
    if (next.currentPlayerIdx != next.mySeatIndex(userId)) return;
    if (next.specialPinnedRank != null) return;
    if (_pickerShownForCardId == sp.id) return;
    if (next.validPairRanks.length < 2) return;
    _pickerShownForCardId = sp.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showPairPicker(next);
    });
  }

  Future<void> _showPairPicker(LiveMatchState m) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF120631),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFD946CB), width: 1.4),
          ),
          title: const Text(
            '★ CHOOSE YOUR ZERO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Color(0xFFFDE047),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pick which pair your Special completes into a ZERO group.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              for (final rank in m.validPairRanks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        _controller.pinSpecial(rank);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFF2A0E5C),
                            Color(0xFF140632)
                          ]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFD946CB), width: 1.1),
                        ),
                        child: Row(children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE047),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              rank,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A0B3D),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pair of $rank → ZERO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white70),
                        ]),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Best pair is auto-locked if you dismiss.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('DISMISS',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  void _showRules(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZcColors.panelPurple,
        title: const Text('How to win', style: TextStyle(color: Colors.white)),
        content: Text(
          'Draw or take a card, then discard one.\n'
          'Keep your count low — A=1, J/Q/K=10.\n'
          'A ★ Special card + a pair of the same rank = ZERO group.\n'
          'Call SHOW! when your count is the lowest.\n\n'
          'This room deals $_handSize cards per player.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('GOT IT', style: TextStyle(color: ZcColors.gold)),
          ),
        ],
      ),
    );
  }

  Widget _reconnectBanner() => Container(
        key: const Key('reconnectBanner'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ZcColors.gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Connection lost — reconnecting and resyncing…',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );

  Widget _errorBanner(String error) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ZcColors.errorRed.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(error,
            key: const Key('liveError'),
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}

ZcSuit _zcSuit(CardSuit s) => switch (s) {
      CardSuit.hearts => ZcSuit.hearts,
      CardSuit.diamonds => ZcSuit.diamonds,
      CardSuit.clubs => ZcSuit.clubs,
      CardSuit.spades => ZcSuit.spades,
    };

// ---------------------------------------------------------------------------
// V1 card flights
// ---------------------------------------------------------------------------

enum _FlightKind { draw, take, discard }

class _CardFlight extends StatefulWidget {
  const _CardFlight({
    required this.rank,
    required this.suit,
    required this.value,
    this.isSpecial = false,
    required this.kind,
    required this.onDone,
  });

  final String rank;
  final ZcSuit suit;
  final int value;
  final bool isSpecial;
  final _FlightKind kind;
  final VoidCallback onDone;

  @override
  State<_CardFlight> createState() => _CardFlightState();
}

class _CardFlightState extends State<_CardFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  bool get _isDiscard => widget.kind == _FlightKind.discard;
  bool get _startsFaceUp => widget.kind != _FlightKind.draw;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _isDiscard ? 650 : 1900),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final front = ZcPlayingCard(
      rank: widget.rank,
      suit: widget.suit,
      value: widget.value,
      isSpecial: widget.isSpecial,
      width: 96,
    );
    const back = ZcPlayingCard(
      rank: '',
      suit: ZcSuit.spades,
      value: 0,
      width: 96,
      faceDown: true,
    );

    if (_isDiscard) {
      final move = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = move.value;
          return Align(
            alignment: Alignment(0, 0.85 - 1.15 * t),
            child: Opacity(
              opacity: 1 - 0.35 * t,
              child: Transform.scale(
                scale: 1 - 0.35 * t,
                child: Transform.rotate(angle: -0.15 * t, child: front),
              ),
            ),
          );
        },
      );
    }

    final entrance = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
    );
    final flip = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.24, 0.52, curve: Curves.easeInOut),
    );
    final exit = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.72, 1.0, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final e = entrance.value;
        final x = exit.value;
        final y = 0.35 - 0.4 * e + 1.15 * x;
        final scale = 0.55 + 0.5 * e - 0.6 * x;
        final opacity = (e < 1 ? e : 1.0) * (1 - x);
        final angle =
            _startsFaceUp ? 0.35 * math.sin(flip.value * math.pi) : flip.value * math.pi;
        final showFront = _startsFaceUp || angle > math.pi / 2;

        Widget card = showFront ? front : back;
        if (angle > math.pi / 2 && !_startsFaceUp) {
          card = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: card,
          );
        }

        return Align(
          alignment: Alignment(0, y.clamp(-1.0, 1.0)),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: Transform.scale(scale: scale, child: card),
            ),
          ),
        );
      },
    );
  }
}

/// Match-over modal with a rematch vote counter and Leave button.
class _LiveMatchOverOverlay extends StatelessWidget {
  const _LiveMatchOverOverlay({
    required this.result,
    required this.seats,
    required this.myUserId,
    required this.rematchVotes,
    required this.rematchSeats,
    required this.iVoted,
    required this.streakBonus,
    required this.onRematch,
    required this.onLeave,
  });

  final Map<String, dynamic> result;
  final List<LiveSeat> seats;
  final String? myUserId;
  final int rematchVotes;
  final int rematchSeats;
  final bool iVoted;
  final Map<String, dynamic>? streakBonus;
  final VoidCallback onRematch;
  final VoidCallback onLeave;

  static const _avatarAssets = [
    'assets/art/play_area_avatar_1.png',
    'assets/art/play_area_avatar_2.png',
    'assets/art/play_area_avatar_3.png',
  ];

  @override
  Widget build(BuildContext context) {
    final winnerId = result['winnerId']?.toString();
    final totals = (result['totals'] as List? ?? const [])
        .map((e) => (e as num).toInt())
        .toList();
    final target = (result['target'] as num?)?.toInt() ?? 100;

    // Build standings from live seats + totals
    final List<({int playerIdx, String name, int score, String avatar, bool isYou})> standings = [];
    for (var i = 0; i < seats.length; i++) {
      final seat = seats[i];
      standings.add((
        playerIdx: i,
        name: seat.name.isNotEmpty ? seat.name : 'Player ${i + 1}',
        score: i < totals.length ? totals[i] : 0,
        avatar: seat.equippedAvatar.isNotEmpty
            ? seat.equippedAvatar
            : _avatarAssets[i % _avatarAssets.length],
        isYou: seat.id == myUserId,
      ));
    }
    standings.sort((a, b) => a.score.compareTo(b.score));

    final youRank = standings.indexWhere((p) => p.isYou) + 1;
    final earnedCoins = youRank == 1 ? 120 : (youRank == 2 ? 40 : (youRank == 3 ? -20 : -40));
    final earnedGems = youRank == 1 ? 2 : 0;

    return Positioned.fill(
      child: MatchCompletedScreen(
        isMatchEnd: true,
        roundNumber: 0,
        targetScore: target,
        standings: standings,
        youRank: youRank < 1 ? standings.length : youRank,
        earnedCoins: earnedCoins,
        earnedGems: earnedGems,
        onShare: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Results copied!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF7B2FE0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        onPrimaryAction: onRematch,
        primaryLabel: rematchVotes > 0
            ? 'REMATCH ($rematchVotes/$rematchSeats)'
            : 'PLAY AGAIN',
      ),
    );
  }
}

}

class _OverBtn extends StatelessWidget {
  const _OverBtn({required this.label, required this.primary, this.onTap});

  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: [Color(0xFFD946CB), Color(0xFF8B5CF6)],
                  )
                : null,
            color: primary ? null : const Color(0x22FFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primary
                  ? const Color(0xFFD946CB)
                  : const Color(0x66FFFFFF),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: disabled ? Colors.white54 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// R1.6 celebration badge for win-streak milestones.
class _StreakBonusBadge extends StatelessWidget {
  const _StreakBonusBadge({required this.streak, required this.coins});

  final int streak;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEF4444)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥',
              style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WIN STREAK ×$streak',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
              if (coins > 0)
                Text(
                  '+$coins coins',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sticker quick-send panel. Shows the player's 5 free stickers + any owned.
class _StickerPanel extends StatelessWidget {
  const _StickerPanel({
    required this.stickerSetId,
    required this.onClose,
    required this.onSend,
  });

  final String stickerSetId;
  final VoidCallback onClose;
  final ValueChanged<String> onSend;

  // All sticker ids mapped to emoji labels for code-drawn display.
  static const _stickers = {
    'st_gg': '🏆',
    'st_nice': '👏',
    'st_wow': '😮',
    'st_fire': '🔥',
    'st_lol': '😂',
    'st_cry': '😭',
    'st_zero': '💥',
    'st_think': '🤔',
    'st_love': '😌',
    'st_angry': '😤',
    'st_crown': '👑',
    'st_luck': '💯',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xF20A0420),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x33A855F7), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Stickers',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _stickers.entries)
                  GestureDetector(
                    onTap: () => onSend(entry.key),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        border: entry.key == stickerSetId
                            ? Border.all(
                                color: const Color(0xFFA855F7), width: 1.5)
                            : null,
                      ),
                      child: Text(entry.value,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
