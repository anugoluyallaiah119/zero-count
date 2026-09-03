import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/widgets/mini_card.dart';

/// How-to-play tutorial (G1.9): four swipeable screens teaching the V1 rules.
/// Reachable from the home screen (?) icon and the in-game help button.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <_TutorialPage>[
      const _TutorialPage(
        title: 'KEEP YOUR COUNT LOW',
        body: 'Every card has points: A = 1, 2–9 face value, '
            '10/J/Q/K = 10. Your hand total is your COUNT — '
            'lower is always better.',
        cards: [('A', CardSuit.hearts), ('7', CardSuit.spades), ('K', CardSuit.diamonds)],
        caption: 'A♥ + 7♠ + K♦ = 18 points',
      ),
      const _TutorialPage(
        title: 'MAKE A ZERO',
        body: 'Three or more cards of the SAME RANK form a ZERO group — '
            'they count for nothing, no matter how many.',
        cards: [('5', CardSuit.hearts), ('5', CardSuit.clubs), ('5', CardSuit.spades)],
        caption: '5♥ 5♣ 5♠ = ZERO (0 points)',
      ),
      const _TutorialPage(
        title: 'DRAW → DISCARD',
        body: 'On your turn, take the top card from the draw deck OR the '
            'discard pile, then discard one card you don’t need. '
            'Sequences don’t matter — only ranks do.',
        cards: [('9', CardSuit.diamonds), ('9', CardSuit.hearts), ('3', CardSuit.clubs)],
        caption: 'Pairs still count: 9+9+3 = 21',
      ),
      const _TutorialPage(
        title: 'CALL SHOW!',
        body: 'Think your count is the lowest? Tap SHOW to end the round. '
            'Everyone reveals; the lowest count wins the round. '
            'Reach the target score and the lowest total takes the match.',
        cards: [('2', CardSuit.clubs), ('A', CardSuit.spades), ('4', CardSuit.hearts)],
        caption: 'Count 7 — a great time to SHOW',
      ),
    ];

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: ZeroCountTheme.canvasGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  key: const Key('tutorialClose'),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => pages[i],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: _page == i ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == i
                            ? ZeroCountTheme.yellow
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: GradientButton(
                  key: const Key('tutorialNext'),
                  label: _page == pages.length - 1 ? 'GOT IT!' : 'NEXT',
                  textColor: ZeroCountTheme.yellowText,
                  onPressed: () {
                    if (_page == pages.length - 1) {
                      context.pop();
                    } else {
                      _pager.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({
    required this.title,
    required this.body,
    required this.cards,
    required this.caption,
  });

  final String title;
  final String body;
  final List<(String, CardSuit)> cards;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (rank, suit) in cards)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: MiniCard(rank: rank, suit: suit, width: 64),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(caption,
              style: const TextStyle(
                  color: ZeroCountTheme.yellow,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 26),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
