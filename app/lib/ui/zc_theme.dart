import 'package:flutter/material.dart';

/// Zero Count V2 design tokens — colors measured directly from the approved
/// UI mockups (dark purple carnival casino theme).
class ZcColors {
  ZcColors._();

  // Backgrounds (vertical gradient, top → bottom)
  static const bgTop = Color(0xFF0D0328);
  static const bgBottom = Color(0xFF08051E);
  static const bgLogin = Color(0xFF16083D);

  // Panels
  static const panelPurple = Color(0xFF130B3B); // quick-play / default card
  static const panelDeepBlue = Color(0xFF000A2C); // classic-play card
  static const panelGreen = Color(0xFF0D2C15); // join-room card
  static const panelInput = Color(0xFF1D0A4B); // input fills / inner panels

  // Neon / glow accents
  static const neonPurple = Color(0xFF9B30FF);
  static const neonPurpleDim = Color(0xFF27075B);
  static const neonPink = Color(0xFFD846CB);
  static const neonGreen = Color(0xFF2EEA6A);
  static const neonBlue = Color(0xFF2E7CF6);

  // Gold CTA (CONTINUE / JOIN / VERIFY buttons)
  static const goldLight = Color(0xFFFDE03A);
  static const gold = Color(0xFFFDC421);
  static const goldDark = Color(0xFFF9A809);
  static const goldText = Color(0xFF1A0B3C); // dark text on gold

  // Action buttons (live game)
  static const drawBlue = Color(0xFF1565E8);
  static const drawBlueDark = Color(0xFF0B3FA0);
  static const takeGreen = Color(0xFF18B84A);
  static const takeGreenDark = Color(0xFF0B7A30);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB9A8E0);
  static const textGold = Color(0xFFFDC421);
  static const textGreen = Color(0xFF2EEA6A);

  // Currency / status
  static const gemPurple = Color(0xFFB04DFF);
  static const onlineGreen = Color(0xFF2EEA6A);
  static const errorRed = Color(0xFFE5484D);

  // Card faces
  static const cardFace = Color(0xFFFFFFFF);
  static const cardRed = Color(0xFFD21F3C);
  static const cardBlack = Color(0xFF1B1B22);
  static const valueChip = Color(0xFF23232B);

  static const bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, gold, goldDark],
  );
}

class ZcRadii {
  ZcRadii._();
  static const panel = 20.0;
  static const button = 14.0;
  static const chip = 12.0;
  static const card = 10.0;
}

class ZcText {
  ZcText._();

  // Display font is Bungee (loaded via google_fonts at runtime); fallbacks
  // keep tests/headless rendering stable.
  static TextStyle display(double size,
          {Color color = ZcColors.textPrimary, double spacing = 1.2}) =>
      TextStyle(
        fontFamily: 'Bungee',
        fontSize: size,
        color: color,
        letterSpacing: spacing,
        fontWeight: FontWeight.w400,
      );

  static TextStyle heading(double size,
          {Color color = ZcColors.textPrimary}) =>
      TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w800,
      );

  static TextStyle body(double size,
          {Color color = ZcColors.textSecondary,
          FontWeight weight = FontWeight.w600}) =>
      TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        color: color,
        fontWeight: weight,
      );
}

/// Reusable glow decoration for neon-bordered panels.
BoxDecoration zcGlowPanel({
  Color fill = ZcColors.panelPurple,
  Color border = ZcColors.neonPurple,
  double radius = ZcRadii.panel,
  double borderWidth = 1.6,
  bool selected = false,
}) {
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: selected ? border : border.withValues(alpha: 0.45),
      width: selected ? borderWidth + 0.6 : borderWidth,
    ),
    boxShadow: selected
        ? [BoxShadow(color: border.withValues(alpha: 0.55), blurRadius: 18, spreadRadius: 1)]
        : null,
  );
}
