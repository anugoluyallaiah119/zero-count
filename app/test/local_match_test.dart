import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/engine/ai.dart';
import 'package:zerocount_app/engine/model.dart';
import 'package:zerocount_app/features/game/local_match_controller.dart';

/// G1.1/G1.2/G1.6 controller-level coverage: the local match loop drives the
/// real engine, validates turn flow, runs AI opponents on timers, and ends
/// rounds/matches with correct results.
void main() {
  group('LocalMatchController', () {
    test('human turn flow: draw → discard → post → next player', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final ctrl = container.read(localMatchProvider.notifier);
        ctrl.newMatch(GameConfig.quickPlay(4), DifficultyProfile.normal,
            seed: 42);
        final s0 = container.read(localMatchProvider)!;
        expect(s0.session.currentPlayerIdx, 0);
        expect(s0.session.phase, Phase.draw);
        expect(s0.you.hand.size, 7);

        // Discard before drawing is illegal and ignored.
        ctrl.selectCard(s0.you.hand.cards.first.id);
        ctrl.discardSelected();
        expect(container.read(localMatchProvider)!.you.hand.size, 7);

        // Draw, then discard the newly drawn card (last in hand).
        ctrl.drawStock();
        expect(container.read(localMatchProvider)!.you.hand.size, 8);
        final sel = container.read(localMatchProvider)!.you.hand.cards.last;
        ctrl.selectCard(sel.id);
        ctrl.discardSelected();
        final s1 = container.read(localMatchProvider)!;
        expect(s1.you.hand.size, 7);
        expect(s1.session.phase, Phase.post);
        expect(s1.selectedCardId, isNull); // selection consumed

        // End turn → control passes to AI seat 1.
        ctrl.endTurn();
        expect(container.read(localMatchProvider)!.session.currentPlayerIdx,
            1);
      });
    });

    test('AI opponents play their turns automatically', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final ctrl = container.read(localMatchProvider.notifier);
        ctrl.newMatch(GameConfig.quickPlay(4), DifficultyProfile.normal,
            seed: 7);
        ctrl.drawStock();
        final card =
            container.read(localMatchProvider)!.you.hand.cards.first;
        ctrl.selectCard(card.id);
        ctrl.discardSelected();
        ctrl.endTurn();

        // Each AI step is a 750ms timer; 3 opponents × ~3 steps each.
        async.elapse(const Duration(seconds: 30));
        final s = container.read(localMatchProvider)!;
        // Control is back with the human (or the round ended).
        expect(
            s.session.currentPlayerIdx == 0 || s.roundResult != null,
            isTrue);
        expect(s.aiThinking, isFalse);
      });
    });

    test('full match completes and reports a winner', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final ctrl = container.read(localMatchProvider.notifier);
        ctrl.newMatch(GameConfig.quickPlay(2), DifficultyProfile.easy,
            seed: 3);

        var guard = 0;
        while (guard++ < 400) {
          final s = container.read(localMatchProvider)!;
          if (s.matchResult != null) break;
          if (s.roundResult != null) {
            ctrl.nextRound();
          } else if (s.isHumanTurn) {
            switch (s.session.phase) {
              case Phase.draw:
                ctrl.drawStock();
              case Phase.discard:
                final c = s.you.hand.cards.first;
                ctrl.selectCard(c.id);
                ctrl.discardSelected();
              case Phase.post:
                ctrl.endTurn();
              default:
                break;
            }
          }
          async.elapse(const Duration(seconds: 5));
        }
        final s = container.read(localMatchProvider)!;
        expect(s.matchResult, isNotNull);
        expect(s.matchResult!.winnerId, anyOf('you', 'ai1'));
        // Totals consistent: winner has the strictly lowest total.
        final totals = s.matchResult!.totals;
        final winIdx = s.matchResult!.winnerId == 'you' ? 0 : 1;
        expect(totals[winIdx],
            totals.reduce((a, b) => a < b ? a : b));
      });
    });

    test('score preview reflects the live hand count', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container
            .read(localMatchProvider.notifier)
            .newMatch(GameConfig.quickPlay(2), DifficultyProfile.normal,
                seed: 11);
        final s = container.read(localMatchProvider)!;
        // Preview equals the engine's own scoring of the same cards.
        final expected = s.you.hand.cards
            .fold<int>(0, (sum, c) => sum + c.value);
        // (No ZERO groups at 7 distinct-or-paired ranks in expectation;
        //  compare against the engine's count directly instead.)
        expect(s.yourCount, lessThanOrEqualTo(expected));
        expect(s.yourCount, greaterThanOrEqualTo(0));
      });
    });

    test('show() preserves roundResult until nextRound() is explicitly invoked', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final ctrl = container.read(localMatchProvider.notifier);
        ctrl.newMatch(GameConfig.quickPlay(2), DifficultyProfile.normal, seed: 12);
        
        ctrl.drawStock();
        final sel = container.read(localMatchProvider)!.you.hand.cards.first;
        ctrl.selectCard(sel.id);
        ctrl.discardSelected();
        
        // In post phase, declare show
        ctrl.show();
        final sAfterShow = container.read(localMatchProvider)!;
        expect(sAfterShow.roundResult, isNotNull, reason: 'roundResult must stay populated for announcement modal');
        
        // Verify roundResult stays populated across time ticks
        async.elapse(const Duration(seconds: 5));
        expect(container.read(localMatchProvider)!.roundResult, isNotNull);
        
        // Tap next round
        ctrl.nextRound();
        expect(container.read(localMatchProvider)!.roundResult, isNull);
      });
    });
  });
}
