import 'package:flutter/material.dart';

/// Vector-drawn Indian flag (saffron / white / green + navy chakra), so it
/// renders pixel-identically on every device without emoji/font dependency.
class ZcIndiaFlag extends StatelessWidget {
  const ZcIndiaFlag({super.key, this.width = 24});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 0.68),
      painter: const _IndiaFlagPainter(),
    );
  }
}

class _IndiaFlagPainter extends CustomPainter {
  const _IndiaFlagPainter();

  static const _saffron = Color(0xFFFF9933);
  static const _green = Color(0xFF138808);
  static const _navy = Color(0xFF06038D);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.height * 0.16));
    canvas.clipRRect(r);
    final stripe = size.height / 3;
    final paint = Paint();
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, stripe), paint..color = _saffron);
    canvas.drawRect(Rect.fromLTWH(0, stripe, size.width, stripe), paint..color = Colors.white);
    canvas.drawRect(
        Rect.fromLTWH(0, stripe * 2, size.width, stripe), paint..color = _green);
    // Ashoka Chakra.
    final c = Offset(size.width / 2, size.height / 2);
    final radius = stripe * 0.42;
    canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = _navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * 0.045);
    final spoke = Paint()
      ..color = _navy
      ..strokeWidth = size.height * 0.03;
    for (var i = 0; i < 8; i++) {
      final a = i * 3.141592653589793 / 4;
      canvas.drawLine(
          c,
          c + Offset(radius * 0.92 * _cos(a), radius * 0.92 * _sin(a)),
          spoke);
    }
  }

  double _cos(double a) =>
      // Taylor is overkill; dart:math via lookup keeps painter self-contained.
      _sin(a + 3.141592653589793 / 2);

  double _sin(double x) {
    // Fast sine for multiples of pi/4.
    const vals = [0.0, 0.70710678, 1.0, 0.70710678, 0.0, -0.70710678, -1.0, -0.70710678];
    final idx = ((x / (3.141592653589793 / 4)).round()) % 8;
    return vals[(idx + 8) % 8];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
