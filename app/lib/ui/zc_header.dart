import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/player/profile_repository.dart';
import 'zc_theme.dart';

/// Shared screen header used by the V2 mockup screens: back square, title +
/// subtitle, coin/gem pills from the profile and a trailing round button
/// (bell with red badge by default).
class ZcScreenHeader extends ConsumerWidget {
  const ZcScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing = ZcHeaderTrailing.bell,
  });

  final String title;
  final String subtitle;
  final ZcHeaderTrailing trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          const ZcBackButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ZcText.heading(16).copyWith(letterSpacing: 0.5)),
                Text(subtitle, style: ZcText.body(11.5)),
              ],
            ),
          ),
          ZcCurrencyPill(asset: 'assets/art/coin.png', value: '${p?.coins ?? 0}'),
          const SizedBox(width: 6),
          ZcCurrencyPill(asset: 'assets/art/gem.png', value: '${p?.gems ?? 0}'),
          if ((p?.winStreak ?? 0) > 0) ...[
            const SizedBox(width: 6),
            ZcStreakPill(streak: p!.winStreak),
          ],
          const SizedBox(width: 6),
          switch (trailing) {
            ZcHeaderTrailing.bell => const _BellButton(),
            ZcHeaderTrailing.info => const _RoundIconButton(
                icon: Icons.info_outline_rounded),
          },
        ],
      ),
    );
  }
}

enum ZcHeaderTrailing { bell, info }

/// Mockup back button: rounded square, translucent fill, thin outline.
class ZcBackButton extends StatelessWidget {
  const ZcBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (context.canPop()) context.pop();
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0x990D0330),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x40FFFFFF), width: 1.1),
          ),
          child: const Icon(Icons.chevron_left_rounded,
              color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Coin/gem pill: icon + value + green plus badge.
class ZcCurrencyPill extends StatelessWidget {
  const ZcCurrencyPill({super.key, required this.asset, required this.value});

  final String asset;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 4, 3),
      decoration: BoxDecoration(
        color: const Color(0x990D0330),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x33FFFFFF), width: 1),
      ),
      child: Row(children: [
        Image.asset(asset, width: 17, height: 17),
        const SizedBox(width: 3),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 2),
        const CircleAvatar(
          radius: 7,
          backgroundColor: ZcColors.onlineGreen,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 11),
        ),
      ]),
    );
  }
}

/// R1.6 — win-streak flame pill shown next to the currency chips.
class ZcStreakPill extends StatelessWidget {
  const ZcStreakPill({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEF4444)],
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🔥', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 3),
        Text(
          '$streak',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ]),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const _RoundIconButton(icon: Icons.notifications_rounded),
        Positioned(
          right: -1,
          top: -3,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
                color: ZcColors.errorRed, shape: BoxShape.circle),
            child: const Text('3',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 15,
      backgroundColor: const Color(0x2EFFFFFF),
      child: Icon(icon, color: Colors.white, size: 17),
    );
  }
}
