import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Card suits, rendered as glyphs exactly like the V1 web cards.
enum CardSuit {
  hearts('♥', true),
  diamonds('♦', true),
  spades('♠', false),
  clubs('♣', false);

  const CardSuit(this.glyph, this.isRed);

  final String glyph;
  final bool isRed;
}

/// A playing card face — 1:1 port of V1's `.card`:
/// white gradient face, corner rank+suit, large center pip, and the small
/// dark value chip in the bottom-right corner showing the card's points.
class MiniCard extends StatelessWidget {
  const MiniCard({
    super.key,
    required this.rank,
    required this.suit,
    this.width = 54,
    this.showValue = true,
  });

  /// Display rank: 'A', '2'…'10', 'J', 'Q', 'K' (or '0' for brand art).
  final String rank;
  final CardSuit suit;
  final double width;
  final bool showValue;

  /// V1 point values: A=1, 2-10 face, J/Q/K=10.
  static int valueOf(String rank) => switch (rank) {
        'A' => 1,
        'J' || 'Q' || 'K' => 10,
        '0' => 0,
        _ => int.tryParse(rank) ?? 0,
      };

  @override
  Widget build(BuildContext context) {
    final height = width * (78 / 54); // V1 aspect 54x78
    final ink = suit.isRed ? ZeroCountTheme.cardRed : ZeroCountTheme.cardInk;
    final value = valueOf(rank);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: ZeroCountTheme.cardFace,
        borderRadius: BorderRadius.circular(width / 6),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 2,
              offset: const Offset(0, 1)),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Stack(
        children: [
          // corner rank + suit
          Positioned(
            top: width * 0.07,
            left: width * 0.09,
            child: Column(
              children: [
                Text(rank,
                    style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: width * 0.24,
                        height: 1.05)),
                Text(suit.glyph,
                    style: TextStyle(color: ink, fontSize: width * 0.2, height: 1.05)),
              ],
            ),
          ),
          // center pip
          Center(
            child: Text(suit.glyph,
                style: TextStyle(color: ink, fontSize: width * 0.44)),
          ),
          // value chip (V1 .card .val)
          if (showValue)
            Positioned(
              right: width * 0.055,
              bottom: width * 0.055,
              child: Container(
                constraints: BoxConstraints(minWidth: width * 0.28),
                height: width * 0.28,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: ZeroCountTheme.cardInk,
                  borderRadius: BorderRadius.circular(width * 0.14),
                ),
                alignment: Alignment.center,
                child: Text('$value',
                    style: TextStyle(
                        color: ZeroCountTheme.cardValueChipText,
                        fontSize: width * 0.17,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card back — V1 `.card.back`: concentric blue rings with a white rim.
class CardBack extends StatelessWidget {
  const CardBack({super.key, this.width = 54});

  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * (78 / 54);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width / 6),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width / 6 - 2),
        child: CustomPaint(painter: _CardBackPainter()),
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = math.sqrt(size.width * size.width + size.height * size.height);
    final step = size.width * 0.1;
    var light = false;
    for (var r = maxR; r > 0; r -= step) {
      final paint = Paint()
        ..color = light
            ? ZeroCountTheme.cardBackBlueLight
            : ZeroCountTheme.cardBackBlue;
      canvas.drawCircle(center, r, paint);
      light = !light;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Three fanned cards — brand hero art on splash/auth screens.
/// Center card is the ZERO card: the whole point of the game.
class CardFan extends StatelessWidget {
  const CardFan({super.key, this.size = 150});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cardW = size * 0.56;
    return SizedBox(
      width: size * 1.5,
      height: size * 0.95,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -18 * math.pi / 180,
            child: Transform.translate(
              offset: Offset(-size * 0.32, size * 0.04),
              child: MiniCard(rank: '5', suit: CardSuit.spades, width: cardW),
            ),
          ),
          Transform.rotate(
            angle: 18 * math.pi / 180,
            child: Transform.translate(
              offset: Offset(size * 0.32, size * 0.04),
              child: MiniCard(rank: '3', suit: CardSuit.hearts, width: cardW),
            ),
          ),
          // Center hero: the ZERO card.
          MiniCard(
              rank: '0',
              suit: CardSuit.diamonds,
              width: cardW * 1.08,
              showValue: false),
        ],
      ),
    );
  }
}
