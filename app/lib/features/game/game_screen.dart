import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../engine/ai.dart';
import '../../engine/model.dart' as eng;
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
              ),
          ],
          topDiscard: top == null
              ? null
              : ZcPlayingCard(
                  key: ValueKey(top.id),
                  rank: top.rank.label,
                  suit: _zcSuit(top.suit),
                  value: top.value,
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

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$what arrive with the social update'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZcColors.panelPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
    final totalScores = isMatchEnd
        ? matchResult!.totals
        : roundResult!.totals;

    // Rank players by lowest cumulative score
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

    final earnedCoins = youWon ? 120 : (youRank == 2 ? 40 : -20);
    final earnedGems = youWon ? 2 : 0;

    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Golden Crown + Laurel Header Banner
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Laurel Garland Badge
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF6B21A8), Color(0xFF3B0764)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFA855F7).withValues(alpha: 0.5),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              isMatchEnd ? 'MATCH COMPLETED!' : 'ROUND $roundNumber COMPLETED!',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '◆',
                              style: TextStyle(color: Color(0xFFA855F7), fontSize: 10),
                            ),
                          ],
                        ),
                      ),

                      // Golden Crown Floater
                      Positioned(
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x88FDE047),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: const Text('👑', style: TextStyle(fontSize: 38)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Target Score Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x991E0B42),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x33A855F7)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'TARGET SCORE',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '$targetScore',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFDE047),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Standings Table Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xD912062E),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0x558B5CF6), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x338B5CF6),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Row
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(width: 32),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'PLAYER',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'FINAL SCORE',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: Colors.white54,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'RESULT',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: Colors.white54,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Color(0x22FFFFFF), height: 12),

                        // Player Rows
                        for (var rank = 0; rank < standings.length; rank++)
                          _buildPlayerRow(
                            rank: rank + 1,
                            player: standings[rank],
                            isWinner: rank == 0,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Rewards Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🌿 ', style: TextStyle(fontSize: 12)),
                      Text(
                        'REWARDS',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: const Color(0xFFC084FC),
                        ),
                      ),
                      const Text(' 🌿', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Coins Reward Card
                      _buildRewardCard(
                        iconWidget: Image.asset(
                          'assets/art/coin.png',
                          width: 32,
                          height: 32,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on_rounded,
                            color: Color(0xFFFDE047),
                            size: 32,
                          ),
                        ),
                        label: 'COINS',
                        value: earnedCoins >= 0 ? '+$earnedCoins' : '$earnedCoins',
                        isPositive: earnedCoins >= 0,
                      ),
                      const SizedBox(width: 14),

                      // Gems Reward Card
                      _buildRewardCard(
                        iconWidget: Image.asset(
                          'assets/art/gem.png',
                          width: 32,
                          height: 32,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.diamond_rounded,
                            color: Color(0xFFC084FC),
                            size: 32,
                          ),
                        ),
                        label: 'GEMS',
                        value: '+$earnedGems',
                        isPositive: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 5. Bottom Action Buttons
                  Row(
                    children: [
                      // SHARE Button
                      Expanded(
                        flex: 4,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Results copied to share!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF7B2FE0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF581C87), Color(0xFF3B0764)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0x44A855F7)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.ios_share_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'SHARE',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // PLAY AGAIN or NEXT ROUND Button
                      Expanded(
                        flex: 6,
                        child: GestureDetector(
                          onTap: isMatchEnd ? onPlayAgain : onNextRound,
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isMatchEnd ? 'PLAY AGAIN' : 'NEXT ROUND ▶',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerRow({
    required int rank,
    required ({int playerIdx, String name, int score, String avatar, bool isYou}) player,
    required bool isWinner,
  }) {
    // Medal Icon or rank badge
    Widget rankWidget;
    if (rank == 1) {
      rankWidget = Container(
        width: 24,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF59E0B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(8)),
        ),
        child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      );
    } else if (rank == 2) {
      rankWidget = Container(
        width: 24,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF94A3B8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(8)),
        ),
        child: const Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      );
    } else if (rank == 3) {
      rankWidget = Container(
        width: 24,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFB45309),
          borderRadius: BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(8)),
        ),
        child: const Text('3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      );
    } else {
      rankWidget = Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          shape: BoxShape.circle,
        ),
        child: Text('$rank', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 11)),
      );
    }

    final coinResult = rank == 1 ? '+120' : (rank == 2 ? '+40' : (rank == 3 ? '-20' : '-40'));
    final isPositive = rank <= 2;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Rank Badge
          SizedBox(width: 28, child: Center(child: rankWidget)),
          const SizedBox(width: 8),

          // Avatar + Online Indicator + Name
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: isWinner ? const Color(0xFFFDE047) : const Color(0x33FFFFFF),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundImage: AssetImage(player.avatar),
                        backgroundColor: const Color(0xFF3B0764),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
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
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Final Score
          Expanded(
            flex: 3,
            child: Text(
              '${player.score}',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isWinner ? const Color(0xFF4ADE80) : Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Coins Result Delta
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isWinner) ...[
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFFDE047), size: 14),
                  const SizedBox(width: 2),
                ],
                Text(
                  coinResult,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 3),
                Image.asset(
                  'assets/art/coin.png',
                  width: 14,
                  height: 14,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.monetization_on,
                    size: 14,
                    color: Color(0xFFFACC15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard({
    required Widget iconWidget,
    required String label,
    required String value,
    required bool isPositive,
  }) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x881E0A3C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x448B5CF6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}
