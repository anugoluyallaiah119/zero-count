import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Avatar renderer — uses PNG assets when available, falls back to code-drawn.
abstract final class ZcAvatars {
  // All IDs that have a corresponding PNG file in assets/art/.
  static const _pngIds = {
    'av_joker', 'av_cyber', 'av_fox', 'av_robot', 'av_queen',
    'av_panda', 'av_ninja', 'av_king', 'av_wizard', 'av_tiger',
    'av_owl', 'av_alien', 'av_knight', 'av_phoenix', 'av_dragon',
    'av_ace',
  };

  static Widget forId(String id, double size) {
    if (_pngIds.contains(id)) {
      return ClipOval(
        child: Image.asset(
          'assets/art/$id.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _codeDrawn(id, size),
        ),
      );
    }
    return _codeDrawn(id, size);
  }

  static Widget _codeDrawn(String id, double size) => ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: _painterFor(id, size),
        ),
      );

  static CustomPainter _painterFor(String id, double s) => switch (id) {
        'av_cyber'   => _CyberAvatar(s),
        'av_fox'     => _FoxAvatar(s),
        'av_robot'   => _RobotAvatar(s),
        'av_queen'   => _QueenAvatar(s),
        'av_panda'   => _PandaAvatar(s),
        'av_ninja'   => _NinjaAvatar(s),
        'av_king'    => _KingAvatar(s),
        'av_wizard'  => _WizardAvatar(s),
        'av_tiger'   => _TigerAvatar(s),
        'av_owl'     => _OwlAvatar(s),
        'av_alien'   => _AlienAvatar(s),
        'av_knight'  => _KnightAvatar(s),
        'av_phoenix' => _PhoenixAvatar(s),
        'av_dragon'  => _DragonAvatar(s),
        _            => _DefaultAvatar(s),
      };
}

abstract class _BaseAvatar extends CustomPainter {
  const _BaseAvatar(this.s);
  final double s;
  double get r => s / 2;
  void paintBg(Canvas c, Color color) =>
      c.drawCircle(Offset(r, r), r, Paint()..color = color);
  void drawText(Canvas c, String text, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(r - tp.width / 2, r - tp.height / 2));
  }
  @override
  bool shouldRepaint(_) => false;
}

class _DefaultAvatar extends _BaseAvatar {
  const _DefaultAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    c.drawRect(rect, Paint()..shader = const LinearGradient(
      colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)]).createShader(rect));
    drawText(c, 'Z', s * 0.52, Colors.white);
  }
}

class _CyberAvatar extends _BaseAvatar {
  const _CyberAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, const Color(0xFF0A0F1E));
    c.drawCircle(Offset(r, r), r * 0.9, Paint()..color = const Color(0xFF00D4FF).withValues(alpha: 0.1));
    c.drawCircle(Offset(r, r), r * 0.5, Paint()..color = const Color(0xFF00D4FF).withValues(alpha: 0.9));
    drawText(c, '⚡', s * 0.4, Colors.white);
  }
}

class _FoxAvatar extends _BaseAvatar {
  const _FoxAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, const Color(0xFFF97316));
    // Ears
    final ep = Paint()..color = const Color(0xFFFFB88C);
    c.drawCircle(Offset(r * 0.6, r * 0.5), r * 0.28, ep);
    c.drawCircle(Offset(r * 1.4, r * 0.5), r * 0.28, ep);
    drawText(c, '🦊', s * 0.42, Colors.white);
  }
}

class _RobotAvatar extends _BaseAvatar {
  const _RobotAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, const Color(0xFF1E293B));
    c.drawRRect(RRect.fromLTRBR(r * 0.3, r * 0.3, r * 1.7, r * 1.7, const Radius.circular(8)),
        Paint()..color = const Color(0xFF475569));
    c.drawCircle(Offset(r * 0.7, r * 0.85), r * 0.15, Paint()..color = const Color(0xFF00D4FF));
    c.drawCircle(Offset(r * 1.3, r * 0.85), r * 0.15, Paint()..color = const Color(0xFF00D4FF));
  }
}

class _QueenAvatar extends _BaseAvatar {
  const _QueenAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    c.drawRect(rect, Paint()..shader = const LinearGradient(
      colors: [Color(0xFF9333EA), Color(0xFFDB2777)]).createShader(rect));
    drawText(c, '♛', s * 0.5, const Color(0xFFFFE57F));
  }
}

class _PandaAvatar extends _BaseAvatar {
  const _PandaAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, Colors.white);
    c.drawCircle(Offset(r * 0.6, r * 0.75), r * 0.22, Paint()..color = Colors.black);
    c.drawCircle(Offset(r * 1.4, r * 0.75), r * 0.22, Paint()..color = Colors.black);
    c.drawCircle(Offset(r, r * 1.15), r * 0.2, Paint()..color = Colors.black);
    drawText(c, '🐼', s * 0.44, Colors.black);
  }
}

class _NinjaAvatar extends _BaseAvatar {
  const _NinjaAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, const Color(0xFF0F172A));
    c.drawRect(Rect.fromLTWH(0, r * 0.9, s, r * 0.2), Paint()..color = const Color(0xFF1E293B));
    drawText(c, '🥷', s * 0.44, Colors.white);
  }
}

class _KingAvatar extends _BaseAvatar {
  const _KingAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    c.drawRect(rect, Paint()..shader = const LinearGradient(
      colors: [Color(0xFF1A1200), Color(0xFF2E1800)]).createShader(rect));
    drawText(c, '♚', s * 0.5, const Color(0xFFD4AF37));
  }
}

class _WizardAvatar extends _BaseAvatar {
  const _WizardAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, const Color(0xFF1B003E));
    drawText(c, '🧙', s * 0.44, Colors.white);
  }
}

class _TigerAvatar extends _BaseAvatar {
  const _TigerAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, const Color(0xFFD97706));
    final sp = Paint()..color = const Color(0xFF92400E)..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final x = r * 0.5 + i * r * 0.35;
      c.drawLine(Offset(x, r * 0.3), Offset(x - r * 0.05, r * 1.1), sp);
    }
    drawText(c, '🐯', s * 0.44, Colors.white);
  }
}

class _OwlAvatar extends _BaseAvatar {
  const _OwlAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, const Color(0xFF1B3A5C));
    drawText(c, '🦉', s * 0.44, Colors.white);
  }
}

class _AlienAvatar extends _BaseAvatar {
  const _AlienAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, const Color(0xFF064E3B));
    drawText(c, '👽', s * 0.44, Colors.white);
  }
}

class _KnightAvatar extends _BaseAvatar {
  const _KnightAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    paintBg(c, const Color(0xFF111827));
    drawText(c, '⚔️', s * 0.44, Colors.white);
  }
}

class _PhoenixAvatar extends _BaseAvatar {
  const _PhoenixAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    c.drawRect(rect, Paint()..shader = const LinearGradient(
      colors: [Color(0xFFDC2626), Color(0xFFF97316)]).createShader(rect));
    drawText(c, '🦅', s * 0.44, Colors.white);
  }
}

class _DragonAvatar extends _BaseAvatar {
  const _DragonAvatar(super.s);
  @override
  void paint(Canvas c, Size _) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    c.drawRect(rect, Paint()..shader = const LinearGradient(
      colors: [Color(0xFF0E7490), Color(0xFF1E3A5F)]).createShader(rect));
    drawText(c, '🐉', s * 0.44, Colors.white);
  }
}

// =============================================================================
// SPECIAL CARD SKINS — shown when isSpecial=true in ZcPlayingCard
// =============================================================================

/// Returns gradient + label colour + star label for the equipped special skin.
class ZcSpecialSkin {
  const ZcSpecialSkin({
    required this.gradient,
    required this.starColor,
    required this.glowColor,
    required this.label,
  });

  final LinearGradient gradient;
  final Color starColor;
  final Color glowColor;
  final String label;

  static ZcSpecialSkin forId(String id) => _skins[id] ?? _skins['sp_classic']!;

  static final _skins = {
    'sp_classic': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF2A0A4B), Color(0xFF13033B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFFD946CB),
      glowColor: const Color(0xFFD946CB),
      label: '★',
    ),
    'sp_inferno': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF3D0500), Color(0xFF8B0000)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ),
      starColor: const Color(0xFFFF6B00),
      glowColor: const Color(0xFFFF2200),
      label: '🔥',
    ),
    'sp_forest': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF0C1F0C), Color(0xFF1A3A1A)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFF4ADE80),
      glowColor: const Color(0xFF16A34A),
      label: '🌿',
    ),
    'sp_thunder': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1200), Color(0xFF2E1800)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFFFDE047),
      glowColor: const Color(0xFFF59E0B),
      label: '⚡',
    ),
    'sp_golden_ten': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1000), Color(0xFF3D2800)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFFD4AF37),
      glowColor: const Color(0xFFD4AF37),
      label: '10',
    ),
    'sp_frost_nine': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D1B2E), Color(0xFF1B3A5C)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFFB8E0FF),
      glowColor: const Color(0xFF38BDF8),
      label: '9',
    ),
    'sp_neon_eight': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF0A0F1E), Color(0xFF050510)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFF00D4FF),
      glowColor: const Color(0xFF0EA5E9),
      label: '8',
    ),
    'sp_blossom_seven': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A0028), Color(0xFF3D0057)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFFFF6FA0),
      glowColor: const Color(0xFFDB2777),
      label: '7',
    ),
    'sp_royal_three': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1200), Color(0xFF2E1800)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFFD4AF37),
      glowColor: const Color(0xFFEAB308),
      label: '♛',
    ),
    'sp_radiant_ace': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF1B003E), Color(0xFF09001A)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFFE879F9),
      glowColor: const Color(0xFFA855F7),
      label: 'A',
    ),
    'sp_phoenix_zero': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF450A0A), Color(0xFF991B1B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFFF97316),
      glowColor: const Color(0xFFDC2626),
      label: '🦅',
    ),
    'sp_mystic_joker': ZcSpecialSkin(
      gradient: const LinearGradient(
        colors: [Color(0xFF0C0C0C), Color(0xFF1C1C1C)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      starColor: const Color(0xFFD4AF37),
      glowColor: const Color(0xFFFDE047),
      label: '🃏',
    ),
  };
}

// =============================================================================
// EFFECTS — overlay animations shown on draw/discard events
// =============================================================================

/// Returns a short-lived overlay widget for the given effect id.
Widget? buildEffectOverlay({
  required String effectId,
  required VoidCallback onDone,
}) {
  return _EffectOverlay(effectId: effectId, onDone: onDone);
}

class _EffectOverlay extends StatefulWidget {
  const _EffectOverlay({required this.effectId, required this.onDone});
  final String effectId;
  final VoidCallback onDone;
  @override
  State<_EffectOverlay> createState() => _EffectOverlayState();
}

class _EffectOverlayState extends State<_EffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _EffectPainter(widget.effectId, _c.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _EffectPainter extends CustomPainter {
  const _EffectPainter(this.effectId, this.t);
  final String effectId;
  final double t;
  static final _rng = math.Random(99);

  @override
  void paint(Canvas c, Size s) {
    switch (effectId) {
      case 'ef_lightning':
        _lightning(c, s);
      case 'ef_frost':
        _frost(c, s);
      case 'ef_fireworks':
        _fireworks(c, s);
      case 'ef_rainbow':
        _rainbow(c, s);
      case 'ef_hearts':
        _hearts(c, s);
      case 'ef_golden':
        _golden(c, s);
      case 'ef_confetti':
        _confetti(c, s);
      case 'ef_shadow':
        _shadow(c, s);
    }
  }

  void _lightning(Canvas c, Size s) {
    final fade = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
    final p = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: fade * 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cx = s.width / 2;
    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx - 20, s.height * 0.35)
      ..lineTo(cx + 15, s.height * 0.35)
      ..lineTo(cx - 10, s.height * 0.65)
      ..lineTo(cx + 25, s.height * 0.65)
      ..lineTo(cx, s.height);
    c.drawPath(path, p);
  }

  void _frost(Canvas c, Size s) {
    final fade = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
    final p = Paint()
      ..color = const Color(0xFFB8E0FF).withValues(alpha: fade * 0.6)
      ..strokeWidth = 1.5;
    final cx = s.width / 2, cy = s.height / 2;
    for (var i = 0; i < 6; i++) {
      final a = (i / 6) * math.pi * 2;
      c.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(a) * s.width * 0.4, cy + math.sin(a) * s.height * 0.4),
        p,
      );
    }
  }

  void _fireworks(Canvas c, Size s) {
    final phase = ((t * 3) % 1.0);
    final fade = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.0, 1.0);
    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2;
      final len = s.width * 0.25 * phase;
      final p = Paint()
        ..color = [
          const Color(0xFFFF4500),
          const Color(0xFFFFD700),
          const Color(0xFF00FF7F),
          const Color(0xFF1E90FF),
        ][i % 4]
            .withValues(alpha: fade * 0.8)
        ..strokeWidth = 2.5;
      c.drawLine(
        Offset(s.width * 0.5, s.height * 0.35),
        Offset(s.width * 0.5 + math.cos(a) * len,
            s.height * 0.35 + math.sin(a) * len),
        p,
      );
    }
  }

  void _rainbow(Canvas c, Size s) {
    final fade = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
    final colors = [
      const Color(0xFFFF0000),
      const Color(0xFFFF7F00),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF00),
      const Color(0xFF0000FF),
      const Color(0xFF8B00FF),
    ];
    for (var i = 0; i < colors.length; i++) {
      final r = s.width * (0.15 + i * 0.08);
      c.drawArc(
        Rect.fromCenter(center: Offset(s.width / 2, s.height * 0.6), width: r * 2, height: r),
        math.pi, math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = colors[i].withValues(alpha: fade * 0.7),
      );
    }
  }

  void _hearts(Canvas c, Size s) {
    for (var i = 0; i < 8; i++) {
      final x = _rng.nextDouble() * s.width;
      final y = s.height * (1 - t * 0.9) - _rng.nextDouble() * s.height * 0.5;
      final fade = (1 - t).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '♥',
          style: TextStyle(
            fontSize: 18 + _rng.nextDouble() * 10,
            color: const Color(0xFFFF4FA0).withValues(alpha: fade * 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(x, y));
    }
  }

  void _golden(Canvas c, Size s) {
    final fade = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
    for (var i = 0; i < 16; i++) {
      final a = (i / 16) * math.pi * 2;
      final len = s.width * 0.35 * t;
      c.drawCircle(
        Offset(s.width / 2 + math.cos(a) * len, s.height / 2 + math.sin(a) * len),
        3 + _rng.nextDouble() * 4,
        Paint()..color = const Color(0xFFD4AF37).withValues(alpha: fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  void _confetti(Canvas c, Size s) {
    final colors = [
      const Color(0xFFFF4500), const Color(0xFF00BFFF),
      const Color(0xFF32CD32), const Color(0xFFFFD700), const Color(0xFFFF69B4),
    ];
    for (var i = 0; i < 20; i++) {
      final x = _rng.nextDouble() * s.width;
      final y = (_rng.nextDouble() * s.height * t + t * s.height * 0.5) % s.height;
      final fade = (1 - t * 0.7).clamp(0.0, 1.0);
      c.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 6, height: 10),
        Paint()..color = colors[i % colors.length].withValues(alpha: fade),
      );
    }
  }

  void _shadow(Canvas c, Size s) {
    final fade = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
    c.drawRect(
      Rect.fromLTWH(0, 0, s.width, s.height),
      Paint()
        ..color = Colors.black.withValues(alpha: fade * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 20),
    );
  }

  @override
  bool shouldRepaint(covariant _EffectPainter old) => old.t != t;
}
