import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/zc_theme.dart';

/// Where an opponent/player avatar sits relative to the table.
enum AvatarSlot {
  topCenter,
  topLeft,
  topRight,
  left,
  right,
  bottomCenter,
}

/// The immersive play-area theme shown in the mockups.
@immutable
class PlayAreaTheme {
  const PlayAreaTheme({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.backgroundAsset,
    required this.bannerAsset,
    this.tableAsset,
    this.cardBackAsset = 'assets/art/card_back_zero.png',
    required this.tableGradient,
    required this.borderColor,
    required this.borderGlow,
    required this.accent,
    required this.avatarSlots,
    required this.showInfoPanels,
    required this.showHintGroup,
    this.showSidePanels = false,
  });

  final String id;
  final String name;
  final String subtitle;
  final String backgroundAsset;
  final String bannerAsset;
  final String? tableAsset;
  final String cardBackAsset;
  final List<Color> tableGradient;
  final Color borderColor;
  final Color borderGlow;
  final Color accent;
  final List<AvatarSlot> avatarSlots;
  final bool showInfoPanels;
  final bool showHintGroup;
  // Japan theme: shows left scroll + right lantern/bamboo decorations
  final bool showSidePanels;

  /// 0. Sakura Japan Theme (Mount Fuji + Cherry Blossoms + Tatami Table)
  static const sakuraJapan = PlayAreaTheme(
    id: 'sakuraJapan',
    name: 'Sakura Japan',
    subtitle: 'Cherry Blossoms & Mount Fuji',
    backgroundAsset: 'assets/art/th_sakura_garden.png',
    bannerAsset: 'assets/art/th_sakura_garden.png',
    cardBackAsset: 'assets/art/cb_sakura.png',
    tableGradient: [Color(0xFF1A0A0A), Color(0xFF2D0F0F)],
    borderColor: Color(0xFFE8A4B8),
    borderGlow: Color(0xFFFF6B9D),
    accent: Color(0xFFFFD4E8),
    avatarSlots: [AvatarSlot.topCenter, AvatarSlot.left, AvatarSlot.right],
    showInfoPanels: false,
    showHintGroup: false,
    showSidePanels: true,
  );

  /// 1. Brazilian Carnival Theme (Rio de Janeiro Copacabana & Corcovado Night)
  static const brazilCarnival = PlayAreaTheme(
    id: 'brazilCarnival',
    name: 'Brazil Carnival',
    subtitle: 'Night Space',
    backgroundAsset: 'assets/art/play_area_bg_brazil.jpg',
    bannerAsset: 'assets/art/home_brazil_banner.png',
    tableAsset: 'assets/art/play_area_table_brazil.png',
    cardBackAsset: 'assets/art/card_back_brazil.png',
    tableGradient: [Color(0xFF0D6E38), Color(0xFF044823)],
    borderColor: Color(0xFFEAB308),
    borderGlow: Color(0xFF22C55E),
    accent: Color(0xFFFDE047),
    avatarSlots: [AvatarSlot.topCenter, AvatarSlot.left, AvatarSlot.right],
    showInfoPanels: true,
    showHintGroup: true,
  );

  /// 2. Mystic Garden Fantasy Night
  static const mysticGarden = PlayAreaTheme(
    id: 'mysticGarden',
    name: 'Mystic Garden',
    subtitle: 'Fantasy Night',
    backgroundAsset: 'assets/art/play_area_bg_garden.png',
    bannerAsset: 'assets/art/banner_carnival.png',
    tableAsset: 'assets/art/play_area_table_wood_neon.png',
    cardBackAsset: 'assets/art/card_back_zero.png',
    tableGradient: [Color(0xFF270E4A), Color(0xFF160830)],
    borderColor: Color(0xFF6B4423),
    borderGlow: ZcColors.neonPurple,
    accent: ZcColors.neonPurple,
    avatarSlots: [AvatarSlot.topCenter, AvatarSlot.left, AvatarSlot.right],
    showInfoPanels: false,
    showHintGroup: false,
  );

  /// 3. Neon Cyber Night Space
  static const neonCyber = PlayAreaTheme(
    id: 'neonCyber',
    name: 'Neon Cyber',
    subtitle: 'Cyber City',
    backgroundAsset: 'assets/art/play_area_bg_garden.png',
    bannerAsset: 'assets/art/banner_carnival.png',
    tableAsset: 'assets/art/play_area_table_wood_neon.png',
    cardBackAsset: 'assets/art/cb_cyber.png',
    tableGradient: [Color(0xFF0F172A), Color(0xFF020617)],
    borderColor: Color(0xFF06B6D4),
    borderGlow: Color(0xFF38BDF8),
    accent: Color(0xFF06B6D4),
    avatarSlots: [AvatarSlot.topCenter, AvatarSlot.left, AvatarSlot.right],
    showInfoPanels: false,
    showHintGroup: false,
  );

  static const List<PlayAreaTheme> all = [
    sakuraJapan,
    brazilCarnival,
    mysticGarden,
    neonCyber,
  ];

  static PlayAreaTheme get defaultTheme => brazilCarnival;

  static PlayAreaTheme random() => all[0];

  static PlayAreaTheme randomFor(int playerCount) => brazilCarnival;

  /// Returns the theme matching [themeId], falling back to brazilCarnival.
  static PlayAreaTheme forId(String? themeId) {
    if (themeId == null) return brazilCarnival;
    return all.firstWhere((t) => t.id == themeId, orElse: () => brazilCarnival);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayAreaTheme && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Global provider for currently equipped theme.
class EquippedThemeNotifier extends Notifier<PlayAreaTheme> {
  @override
  PlayAreaTheme build() => PlayAreaTheme.brazilCarnival;

  void setTheme(PlayAreaTheme theme) {
    state = theme;
  }
}

final equippedThemeProvider =
    NotifierProvider<EquippedThemeNotifier, PlayAreaTheme>(
  EquippedThemeNotifier.new,
);
