import 'package:flutter/material.dart';

/// Zero Count visual identity — a faithful, polished port of the V1 web
/// design (frozen `app/index.html` spec).
///
/// Tokens are lifted 1:1 from V1's CSS:
///   canvas    : linear-gradient(170deg, #3b2270 0%, #241546 45%, #160d2e)
///   accents   : yellow #ffb830, orange #ff9d1b, green #2fbf5f,
///               red #e74c3c, blue #3d8bff, purple #8a3ffb
///   CTA style : chunky gradient buttons with a 4px darker "bevel" shadow
///   cards     : white gradient faces, blue radial backs
///   table     : green radial felt with a wooden rim
/// Typography  : system-ui (V1 used Segoe UI / system-ui).
class ZeroCountTheme {
  ZeroCountTheme._();

  // ---- canvas ----
  static const Color canvasTop = Color(0xFF3B2270);
  static const Color canvasMid = Color(0xFF241546);
  static const Color canvasBottom = Color(0xFF160D2E);

  /// V1 `linear-gradient(170deg, …)` ≈ top-slightly-right → bottom.
  static const LinearGradient canvasGradient = LinearGradient(
    begin: Alignment(0.17, -1),
    end: Alignment(-0.17, 1),
    colors: [canvasTop, canvasMid, canvasBottom],
    stops: [0.0, 0.45, 1.0],
  );

  // ---- accents (V1 :root) ----
  static const Color yellow = Color(0xFFFFB830);
  static const Color orange = Color(0xFFFF9D1B);
  static const Color green = Color(0xFF2FBF5F);
  static const Color red = Color(0xFFE74C3C);
  static const Color blue = Color(0xFF3D8BFF);
  static const Color purple = Color(0xFF8A3FFB);

  // ---- button gradients + bevel colors (V1 .btn.*) ----
  static const LinearGradient yellowGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFC94D), yellow],
  );
  static const Color yellowBevel = Color(0xFFC78F12);
  static const Color yellowText = Color(0xFF3A2703);

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3DD670), green],
  );
  static const Color greenBevel = Color(0xFF1A7A43);

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF9D55FF), purple],
  );
  static const Color purpleBevel = Color(0xFF5B21B6);

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5EA0FF), blue],
  );
  static const Color blueBevel = Color(0xFF2170A8);

  /// V1 home "QUICK PLAY" tile (120deg yellow→orange).
  static const LinearGradient quickTileGradient = LinearGradient(
    begin: Alignment(-1, -0.55),
    end: Alignment(1, 0.55),
    colors: [Color(0xFFFFC94D), orange],
  );

  /// V1 home "CLASSIC PLAY" tile (120deg light-blue→blue).
  static const LinearGradient classicTileGradient = LinearGradient(
    begin: Alignment(-1, -0.55),
    end: Alignment(1, 0.55),
    colors: [Color(0xFF5EA0FF), blue],
  );

  /// V1 avatar/icon circle: radial violet.
  static const RadialGradient avatarGradient = RadialGradient(
    center: Alignment(-0.35, -0.45),
    radius: 1.1,
    colors: [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
  );

  // ---- surfaces ----
  static const Color inputFill = Color(0xFF31215A);
  static const Color overlay = Color(0x40000000); // rgba(0,0,0,.25)
  static const Color overlayDark = Color(0x59000000); // rgba(0,0,0,.35)
  static const Color linkPurple = Color(0xFFB678F0);

  // ---- playing cards ----
  static const LinearGradient cardFace = LinearGradient(
    begin: Alignment(-0.7, -1),
    end: Alignment(0.7, 1),
    colors: [Color(0xFFFFFFFF), Color(0xFFF2F2F0)],
  );
  static const Color cardInk = Color(0xFF20232A);
  static const Color cardRed = Color(0xFFE0392F);
  static const Color cardValueChipText = Color(0xFFFFD54F);
  static const Color cardBackBlue = Color(0xFF2B4ACB);
  static const Color cardBackBlueLight = Color(0xFF3B5AE0);

  // ---- game table (reserved for E3.5) ----
  static const RadialGradient feltGradient = RadialGradient(
    center: Alignment(0, -0.24),
    radius: 1.15,
    colors: [Color(0xFF217A52), Color(0xFF17573C), Color(0xFF0F4030)],
    stops: [0.0, 0.55, 1.0],
  );
  static const Color tableRim = Color(0xFF6B4A2A);
  static const Color tableRimInner = Color(0xFF4A2F18);

  // ---- typography ----
  static const String fontFamilyFallback = 'system-ui';

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        // Deterministic ripple (InkSparkle's shader asset is unavailable in
        // widget tests and inconsistent across devices).
        splashFactory: InkRipple.splashFactory,
        scaffoldBackgroundColor: canvasBottom,
        colorScheme: const ColorScheme.dark(
          primary: yellow,
          secondary: purple,
          surface: inputFill,
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 40,
              letterSpacing: 1.5),
          headlineLarge: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24),
          titleLarge: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          bodyMedium: TextStyle(
              color: Color(0xD9FFFFFF), // white @ 85%
              fontSize: 14,
              height: 1.5),
          labelLarge: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 1),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFill,
          hintStyle: const TextStyle(color: Color(0x80FFFFFF)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x26FFFFFF), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: yellow, width: 1.5),
          ),
        ),
      );
}

/// V1's signature "chunky" button: bright gradient face, 4px solid darker
/// bevel underneath, subtle press sink. Used for every primary action.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = ZeroCountTheme.yellowGradient,
    this.bevelColor = ZeroCountTheme.yellowBevel,
    this.textColor = ZeroCountTheme.yellowText,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final Color bevelColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.32,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            // V1: box-shadow: 0 4px 0 <bevel> — a solid bottom edge.
            BoxShadow(color: bevelColor, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: textColor, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(label,
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-bleed purple canvas every screen sits on.
class CanvasBackground extends StatelessWidget {
  const CanvasBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: ZeroCountTheme.canvasGradient),
      child: child,
    );
  }
}

/// V1 iconCircle / avatar — radial violet disc with a soft glow.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    this.radius = 46,
    this.icon = Icons.person_rounded,
    this.iconSize,
  });

  final double radius;
  final IconData icon;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        gradient: ZeroCountTheme.avatarGradient,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
            BorderSide(color: Color(0x4DFFFFFF), width: 2)),
        boxShadow: [
          BoxShadow(
              color: Color(0x808B5CF6), blurRadius: 30, spreadRadius: -4),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize ?? radius),
    );
  }
}
