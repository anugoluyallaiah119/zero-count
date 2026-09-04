import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_playing_card.dart';
import '../../ui/zc_theme.dart';
import '../auth/avatar_catalog.dart';
import '../game/play_area_theme.dart';
import '../player/profile_repository.dart';

/// Home (E3.4) — pixel-matched to the approved combination of both home
/// mockups: Home2's "CURRENT MIND SPACE" carnival banner + Home1's single
/// bottom nav. Live profile from GET /api/players/me (E2.4).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coming soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ZcColors.panelInput,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
        child: SafeArea(
          child: RefreshIndicator(
            color: ZcColors.gold,
            backgroundColor: ZcColors.panelInput,
            onRefresh: () async => ref.invalidate(profileProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    profile: profile,
                    onBell: () => context.push('/friends'),
                    onSettings: () => context.push('/tutorial'),
                  ),
                  const SizedBox(height: 14),
                  const _MindSpaceBanner(),
                  const SizedBox(height: 16),
                  const _SectionHeader('PLAY'),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ModePanel(
                          key: const Key('playVsAiButton'),
                          fill: ZcColors.panelPurple,
                          border: ZcColors.neonPurple,
                          cards: const [
                            ('2', ZcSuit.clubs, 2),
                            ('5', ZcSuit.hearts, 5),
                            ('K', ZcSuit.diamonds, 10),
                          ],
                          title: 'QUICK PLAY',
                          subtitle: '7 Cards',
                          meta1: '2 - 4 Players',
                          meta2: '5 - 10 min',
                          onTap: () =>
                              context.push('/choose-game', extra: 'quick'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModePanel(
                          key: const Key('playWithFriendsButton'),
                          fill: ZcColors.panelDeepBlue,
                          border: ZcColors.neonBlue,
                          cards: const [
                            ('J', ZcSuit.spades, 10),
                            ('Q', ZcSuit.hearts, 10),
                            ('K', ZcSuit.diamonds, 10),
                          ],
                          title: 'CLASSIC PLAY',
                          subtitle: '13 Cards',
                          meta1: '2 - 4 Players',
                          meta2: '10 - 20 min',
                          onTap: () =>
                              context.push('/choose-game', extra: 'classic'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _SectionHeader('SOCIAL'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialPanel(
                          fill: ZcColors.panelPurple,
                          border: ZcColors.neonPurple,
                          iconAsset: 'assets/art/icon_players.png',
                          title: 'CREATE ROOM',
                          subtitle: 'Create a room and\ninvite your friends',
                          buttonLabel: 'CREATE ROOM',
                          buttonColor: ZcColors.gemPurple,
                          onTap: () => context.push('/create-room'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SocialPanel(
                          fill: ZcColors.panelGreen,
                          border: ZcColors.neonGreen,
                          iconAsset: 'assets/art/door_join.png',
                          title: 'JOIN ROOM',
                          subtitle: 'Enter room code\nand join the fun',
                          buttonLabel: 'JOIN ROOM',
                          buttonColor: ZcColors.takeGreen,
                          onTap: () => context.push('/join-room'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _SectionHeader('DAILY CHALLENGE'),
                  const SizedBox(height: 10),
                  const _DailyChallenge(),
                  const SizedBox(height: 16),
                  _BottomNav(onComingSoon: () => _comingSoon(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header: avatar + name + level/XP (left), coins/gems pills + bell + gear.
class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.onBell,
    required this.onSettings,
  });

  final AsyncValue<PlayerProfile> profile;
  final VoidCallback onBell;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final p = profile.valueOrNull;
    final level = p?.level ?? 1;
    final xp = p == null ? 0 : (p.matches % 10) * 150;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar with level badge — taps to the profile screen.
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ZcColors.gold, width: 2.5),
              ),
              child: ClipOval(
                child: profile.isLoading
                    ? const ColoredBox(
                        key: Key('profileLoading'), color: ZcColors.panelInput)
                    : Image.asset(avatarAsset(p?.avatar ?? ''),
                        fit: BoxFit.cover),
              ),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7B2FF7), Color(0xFF4A11B8)]),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Text('$level',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p?.displayName ?? '…',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 1),
              Text('Level $level · ELO ${p?.elo ?? 0}',
                  key: const Key('profileSummary'),
                  style: const TextStyle(
                      color: ZcColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 7,
                  child: Stack(children: [
                    const ColoredBox(color: Color(0x26FFFFFF)),
                    FractionallySizedBox(
                      widthFactor: (p?.levelProgress ?? 0).clamp(0.0, 1.0),
                      child: const ColoredBox(color: ZcColors.gemPurple),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 3),
              Text('$xp / 1500 XP',
                  style: const TextStyle(
                      color: ZcColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(children: [
              _CurrencyPill(
                  asset: 'assets/art/coin.png', value: '${p?.coins ?? 0}'),
              const SizedBox(width: 6),
              _CurrencyPill(
                  asset: 'assets/art/gem.png', value: '${p?.gems ?? 0}'),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: onBell,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.notifications_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                  const Positioned(
                    right: -2,
                    top: -2,
                    child: CircleAvatar(
                        radius: 7,
                        backgroundColor: ZcColors.errorRed,
                        child: Text('3',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800))),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              InkWell(
                key: const Key('howToPlayButton'),
                onTap: onSettings,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.settings_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ]),
          ],
        ),
      ],
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.asset, required this.value});

  final String asset;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 4, 3),
      decoration: BoxDecoration(
        color: const Color(0x990D0330),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33FFFFFF), width: 1),
      ),
      child: Row(
        children: [
          Image.asset(asset, width: 20, height: 20),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 3),
          const CircleAvatar(
            radius: 8,
            backgroundColor: ZcColors.onlineGreen,
            child:
                Icon(Icons.add_rounded, color: Colors.white, size: 13),
          ),
        ],
      ),
    );
  }
}

/// CURRENT MIND SPACE swipeable theme carousel (Home_screen2).
class _MindSpaceBanner extends ConsumerStatefulWidget {
  const _MindSpaceBanner();

  @override
  ConsumerState<_MindSpaceBanner> createState() => _MindSpaceBannerState();
}

class _MindSpaceBannerState extends ConsumerState<_MindSpaceBanner> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final equipped = ref.read(equippedThemeProvider);
    final initialIndex = PlayAreaTheme.all.indexWhere((t) => t.id == equipped.id);
    _currentPage = initialIndex >= 0 ? initialIndex : 0;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final equippedTheme = ref.watch(equippedThemeProvider);
    final themes = PlayAreaTheme.all;

    return Container(
      height: 218,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ZcColors.neonPurple.withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: ZcColors.neonPurple.withValues(alpha: 0.25),
            blurRadius: 18,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Swipeable Theme Cards
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                ref.read(equippedThemeProvider.notifier).setTheme(themes[index]);
              },
              itemCount: themes.length,
              itemBuilder: (context, index) {
                final theme = themes[index];
                final isEquipped = theme.id == equippedTheme.id;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      theme.bannerAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/art/banner_carnival.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xF008051E), Color(0x4008051E)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'CURRENT MIND SPACE',
                                style: ZcText.body(
                                  10.5,
                                  color: const Color(0xFFC084FC),
                                  weight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ZcColors.takeGreenDark,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: ZcColors.onlineGreen,
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_rounded,
                                        color: Colors.white, size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'Owned',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            theme.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            theme.subtitle,
                            style: const TextStyle(
                              color: ZcColors.gold,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.groups_rounded,
                                  color: ZcColors.textSecondary, size: 14),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Used by you in this lobby',
                                  overflow: TextOverflow.ellipsis,
                                  style: ZcText.body(11),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.help_outline_rounded,
                                  color: ZcColors.textSecondary, size: 14),
                            ],
                          ),
                          const Spacer(),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    ref.read(equippedThemeProvider.notifier).setTheme(theme);
                                    context.push('/choose-game', extra: 'quick');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x66000000),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0x66FFFFFF),
                                        width: 1.1,
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.visibility_rounded,
                                            color: Colors.white, size: 13),
                                        SizedBox(width: 5),
                                        Text(
                                          'Preview in Game',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    ref.read(equippedThemeProvider.notifier).setTheme(theme);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${theme.name} theme equipped!'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: const Color(0xFF22C55E),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: isEquipped
                                          ? const LinearGradient(
                                              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                            )
                                          : ZcColors.goldGradient,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isEquipped ? 'EQUIPPED ✓' : 'CHANGE THEME',
                                      style: TextStyle(
                                        color: isEquipped ? Colors.white : ZcColors.goldText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            // Indicator Dots
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < themes.length; i++)
                    _Dot(active: i == _currentPage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.active = false});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 16 : 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFDE047) : Colors.white24,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// ≫ PLAY ≪ section header.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('≫', style: ZcText.body(15, color: ZcColors.gold)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6)),
        const SizedBox(width: 8),
        Text('≪', style: ZcText.body(15, color: ZcColors.gold)),
      ],
    );
  }
}

/// QUICK PLAY / CLASSIC PLAY mode panel with vector card fan.
class _ModePanel extends StatelessWidget {
  const _ModePanel({
    super.key,
    required this.fill,
    required this.border,
    required this.cards,
    required this.title,
    required this.subtitle,
    required this.meta1,
    required this.meta2,
    required this.onTap,
  });

  final Color fill;
  final Color border;
  final List<(String, ZcSuit, int)> cards;
  final String title;
  final String subtitle;
  final String meta1;
  final String meta2;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: border.withValues(alpha: 0.55), width: 1.5),
            boxShadow: [
              BoxShadow(color: border.withValues(alpha: 0.28), blurRadius: 16),
            ],
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0x33FFFFFF),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              ZcCardFan(cards: cards, cardWidth: 44, overlap: 0.55),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8)),
              Text(subtitle,
                  style: const TextStyle(
                      color: ZcColors.gold,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0x55000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.groups_rounded,
                        color: ZcColors.gemPurple, size: 14),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(meta1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: SizedBox(
                          height: 12,
                          child: VerticalDivider(
                              color: Color(0x33FFFFFF), width: 1)),
                    ),
                    const Icon(Icons.schedule_rounded,
                        color: ZcColors.gemPurple, size: 14),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(meta2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CREATE ROOM / JOIN ROOM social panel.
class _SocialPanel extends StatelessWidget {
  const _SocialPanel({
    required this.fill,
    required this.border,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onTap,
  });

  final Color fill;
  final Color border;
  final String iconAsset;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Image.asset(iconAsset, width: 40, height: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(subtitle,
              style: ZcText.body(11).copyWith(height: 1.3)),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: buttonColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(buttonLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 15),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// DAILY CHALLENGE strip.
class _DailyChallenge extends StatelessWidget {
  const _DailyChallenge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZcColors.panelPurple,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: ZcColors.neonPurple.withValues(alpha: 0.45), width: 1.3),
      ),
      child: Row(
        children: [
          Image.asset('assets/art/icon_target.png', width: 46, height: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create 2 ZERO groups in any game',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const SizedBox(
                        height: 7,
                        child: Stack(children: [
                          ColoredBox(color: Color(0x26FFFFFF)),
                          FractionallySizedBox(
                            widthFactor: 0.5,
                            child: ColoredBox(color: ZcColors.gold),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('1 / 2',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 7),
                Row(children: [
                  Text('REWARD',
                      style: ZcText.body(10,
                          color: ZcColors.gold, weight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Image.asset('assets/art/coin.png', width: 15, height: 15),
                  const SizedBox(width: 3),
                  const Text('50',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Image.asset('assets/art/gem.png', width: 15, height: 15),
                  const SizedBox(width: 3),
                  const Text('5',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              gradient: ZcColors.goldGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('PLAY NOW',
                style: TextStyle(
                    color: ZcColors.goldText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

/// Bottom nav (Home_screen1 single bar): HOME active, FRIENDS/RANKING/STORE.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.onComingSoon});

  final VoidCallback onComingSoon;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label,
        {bool active = false, VoidCallback? onTap}) {
      final color = active ? ZcColors.gold : Colors.white;
      return Expanded(
        child: Opacity(
          opacity: active ? 1 : 0.55,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: active
                  ? BoxDecoration(
                      color: ZcColors.gemPurple.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 21),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC0D0330),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1),
      ),
      child: Row(
        children: [
          item(Icons.home_rounded, 'HOME', active: true, onTap: () {}),
          item(Icons.calendar_month_rounded, 'EVENTS',
              onTap: () => context.push('/events')),
          item(Icons.style_rounded, 'COLLECTION',
              onTap: () => context.push('/collection')),
          item(Icons.group_rounded, 'FRIENDS',
              onTap: () => context.push('/invite-friends')),
        ],
      ),
    );
  }
}
