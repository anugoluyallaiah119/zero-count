import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'zc_theme.dart';

/// Shared 5-tab bottom navigation from the V2 mockups:
/// Home · Play · Events · Collection · Profile.
/// The active tab shows a rounded pill (dark screens: purple glow pill,
/// light screens: purple text).
enum ZcNavTab { home, play, events, collection, profile }

class ZcBottomNav extends StatelessWidget {
  const ZcBottomNav({super.key, required this.active, this.dark = true});

  final ZcNavTab active;

  /// Dark bar (Events) vs light bar (Collection screens).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xF20A0420) : Colors.white;
    final divider = dark ? const Color(0x22FFFFFF) : const Color(0x11000000);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: divider, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 14),
      child: Row(
        children: [
          _item(context, ZcNavTab.home, Icons.home_rounded, 'Home'),
          _item(context, ZcNavTab.play, Icons.play_arrow_rounded, 'Play'),
          _item(context, ZcNavTab.events, Icons.calendar_month_rounded,
              'Events'),
          _item(context, ZcNavTab.collection, Icons.style_rounded,
              'Collection'),
          _item(context, ZcNavTab.profile, Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _item(
      BuildContext context, ZcNavTab tab, IconData icon, String label) {
    final isActive = tab == active;
    final inactive =
        dark ? const Color(0xFF8E84B0) : const Color(0xFF8A83A3);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _go(context, tab),
        child: isActive && dark
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF5A1FA8), Color(0xFF3A1280)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: ZcColors.neonPurple.withValues(alpha: 0.6),
                          width: 1.2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(height: 2),
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      color: isActive ? const Color(0xFF7C3AED) : inactive,
                      size: 23),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? const Color(0xFF7C3AED) : inactive,
                      fontSize: 10.5,
                      fontWeight:
                          isActive ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _go(BuildContext context, ZcNavTab tab) {
    if (tab == active) return;
    switch (tab) {
      case ZcNavTab.home:
        context.go('/home');
      case ZcNavTab.play:
        context.go('/choose-game');
      case ZcNavTab.events:
        context.go('/events');
      case ZcNavTab.collection:
        context.go('/collection');
      case ZcNavTab.profile:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile hub arrives in the next phase')));
    }
  }
}
