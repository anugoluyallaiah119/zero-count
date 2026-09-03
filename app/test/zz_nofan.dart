import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/ui/zc_button.dart';
import 'package:zerocount_app/ui/zc_playing_card.dart';
import 'package:zerocount_app/ui/zc_theme.dart';

/// Renders a showcase of the new design-system widgets and captures a golden
/// image so we can eyeball it against the mockups.
void main() {
  testWidgets('showcase nofan', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                Text('ZERO COUNT', style: ZcText.display(24)),
                const SizedBox(height: 8),
                Text('Think your way to zero',
                    style: ZcText.body(14)),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    ZcCurrencyPill(
                      icon: CircleAvatar(backgroundColor: ZcColors.gold),
                      value: '2,500',
                    ),
                    SizedBox(width: 12),
                    ZcCurrencyPill(
                      icon: CircleAvatar(backgroundColor: ZcColors.gemPurple),
                      value: '50',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const ZcGoldButton(label: 'CONTINUE'),
                const SizedBox(height: 16),
                const ZcOutlineButton(label: 'COPY LINK'),
                const SizedBox(height: 28),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    ZcPlayingCard(rank: 'K', suit: ZcSuit.diamonds, value: 10),
                    SizedBox(width: 16),
                    ZcPlayingCard(rank: '0', suit: ZcSuit.spades, value: 0, faceDown: true),
                  ],
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/zc_showcase.png'),
    );
  });
}
