import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/zc_card_backs.dart';
import '../../ui/zc_cosmetics.dart';
import '../../ui/zc_playing_card.dart';
import 'play_area_theme.dart';

/// Renders an avatar from either a ZcAvatars id (av_*) or a legacy asset path.
Widget _avatarWidget(String? assetOrId, double size) {
  if (assetOrId != null && assetOrId.startsWith('av_')) {
    return ZcAvatars.forId(assetOrId, size);
  }
  return Image.asset(
    assetOrId ?? 'assets/art/avatar_01.png',
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => ZcAvatars.forId('av_default', size),
  );
}

/// A player/opponent shown around the table.
@immutable
class PlayAreaPlayer {
  const PlayAreaPlayer({
    required this.name,
    required this.score,
    required this.cards,
    required this.order,
    this.avatarAsset,
    this.isActive = false,
    this.isYou = false,
  });

  final String name;
  final int score;
  final int cards;
  final int order;
  final String? avatarAsset;
  final bool isActive;
  final bool isYou;
}

/// A card in the human hand.
@immutable
class PlayAreaHandCard {
  const PlayAreaHandCard({
    required this.id,
    required this.rank,
    required this.suit,
    required this.value,
    this.isSpecial = false,
  });

  final int id;
  final String rank;
  final ZcSuit suit;
  final int value;
  final bool isSpecial;
}

/// Single card in deal flight.
class _DealFlightCard {
  _DealFlightCard({
    required this.targetSeat,
    required this.cardIndex,
    required this.startTimeMs,
  });

  final int targetSeat; // 0=You, 1=Rahul(Top), 2=Sneha(Left), 3=Karan(Right)
  final int cardIndex;
  final int startTimeMs;
}

/// Main play area table with smooth, unhurried animations, active player neon glow sweep,
/// and accurate full-screen flight paths landing directly into the player's hand.
class PlayAreaTable extends StatefulWidget {
  const PlayAreaTable({
    super.key,
    required this.theme,
    required this.players,
    required this.hand,
    required this.topDiscard,
    required this.isMyTurn,
    required this.phase,
    required this.canDraw,
    required this.canDiscard,
    required this.selectedCardId,
    required this.round,
    required this.target,
    required this.modeLabel,
    this.coins,
    this.gems,
    this.sorted = false,
    this.grouping = true,
    this.cardBackId,
    this.specialHint,
    this.specialHintUrgent = false,
    this.onBack,
    this.onSort,
    this.onToggleGrouping,
    this.onSettings,
    this.onChat,
    this.onEmoji,
    this.onHint,
    this.onGroup,
    this.onCardTap,
    this.onDrawStock,
    this.onDrawDiscard,
    this.onDiscard,
    this.onShow,
    this.onEndTurn,
  });

  final PlayAreaTheme theme;
  final List<PlayAreaPlayer> players;
  final List<PlayAreaHandCard> hand;
  final ZcPlayingCard? topDiscard;
  final bool isMyTurn;
  final String phase;
  final bool canDraw;
  final bool canDiscard;
  final int? selectedCardId;
  final int round;
  final String? cardBackId; // equipped cb_* id — overrides theme cardBackAsset
  final int target;
  final String modeLabel;
  final int? coins;
  final int? gems;
  final bool sorted;
  final bool grouping;

  /// Short contextual message about the human's Special card (ready/waiting).
  /// Null when no Special is held.
  final String? specialHint;

  /// True when the hint should render with an urgent (red) accent.
  final bool specialHintUrgent;

  final VoidCallback? onBack;
  final VoidCallback? onSort;
  final VoidCallback? onToggleGrouping;
  final VoidCallback? onSettings;
  final VoidCallback? onChat;
  final VoidCallback? onEmoji;
  final VoidCallback? onHint;
  final VoidCallback? onGroup;
  final ValueChanged<int>? onCardTap;
  // Fires immediately on tap and returns the drawn card so animation can reveal it.
  final PlayAreaHandCard? Function()? onDrawStock;
  final VoidCallback? onDrawDiscard;
  final VoidCallback? onDiscard;
  final VoidCallback? onShow;
  final VoidCallback? onEndTurn;

  @override
  State<PlayAreaTable> createState() => _PlayAreaTableState();
}

class _PlayAreaTableState extends State<PlayAreaTable>
    with TickerProviderStateMixin {
  // GlobalKeys
  final GlobalKey _deckKey = GlobalKey();
  final GlobalKey _discardKey = GlobalKey();
  final GlobalKey _handKey = GlobalKey();
  final GlobalKey _seatTopKey = GlobalKey();
  final GlobalKey _seatLeftKey = GlobalKey();
  final GlobalKey _seatRightKey = GlobalKey();

  // Subtle ambient traveling neon glow animation controller
  late AnimationController _ambientGlowController;

  // Draw flight animation controller (850ms: Pop-up Showcase + Glide into Hand)
  late AnimationController _drawController;
  bool _drawingFromDiscard = false;
  PlayAreaHandCard? _drawnCardInfo;
  VoidCallback? _pendingDrawCallback;

  // Discard flight animation controller (650ms smooth parabolic arc flight)
  late AnimationController _discardController;
  PlayAreaHandCard? _discardingCardInfo;
  VoidCallback? _pendingDiscardCallback;

  // Opponent flight animation controller (700ms smooth flight to/from AI avatars)
  late AnimationController _opponentController;
  int _opponentFlightSeat = 1;
  bool _opponentFlightIsDiscard = false;
  PlayAreaHandCard? _opponentFlightCard;

  // Deal ceremony animation (3300ms total - slowed down by ~30% for natural pacing)
  late AnimationController _dealController;
  int? _lastRoundDealt;
  bool _isDealing = false;
  final List<_DealFlightCard> _dealCards = [];

  // Score tracking & flash animation
  int _lastScore = 0;
  Color _scoreColor = const Color(0xFFFDE047);
  Timer? _scoreFlashTimer;

  // 3-second SHOW countdown timer during POST window
  Timer? _showCountdownTimer;
  int _showCountdownSeconds = 3;
  double _showCountdownProgress = 1.0;

  @override
  void initState() {
    super.initState();

    _lastScore = _calculateHandScore(widget.hand);

    // Subtle table glow sweep: 4.0s continuous rotation
    _ambientGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // 1) 3-Phase Draw Flight Controller: fly up → flip reveal → glide to hand
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _drawController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final cb = _pendingDrawCallback;
        setState(() {
          _drawingFromDiscard = false;
          _drawnCardInfo = null;
          _pendingDrawCallback = null;
        });
        _drawController.reset();
        cb?.call();
      }
    });

    // 2) Discard Flight Controller (650ms)
    _discardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _discardController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final cb = _pendingDiscardCallback;
        setState(() {
          _discardingCardInfo = null;
          _pendingDiscardCallback = null;
        });
        _discardController.reset();
        cb?.call();
        _startShowCountdown();
      }
    });

    // 3) Opponent Flight Controller — slow parabolic arc
    _opponentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _opponentController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _opponentFlightCard = null;
        });
        _opponentController.reset();
      }
    });

    // 4) Deal Ceremony Controller (3300ms total)
    _dealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3300),
    );
    _dealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isDealing = false;
          _dealCards.clear();
        });
        _dealController.reset();
      }
    });

    _checkAndStartDealCeremony();
  }

  @override
  void didUpdateWidget(covariant PlayAreaTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.round != widget.round) {
      _checkAndStartDealCeremony();
    }

    // Opponent Action Flights
    if (!widget.isMyTurn && !_drawController.isAnimating && !_discardController.isAnimating) {
      final activeIndex = widget.players.indexWhere((p) => p.isActive && !p.isYou);
      if (activeIndex > 0) {
        // Detect Discard: Top discard changed while AI is playing
        if (widget.topDiscard != null &&
            oldWidget.topDiscard?.key != widget.topDiscard?.key &&
            !_opponentController.isAnimating) {
          final top = widget.topDiscard!;
          setState(() {
            _opponentFlightSeat = activeIndex;
            _opponentFlightIsDiscard = true;
            _opponentFlightCard = PlayAreaHandCard(
              id: -1,
              rank: top.rank,
              suit: top.suit,
              value: top.value,
              isSpecial: top.isSpecial,
            );
          });
          _opponentController.forward(from: 0.0);
        }
        // Detect Draw: Opponent card count increased
        else if (widget.players[activeIndex].cards > oldWidget.players[activeIndex].cards &&
            !_opponentController.isAnimating) {
          setState(() {
            _opponentFlightSeat = activeIndex;
            _opponentFlightIsDiscard = false;
            _opponentFlightCard = null;
          });
          _opponentController.forward(from: 0.0);
        }
      }
    }

    final currentScore = _calculateHandScore(widget.hand);
    if (currentScore != _lastScore) {
      _scoreFlashTimer?.cancel();
      setState(() {
        _scoreColor = currentScore < _lastScore
            ? const Color(0xFF4ADE80)
            : const Color(0xFFEF4444);
      });
      _lastScore = currentScore;
      _scoreFlashTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() {
            _scoreColor = const Color(0xFFFDE047);
          });
        }
      });
    }

    if (widget.phase == 'POST' && oldWidget.phase != 'POST' && widget.isMyTurn) {
      _startShowCountdown();
    } else if (widget.phase != 'POST' && oldWidget.phase == 'POST') {
      _cancelShowCountdown();
    }
  }

  static int _calculateHandScore(List<PlayAreaHandCard> cards) {
    final byRank = <String, List<PlayAreaHandCard>>{};
    for (final c in cards) {
      byRank.putIfAbsent(c.rank, () => []).add(c);
    }
    var total = 0;
    for (final group in byRank.values) {
      if (group.length < 3) {
        for (final c in group) {
          total += c.value;
        }
      }
    }
    return total;
  }

  static int _countZeroGroups(List<PlayAreaHandCard> cards) {
    final byRank = <String, int>{};
    for (final c in cards) {
      byRank[c.rank] = (byRank[c.rank] ?? 0) + 1;
    }
    return byRank.values.where((count) => count >= 3).length;
  }

  void _checkAndStartDealCeremony() {
    if (_lastRoundDealt != widget.round) {
      _lastRoundDealt = widget.round;

      _dealCards.clear();
      final numSeats = max(2, widget.players.length);
      final handSize = widget.modeLabel.contains('13') ? 13 : 7;
      final gap = handSize > 7 ? 95 : 135; // 30% slower pacing for dealing

      var currentMs = 950;
      for (var r = 0; r < handSize; r++) {
        for (var k = 0; k < numSeats; k++) {
          _dealCards.add(_DealFlightCard(
            targetSeat: k,
            cardIndex: r,
            startTimeMs: currentMs,
          ));
          currentMs += gap;
        }
      }

      setState(() {
        _isDealing = true;
      });
      _dealController.forward(from: 0.0);
    }
  }

  void _startShowCountdown() {
    _cancelShowCountdown();
    setState(() {
      _showCountdownSeconds = 3;
      _showCountdownProgress = 1.0;
    });

    const stepMs = 50;
    const totalMs = 3000;
    var elapsedMs = 0;

    _showCountdownTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      elapsedMs += stepMs;
      final remaining = (totalMs - elapsedMs) / 1000.0;
      if (remaining <= 0) {
        timer.cancel();
        if (mounted && widget.isMyTurn && widget.phase == 'POST') {
          setState(() {
            _showCountdownSeconds = 0;
            _showCountdownProgress = 0.0;
          });
          widget.onEndTurn?.call();
        }
      } else {
        if (mounted) {
          setState(() {
            _showCountdownSeconds = remaining.ceil();
            _showCountdownProgress = remaining / 3.0;
          });
        }
      }
    });
  }

  void _cancelShowCountdown() {
    _showCountdownTimer?.cancel();
    _showCountdownTimer = null;
  }

  @override
  void dispose() {
    _scoreFlashTimer?.cancel();
    _cancelShowCountdown();
    _ambientGlowController.dispose();
    _drawController.dispose();
    _discardController.dispose();
    _dealController.dispose();
    super.dispose();
  }

  void _triggerDrawAnimation({
    required bool fromDiscard,
    required VoidCallback onComplete,
    PlayAreaHandCard? drawnCard,
  }) {
    if (_isDealing || _drawController.isAnimating) {
      onComplete();
      return;
    }

    setState(() {
      _drawingFromDiscard = fromDiscard;
      _pendingDrawCallback = onComplete;
      if (fromDiscard && widget.topDiscard != null) {
        _drawnCardInfo = PlayAreaHandCard(
          id: -1,
          rank: widget.topDiscard!.rank,
          suit: widget.topDiscard!.suit,
          value: widget.topDiscard!.value,
          isSpecial: widget.topDiscard!.isSpecial,
        );
      } else {
        // Stock draw: use the card returned by onDrawStock eager callback
        _drawnCardInfo = drawnCard;
      }
    });

    _drawController.forward(from: 0.0);
  }

  void _triggerDiscardAnimation({
    required VoidCallback onComplete,
  }) {
    if (_discardController.isAnimating || _isDealing) {
      onComplete();
      return;
    }

    final selected = widget.hand
        .where((c) => c.id == widget.selectedCardId)
        .firstOrNull;

    if (selected == null) {
      onComplete();
      return;
    }

    setState(() {
      _discardingCardInfo = selected;
      _pendingDiscardCallback = onComplete;
    });

    _discardController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Deep cosmic foundation gradient
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0C0420),
                  Color(0xFF19093E),
                  Color(0xFF130630),
                  Color(0xFF0B031A),
                ],
                stops: [0.0, 0.4, 0.75, 1.0],
              ),
            ),
          ),
        ),

        // 2. Full-screen backdrop art (Mystic Garden Scene)
        Positioned.fill(
          child: Image.asset(
            widget.theme.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ),

        // 3. Ambient atmospheric lighting glow
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.10),
                radius: 0.95,
                colors: [
                  Color(0x308B5CF6),
                  Color(0x103B0764),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Japan theme: left scroll panel "雅 / ZERO COUNT" + right bamboo panel
        if (widget.theme.showSidePanels) ...[
          Positioned(
            left: 0,
            top: 60,
            bottom: 120,
            width: 52,
            child: _buildJapanLeftPanel(),
          ),
          Positioned(
            right: 0,
            top: 60,
            bottom: 120,
            width: 52,
            child: _buildJapanRightPanel(),
          ),
        ],

        SafeArea(
          child: Column(
            children: [
              _buildTopHeader(),
              _buildSubHeader(),
              // Responsive expanded table area that houses all table elements + hand
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    _buildTableFeltAndPiles(),
                    ..._buildOpponents(),
                    _buildYouAvatar(),
                    // Deal ceremony card distribution flight layer
                    if (_isDealing) _buildDealCeremonyLayer(),
                  ],
                ),
              ),
              _buildHandArea(),
              _buildActionBar(),
              _buildInfoStrip(),
              _buildChatBar(),
            ],
          ),
        ),

        // Discard blackout: only dims during arc phase (28-80%), fades out before end
        if (_discardingCardInfo != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _discardController,
              builder: (_, __) {
                final t = _discardController.value;
                // Fade in 0.28→0.50, hold 0.50→0.72, fade out 0.72→1.0
                double alpha = 0.0;
                if (t >= 0.28 && t < 0.50) {
                  alpha = ((t - 0.28) / 0.22) * 0.52;
                } else if (t >= 0.50 && t < 0.72) {
                  alpha = 0.52;
                } else if (t >= 0.72) {
                  alpha = (1.0 - (t - 0.72) / 0.28) * 0.52;
                }
                return IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: alpha.clamp(0.0, 0.52)),
                  ),
                );
              },
            ),
          ),

        // Flight layers for user and opponents
        if (_drawController.isAnimating) _buildDrawFlightLayer(),
        if (_discardingCardInfo != null) _buildDiscardFlightLayer(),
        if (_opponentController.isAnimating) _buildOpponentFlightLayer(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 1. Top Header Bar
  // -------------------------------------------------------------------------

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      child: Row(
        children: [
          // Frosted Back Button (<)
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0x990D0330),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0x40FFFFFF),
                  width: 1.1,
                ),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Round & Mode Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ROUND ${widget.round}/10',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFDE047),
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    widget.modeLabel,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // ZERO COUNT center logo
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'ZERO',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: ' C',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: '0',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFDE047),
                        letterSpacing: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: 'UNT',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Coin Capsule
          _buildCurrencyCapsule(
            icon: Icons.monetization_on_rounded,
            iconColor: const Color(0xFFFACC15),
            value: widget.coins != null ? '${widget.coins}' : '2,500',
          ),
          const SizedBox(width: 5),

          // Gem Capsule
          _buildCurrencyCapsule(
            icon: Icons.diamond_rounded,
            iconColor: const Color(0xFFC084FC),
            value: widget.gems != null ? '${widget.gems}' : '50',
          ),
          const SizedBox(width: 5),

          // Chat Notification Button (In Top Bar)
          GestureDetector(
            onTap: widget.onChat,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0x990D0330),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0x33FFFFFF),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 13, minHeight: 13),
                    child: const Text(
                      '1',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyCapsule({
    required IconData icon,
    required Color iconColor,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0x990D0330),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33FFFFFF), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 3),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Nunito',
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 11,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 2. Subheader Bar (Target Score + Sort + Emoji + Settings)
  // -------------------------------------------------------------------------

  Widget _buildSubHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      child: Row(
        children: [
          // Target Score Pill — matches mockup: dark pill center
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xCC09031E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x33A855F7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Target Score: ',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '${widget.target}',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFDE047),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // SORT button — green solid like mockup
          GestureDetector(
            key: const Key('sortButton'),
            onTap: widget.onSort,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF166534),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    color: widget.sorted ? const Color(0xFFFDC421) : Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SORT',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: widget.sorted ? const Color(0xFFFDC421) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Settings gear
          GestureDetector(
            onTap: widget.onSettings,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0x3310062E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33FFFFFF), width: 1),
              ),
              child: const Icon(Icons.settings_rounded, color: Colors.white70, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 3. 3D Game Table Felt + Center Piles + Active Player Ambient Glow Sweep (Req 4)
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // Japan Side Panels (left scroll + right bamboo/lantern)
  // -------------------------------------------------------------------------

  Widget _buildJapanLeftPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC1A0800),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
        border: Border.all(color: const Color(0x44E8A4B8), width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Scroll-style top divider
          Container(height: 1, color: const Color(0x88E8A4B8)),
          const SizedBox(height: 12),
          // 雅 kanji (elegance)
          const Text(
            '雅',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 26,
              color: Color(0xFFE8A4B8),
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Container(width: 24, height: 1, color: const Color(0x66E8A4B8)),
          const SizedBox(height: 10),
          // ZERO COUNT vertical text
          ...['Z','E','R','O','','C','O','U','N','T'].map(
            (c) => Text(
              c,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: Color(0xCCFFD4E8),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0x88E8A4B8)),
        ],
      ),
    );
  }

  Widget _buildJapanRightPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC1A0800),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
        border: Border.all(color: const Color(0x44E8A4B8), width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(height: 1, color: const Color(0x88E8A4B8)),
          const SizedBox(height: 12),
          // 和 kanji (harmony) in lantern style
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xAACC2200),
              border: Border.all(color: const Color(0x88FF6B9D), width: 1),
            ),
            alignment: Alignment.center,
            child: const Text(
              '和',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(width: 24, height: 1, color: const Color(0x66E8A4B8)),
          const SizedBox(height: 10),
          // 一手で変わる vertical text (means "One hand changes everything")
          ...['一','手','で','変','わ','る'].map(
            (c) => Text(
              c,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Color(0xCCFFD4E8),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(width: 24, height: 1, color: const Color(0x44E8A4B8)),
          const SizedBox(height: 8),
          // PLAY CALM PLAY SMART vertical
          ...['P','L','A','Y',' ','C','A','L','M'].map(
            (c) => Text(
              c,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 6.5,
                fontWeight: FontWeight.w900,
                color: Color(0x99FFD4E8),
                height: 1.5,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0x88E8A4B8)),
        ],
      ),
    );
  }

  Widget _buildTableFeltAndPiles() {
    return LayoutBuilder(builder: (context, constraints) {
      final tableWidth = constraints.maxWidth * 0.94;
      final tableHeight = constraints.maxHeight * 0.96;

      // Identify active seat for targeted light indicator
      int activeSeat = 0;
      for (var i = 0; i < widget.players.length; i++) {
        if (widget.players[i].isActive) {
          activeSeat = i;
          break;
        }
      }

      return AnimatedBuilder(
        animation: _ambientGlowController,
        builder: (context, _) {
          final t = _ambientGlowController.value;
          final angle = t * 2 * pi;

          // Align moving light towards active seat
          Alignment glowAlignment;
          if (activeSeat == 1) {
            glowAlignment = Alignment(cos(angle) * 0.4, -0.9); // Top (Rahul)
          } else if (activeSeat == 2) {
            glowAlignment = Alignment(-0.9, sin(angle) * 0.4); // Left (Sneha)
          } else if (activeSeat == 3) {
            glowAlignment = Alignment(0.9, sin(angle) * 0.4); // Right (Karan)
          } else {
            glowAlignment = Alignment(cos(angle) * 0.4, 0.9); // You (Bottom)
          }

          final hasTableAsset = widget.theme.tableAsset != null;

          return Center(
            child: SizedBox(
              key: const Key('feltTable'),
              width: tableWidth,
              height: tableHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 3D Stadium Table Asset with Transparent Alpha
                  if (hasTableAsset)
                    Positioned.fill(
                      child: Image.asset(
                        widget.theme.tableAsset!,
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) => _buildFallbackFelt(),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: _buildFallbackFelt(),
                    ),

                  // Traveling subtle neon glow light along border
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        gradient: RadialGradient(
                          center: glowAlignment,
                          radius: 0.85,
                          colors: [
                            widget.theme.borderGlow.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Optional Side Floating Controls (Brazil Carnival: HINT 3, GROUP)
                  if (widget.theme.showHintGroup) ...[
                    // Floating Hint & Group Dock
                    Positioned(
                      right: 10,
                      top: 120,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // HINT button with badge count
                          GestureDetector(
                            onTap: () => widget.onHint?.call(),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 52,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xEE0D4A2B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
                                    boxShadow: const [BoxShadow(color: Color(0x4422C55E), blurRadius: 10)],
                                  ),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lightbulb_rounded, color: Color(0xFFFDE047), size: 20),
                                      SizedBox(height: 3),
                                      Text(
                                        'HINT',
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Badge — "3" count like mockup
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '3',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // GROUP button
                          GestureDetector(
                            onTap: () => widget.onGroup?.call(),
                            child: Container(
                              width: 52,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xEE0D4A2B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
                                boxShadow: const [BoxShadow(color: Color(0x4422C55E), blurRadius: 10)],
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.style_rounded, color: Colors.white, size: 20),
                                  SizedBox(height: 3),
                                  Text(
                                    'GROUP',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Top-right YOUR TURN green hexagon status pill
                    if (widget.isMyTurn)
                      Positioned(
                        right: 20,
                        top: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xEE093B1F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x4422C55E),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'YOUR TURN',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.hexagon_rounded, color: Color(0xFF22C55E), size: 12),
                            ],
                          ),
                        ),
                      ),
                  ],

                  // Japan theme: Enso circle + 零 kanji painted on tatami
                  if (widget.theme.showSidePanels)
                    Center(
                      child: CustomPaint(
                        size: const Size(180, 180),
                        painter: _EnsoPainter(),
                      ),
                    ),

                  // Center Piles & Turn Banner
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDrawDeck(),
                          const SizedBox(width: 32),
                          _buildDiscardPile(),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildTurnBanner(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildFallbackFelt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.theme.tableGradient,
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: widget.theme.borderColor,
          width: 4.5,
        ),
      ),
    );
  }

  Widget _buildDrawDeck() {
    final canDraw = widget.isMyTurn && widget.canDraw && !_isDealing;

    return GestureDetector(
      key: _deckKey,
      onTap: canDraw
          ? () {
              // Fire immediately so engine processes the draw and we get the card
              final drawn = widget.onDrawStock?.call();
              _triggerDrawAnimation(
                fromDiscard: false,
                drawnCard: drawn,
                onComplete: () {},
              );
            }
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 58,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                if (canDraw)
                  BoxShadow(
                    color: const Color(0xFFFDE047).withValues(alpha: 0.85),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 3,
                  left: 1.5,
                  right: -1.5,
                  bottom: -3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E0A3C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0x33A855F7),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                // Show equipped card back; fall back to theme asset.
                widget.cardBackId != null
                    ? ZcCardBackWidget(
                        backId: widget.cardBackId!,
                        width: 58,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          widget.theme.cardBackAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF4C1D95),
                            child: const Center(
                              child: Text('0',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFC084FC),
                                  )),
                            ),
                          ),
                        ),
                      ),
                if (canDraw)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFDE047),
                          width: 2.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'DRAW DECK',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscardPile() {
    final canDraw = widget.isMyTurn && widget.canDraw && !_isDealing;
    final top = widget.topDiscard;

    return GestureDetector(
      key: _discardKey,
      onTap: canDraw
          ? () {
              _triggerDrawAnimation(
                fromDiscard: true,
                onComplete: () => widget.onDrawDiscard?.call(),
              );
            }
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 58,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                if (canDraw)
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.85),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: top != null
                ? ZcPlayingCard(
                    rank: top.rank,
                    suit: top.suit,
                    value: top.value,
                    isSpecial: top.isSpecial,
                    width: 58,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white24,
                        style: BorderStyle.solid,
                        width: 1.2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.layers_clear_rounded,
                        color: Colors.white30,
                        size: 26,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          const Text(
            'DISCARD PILE',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnBanner() {
    final active = widget.isMyTurn;
    final over = widget.phase == 'OVER';

    final String title;
    final String subtitle;
    if (_isDealing) {
      title = 'Dealing Cards…';
      subtitle = 'Shuffling deck for Round ${widget.round}';
    } else if (over) {
      title = 'MATCH OVER';
      subtitle = '';
    } else if (widget.isMyTurn) {
      title = 'Your Turn';
      subtitle = widget.phase == 'POST'
          ? 'Turn passes in ${_showCountdownSeconds}s… Tap SHOW if count is low!'
          : widget.phase == 'DISCARD'
              ? (widget.selectedCardId != null ? 'Card selected · Tap DISCARD' : 'Select a card to discard')
              : 'Pick a card to play';
    } else {
      title = 'Waiting…';
      subtitle = 'Opponent is thinking';
    }

    // Mockup: green title text, white subtitle, laurel emoji decorations
    return Column(
      key: const Key('turnBanner'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🌿',
              style: TextStyle(
                fontSize: 14,
                color: active ? null : Colors.white24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: active ? const Color(0xFF4ADE80) : Colors.white54,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '🌿',
              style: TextStyle(
                fontSize: 14,
                color: active ? null : Colors.white24,
              ),
            ),
          ],
        ),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 4. Opponents & You Avatars
  // -------------------------------------------------------------------------

  List<Widget> _buildOpponents() {
    final List<Widget> widgets = [];
    if (widget.players.length > 1) {
      final p1 = widget.players[1];
      widgets.add(
        Positioned(
          top: 6,
          child: Container(
            key: _seatTopKey,
            child: _buildAvatarPill(
              player: p1,
              fallbackName: 'Rahul',
              asset: p1.avatarAsset ?? 'assets/art/play_area_avatar_1.png',
              ringColor: const Color(0xFFC084FC),
              order: 1,
            ),
          ),
        ),
      );
    }

    if (widget.players.length > 2) {
      final p2 = widget.players[2];
      widgets.add(
        Positioned(
          left: 10,
          top: MediaQuery.of(context).size.height * 0.16,
          child: Container(
            key: _seatLeftKey,
            child: _buildAvatarPill(
              player: p2,
              fallbackName: 'Sneha',
              asset: p2.avatarAsset ?? 'assets/art/play_area_avatar_2.png',
              ringColor: const Color(0xFF38BDF8),
              order: 2,
            ),
          ),
        ),
      );
    }

    if (widget.players.length > 3) {
      final p3 = widget.players[3];
      widgets.add(
        Positioned(
          right: 10,
          top: MediaQuery.of(context).size.height * 0.16,
          child: Container(
            key: _seatRightKey,
            child: _buildAvatarPill(
              player: p3,
              fallbackName: 'Karan',
              asset: p3.avatarAsset ?? 'assets/art/play_area_avatar_3.png',
              ringColor: const Color(0xFFF59E0B),
              order: 3,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildAvatarPill({
    required PlayAreaPlayer player,
    required String fallbackName,
    required String asset,
    required Color ringColor,
    required int order,
  }) {
    final displayName = player.name == 'You' ? fallbackName : player.name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topRight,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: player.isActive ? const Color(0xFFFDE047) : ringColor,
                  width: player.isActive ? 2.8 : 2.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (player.isActive ? const Color(0xFFFDE047) : ringColor)
                        .withValues(alpha: player.isActive ? 0.8 : 0.55),
                    blurRadius: player.isActive ? 16 : 10,
                    spreadRadius: player.isActive ? 2.5 : 1.5,
                  ),
                ],
              ),
              child: ClipOval(child: _avatarWidget(asset, 52)),
            ),
            Positioned(
              top: -2,
              left: -2,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 1.2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$order',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F172A), width: 1.8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xDD09031E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ringColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Score: ${player.score}',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFDE047),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '🎴 x ${player.cards}',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 8,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYouAvatar() {
    final you = widget.players.isNotEmpty ? widget.players[0] : null;
    final avatarAsset = you?.avatarAsset ?? 'assets/art/avatar_01.png';
    final currentScore = _calculateHandScore(widget.hand);
    final countAfterDiscard = (widget.selectedCardId != null && widget.phase == 'DISCARD')
        ? _calculateHandScore(widget.hand.where((c) => c.id != widget.selectedCardId).toList())
        : null;

    return Positioned(
      bottom: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE047), width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFDE047).withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 1.5,
                ),
              ],
            ),
            child: ClipOval(child: _avatarWidget(avatarAsset, 46)),
          ),
          const SizedBox(height: 3),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xDD09031E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0x33FDE047),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'You',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 2),
                    Text('⚡', style: TextStyle(fontSize: 9)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Score: ',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    if (countAfterDiscard != null) ...[
                      Text(
                        '$currentScore → ',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '$countAfterDiscard',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4ADE80),
                        ),
                      ),
                    ] else ...[
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: _scoreColor,
                        ),
                        child: Text('$currentScore'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 5. Deal Ceremony (Slowed down by ~30% for natural pacing - Req 1)
  // -------------------------------------------------------------------------

  Widget _buildDealCeremonyLayer() {
    return AnimatedBuilder(
      animation: _dealController,
      builder: (context, _) {
        final elapsedMs = (_dealController.value * 3300).toInt();

        // 1) Shuffling Badge with Wig-Wag Animation (0 - 950ms)
        if (elapsedMs < 950) {
          final t = elapsedMs / 950.0;
          final wigWag = sin(t * pi * 8) * 0.12;
          return Center(
            child: Transform.rotate(
              angle: wigWag,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7E22CE), Color(0xFF4C1D95)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE047), width: 1.4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66FDE047),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🂠', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 5),
                    Text(
                      'Shuffling…',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 2) Individual Card Flights round-robin (520ms per card flight)
        final List<Widget> flyingWidgets = [];

        for (final item in _dealCards) {
          final cardElapsed = elapsedMs - item.startTimeMs;
          if (cardElapsed >= 0 && cardElapsed <= 520) {
            final p = (cardElapsed / 520.0).clamp(0.0, 1.0);
            final ease = Curves.easeOutCubic.transform(p);

            double targetX = 0;
            double targetY = 0;
            if (item.targetSeat == 1) {
              targetX = 0; // Top
              targetY = -120;
            } else if (item.targetSeat == 2) {
              targetX = -110; // Left
              targetY = -30;
            } else if (item.targetSeat == 3) {
              targetX = 110; // Right
              targetY = -30;
            } else {
              targetX = 0; // You / Hand
              targetY = 140;
            }

            final currentX = targetX * ease;
            final currentY = targetY * ease;
            final scale = 0.9 - (0.2 * ease);

            flyingWidgets.add(
              Positioned(
                child: Transform.translate(
                  offset: Offset(currentX, currentY),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: (1.0 - p * 0.25).clamp(0.0, 1.0),
                      child: const ZcPlayingCard(
                        faceDown: true,
                        rank: 'A',
                        suit: ZcSuit.spades,
                        value: 1,
                        width: 44,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: flyingWidgets,
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 6. Draw Card 2-Phase Showcase & Glide Animation (Deck/Pile -> Pop-up -> Hand)
  // -------------------------------------------------------------------------

  Widget _buildDrawFlightLayer() {
    return AnimatedBuilder(
      animation: _drawController,
      builder: (context, _) {
        if (!_drawController.isAnimating) return const SizedBox();
        final t = _drawController.value;
        final size = MediaQuery.of(context).size;

        final isDiscard = _drawingFromDiscard;
        final startX = isDiscard ? size.width * 0.5 + 20 : size.width * 0.5 - 54;
        final startY = size.height * 0.38;

        // Showcase position: centered on screen
        final centerX = size.width * 0.5 - 38;
        final centerY = size.height * 0.36;

        final endX = size.width * 0.5 - 26;
        final endY = size.height - 160;

        double currentX;
        double currentY;
        double scale;
        // flipProgress drives 0→1 card-back→face-up during phase 2
        double flipProgress = 0.0;
        double glowAlpha = 0.9;

        if (t < 0.38) {
          // Phase 1 (0–38%): fly from deck/discard up to center showcase
          final p = Curves.easeOutCubic.transform(t / 0.38);
          currentX = startX + (centerX - startX) * p;
          currentY = startY + (centerY - startY) * p;
          scale = 1.0 + 0.55 * p;
          flipProgress = 0.0;
        } else if (t < 0.62) {
          // Phase 2 (38–62%): held at center, card flips to reveal face
          final p = ((t - 0.38) / 0.24).clamp(0.0, 1.0);
          currentX = centerX;
          currentY = centerY;
          scale = 1.55;
          flipProgress = Curves.easeInOutCubic.transform(p);
          glowAlpha = 0.9 + 0.1 * sin(p * pi);
        } else {
          // Phase 3 (62–100%): glide from center down into user's hand
          final p = Curves.easeInCubic.transform((t - 0.62) / 0.38);
          currentX = centerX + (endX - centerX) * p;
          currentY = centerY + (endY - centerY) * p;
          scale = 1.55 - 0.55 * p;
          flipProgress = 1.0;
        }

        // The flip uses a scaleX trick: 0→0.5 shows back shrinking, 0.5→1 shows face growing
        final scaleX = flipProgress < 0.5
            ? 1.0 - flipProgress * 2
            : (flipProgress - 0.5) * 2;
        final showFace = flipProgress >= 0.5 || isDiscard;

        Widget cardFace;
        if (showFace && _drawnCardInfo != null) {
          cardFace = ZcPlayingCard(
            rank: _drawnCardInfo!.rank,
            suit: _drawnCardInfo!.suit,
            value: _drawnCardInfo!.value,
            width: 54,
          );
        } else {
          cardFace = ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              widget.theme.cardBackAsset,
              width: 54,
              height: 78,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 54,
                height: 78,
                color: const Color(0xFF4C1D95),
              ),
            ),
          );
        }

        // White flash at flip midpoint
        final flashAlpha = (flipProgress > 0.4 && flipProgress < 0.6)
            ? sin((flipProgress - 0.4) / 0.2 * pi) * 0.55
            : 0.0;

        return Positioned(
          left: currentX,
          top: currentY,
          child: Transform.scale(
            scale: scale,
            child: Transform(
              transform: Matrix4.identity()..scale(scaleX.clamp(0.0, 1.0), 1.0),
              alignment: Alignment.center,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFDE047).withValues(alpha: glowAlpha * 0.85),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                    if (flipProgress >= 0.5)
                      const BoxShadow(
                        color: Color(0x66FFFFFF),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    cardFace,
                    if (flashAlpha > 0)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: Colors.white.withValues(alpha: flashAlpha),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 7. Discard Card Smooth Arc Flight (Hand -> Discard Pile)
  // -------------------------------------------------------------------------

  Widget _buildDiscardFlightLayer() {
    final info = _discardingCardInfo;
    if (info == null) return const SizedBox();

    return AnimatedBuilder(
      animation: _discardController,
      builder: (context, _) {
        final t = _discardController.value;
        final size = MediaQuery.of(context).size;

        // Phase 1 (0–30%): card lifts up from hand with a pop
        // Phase 2 (30–100%): smooth arc flight to discard pile
        double currentX, currentY, scale, angle;

        final startX = size.width * 0.5 - 28;
        final startY = size.height - 155;
        final liftX = size.width * 0.5 - 28;
        final liftY = size.height - 210; // lifts straight up first
        final endX = size.width * 0.5 + 22;
        final endY = size.height * 0.40;

        if (t < 0.28) {
          // Pop-up lift phase
          final p = Curves.easeOutBack.transform(t / 0.28);
          currentX = startX + (liftX - startX) * p;
          currentY = startY + (liftY - startY) * p;
          scale = 1.0 + 0.35 * p;
          angle = 0.0;
        } else {
          // Parabolic arc to discard pile
          final p = Curves.easeInOutCubic.transform((t - 0.28) / 0.72);
          currentX = liftX + (endX - liftX) * p;
          currentY = liftY + (endY - liftY) * p - sin(p * pi) * 55;
          scale = 1.35 - 0.35 * p;
          angle = sin(p * pi) * -0.18;
        }

        return Positioned(
          left: currentX,
          top: currentY,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.9),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ZcPlayingCard(
                  rank: info.rank,
                  suit: info.suit,
                  value: info.value,
                  isSpecial: info.isSpecial,
                  width: 56,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 8. Opponent Card Flight (AI Draw / Discard Actions)
  // -------------------------------------------------------------------------

  Widget _buildOpponentFlightLayer() {
    return AnimatedBuilder(
      animation: _opponentController,
      builder: (context, _) {
        if (!_opponentController.isAnimating) return const SizedBox();
        final t = _opponentController.value;
        final ease = Curves.easeInOutCubic.transform(t);
        final size = MediaQuery.of(context).size;

        // Opponent seat coordinates
        double seatX;
        double seatY;
        if (_opponentFlightSeat == 1) {
          // Top Seat (Rahul)
          seatX = size.width * 0.5 - 24;
          seatY = size.height * 0.12;
        } else if (_opponentFlightSeat == 2) {
          // Left Seat (Sneha)
          seatX = 40;
          seatY = size.height * 0.28;
        } else {
          // Right Seat (Karan)
          seatX = size.width - 80;
          seatY = size.height * 0.28;
        }

        final pileX = _opponentFlightIsDiscard
            ? size.width * 0.5 + 20 // Discard Pile
            : size.width * 0.5 - 50; // Draw Deck
        final pileY = size.height * 0.38;

        final startX = _opponentFlightIsDiscard ? seatX : pileX;
        final startY = _opponentFlightIsDiscard ? seatY : pileY;

        final endX = _opponentFlightIsDiscard ? pileX : seatX;
        final endY = _opponentFlightIsDiscard ? pileY : seatY;

        // Slow parabolic arc: ease in-out with sin lift on Y axis
        final ease = Curves.easeInOutSine.transform(t);
        final currentX = startX + (endX - startX) * ease;
        final arcHeight = _opponentFlightIsDiscard ? 70.0 : 50.0;
        final currentY = startY + (endY - startY) * ease - sin(ease * pi) * arcHeight;
        final scale = 0.92 + sin(ease * pi) * 0.22;
        // Slight rotation during arc
        final angle = _opponentFlightIsDiscard
            ? sin(ease * pi) * -0.15
            : sin(ease * pi) * 0.10;

        return Positioned(
          left: currentX,
          top: currentY,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFDE047).withValues(alpha: 0.70),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _opponentFlightIsDiscard && _opponentFlightCard != null
                    ? ZcPlayingCard(
                        rank: _opponentFlightCard!.rank,
                        suit: _opponentFlightCard!.suit,
                        value: _opponentFlightCard!.value,
                        isSpecial: _opponentFlightCard!.isSpecial,
                        width: 48,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          widget.theme.cardBackAsset,
                          width: 48,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48, height: 70,
                            color: const Color(0xFF4C1D95),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 8. User Hand Area with Live Score Preview & Clean Card Elevation
  // -------------------------------------------------------------------------

  Widget _buildHandArea() {
    final currentScore = _calculateHandScore(widget.hand);
    final countAfterDiscard = (widget.selectedCardId != null && widget.phase == 'DISCARD')
        ? _calculateHandScore(widget.hand.where((c) => c.id != widget.selectedCardId).toList())
        : null;
    final numZeroGroups = _countZeroGroups(widget.hand);

    return LayoutBuilder(builder: (context, constraints) {
      final cardList = [
        for (final c in widget.hand)
          (id: c.id, rank: c.rank, suit: c.suit, value: c.value)
      ];

      return Container(
        key: _handKey,
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score & Group Status Pill above Hand
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xCC09031E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: countAfterDiscard != null
                      ? const Color(0xFF4ADE80)
                      : const Color(0x33A855F7),
                  width: 1.1,
                ),
                boxShadow: [
                  if (countAfterDiscard != null)
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your Count: ',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  if (countAfterDiscard != null) ...[
                    Text(
                      '$currentScore → ',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '$countAfterDiscard (-${currentScore - countAfterDiscard} pts)',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '$currentScore pts',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _scoreColor,
                      ),
                    ),
                  ],
                  if (numZeroGroups > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0x44FDE047),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE047), width: 0.8),
                      ),
                      child: Text(
                        '★ $numZeroGroups Group (0 pts)',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFDE047),
                        ),
                      ),
                    ),
                  ],
                  if (widget.specialHint != null) ...[
                    const SizedBox(width: 8),
                    _SpecialHintPill(
                      text: widget.specialHint!,
                      urgent: widget.specialHintUrgent,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Hand Fan Dock Tray
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 3),
              decoration: BoxDecoration(
                color: const Color(0x35140632),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0x33A855F7),
                  width: 1.1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F8B5CF6),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Center(
                child: ZcCardFan(
                  key: const Key('playerHand'),
                  cards: cardList,
                  cardWidth: widget.hand.length > 7 ? 43 : 52,
                  overlap: widget.hand.length > 7 ? 0.52 : 0.62,
                  enableGrouping: widget.grouping,
                  selectedCardId: widget.selectedCardId,
                  onCardTap: (id) {
                    if (widget.isMyTurn && (widget.phase == 'DISCARD' || widget.phase == 'DRAW')) {
                      widget.onCardTap?.call(id);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // -------------------------------------------------------------------------
  // 9. Action Bar (Direct Draw + Discard + 3-Second SHOW Window)
  // -------------------------------------------------------------------------

  Widget _buildActionBar() {
    final currentScore = _calculateHandScore(widget.hand);
    final countAfterDiscard = (widget.selectedCardId != null && widget.phase == 'DISCARD')
        ? _calculateHandScore(widget.hand.where((c) => c.id != widget.selectedCardId).toList())
        : null;

    if (widget.phase == 'OVER') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        child: _buildButton(
          label: 'BACK TO HOME',
          gradient: const [Color(0xFFFDE047), Color(0xFFEAB308)],
          textColor: const Color(0xFF1E1B4B),
          onTap: widget.onBack,
        ),
      );
    }

    Widget content;
    if (!widget.isMyTurn) {
      content = Container(
        height: 28,
        alignment: Alignment.center,
        child: Text(
          'Waiting for opponent…',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      );
    } else if (widget.phase == 'DRAW') {
      final top = widget.topDiscard;
      final discardSymbol = top != null ? '${top.rank}${top.suit.symbol}' : '';

      content = Row(
        children: [
          // DRAW CARD Button
          Expanded(
            child: _buildButton(
              label: '🎴 DRAW CARD',
              gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              onTap: widget.canDraw
                  ? () {
                      final drawn = widget.onDrawStock?.call();
                      _triggerDrawAnimation(
                        fromDiscard: false,
                        drawnCard: drawn,
                        onComplete: () {},
                      );
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // TAKE DISCARD Button
          Expanded(
            child: _buildButton(
              label: top != null ? 'TAKE $discardSymbol' : 'TAKE DISCARD',
              gradient: const [Color(0xFF22C55E), Color(0xFF16A34A)],
              onTap: widget.canDraw && top != null
                  ? () => _triggerDrawAnimation(
                        fromDiscard: true,
                        onComplete: () => widget.onDrawDiscard?.call(),
                      )
                  : null,
            ),
          ),
        ],
      );
    } else if (widget.phase == 'DISCARD') {
      final hasSelected = widget.selectedCardId != null;

      final discardLabel = hasSelected
          ? (countAfterDiscard != null
              ? 'DISCARD ($currentScore → $countAfterDiscard)'
              : 'DISCARD')
          : 'SELECT A CARD TO DISCARD';

      content = _buildButton(
        label: discardLabel,
        icon: Icons.upload_rounded,
        gradient: hasSelected
            ? const [Color(0xFFF0655A), Color(0xFFE74C3C)]
            : const [Color(0x44331B4D), Color(0x441E0E38)],
        textColor: hasSelected ? Colors.white : Colors.white38,
        onTap: hasSelected
            ? () => _triggerDiscardAnimation(
                  onComplete: () => widget.onDiscard?.call(),
                )
            : null,
      );
    } else if (widget.phase == 'POST') {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildButton(
                  label: '🚩 SHOW ($_showCountdownSeconds s)',
                  icon: Icons.visibility_rounded,
                  gradient: const [Color(0xFFFDE047), Color(0xFFEAB308)],
                  textColor: const Color(0xFF1E1B4B),
                  onTap: () {
                    _cancelShowCountdown();
                    widget.onShow?.call();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildButton(
                  label: 'PASS',
                  icon: Icons.skip_next_rounded,
                  gradient: const [Color(0xFF334155), Color(0xFF1E293B)],
                  textColor: Colors.white,
                  onTap: () {
                    _cancelShowCountdown();
                    widget.onEndTurn?.call();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _showCountdownProgress,
              backgroundColor: const Color(0x33FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFDE047)),
              minHeight: 2.5,
            ),
          ),
        ],
      );
    } else {
      content = const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 1, 16, 6),
      child: content,
    );
  }

  // -------------------------------------------------------------------------
  // 10. Info Strip — HOW SHOW WORKS / ROUND STAKE / GAME PROGRESS
  // -------------------------------------------------------------------------

  Widget _buildInfoStrip() {
    final completedRounds = (widget.round - 1).clamp(0, 10);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC09031E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HOW SHOW WORKS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'HOW SHOW WORKS',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFFFFF),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _infoLine('🔍', 'Declare when you think their count is low.'),
                  _infoLine('🏳', 'All players reveal'),
                  _infoLine('🏆', 'Closest to Zero wins the round!'),
                ],
              ),
            ),
            VerticalDivider(color: Colors.white.withValues(alpha: 0.1), width: 16),
            // ROUND STAKE
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ROUND STAKE',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFFFFF),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Text('Victory', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, color: Colors.white60)),
                      const Spacer(),
                      const Text('+100 ', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF4ADE80))),
                      Image.asset('assets/art/coin.png', width: 10, height: 10, errorBuilder: (_, __, ___) => const Text('🪙', style: TextStyle(fontSize: 8))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text('Penalty', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, color: Colors.white60)),
                      const Spacer(),
                      const Text('-100 ', style: TextStyle(fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFEF4444))),
                      Image.asset('assets/art/coin.png', width: 10, height: 10, errorBuilder: (_, __, ___) => const Text('🪙', style: TextStyle(fontSize: 8))),
                    ],
                  ),
                ],
              ),
            ),
            VerticalDivider(color: Colors.white.withValues(alpha: 0.1), width: 16),
            // GAME PROGRESS
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'GAME PROGRESS',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFFFFF),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Dot progress bar
                  Row(
                    children: [
                      for (var i = 0; i < 5; i++) ...[
                        Container(
                          width: i < completedRounds ? 10 : 8,
                          height: i < completedRounds ? 10 : 8,
                          decoration: BoxDecoration(
                            color: i < completedRounds
                                ? const Color(0xFF22C55E)
                                : const Color(0x33FFFFFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i < 4) const SizedBox(width: 4),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Round ${widget.round} of 10',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 8.5,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 8.5,
                color: Colors.white60,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 11. Chat Bar — bottom full-width like mockup
  // -------------------------------------------------------------------------

  Widget _buildChatBar() {
    return GestureDetector(
      onTap: widget.onChat,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xCC09031E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x22FFFFFF), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF22C55E), size: 18),
            const SizedBox(width: 8),
            const Text(
              'CHAT',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF22C55E),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Type a message...',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
            const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.white30, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    IconData? icon,
    required List<Color> gradient,
    Color textColor = Colors.white,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? gradient
                : [gradient[0].withValues(alpha: 0.35), gradient[1].withValues(alpha: 0.35)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: gradient[0].withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
          border: Border.all(
            color: enabled ? Colors.white.withValues(alpha: 0.25) : Colors.white10,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 16),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill showing the human's Special card status (ready or waiting).
class _SpecialHintPill extends StatelessWidget {
  const _SpecialHintPill({required this.text, required this.urgent});

  final String text;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final accent = urgent ? const Color(0xFFEF4444) : const Color(0xFFD946CB);
    final bg = urgent ? const Color(0x33EF4444) : const Color(0x33D946CB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('★ ',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: accent,
              )),
          Text(text,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: accent,
              )),
        ],
      ),
    );
  }
}

/// Ink-brush Enso circle + 零 kanji painted on the Japan tatami table.
class _EnsoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;

    // Ink-brush enso circle — thick, slightly uneven opacity
    final paint = Paint()
      ..color = const Color(0x552D1A00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -pi * 0.7,
      pi * 1.85,
      false,
      paint,
    );

    // Inner faint circle for depth
    paint
      ..color = const Color(0x22E8A4B8)
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), r * 0.72, paint);

    // 零 kanji in center (drawn as text)
    final tp = TextPainter(
      text: const TextSpan(
        text: '零',
        style: TextStyle(
          fontSize: 38,
          color: Color(0x66C8787E),
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - 2));

    // ZERO COUNT label below kanji
    final sub = TextPainter(
      text: const TextSpan(
        text: 'ZERO COUNT',
        style: TextStyle(
          fontSize: 8,
          color: Color(0x55C8787E),
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sub.paint(canvas, Offset(cx - sub.width / 2, cy + 24));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
