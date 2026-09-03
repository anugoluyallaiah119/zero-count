import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/avatar_catalog.dart';
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
  late final LiveMatchController _controller;
  late final PlayAreaTheme _theme;

  /// Active card flight overlay (draw/take reveal or discard fly).
  _CardFlight? _flight;

  @override
  void initState() {
    super.initState();
    _theme = PlayAreaTheme.randomFor(4);
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
      final newEvents = next.lastEvents.length > (prev?.lastEvents.length ?? 0)
          ? next.lastEvents.sublist(prev?.lastEvents.length ?? 0)
          : const <String>[];
      final sfx = ref.read(sfxServiceProvider);
      for (final e in newEvents) {
        if (e.contains('SHOW')) sfx.show();
        if (e.contains('drew') || e.contains('took')) sfx.draw();
        if (e.contains('discarded')) sfx.discard();
        if (e.contains('Match over')) sfx.win();
      }
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
                  avatarAsset: kAvatarFor(match.seats[i].id),
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
                ),
            ],
            topDiscard: match.topDiscard == null
                ? null
                : ZcPlayingCard(
                    key: ValueKey(match.topDiscard!.id),
                    rank: match.topDiscard!.rank,
                    suit: _zcSuit(match.topDiscard!.suit),
                    value: match.topDiscard!.value,
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
            onBack: () => context.go('/home'),
            onSort: () => setState(() => _sorted = !_sorted),
            onToggleGrouping: () => setState(() => _grouping = !_grouping),
            onSettings: () => _showRules(context),
            onChat: () => _soon('Stickers & chat'),
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

  void _showRules(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZcColors.panelPurple,
        title: const Text('How to win', style: TextStyle(color: Colors.white)),
        content: Text(
          'Draw or take a card, then discard one.\n'
          'Keep your count low — A=1, J/Q/K=10.\n'
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
    required this.kind,
    required this.onDone,
  });

  final String rank;
  final ZcSuit suit;
  final int value;
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
