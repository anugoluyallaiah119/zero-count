import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_cosmetics.dart';
import '../../ui/zc_theme.dart';
import '../../ui/zc_bottom_nav.dart';
import '../auth/avatar_catalog.dart';
import '../player/achievement_repository.dart';
import '../player/profile_repository.dart';
import 'edit_profile_sheet.dart';

/// Full player profile page — stats, cosmetics shortcuts, match history,
/// notification settings, leaderboard shortcut.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
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
          child: profileAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: ZcColors.neonPurple)),
            error: (e, _) => Center(
                child: Text(e.toString(),
                    style: const TextStyle(color: Colors.white54))),
            data: (p) => _Body(profile: p),
          ),
        ),
      ),
      bottomNavigationBar:
          const ZcBottomNav(active: ZcNavTab.profile, dark: true),
    );
  }
}

// =============================================================================
// BODY
// =============================================================================

class _Body extends ConsumerWidget {
  const _Body({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: ZcColors.gold,
      backgroundColor: const Color(0xFF1A0B3D),
      onRefresh: () async => ref.invalidate(profileProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _Header(profile: profile),
            const SizedBox(height: 6),
            _StatsRow(profile: profile),
            const SizedBox(height: 14),
            _QuickLinks(profile: profile),
            const SizedBox(height: 14),
            _AchievementsSkeleton(profile: profile),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HEADER — avatar, name, phone, ELO badge, edit button
// =============================================================================

class _Header extends ConsumerWidget {
  const _Header({required this.profile});
  final PlayerProfile profile;

  Widget _avatar(String id, double size) {
    if (id.startsWith('av_')) return ZcAvatars.forId(id, size);
    final opt = kAvatars.firstWhere((a) => a.id == id,
        orElse: () => kAvatars.first);
    return Image.asset(opt.asset,
        width: size, height: size, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Background wave
        Container(
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A0E5C), Color(0x00000000)],
            ),
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 16),
            // Back + settings row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0x22FFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0x33FFFFFF),
                              width: 1.1),
                        ),
                        child: const Icon(Icons.chevron_left_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          context.push('/notification-settings'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0x22FFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0x33FFFFFF),
                              width: 1.1),
                        ),
                        child: const Icon(
                            Icons.notifications_rounded,
                            color: Colors.white70,
                            size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Avatar ring
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ZcColors.gold, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: ZcColors.gold.withValues(alpha: 0.45),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _avatar(
                      profile.avatar.isNotEmpty
                          ? profile.avatar
                          : 'av_default',
                      90,
                    ),
                  ),
                ),
                // Edit pencil badge
                GestureDetector(
                  onTap: () => _openEdit(context, ref),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ZcColors.neonPurple,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF09031E),
                          width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Name
            Text(
              profile.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.phoneMasked,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            // ELO + level row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Pill('ELO ${profile.elo}',
                    const Color(0xFFFDE047), Icons.bolt_rounded),
                const SizedBox(width: 10),
                _Pill('Level ${profile.level}',
                    ZcColors.neonPurple, Icons.star_rounded),
                if (profile.winStreak > 0) ...[
                  const SizedBox(width: 10),
                  _Pill('Streak ${profile.winStreak}',
                      const Color(0xFFF97316), Icons.local_fire_department_rounded),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }

  void _openEdit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(profile: profile),
    ).then((changed) {
      if (changed == true) ref.invalidate(profileProvider);
    });
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STATS ROW
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Row(
          children: [
            _StatCell(
                value: '${profile.matches}', label: 'Matches'),
            _divider(),
            _StatCell(
                value: '${profile.wins}', label: 'Wins'),
            _divider(),
            _StatCell(
                value: profile.bestCount < 0
                    ? '—'
                    : '${profile.bestCount}',
                label: 'Best Score'),
            _divider(),
            _StatCell(
                value: '${profile.zerosMade}', label: 'Zeros'),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: const Color(0x22FFFFFF),
      );
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// QUICK LINKS
// =============================================================================

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('QUICK LINKS'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.people_rounded,
                  label: 'Friends',
                  subtitle: 'Invite & challenge',
                  color: const Color(0xFF38BDF8),
                  onTap: () => context.push('/friends'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.leaderboard_rounded,
                  label: 'Leaderboard',
                  subtitle: 'Weekly & All-Time',
                  color: const Color(0xFFFDE047),
                  onTap: () => context.push('/leaderboard'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Store',
                  subtitle: 'Cosmetics',
                  color: ZcColors.neonPurple,
                  onTap: () => context.go('/collection'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  subtitle: 'Manage alerts',
                  color: const Color(0xFFF97316),
                  onTap: () =>
                      context.push('/notification-settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: color.withValues(alpha: 0.25), width: 1.1),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        )),
                    Text(subtitle,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ACHIEVEMENTS — V2.3 real grid
// =============================================================================

class _AchievementsSkeleton extends ConsumerWidget {
  const _AchievementsSkeleton({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('HIGHLIGHTS'),
          const SizedBox(height: 8),
          Row(
            children: [
              _HighlightCard(
                emoji: '🏆',
                title: '${profile.wins}',
                subtitle: 'Total Wins',
                color: const Color(0xFFD4AF37),
              ),
              const SizedBox(width: 10),
              _HighlightCard(
                emoji: '🔥',
                title: '${profile.winStreak}',
                subtitle: 'Best Streak',
                color: const Color(0xFFF97316),
              ),
              const SizedBox(width: 10),
              _HighlightCard(
                emoji: '0️⃣',
                title: '${profile.zerosMade}',
                subtitle: 'Zeros Made',
                color: const Color(0xFF4ADE80),
              ),
            ],
          ),
          const SizedBox(height: 16),
          achievementsAsync.when(
            loading: () => const _AchievementShimmer(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) => _AchievementsGrid(achievements: list),
          ),
        ],
      ),
    );
  }
}

class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({required this.achievements});
  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final earned = achievements.where((a) => a.earned).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionLabel('ACHIEVEMENTS'),
            const Spacer(),
            Text(
              '$earned / ${achievements.length}',
              style: const TextStyle(
                  color: ZcColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: achievements.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (_, i) => _AchievementTile(a: achievements[i]),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.a});
  final Achievement a;

  @override
  Widget build(BuildContext context) {
    final color = Achievement.rarityColor(a.rarity);
    return Tooltip(
      message: '${a.title}\n${a.description}'
          '${a.rewardCoins > 0 ? '\n+${a.rewardCoins} coins' : ''}',
      child: Container(
        decoration: BoxDecoration(
          color: a.earned
              ? color.withValues(alpha: 0.15)
              : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: a.earned
                ? color.withValues(alpha: 0.5)
                : const Color(0x18FFFFFF),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: a.earned
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      0.4, 0,
                    ]),
              child: Text(a.icon,
                  style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 4),
            Text(
              a.title,
              style: TextStyle(
                color: a.earned ? Colors.white : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementShimmer extends StatelessWidget {
  const _AchievementShimmer();
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: color.withValues(alpha: 0.3), width: 1.1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      );
}
