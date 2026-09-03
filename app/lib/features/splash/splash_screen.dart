import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_playing_card.dart';
import '../../ui/zc_theme.dart';
import '../auth/auth_controller.dart';

/// Splash (Main_screen mockup): purple palace background, ZERO COUNT logo,
/// hero card fan (2♣ 5♥ K♦) on a neon glow ring, tagline, LOADING bar,
/// and the four feature icons. Meanwhile the saved session is restored
/// (E3.3): refresh-token rotation sends the user straight to home,
/// otherwise to login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..forward();

  @override
  void initState() {
    super.initState();
    _restoreThenRoute();
  }

  Future<void> _restoreThenRoute() async {
    final restore = ref.read(authControllerProvider.notifier).restore();
    final minSplash =
        Future<void>.delayed(const Duration(milliseconds: 2600));
    await Future.wait([restore, minSplash]);
    if (!mounted) return;
    final status = ref.read(authControllerProvider).status;
    context.go(status == AuthStatus.authenticated ? '/home' : '/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Purple carnival-night palace background.
          Image.asset('assets/art/bg_splash.png', fit: BoxFit.cover),
          // Darken slightly toward the bottom for legibility.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x88050216)],
                stops: [0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity:
                  CurvedAnimation(parent: _controller, curve: Curves.easeOut),
              child: LayoutBuilder(builder: (context, c) {
                // Scale the hero block to the available height so small
                // screens never overflow (mockups are authored at ~800px+).
                final s = (c.maxHeight / 820).clamp(0.55, 1.0);
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                children: [
                  SizedBox(height: 30 * s),
                  // Logo lockup (generated to match the mockup) — the hero.
                  Image.asset(
                    'assets/art/logo.png',
                    key: const Key('splashLogo'),
                    width: 480 * s,
                  ),
                  SizedBox(height: 26 * s),
                  // Hero card fan on a neon glow ring.
                  SizedBox(
                    height: 210 * s,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ZcColors.neonPurple
                                  .withValues(alpha: 0.8),
                              width: 2.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ZcColors.neonPurple
                                    .withValues(alpha: 0.55),
                                blurRadius: 34,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, 26),
                          child: ZcCardFan(
                            cardWidth: 92 * s,
                            overlap: 0.55,
                            fanAngle: 0.16,
                            cards: [
                              ('2', ZcSuit.clubs, 2),
                              ('5', ZcSuit.hearts, 5),
                              ('K', ZcSuit.diamonds, 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18 * s),
                  // Tagline: "≫ Collect, Group & Count Low! ≪" with gold wings.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard_double_arrow_right_rounded,
                          color: ZcColors.gold, size: 26 * s),
                      const SizedBox(width: 8),
                      Text.rich(
                        TextSpan(
                          style: ZcText.heading(21),
                          children: [
                            const TextSpan(text: 'Collect, Group &\nCount '),
                            TextSpan(
                                text: 'Low',
                                style: ZcText.heading(21)
                                    .copyWith(color: ZcColors.textGold)),
                            const TextSpan(text: '!'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.keyboard_double_arrow_left_rounded,
                          color: ZcColors.gold, size: 26 * s),
                    ],
                  ),
                  SizedBox(height: 44 * s),
                  Text('L O A D I N G . . .',
                      style: ZcText.heading(13)
                          .copyWith(color: ZcColors.textSecondary)),
                  const SizedBox(height: 12),
                  // Thick purple loading bar.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 260,
                      height: 12,
                      decoration: BoxDecoration(
                        color: ZcColors.panelInput,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: ZcColors.neonPurpleDim, width: 1),
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => FractionallySizedBox(
                          widthFactor: _controller.value,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                colors: [
                                  ZcColors.neonPurple,
                                  ZcColors.neonPink
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Four feature icons (hidden on very short screens).
                  if (c.maxHeight > 840)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Feature(
                            asset: 'assets/art/icon_players.png',
                            label: 'PLAY WITH\nFRIENDS'),
                        _Feature(
                            asset: 'assets/art/icon_aces.png',
                            label: 'MAKE GROUPS\n& SCORE LOW'),
                        _Feature(
                            asset: 'assets/art/icon_trophy.png',
                            label: 'WIN ROUNDS\n& RANK UP'),
                        _Feature(
                            asset: 'assets/art/gift_box.png',
                            label: 'EARN REWARDS\n& UNLOCK MORE'),
                      ],
                    ),
                  ),
                  SizedBox(height: 20 * s),
                ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(asset, width: 54, height: 54),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: ZcText.heading(10).copyWith(height: 1.35),
        ),
      ],
    );
  }
}
