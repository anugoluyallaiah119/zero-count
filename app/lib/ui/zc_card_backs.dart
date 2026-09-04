import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Registry of all card back designs.
/// PNG assets are used when available; code-drawn painters as fallback.
abstract final class ZcCardBacks {
  // Map from catalog id → PNG asset filename (without path/extension).
  static const _pngMap = <String, String>{
    'cb_classic':   'cb_classic',
    'cb_midnight':  'cb_midnight',
    'cb_amethyst':  'cb_cyber',    // best visual match for purple/amethyst
    'cb_ember':     'cb_ember',
    'cb_arctic':    'cb_sakura',   // cool tones, different palette
    'cb_galaxy':    'cb_cyber',
    'cb_sakura':    'cb_sakura',
    'cb_inferno':   'cb_gold',
    'cb_obsidian':  'cb_royal',
    'cb_ocean':     'cb_ocean',
    'cb_forest':    'cb_classic',
    'cb_prism':     'cb_cyber',
  };

  static Widget widgetFor(String id, double width) {
    final pngName = _pngMap[id];
    final h = width * 1.44;
    final radius = BorderRadius.circular(width * 0.09);
    if (pngName != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'assets/art/$pngName.png',
          width: width,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ClipRRect(
            borderRadius: radius,
            child: CustomPaint(
              size: Size(width, h),
              painter: _painterFor(id, width, h),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: CustomPaint(
        size: Size(width, h),
        painter: _painterFor(id, width, h),
      ),
    );
  }

  static CustomPainter _painterFor(String id, double width, double height) =>
      switch (id) {
        'cb_midnight' => _MidnightPulsePainter(width, height),
        'cb_amethyst' => _AmethystVeilPainter(width, height),
        'cb_ember'    => _EmberCorePainter(width, height),
        'cb_arctic'   => _ArcticFrostPainter(width, height),
        'cb_galaxy'   => _CosmicDriftPainter(width, height),
        'cb_sakura'   => _SakuraStormPainter(width, height),
        'cb_inferno'  => _InfernoAcePainter(width, height),
        'cb_obsidian' => _ObsidianCrownPainter(width, height),
        _             => _ZeroClassicPainter(width, height),
      };

  static const rarity = <String, String>{
    'cb_classic': 'rare',   'cb_midnight': 'rare',  'cb_amethyst': 'epic',
    'cb_ember':   'epic',   'cb_arctic':   'rare',  'cb_galaxy':   'epic',
    'cb_sakura':  'epic',   'cb_inferno':  'legendary', 'cb_obsidian': 'legendary',
    'cb_ocean':   'epic',   'cb_forest':   'rare',  'cb_prism':    'legendary',
  };
}

// ---------------------------------------------------------------------------
// Widget wrapper ─ converts any painter into a ready-to-use card face.
// ---------------------------------------------------------------------------

class ZcCardBackWidget extends StatelessWidget {
  const ZcCardBackWidget({
    super.key,
    required this.backId,
    required this.width,
  });

  final String backId;
  final double width;

  @override
  Widget build(BuildContext context) => ZcCardBacks.widgetFor(backId, width);
}

// ============================================================================
// 1. ZERO CLASSIC (free)
// ============================================================================

class _ZeroClassicPainter extends CustomPainter {
  const _ZeroClassicPainter(this.w, this.h);
  final double w, h;

  @override
  void paint(Canvas c, Size _) {
    final r = Radius.circular(w * 0.09);
    final rect = RRect.fromLTRBR(0, 0, w, h, r);
    // Deep navy background.
    c.drawRRect(rect, Paint()..color = const Color(0xFF0A1628));
    // Gold diagonal grid.
    final gridPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.18)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    for (var i = -h.toInt(); i < w + h; i += 20) {
      c.drawLine(Offset(i.toDouble(), 0), Offset(i + h, h), gridPaint);
      c.drawLine(Offset(i.toDouble(), h), Offset(i + h, 0), gridPaint);
    }
    // Central 0 emblem.
    final center = Offset(w / 2, h / 2);
    c.drawCircle(
        center,
        w * 0.26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035
          ..color = const Color(0xFFD4AF37));
    c.drawCircle(
        center,
        w * 0.18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.022
          ..color = const Color(0xFFD4AF37).withValues(alpha: 0.5));
    final tp = TextPainter(
      text: const TextSpan(
        text: '0',
        style: TextStyle(
          color: Color(0xFFD4AF37),
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
    // Corner pips.
    const pip = Color(0xFFD4AF37);
    for (final pos in [
      const Offset(10, 10),
      Offset(w - 10, 10),
      Offset(10, h - 10),
      Offset(w - 10, h - 10),
    ]) {
      c.drawCircle(pos, 2.5, Paint()..color = pip);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================================
// 2. MIDNIGHT PULSE (₹9)
// ============================================================================

class _MidnightPulsePainter extends CustomPainter {
  const _MidnightPulsePainter(this.w, this.h);
  final double w, h;

  @override
  void paint(Canvas c, Size _) {
    // Pure black base.
    c.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF050510));
    // Neon blue grid lines.
    final lp = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.25)
      ..strokeWidth = 0.6;
    for (var x = 0.0; x < w; x += 16) {
      c.drawLine(Offset(x, 0), Offset(x, h), lp);
    }
    for (var y = 0.0; y < h; y += 16) {
      c.drawLine(Offset(0, y), Offset(w, y), lp);
    }
    // Glowing pulse rings from center.
    final center = Offset(w / 2, h / 2);
    for (var r = w * 0.08; r < w * 0.55; r += w * 0.12) {
      c.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF00D4FF)
                .withValues(alpha: 0.6 - r / (w * 0.7)));
    }
    // Bright center dot.
    c.drawCircle(
        center,
        4,
        Paint()
          ..color = const Color(0xFF00D4FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================================
// 3. AMETHYST VEIL (₹19)
// ============================================================================

class _AmethystVeilPainter extends CustomPainter {
  const _AmethystVeilPainter(this.w, this.h);
  final double w, h;

  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0040), Color(0xFF3D0070), Color(0xFF1A0040)],
          ).createShader(rect));
    // Crystal facets.
    final path = Path();
    final cx = w / 2, cy = h / 2;
    final fPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFCA8FFF).withValues(alpha: 0.4);
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2;
      final bx = cx + math.cos(a) * w * 0.38;
      final by = cy + math.sin(a) * h * 0.38;
      path.moveTo(cx, cy);
      path.lineTo(bx, by);
      final a2 = ((i + 1) / 8) * math.pi * 2;
      path.lineTo(cx + math.cos(a2) * w * 0.38, cy + math.sin(a2) * h * 0.38);
      path.close();
    }
    c.drawPath(path, fPaint);
    // Shimmer highlights.
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2;
      c.drawCircle(
        Offset(cx + math.cos(a) * w * 0.38, cy + math.sin(a) * h * 0.38),
        2.5,
        Paint()
          ..color = const Color(0xFFDDB6FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================================
// 4. EMBER CORE (₹29)
// ============================================================================

class _EmberCorePainter extends CustomPainter {
  const _EmberCorePainter(this.w, this.h);
  final double w, h;

  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Color(0xFF3D0500), Color(0xFF1A0000)],
          ).createShader(rect));
    // Flame-like triangular geometry from bottom.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 0; i < 6; i++) {
      final t = i / 5;
      paint.color = Color.lerp(const Color(0xFFFF6B00), const Color(0xFFFF2200), t)!
          .withValues(alpha: 0.5 - t * 0.3);
      final p = Path()
        ..moveTo(w / 2, h * 0.05)
        ..lineTo(w * (0.1 + t * 0.15), h * 0.95)
        ..lineTo(w * (0.9 - t * 0.15), h * 0.95)
        ..close();
      c.drawPath(p, paint);
    }
    // Glow core.
    c.drawCircle(
      Offset(w / 2, h / 2),
      w * 0.14,
      Paint()
        ..color = const Color(0xFFFF6B00).withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================================
// 5. ARCTIC FROST (₹29)
// ============================================================================

class _ArcticFrostPainter extends CustomPainter {
  const _ArcticFrostPainter(this.w, this.h);
  final double w, h;

  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2E), Color(0xFF1B3A5C), Color(0xFF0D1B2E)],
          ).createShader(rect));
    final cx = w / 2, cy = h / 2;
    // Snowflake arms.
    final sp = Paint()
      ..color = const Color(0xFFB8E0FF).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a = (i / 6) * math.pi * 2;
      c.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(a) * w * 0.36, cy + math.sin(a) * h * 0.36),
        sp,
      );
      for (var b = 0; b < 3; b++) {
        final bl = (b + 1) * 0.25;
        final bx = cx + math.cos(a) * w * 0.36 * bl;
        final by = cy + math.sin(a) * h * 0.36 * bl;
        final ba = a + math.pi / 4;
        c.drawLine(
          Offset(bx, by),
          Offset(bx + math.cos(ba) * w * 0.06, by + math.sin(ba) * h * 0.06),
          sp,
        );
        c.drawLine(
          Offset(bx, by),
          Offset(bx + math.cos(a - math.pi / 4) * w * 0.06,
              by + math.sin(a - math.pi / 4) * h * 0.06),
          sp,
        );
      }
    }
    // Center hex.
    final hp = Path();
    for (var i = 0; i < 6; i++) {
      final a = (i / 6) * math.pi * 2 - math.pi / 6;
      final px = cx + math.cos(a) * w * 0.08;
      final py = cy + math.sin(a) * h * 0.08;
      i == 0 ? hp.moveTo(px, py) : hp.lineTo(px, py);
    }
    hp.close();
    c.drawPath(
        hp,
        Paint()
          ..color = const Color(0xFFE0F4FF).withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================================
// 6. COSMIC DRIFT (₹49)
// ============================================================================

class _CosmicDriftPainter extends CustomPainter {
  const _CosmicDriftPainter(this.w, this.h);
  final double w, h;
  static final _rng = math.Random(42);

  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1B003E), Color(0xFF09001A)],
          ).createShader(rect));
    // Star field.
    final starPaint = Paint()..color = Colors.white;
    for (var i = 0; i < 60; i++) {
      final x = _rng.nextDouble() * w;
      final y = _rng.nextDouble() * h;
      final r = _rng.nextDouble() * 1.2 + 0.3;
      starPaint.color = Colors.white.withValues(alpha: _rng.nextDouble() * 0.7 + 0.3);
      c.drawCircle(Offset(x, y), r, starPaint);
    }
    // Nebula swirl.
    c.drawCircle(
      Offset(w * 0.35, h * 0.4),
      w * 0.32,
      Paint()
        ..color = const Color(0xFF8B00FF).withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    c.drawCircle(
      Offset(w * 0.65, h * 0.6),
      w * 0.28,
      Paint()
        ..color = const Color(0xFF0050FF).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    // Saturn ring.
    final center = Offset(w / 2, h / 2);
    final rp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFB06EFF).withValues(alpha: 0.5);
    c.drawOval(
        Rect.fromCenter(center: center, width: w * 0.5, height: h * 0.12), rp);
    c.drawCircle(center, w * 0.12,
        Paint()..color = const Color(0xFF9B4DFF).withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================================
// 7. SAKURA STORM (₹49)
// ============================================================================

class _SakuraStormPainter extends CustomPainter {
  const _SakuraStormPainter(this.w, this.h);
  final double w, h;
  static final _rng = math.Random(7);

  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C1F0C), Color(0xFF1A3A1A)],
          ).createShader(rect));
    // Falling petal silhouettes.
    final pp = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 28; i++) {
      final x = _rng.nextDouble() * w;
      final y = _rng.nextDouble() * h;
      final sz = _rng.nextDouble() * 6 + 3;
      final a = _rng.nextDouble() * math.pi;
      pp.color = Color.lerp(
        const Color(0xFFFFB7C5),
        const Color(0xFFFF6FA0),
        _rng.nextDouble(),
      )!
          .withValues(alpha: _rng.nextDouble() * 0.5 + 0.3);
      c.save();
      c.translate(x, y);
      c.rotate(a);
      final path = Path()
        ..moveTo(0, -sz)
        ..cubicTo(sz * 0.6, -sz * 0.6, sz * 0.6, sz * 0.6, 0, sz)
        ..cubicTo(-sz * 0.6, sz * 0.6, -sz * 0.6, -sz * 0.6, 0, -sz);
      c.drawPath(path, pp);
      c.restore();
    }
    // Branch silhouette.
    final bp = Paint()
      ..color = const Color(0xFF2D4A1E)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawLine(const Offset(0, 0), Offset(w * 0.6, h * 0.45), bp);
    c.drawLine(Offset(w * 0.3, h * 0.22), Offset(w * 0.75, h * 0.05), bp);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================================
// 8. INFERNO ACE (₹79)
// ============================================================================

class _InfernoAcePainter extends CustomPainter {
  const _InfernoAcePainter(this.w, this.h);
  final double w, h;

  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1200), Color(0xFF2E1800)],
          ).createShader(rect));
    // Gold lattice.
    final lp = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.3)
      ..strokeWidth = 0.7;
    for (var i = 0; i < 8; i++) {
      for (var j = 0; j < 8; j++) {
        final x = i * w / 7, y = j * h / 7;
        c.drawLine(Offset(x, 0), Offset(x, h), lp);
        c.drawLine(Offset(0, y), Offset(w, y), lp);
      }
    }
    // Flame corona from center.
    final center = Offset(w / 2, h / 2);
    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2;
      final r = w * (0.18 + 0.14 * math.sin(i * 2.3));
      c.drawLine(
        center,
        Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r),
        Paint()
          ..color = Color.lerp(const Color(0xFFFF8C00), const Color(0xFFD4AF37),
                  i / 12)!
              .withValues(alpha: 0.7)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
    // Gold A emblem.
    c.drawCircle(
        center,
        w * 0.13,
        Paint()..color = const Color(0xFF1A1200));
    final tp = TextPainter(
      text: const TextSpan(
        text: 'A',
        style: TextStyle(
          color: Color(0xFFD4AF37),
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================================
// 9. OBSIDIAN CROWN (₹99)
// ============================================================================

class _ObsidianCrownPainter extends CustomPainter {
  const _ObsidianCrownPainter(this.w, this.h);
  final double w, h;

  @override
  void paint(Canvas c, Size _) {
    // Matte near-black with subtle warm tint.
    c.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0C0C), Color(0xFF181210)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));
    final cx = w / 2, cy = h / 2;
    // Fine gold micro-dot grid.
    final gp = Paint()..color = const Color(0xFFD4AF37).withValues(alpha: 0.12);
    for (var x = 0.0; x < w; x += 12) {
      for (var y = 0.0; y < h; y += 12) {
        c.drawCircle(Offset(x, y), 0.7, gp);
      }
    }
    // Crown silhouette.
    final cp = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFD4AF37);
    final crown = Path();
    final base = cy + w * 0.12;
    final top = cy - w * 0.22;
    final left = cx - w * 0.26;
    final right = cx + w * 0.26;
    crown
      ..moveTo(left, base)
      ..lineTo(left, top + w * 0.08)
      ..lineTo(left + w * 0.09, cy)
      ..lineTo(cx - w * 0.09, top)
      ..lineTo(cx, cy - w * 0.28)
      ..lineTo(cx + w * 0.09, top)
      ..lineTo(right - w * 0.09, cy)
      ..lineTo(right, top + w * 0.08)
      ..lineTo(right, base)
      ..close();
    c.drawPath(crown, cp);
    // Jewels on crown.
    final jewels = [
      [cx, top - w * 0.02],
      [left + w * 0.05, top + w * 0.08],
      [right - w * 0.05, top + w * 0.08],
    ];
    for (final j in jewels) {
      c.drawCircle(
          Offset(j[0], j[1]),
          w * 0.04,
          Paint()
            ..color = const Color(0xFFFF3B3B)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      c.drawCircle(
          Offset(j[0], j[1]),
          w * 0.025,
          Paint()..color = const Color(0xFFFF8080));
    }
    // Glow under the crown.
    c.drawRect(
      Rect.fromLTWH(left, base - 6, right - left, 6),
      Paint()
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
