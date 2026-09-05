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
      margin: const EdgeInsets.only(left: 6),
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Scroll top wooden rod
          Container(
            height: 5,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723),
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ),
          // Parchment body
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF6EA),
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '雅',
                  style: TextStyle(
                    fontSize: 24,
                    color: Color(0xFF1F1A17),
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Container(width: 20, height: 1, color: const Color(0xFFBCAAA4)),
                const SizedBox(height: 4),
                const Text(
                  'ZERO\nCOUNT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 6,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF4E342E),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                // Red Hanko seal stamp
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB91C1C),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '零',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scroll bottom wooden weight rod
          Container(
            height: 6,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723),
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Japan right wooden board panel ──────────────────────────────────────────

class _JapanRightPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 48,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF2E1A11),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF8D6E63), width: 1),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in ['一', '手', 'で', '変', 'わ', 'る'])
              Text(
                c,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFCC80),
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 4),
            Container(width: 18, height: 1, color: const Color(0xFF6D4C41)),
            const SizedBox(height: 4),
            const Text(
              'PLAY\nCALM\nPLAY\nSMART',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 4.8,
                fontWeight: FontWeight.w900,
                color: Color(0xFFBCAAA4),
                letterSpacing: 0.3,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            // Red seal
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFB91C1C),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child: const Text(
                '印',
                style: TextStyle(
                  fontSize: 6.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
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

// ── Japan Enso ink circle painter with drifting sakura petals ──────────────

class _EnsoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;

    // Golden Enso brush stroke
    final paint = Paint()
      ..color = const Color(0x99D4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -pi * 0.75,
      pi * 1.82,
      false,
      paint,
    );

    // Inner subtle gold ring
    paint
      ..color = const Color(0x44D4AF37)
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(cx, cy), r * 0.88, paint);

    // ZERO COUNT logo text
    final sub = TextPainter(
      text: const TextSpan(
        text: 'ZERO COUNT',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: Color(0xFFD4AF37),
          fontWeight: FontWeight.w900,
          letterSpacing: 3.5,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sub.paint(canvas, Offset(cx - sub.width / 2, cy + 18));

    // Red Hanko Seal Stamp (零)
    const sealSize = 24.0;
    final sealRect = Rect.fromCenter(
      center: Offset(cx, cy + 42),
      width: sealSize,
      height: sealSize,
    );
    final sealPaint = Paint()
      ..color = const Color(0xFFB91C1C)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(sealRect, const Radius.circular(4)), sealPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFFFCDD2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(RRect.fromRectAndRadius(sealRect.deflate(1.5), const Radius.circular(3)), borderPaint);

    final tp = TextPainter(
      text: const TextSpan(
        text: '零',
        style: TextStyle(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 42 - tp.height / 2));

    // Scattered Sakura cherry blossom petals (🌸)
    final petalPaint = Paint()..color = const Color(0xCCD88098);
    _drawPetal(canvas, Offset(cx - r * 0.7, cy - r * 0.4), 6, petalPaint);
    _drawPetal(canvas, Offset(cx + r * 0.75, cy - r * 0.2), 5.5, petalPaint);
    _drawPetal(canvas, Offset(cx - r * 0.6, cy + r * 0.5), 7, petalPaint);
    _drawPetal(canvas, Offset(cx + r * 0.65, cy + r * 0.35), 6.5, petalPaint);
    _drawPetal(canvas, Offset(cx + r * 0.85, cy + r * 0.6), 5, petalPaint);
  }

  void _drawPetal(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size * 1.5, height: size),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
