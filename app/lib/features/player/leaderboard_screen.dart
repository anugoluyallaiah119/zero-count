import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_cosmetics.dart';
import '../../ui/zc_theme.dart';
import '../../ui/zc_bottom_nav.dart';
import '../player/leaderboard_repository.dart';
import '../player/profile_repository.dart';
/// Full leaderboard hub: Weekly · All-Time · My History.
/// Reached via the Profile tab or /leaderboard route.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF09031E), Color(0xFF140733)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(),
              const SizedBox(height: 2),
              _TabBar(controller: _tabs),
              const SizedBox(height: 4),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: const [
                    _WeeklyTab(),
                    _AllTimeTab(),
                    _HistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          const ZcBottomNav(active: ZcNavTab.profile, dark: true),
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (context.canPop()) context.pop();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0x33FFFFFF), width: 1.1),
                ),
                child: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LEADERBOARD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'ELO ${profile?.elo ?? 1200}  •  ${profile?.wins ?? 0} wins',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF5A1FA8), Color(0xFF3A1280)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: ZcColors.neonPurple.withValues(alpha: 0.5),
                  width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Color(0xFFFDE047), size: 15),
                const SizedBox(width: 3),
                Text(
                  'Streak ${profile?.winStreak ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Notification settings bell
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/notification-settings'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0x33FFFFFF), width: 1.1),
                ),
                child: const Icon(Icons.notifications_rounded,
                    color: Colors.white70, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB BAR
// =============================================================================

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5A1FA8), Color(0xFF3A1280)],
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66A855F7), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12.5,
            fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w700),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: const [
          Tab(text: '⚡ Weekly'),
          Tab(text: '🏆 All-Time'),
          Tab(text: '📋 History'),
        ],
      ),
    );
  }
}

// =============================================================================
// WEEKLY TAB
// =============================================================================

class _WeeklyTab extends ConsumerWidget {
  const _WeeklyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(weeklyLeaderboardProvider);
    return data.when(
      loading: () => const _Loader(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (entries) => _RankList(
        entries: entries,
        scoreLabel: 'wins',
        emptyMessage: 'No matches played this week yet.',
      ),
    );
  }
}

// =============================================================================
// ALL-TIME TAB
// =============================================================================

class _AllTimeTab extends ConsumerWidget {
  const _AllTimeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(alltimeLeaderboardProvider);
    return data.when(
      loading: () => const _Loader(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (entries) => _RankList(
        entries: entries,
        scoreLabel: 'ELO',
        showWins: true,
        emptyMessage: 'No ranked players yet.',
      ),
    );
  }
}

// =============================================================================
// HISTORY TAB
// =============================================================================

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(matchHistoryProvider);
    return data.when(
      loading: () => const _Loader(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (history) {
        if (history.isEmpty) {
          return const _EmptyState(
            icon: Icons.history_rounded,
            message: 'No matches played yet.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          itemCount: history.length,
          itemBuilder: (context, i) => _HistoryCard(entry: history[i]),
        );
      },
    );
  }
}

// =============================================================================
// RANK LIST
// =============================================================================

class _RankList extends StatelessWidget {
  const _RankList({
    required this.entries,
    required this.scoreLabel,
    this.showWins = false,
    required this.emptyMessage,
  });

  final List<LeaderboardEntry> entries;
  final String scoreLabel;
  final bool showWins;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyState(
          icon: Icons.leaderboard_rounded, message: emptyMessage);
    }
    // Pin the "me" entry at the top if I'm not in the top 3.
    final List<LeaderboardEntry> list = entries;
    final myEntry = list.firstWhere((e) => e.isMe,
        orElse: () => list.first);
    final topThree = list.take(3).toList();
    final rest = list.skip(3).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PodiumRow(topThree: topThree)),
        if (myEntry.rank > 3)
          SliverToBoxAdapter(
            child: _MePinnedRow(
                entry: myEntry, scoreLabel: scoreLabel, showWins: showWins),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _RankRow(
                entry: rest[i],
                scoreLabel: scoreLabel,
                showWins: showWins,
              ),
              childCount: rest.length,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TOP-3 PODIUM
// =============================================================================

class _PodiumRow extends StatelessWidget {
  const _PodiumRow({required this.topThree});
  final List<LeaderboardEntry> topThree;

  @override
  Widget build(BuildContext context) {
    if (topThree.isEmpty) return const SizedBox.shrink();
    final first = topThree[0];
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null) Expanded(child: _PodiumBlock(entry: second, height: 90)),
          const SizedBox(width: 8),
          Expanded(child: _PodiumBlock(entry: first, height: 116, isTop: true)),
          const SizedBox(width: 8),
          if (third != null) Expanded(child: _PodiumBlock(entry: third, height: 76)),
        ],
      ),
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  const _PodiumBlock({
    required this.entry,
    required this.height,
    this.isTop = false,
  });

  final LeaderboardEntry entry;
  final double height;
  final bool isTop;

  static const _medals = ['🥇', '🥈', '🥉'];
  static const _platformColors = [
    Color(0xFFD4AF37),
    Color(0xFF94A3B8),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank.clamp(1, 3);
    final color = _platformColors[rank - 1];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar circle
        Container(
          width: isTop ? 64 : 52,
          height: isTop ? 64 : 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isTop ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: isTop ? 16 : 8,
                spreadRadius: isTop ? 2 : 1,
              ),
            ],
          ),
          child: ClipOval(child: _avatarForId(entry.avatar, isTop ? 64 : 52)),
        ),
        const SizedBox(height: 6),
        Text(
          _medals[rank - 1],
          style: TextStyle(fontSize: isTop ? 18 : 15),
        ),
        const SizedBox(height: 3),
        Text(
          entry.name.isEmpty ? 'Player' : entry.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: isTop ? 12 : 11,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.score}',
          style: TextStyle(
            color: color,
            fontSize: isTop ? 13 : 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        // Platform block
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.35),
                color.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
        ),
      ],
    );
  }

  Widget _avatarForId(String id, double size) {
    if (id.startsWith('av_')) return ZcAvatars.forId(id, size);
    return Image.asset(
      id.isEmpty ? 'assets/art/avatar_01.png' : id,
      width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ZcAvatars.forId('av_default', size),
    );
  }
}

// =============================================================================
// "ME" PINNED ROW (shown when the user is outside top 3)
// =============================================================================

class _MePinnedRow extends StatelessWidget {
  const _MePinnedRow({
    required this.entry,
    required this.scoreLabel,
    required this.showWins,
  });

  final LeaderboardEntry entry;
  final String scoreLabel;
  final bool showWins;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3A1280), Color(0xFF1B0940)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZcColors.neonPurple.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: ZcColors.neonPurple.withValues(alpha: 0.25),
            blurRadius: 12,
          ),
        ],
      ),
      child: _RankRowContent(
          entry: entry, scoreLabel: scoreLabel, showWins: showWins),
    );
  }
}

// =============================================================================
// RANK ROW
// =============================================================================

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.scoreLabel,
    required this.showWins,
  });

  final LeaderboardEntry entry;
  final String scoreLabel;
  final bool showWins;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isMe
            ? const Color(0x22A855F7)
            : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.isMe
              ? const Color(0x44A855F7)
              : const Color(0x14FFFFFF),
          width: entry.isMe ? 1.4 : 1,
        ),
      ),
      child: _RankRowContent(
          entry: entry, scoreLabel: scoreLabel, showWins: showWins),
    );
  }
}

class _RankRowContent extends StatelessWidget {
  const _RankRowContent({
    required this.entry,
    required this.scoreLabel,
    required this.showWins,
  });

  final LeaderboardEntry entry;
  final String scoreLabel;
  final bool showWins;

  Widget _avatarForId(String id) {
    if (id.startsWith('av_')) return ZcAvatars.forId(id, 38);
    return Image.asset(
      id.isEmpty ? 'assets/art/avatar_01.png' : id,
      width: 38, height: 38, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ZcAvatars.forId('av_default', 38),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Rank number
        SizedBox(
          width: 30,
          child: Text(
            '#${entry.rank}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: entry.rank <= 3
                  ? const Color(0xFFFDE047)
                  : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Avatar
        ClipOval(
          child: SizedBox(
            width: 38,
            height: 38,
            child: _avatarForId(entry.avatar),
          ),
        ),
        const SizedBox(width: 10),
        // Name + sub-info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entry.name.isEmpty ? 'Player' : entry.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.isMe)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: ZcColors.neonPurple.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              if (showWins && entry.wins != null)
                Text(
                  '${entry.wins} wins · ${entry.matches} matches',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        // Score
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.score}',
              style: const TextStyle(
                color: Color(0xFFFDE047),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              scoreLabel,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// HISTORY CARD
// =============================================================================

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});
  final MatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final isWin = entry.isWin;
    final accentColor =
        isWin ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B);
    final diffDays = DateTime.now().difference(entry.endedAt).inDays;
    final when = diffDays == 0
        ? 'Today'
        : diffDays == 1
            ? 'Yesterday'
            : '$diffDays days ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Result badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                isWin ? '🏆' : '💀',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWin ? 'Victory' : 'Defeat',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.seats} players · $when',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${entry.placement} / ${entry.seats}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${entry.finalScore} pts',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED HELPERS
// =============================================================================

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: ZcColors.neonPurple),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white24, size: 56),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
