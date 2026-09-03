import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/ui/zc_button.dart';
import 'package:zerocount_app/ui/zc_playing_card.dart';
import 'package:zerocount_app/ui/zc_theme.dart';
void main() {
  testWidgets('min combo', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
          Row(children: [
            ZcCurrencyPill(icon: CircleAvatar(backgroundColor: ZcColors.gold), value: '2,500'),
            SizedBox(width: 12),
            ZcCurrencyPill(icon: CircleAvatar(backgroundColor: ZcColors.gemPurple), value: '50'),
          ]),
          SizedBox(height: 24),
          ZcGoldButton(label: 'CONTINUE'),
          SizedBox(height: 16),
          ZcOutlineButton(label: 'COPY LINK'),
          SizedBox(height: 28),
          Row(children: [
            ZcPlayingCard(rank: 'K', suit: ZcSuit.diamonds, value: 10),
            SizedBox(width: 16),
            ZcPlayingCard(rank: '0', suit: ZcSuit.spades, value: 0, faceDown: true),
          ]),
        ]))))));
    await t.pumpAndSettle();
  });
}
