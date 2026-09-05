import 'dart:math';

import 'package:flutter/material.dart';

import 'play_area_theme.dart';

/// Full-screen background for the active theme: bg image + ambient glow + side panels.
/// Drop this as the first layer in PlayAreaTable's root Stack.
class PlayAreaBackground extends StatelessWidget {
  const PlayAreaBackground({super.key, required this.theme});

  final PlayAreaTheme theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fallback deep-space gradient shown while image loads
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0C0420),
                Color(0xFF19093E),
                Color(0xFF130630),
                Color(0xFF0B031A),
              ],
              stops: [0.0, 0.4, 0.75, 1.0],
            ),
          ),
        ),

        // Theme background image
        Image.asset(
          theme.backgroundAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),

        // Ambient atmospheric glow overlay
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.10),
              radius: 0.95,
              colors: [
                Color(0x308B5CF6),
                Color(0x103B0764),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Japan theme: left scroll + right bamboo/lantern side panels
        if (theme.showSidePanels) ...[
          Positioned(
            left: 0, top: 60, bottom: 120, width: 52,
            child: _JapanLeftPanel(),
          ),
          Positioned(
            right: 0, top: 60, bottom: 120, width: 52,
            child: _JapanRightPanel(),
          ),
        ],
      ],
    );
  }
}

/// The oval table felt: renders the theme's table asset (or fallback gradient),
/// the traveling border glow, theme-specific decorations, and the center gameplay
/// widgets passed via [centerContent].
class PlayAreaTableFelt extends StatelessWidget {
  const PlayAreaTableFelt({
    super.key,
    required this.theme,
    required this.glowAlignment,
    required this.centerContent,
    this.isMyTurn = false,
    this.onHint,
    this.onGroup,
  });

  final PlayAreaTheme theme;
  final Alignment glowAlignment;
  final Widget centerContent;
  final bool isMyTurn;
  final VoidCallback? onHint;
  final VoidCallback? onGroup;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Table surface: PNG asset or gradient fallback
        Positioned.fill(
          child: theme.tableAsset != null
              ? Image.asset(
                  theme.tableAsset!,
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => _FallbackFelt(theme: theme),
                )
              : _FallbackFelt(theme: theme),
        ),

        // Traveling neon border glow (driven by ambient animation)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              gradient: RadialGradient(
                center: glowAlignment,
                radius: 0.85,
                colors: [
                  theme.borderGlow.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Brazil-style floating HINT + GROUP dock on right edge of table
        if (theme.showHintGroup) ...[
          Positioned(
            right: 10,
            top: 120,
            child: _HintGroupDock(onHint: onHint, onGroup: onGroup),
          ),
          // YOUR TURN pill top-right
          if (isMyTurn)
            Positioned(
              right: 20,
              top: 24,
              child: _YourTurnPill(),
            ),
        ],

        // Japan theme: Enso ink circle + 零 kanji on tatami surface
        if (theme.showSidePanels)
          Center(
            child: CustomPaint(
              size: const Size(180, 180),
              painter: _EnsoPainter(),
            ),
          ),

        // Gameplay widgets (piles, turn banner, etc.)
        centerContent,
      ],
    );
  }
}

// ── Japan left scroll panel ─────────────────────────────────────────────────

class _JapanLeftPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC1A0800),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
        border: Border.all(color: const Color(0x44E8A4B8), width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(height: 1, color: const Color(0x88E8A4B8)),
          const SizedBox(height: 12),
          const Text('雅',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 26,
                  color: Color(0xFFE8A4B8),
                  fontWeight: FontWeight.w900,
                  height: 1.0)),
          const SizedBox(height: 10),
          Container(width: 24, height: 1, color: const Color(0x66E8A4B8)),
          const SizedBox(height: 10),
          for (final c in ['Z', 'E', 'R', 'O', '', 'C', 'O', 'U', 'N', 'T'])
            Text(c,
                style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Color(0xCCFFD4E8),
                    height: 1.5)),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0x88E8A4B8)),
        ],
      ),
    );
  }
}

// ── Japan right bamboo/lantern panel ────────────────────────────────────────

class _JapanRightPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC1A0800),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
        border: Border.all(color: const Color(0x44E8A4B8), width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(height: 1, color: const Color(0x88E8A4B8)),
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xAACC2200),
              border: Border.all(color: const Color(0x88FF6B9D), width: 1),
            ),
            alignment: Alignment.center,
            child: const Text('和',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.0)),
          ),
          const SizedBox(height: 10),
          Container(width: 24, height: 1, color: const Color(0x66E8A4B8)),
          const SizedBox(height: 10),
          for (final c in ['一', '手', 'で', '変', 'わ', 'る'])
            Text(c,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xCCFFD4E8),
                    height: 1.6)),
          const SizedBox(height: 8),
          Container(width: 24, height: 1, color: const Color(0x44E8A4B8)),
          const SizedBox(height: 8),
          for (final c in ['P', 'L', 'A', 'Y', ' ', 'C', 'A', 'L', 'M'])
            Text(c,
                style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 6.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0x99FFD4E8),
                    height: 1.5,
                    letterSpacing: 0.3)),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0x88E8A4B8)),
        ],
      ),
    );
  }
}

// ── Brazil HINT + GROUP dock ─────────────────────────────────────────────────

class _HintGroupDock extends StatelessWidget {
  const _HintGroupDock({this.onHint, this.onGroup});

  final VoidCallback? onHint;
  final VoidCallback? onGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onHint,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xEE0D4A2B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x4422C55E), blurRadius: 10)
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lightbulb_rounded,
                        color: Color(0xFFFDE047), size: 20),
                    SizedBox(height: 3),
                    Text('HINT',
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ],
                ),
              ),
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      color: Color(0xFF22C55E), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('3',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onGroup,
          child: Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xEE0D4A2B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0x4422C55E), blurRadius: 10)
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.style_rounded, color: Colors.white, size: 20),
                SizedBox(height: 3),
                Text('GROUP',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Brazil YOUR TURN pill ───────────────────────────────────────────────────

class _YourTurnPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xEE093B1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x4422C55E), blurRadius: 10)
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('YOUR TURN',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: Colors.white)),
          SizedBox(width: 4),
          Icon(Icons.hexagon_rounded, color: Color(0xFF22C55E), size: 12),
        ],
      ),
    );
  }
}

// ── Fallback table felt gradient ────────────────────────────────────────────

class _FallbackFelt extends StatelessWidget {
  const _FallbackFelt({required this.theme});

  final PlayAreaTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.tableGradient,
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: theme.borderColor, width: 4.5),
      ),
    );
  }
}

// ── Japan Enso ink circle painter ───────────────────────────────────────────

class _EnsoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;

    final paint = Paint()
      ..color = const Color(0x552D1A00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -pi * 0.7,
      pi * 1.85,
      false,
      paint,
    );

    paint
      ..color = const Color(0x22E8A4B8)
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), r * 0.72, paint);

    final tp = TextPainter(
      text: const TextSpan(
        text: '零',
        style: TextStyle(
            fontSize: 38,
            color: Color(0x66C8787E),
            fontWeight: FontWeight.w900,
            height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - 2));

    final sub = TextPainter(
      text: const TextSpan(
        text: 'ZERO COUNT',
        style: TextStyle(
            fontSize: 8,
            color: Color(0x55C8787E),
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sub.paint(canvas, Offset(cx - sub.width / 2, cy + 24));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
