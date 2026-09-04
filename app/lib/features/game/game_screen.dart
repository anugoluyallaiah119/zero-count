import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../engine/ai.dart';
import '../../engine/model.dart' as eng;
import '../../ui/zc_cosmetics.dart';
import '../collection/collection_data.dart';
import '../../engine/scoring.dart' as eng;
import '../../engine/session.dart';
import '../../shared/sfx/sfx_service.dart';
import '../../ui/zc_playing_card.dart';
import '../../ui/zc_theme.dart';
import '../player/profile_repository.dart';
import 'local_match_controller.dart';
import 'play_area_table.dart';

/// Arguments for starting a game match.
class GameArgs {
  const GameArgs({
    this.mode = 'quick',
    this.players = 4,
    this.target = 100,
  });

  final String mode;
  final int players;
  final int target;
}

/// Local quick/classic game (G1.1+) — rendered with the immersive, mockup-
/// matched play area and rich results announcement screen.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.args = const GameArgs()});

  final GameArgs args;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _sorted = false;
  bool _grouping = true;
  int? _pickerShownForCardId;

  static const _aiAvatars = [
    'assets/art/play_area_avatar_1.png',
    'assets/art/play_area_avatar_2.png',
    'assets/art/play_area_avatar_3.png',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final config = eng.GameConfig(
        widget.args.players,
        widget.args.mode == 'classic' ? 13 : 7,
        widget.args.target,
      );
      ref.read(localMatchProvider.notifier).newMatch(
        config,
        DifficultyProfile.normal,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(localMatchProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    ref.listen(localMatchProvider, (prev, next) {
      if (prev == null || next == null) return;
      final sfx = ref.read(sfxServiceProvider);
      for (final e in next.lastEvents) {
        if (e is DrewStock || e is DrewDiscard) sfx.draw();
        if (e is Discarded) sfx.discard();
        if (e is Showed) sfx.show();
        if (e is RoundEnded && e.counts.isNotEmpty && e.counts[0] == 0) {
          sfx.zero();
        }
        if (e is MatchEnded) {
          e.winnerId == 'you' ? sfx.win() : sfx.lose();
        }
      }
      if (prev.session.currentPlayerIdx != 0 &&
          next.session.currentPlayerIdx == 0 &&
          !next.session.isOver &&
          next.roundResult == null) {
        sfx.yourTurn();
      }
      _maybeOfferPicker(next);
    });

    return Scaffold(
      body: match == null
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF09031E), Color(0xFF140733)],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: ZcColors.gold),
              ),
            )
          : _buildTable(match, profile?.coins ?? 2500, profile?.gems ?? 50),
    );
  }

  Widget _buildTable(LocalMatchState m, int coins, int gems) {
    final phase = m.session.isOver
        ? 'OVER'
        : m.session.phase.name.toUpperCase();
    final isMyTurn = m.isHumanTurn;
    final top = m.session.topDiscard;

    final handCards = _sorted
        ? _sortByRank([...m.you.hand.cards])
        : _sortGrouped([...m.you.hand.cards]);

    return Stack(
      fit: StackFit.expand,
      children: [
        PlayAreaTable(
          theme: m.playAreaTheme,
          cardBackId: ref.watch(collectionProvider)['cardBacks']
              ?.firstWhere((e) => e.equipped, orElse: () => ref.watch(collectionProvider)['cardBacks']!.first)
              .id,
          players: [
            for (var i = 0; i < m.session.players.length; i++)
              PlayAreaPlayer(
                name: m.names[i],
                score: m.session.players[i].matchScore,
                cards: m.session.players[i].hand.size,
                order: i + 1,
                avatarAsset: i == 0
                    ? 'assets/art/avatar_01.png'
                    : _aiAvatars[(i - 1) % _aiAvatars.length],
                isActive: m.session.currentPlayerIdx == i && !m.session.isOver,
                isYou: i == 0,
              ),
          ],
          hand: [
            for (final c in handCards)
              PlayAreaHandCard(
                id: c.id,
                rank: c.rank.label,
                suit: _zcSuit(c.suit),
                value: c.value,
                isSpecial: c.isSpecial,
              ),
          ],
          topDiscard: top == null
              ? null
              : ZcPlayingCard(
                  key: ValueKey(top.id),
                  rank: top.rank.label,
                  suit: _zcSuit(top.suit),
                  value: top.value,
                  isSpecial: top.isSpecial,
                  width: 68,
                ),
          isMyTurn: isMyTurn,
          phase: phase,
          canDraw: isMyTurn && m.session.phase == eng.Phase.draw,
          canDiscard: isMyTurn && m.session.phase == eng.Phase.discard,
          selectedCardId: m.selectedCardId,
          round: m.session.round,
          target: m.session.config.target,
          modeLabel:
              widget.args.mode == 'classic' ? 'Classic Play' : 'Quick Play',
          coins: coins,
          gems: gems,
          sorted: _sorted,
          grouping: _grouping,
          specialHint: _specialHint(m),
          specialHintUrgent: m.yourSpecial != null &&
              !m.specialUsable &&
              m.yourSpecialTurnsRemaining > 0 &&
              m.yourSpecialTurnsRemaining <= 2,
          onBack: () {
            ref.read(localMatchProvider.notifier).stopIfAny();
            context.pop();
          },
          onSort: () => setState(() => _sorted = !_sorted),
          onToggleGrouping: () => setState(() => _grouping = !_grouping),
          onSettings: () => context.push('/tutorial'),
          onChat: () => _soon('Stickers & chat'),
          onEmoji: () => _soon('Reactions'),
          onHint: () => _soon('Hint'),
          onGroup: () => setState(() => _grouping = !_grouping),
          onCardTap: (id) {
            if (isMyTurn && m.session.phase == eng.Phase.discard) {
              ref.read(localMatchProvider.notifier).selectCard(id);
            }
          },
          onDrawStock: () =>
              ref.read(localMatchProvider.notifier).drawStock(),
          onDrawDiscard: () =>
              ref.read(localMatchProvider.notifier).drawDiscard(),
          onDiscard: () =>
              ref.read(localMatchProvider.notifier).discardSelected(),
          onShow: () => ref.read(localMatchProvider.notifier).show(),
          onEndTurn: () =>
              ref.read(localMatchProvider.notifier).endTurn(),
        ),

        // Results Announcement Modal (Round Result or Match Completed)
        if (m.roundResult != null || m.matchResult != null)
          _ResultsAnnouncementOverlay(
            isMatchEnd: m.matchResult != null,
            roundNumber: m.session.round,
            targetScore: m.session.config.target,
            roundResult: m.roundResult,
            matchResult: m.matchResult,
            names: m.names,
            aiAvatars: _aiAvatars,
            onNextRound: () =>
                ref.read(localMatchProvider.notifier).nextRound(),
            onPlayAgain: () {
              ref.read(localMatchProvider.notifier).stopIfAny();
              final config = eng.GameConfig(
                widget.args.players,
                widget.args.mode == 'classic' ? 13 : 7,
                widget.args.target,
              );
              ref.read(localMatchProvider.notifier).newMatch(
                config,
                DifficultyProfile.normal,
              );
            },
            onHome: () {
              ref.read(localMatchProvider.notifier).stopIfAny();
              context.pop();
            },
          ),
      ],
    );
  }

  void _maybeOfferPicker(LocalMatchState next) {
    // Show the "Choose your Zero" picker when the human just gained a Special
    // AND has 2+ different pair candidates. Only once per Special instance.
    final sp = next.yourSpecial;
    if (sp == null) {
      _pickerShownForCardId = null;
      return;
    }
    if (!next.isHumanTurn) return;
    if (next.yourPinnedRank != null) return;
    if (_pickerShownForCardId == sp.id) return;
    final targets = next.yourPairTargets;
    if (targets.length < 2) return;
    _pickerShownForCardId = sp.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showPairPicker(next, targets);
    });
  }

  Future<void> _showPairPicker(LocalMatchState m, List<eng.Rank> targets) async {
    final currentCount = m.yourCount;
    final controller = ref.read(localMatchProvider.notifier);
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
              for (final rank in targets)
                _pairChoiceRow(
                  rank: rank,
                  currentCount: currentCount,
                  hand: m.you.hand.cards,
                  onTap: () {
                    controller.pinSpecial(rank);
                    Navigator.of(context).pop();
                  },
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

  Widget _pairChoiceRow({
    required eng.Rank rank,
    required int currentCount,
    required List<eng.Card> hand,
    required VoidCallback onTap,
  }) {
    final pinned = eng.ScoringEngine.count(hand, pinRank: rank);
    final valueSaved = rank.value * 2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A0E5C), Color(0xFF140632)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFD946CB),
                width: 1.1,
              ),
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
                  rank.label,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pair of ${rank.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'saves $valueSaved pts',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Nunito',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$currentCount → $pinned',
                style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$what arrive with the social update'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZcColors.panelPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String? _specialHint(LocalMatchState m) {
    if (m.yourSpecial == null) return null;
    if (m.yourPinnedRank != null) {
      return 'LOCKED — ${m.yourPinnedRank!.label} PAIR = ZERO';
    }
    if (m.specialUsable) return 'READY — PAIR TO ZERO';
    final n = m.yourSpecialTurnsRemaining;
    if (n <= 0) return 'WAITING FOR PAIR';
    return 'WAITING • $n ${n == 1 ? 'TURN' : 'TURNS'} LEFT';
  }

  static ZcSuit _zcSuit(eng.Suit s) => switch (s) {
        eng.Suit.hearts => ZcSuit.hearts,
        eng.Suit.diamonds => ZcSuit.diamonds,
        eng.Suit.spades => ZcSuit.spades,
        eng.Suit.clubs => ZcSuit.clubs,
      };

  static List<eng.Card> _sortByRank(List<eng.Card> cards) {
    cards.sort((a, b) => a.value != b.value
        ? a.value.compareTo(b.value)
        : a.suit.index.compareTo(b.suit.index));
    return cards;
  }

  static List<eng.Card> _sortGrouped(List<eng.Card> cards) {
    final freq = <eng.Rank, int>{};
    for (final c in cards) {
      freq[c.rank] = (freq[c.rank] ?? 0) + 1;
    }
    cards.sort((a, b) {
      final ga = (freq[a.rank] ?? 0) >= 3 ? 0 : 1;
      final gb = (freq[b.rank] ?? 0) >= 3 ? 0 : 1;
      if (ga != gb) return ga.compareTo(gb);
      return a.rank.index != b.rank.index
          ? a.rank.index.compareTo(b.rank.index)
          : a.suit.index.compareTo(b.suit.index);
    });
    return cards;
  }
}

// ===========================================================================
// Pixel-Perfect Results Announcement Screen (Mockup Replica)
// ===========================================================================

class _ResultsAnnouncementOverlay extends StatelessWidget {
  const _ResultsAnnouncementOverlay({
    required this.isMatchEnd,
    required this.roundNumber,
    required this.targetScore,
    this.roundResult,
    this.matchResult,
    required this.names,
    required this.aiAvatars,
    required this.onNextRound,
    required this.onPlayAgain,
    required this.onHome,
  });

  final bool isMatchEnd;
  final int roundNumber;
  final int targetScore;
  final RoundEnded? roundResult;
  final MatchEnded? matchResult;
  final List<String> names;
  final List<String> aiAvatars;
  final VoidCallback onNextRound;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final totalScores = isMatchEnd ? matchResult!.totals : roundResult!.totals;

    final List<({int playerIdx, String name, int score, String avatar, bool isYou})> standings = [];
    for (var i = 0; i < names.length; i++) {
      standings.add((
        playerIdx: i,
        name: names[i],
        score: i < totalScores.length ? totalScores[i] : 0,
        avatar: i == 0 ? 'assets/art/avatar_01.png' : aiAvatars[(i - 1) % aiAvatars.length],
        isYou: i == 0,
      ));
    }
    standings.sort((a, b) => a.score.compareTo(b.score));

    final youRank = standings.indexWhere((p) => p.isYou) + 1;
    final youWon = youRank == 1;
    final earnedCoins = youWon ? 120 : (youRank == 2 ? 40 : (youRank == 3 ? -20 : -40));
    final earnedGems = youWon ? 2 : 0;

    return MatchCompletedScreen(
      isMatchEnd: isMatchEnd,
      roundNumber: roundNumber,
      targetScore: targetScore,
      standings: standings,
      youRank: youRank,
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
      onPrimaryAction: isMatchEnd ? onPlayAgain : onNextRound,
      primaryLabel: isMatchEnd ? 'PLAY AGAIN' : 'NEXT ROUND ▶',
    );
  }
}

// ============================================================================
// MATCH COMPLETED SCREEN — pixel-matched to mockup
// ============================================================================

typedef _Standing = ({int playerIdx, String name, int score, String avatar, bool isYou});

class MatchCompletedScreen extends StatelessWidget {
  const MatchCompletedScreen({
    super.key,
    required this.isMatchEnd,
    required this.roundNumber,
    required this.targetScore,
    required this.standings,
    required this.youRank,
    required this.earnedCoins,
    required this.earnedGems,
    required this.onShare,
    required this.onPrimaryAction,
    required this.primaryLabel,
  });

  final bool isMatchEnd;
  final int roundNumber;
  final int targetScore;
  final List<_Standing> standings;
  final int youRank;
  final int earnedCoins;
  final int earnedGems;
  final VoidCallback onShare;
  final VoidCallback onPrimaryAction;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Full-screen dark bg matching mockup
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.2,
          colors: [Color(0xFF1A0B3D), Color(0xFF08031A)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // ── Crown + Badge header ──────────────────────────────────
                Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Purple badge container
                    Container(
                      margin: const EdgeInsets.only(top: 28),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF5B21B6), Color(0xFF3B0764)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA855F7).withValues(alpha: 0.4),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 14),
                          // Laurel + MATCH COMPLETED text
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🌿', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: ShaderMask(
                                  shaderCallback: (b) => const LinearGradient(
                                    colors: [Color(0xFFFDE047), Color(0xFFFBBF24), Color(0xFFFFFFFF)],
                                  ).createShader(b),
                                  child: Text(
                                    isMatchEnd
                                        ? 'MATCH COMPLETED!'
                                        : 'ROUND $roundNumber COMPLETED!',
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('🌿', style: TextStyle(fontSize: 20)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // TARGET SCORE box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x441E0B42),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x55A855F7)),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'TARGET SCORE',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: Colors.white60,
                                  ),
                                ),
                                Text(
                                  '$targetScore',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFDE047),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Floating crown at top
                    Positioned(
                      top: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          boxShadow: [BoxShadow(color: Color(0xAAFDE047), blurRadius: 20)],
                        ),
                        child: const Text('👑', style: TextStyle(fontSize: 42)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Results table ─────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xCC0F062A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x448B5CF6), width: 1.2),
                  ),
                  child: Column(
                    children: [
                      // Header row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Row(
                          children: const [
                            SizedBox(width: 38),
                            Expanded(flex: 4, child: Text('PLAYER', style: TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white38))),
                            Expanded(flex: 3, child: Text('FINAL SCORE', style: TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white38), textAlign: TextAlign.center)),
                            Expanded(flex: 3, child: Text('RESULT', style: TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white38), textAlign: TextAlign.end)),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0x22FFFFFF), height: 1),
                      // Player rows
                      for (var i = 0; i < standings.length; i++)
                        _PlayerResultRow(
                          rank: i + 1,
                          player: standings[i],
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── REWARDS ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('🌿', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'REWARDS',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('🌿', style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RewardCard(
                      asset: 'assets/art/coin.png',
                      fallbackIcon: Icons.monetization_on_rounded,
                      fallbackColor: const Color(0xFFFDE047),
                      label: 'COINS',
                      value: earnedCoins >= 0 ? '+$earnedCoins' : '$earnedCoins',
                      positive: earnedCoins >= 0,
                    ),
                    const SizedBox(width: 16),
                    _RewardCard(
                      asset: 'assets/art/gem.png',
                      fallbackIcon: Icons.diamond_rounded,
                      fallbackColor: const Color(0xFFC084FC),
                      label: 'GEMS',
                      value: '+$earnedGems',
                      positive: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Buttons ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _ActionButton(
                        label: 'SHARE',
                        icon: Icons.ios_share_rounded,
                        gradient: const [Color(0xFF581C87), Color(0xFF3B0764)],
                        borderColor: const Color(0x55A855F7),
                        onTap: onShare,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: _ActionButton(
                        label: primaryLabel,
                        gradient: const [Color(0xFF16A34A), Color(0xFF15803D)],
                        shadowColor: const Color(0xFF22C55E),
                        onTap: onPrimaryAction,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Player row ───────────────────────────────────────────────────────────────

class _PlayerResultRow extends StatelessWidget {
  const _PlayerResultRow({required this.rank, required this.player});
  final int rank;
  final _Standing player;

  @override
  Widget build(BuildContext context) {
    final isWinner = rank == 1;
    final isPositive = rank <= 2;
    final coinResult = rank == 1 ? '+120' : (rank == 2 ? '+40' : (rank == 3 ? '-20' : '-40'));

    // Medal badge — circular like mockup
    final medalEmoji = rank == 1 ? '🥇' : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : null));

    Widget rankWidget = medalEmoji != null
        ? Text(medalEmoji, style: const TextStyle(fontSize: 26))
        : Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x22FFFFFF),
              shape: BoxShape.circle,
            ),
            child: Text('$rank', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, fontSize: 12)),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: isWinner ? const Color(0x15FDE047) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          SizedBox(width: 38, child: Center(child: rankWidget)),

          // Avatar + name + winner label
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isWinner
                            ? const LinearGradient(colors: [Color(0xFFFDE047), Color(0xFFD97706)])
                            : null,
                        color: isWinner ? null : const Color(0x33FFFFFF),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isWinner ? 2.0 : 1.0),
                        child: ClipOval(
                          child: player.avatar.startsWith('av_')
                              ? ZcAvatars.forId(player.avatar, 34)
                              : Image.asset(
                                  player.avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const ColoredBox(
                                    color: Color(0xFF3B0764),
                                    child: Center(child: Icon(Icons.person, color: Colors.white54, size: 18)),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // Online dot
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0F062A), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        player.name,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: player.isYou ? const Color(0xFFFDE047) : Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isWinner)
                        const Text(
                          '🏆 Winner!',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Final score
          Expanded(
            flex: 3,
            child: Text(
              '${player.score}',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isWinner ? const Color(0xFF4ADE80) : Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Coins result
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isWinner)
                  const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Text('👑', style: TextStyle(fontSize: 12)),
                  ),
                Text(
                  coinResult,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 2),
                Image.asset(
                  'assets/art/coin.png',
                  width: 14,
                  height: 14,
                  errorBuilder: (_, __, ___) => const Text('🪙', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reward card ──────────────────────────────────────────────────────────────

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.asset,
    required this.fallbackIcon,
    required this.fallbackColor,
    required this.label,
    required this.value,
    required this.positive,
  });
  final String asset;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xAA1A0B3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x448B5CF6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            asset,
            width: 40,
            height: 40,
            errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: fallbackColor, size: 40),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: positive ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    this.icon,
    required this.gradient,
    this.borderColor,
    this.shadowColor,
    required this.onTap,
  });
  final String label;
  final IconData? icon;
  final List<Color> gradient;
  final Color? borderColor;
  final Color? shadowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(14),
          border: borderColor != null ? Border.all(color: borderColor!, width: 1) : null,
          boxShadow: shadowColor != null
              ? [BoxShadow(color: shadowColor!.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
