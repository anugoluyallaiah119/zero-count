import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/engine/ai.dart';
import 'package:zerocount_app/engine/draw_brain.dart';
import 'package:zerocount_app/engine/model.dart';
import 'package:zerocount_app/engine/scoring.dart';
import 'package:zerocount_app/engine/session.dart';

import 'dart:math';

/// Test-only RNG: always returns 0 for nextDouble() so probabilistic branches
/// (e.g. DrawBrain opening balancer) fire deterministically.
class _AlwaysHitRng implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.0;
  @override
  int nextInt(int max) => 0;
}


// Card helper: c(rank 1-13, suit 0-3) with unique ids, mirroring the Java
// test harness so cases port 1:1.
int _id = 0;
Card c(int rank, int suit) =>
    Card(_id++, Rank.values[rank - 1], Suit.values[suit], 0);
Card special() => Card(_id++, Rank.ace, Suit.hearts, 0, isSpecial: true);
Hand hand(List<Card> cards) {
  final h = Hand();
  for (final card in cards) {
    h.add(card);
  }
  return h;
}

void main() {
  group('E1.2 scoring parity', () {
    int score(List<Card> cards) => ScoringEngine.count(cards);

    test('A=1', () => expect(score([c(1, 0)]), 1));
    test('2-9 face value', () => expect(score([c(7, 0)]), 7));
    test('10=10', () => expect(score([c(10, 0)]), 10));
    test('J/Q/K=10', () => expect(score([c(11, 0), c(12, 1), c(13, 2)]), 30));
    test('3 same rank = 0', () => expect(score([c(5, 0), c(5, 1), c(5, 2)]), 0));
    test('4 same rank = 0',
        () => expect(score([c(5, 0), c(5, 1), c(5, 2), c(5, 3)]), 0));
    test('7+8+9=24 (sequences mean nothing)',
        () => expect(score([c(7, 0), c(8, 0), c(9, 0)]), 24));
    test('10+J+Q=30', () => expect(score([c(10, 0), c(11, 0), c(12, 0)]), 30));
    test('J+Q+K=30 (distinct ranks)',
        () => expect(score([c(11, 0), c(12, 0), c(13, 0)]), 30));
    test('JJJ=0', () => expect(score([c(11, 0), c(11, 1), c(11, 2)]), 0));
    test('10 10 10=0', () => expect(score([c(10, 0), c(10, 1), c(10, 2)]), 0));
    test('pair counts fully', () => expect(score([c(5, 0), c(5, 1)]), 10));
    test('JJQK mixed',
        () => expect(score([c(11, 0), c(11, 1), c(12, 0), c(13, 0)]), 40));
    test('group + leftover',
        () => expect(score([c(5, 0), c(5, 1), c(5, 2), c(9, 1)]), 9));
    test(
        'user scenario 777+333+4+2=6',
        () => expect(
            score([
              c(7, 0), c(7, 1), c(7, 2), c(3, 0), //
              c(3, 1), c(3, 2), c(4, 2), c(2, 0)
            ]),
            6));

    test('special + pair = 0', () {
      expect(score([c(5, 0), c(5, 1), special()]), 0);
    });
    test('lone special = 10', () => expect(score([special()]), 10));
    test('two specials = 20', () => expect(score([special(), special()]), 20));
    test('special + single = 15', () => expect(score([c(5, 0), special()]), 15));

    test('structural: one group + one loose', () {
      final r = ScoringEngine.optimize([c(5, 0), c(5, 1), c(5, 2), c(9, 1)]);
      expect(r.groups.length, 1);
      expect(r.loose.length, 1);
      expect(r.loose[0].rank, Rank.nine);
    });

    test('structural: two triples both zero', () {
      final r = ScoringEngine.optimize(
          [c(3, 0), c(3, 1), c(3, 2), c(7, 0), c(7, 1), c(7, 2)]);
      expect(r.count, 0);
      expect(r.groups.length, 2);
    });

    test('pin forces Special onto chosen pair', () {
      // Hand: 5♥ 5♦ K♠ K♣ + Special. Auto picks K pair (saves 20).
      final hand = [c(5, 0), c(5, 1), c(13, 2), c(13, 3), special()];
      final auto = ScoringEngine.optimize(hand);
      expect(auto.count, 10); // 5-pair leftover
      // Pinning the 5 pair forces the worse choice (saves 10 → 20 remain).
      final pinnedFives = ScoringEngine.count(hand, pinRank: Rank.five);
      expect(pinnedFives, 20);
      // Pinning to K matches the auto choice.
      final pinnedKings = ScoringEngine.count(hand, pinRank: Rank.king);
      expect(pinnedKings, 10);
    });

    test('pin to a broken pair is ignored (falls back to optimal)', () {
      // Only one 5 in hand — pinning to fives is invalid, engine picks Kings.
      final hand = [c(5, 0), c(13, 2), c(13, 3), special()];
      expect(ScoringEngine.count(hand, pinRank: Rank.five), 5);
    });
  });

  group('E1.3 session parity', () {
    GameSession newGame([int seed = 42]) =>
        GameSession(GameConfig.quickPlay(2), ['p1', 'p2'], seed);

    test('deal: hands, one visible discard, stock size, phase DRAW', () {
      final g = newGame();
      expect(g.phase, Phase.draw);
      expect(g.players[0].hand.size, 7);
      expect(g.players[1].hand.size, 7);
      expect(g.topDiscard, isNotNull);
      expect(g.stockSize, g.config.deckSize - 15);
      expect(g.round, 1);
    });

    test('turn flow: draw → discard → pass; wrong-phase/wrong-actor rejected',
        () {
      final g = newGame();
      expect(() => g.apply('p2', const DrawStock()),
          throwsStateError); // not your turn
      expect(() => g.apply('p1', Discard(g.players[0].hand.cards[0])),
          throwsStateError); // discard in DRAW
      expect(() => g.apply('p1', const Show()), throwsStateError);

      final stockBefore = g.stockSize;
      g.apply('p1', const DrawStock());
      expect(g.players[0].hand.size, 8);
      expect(g.stockSize, stockBefore - 1);
      expect(g.phase, Phase.discard);
      expect(() => g.apply('p1', const DrawStock()), throwsStateError);

      // discard the just-drawn card (explicitly allowed in V1)
      final justDrew = g.players[0].hand.cards.last;
      g.apply('p1', Discard(justDrew));
      expect(g.players[0].hand.size, 7);
      expect(g.topDiscard, justDrew);
      expect(g.phase, Phase.post);

      g.passTurn();
      expect(g.currentPlayer.playerId, 'p2');
      expect(g.phase, Phase.draw);

      // p2 takes the visible discard
      final top = g.topDiscard!;
      g.apply('p2', const DrawDiscard());
      expect(g.players[1].hand.contains(top), true);
      expect(g.players[1].hand.size, 8);
    });

    test('show ends round, both score, first player rotates', () {
      final g = newGame();
      g.apply('p1', const DrawStock());
      g.apply('p1', Discard(g.players[0].hand.cards.first));
      g.apply('p1', const Show());
      expect(g.phase == Phase.showdown || g.phase == Phase.draw, true);
      expect(g.round == 2 || g.isOver, true);
      if (!g.isOver) expect(g.currentPlayerIdx, 1);
    });

    test('event log: strictly increasing seq, events recorded', () {
      final g = newGame();
      g.apply('p1', const DrawStock());
      g.apply('p1', Discard(g.players[0].hand.cards.first));
      g.passTurn();
      var ordered = true;
      for (var i = 1; i < g.eventLog.length; i++) {
        if (g.eventLog[i].seq <= g.eventLog[i - 1].seq) ordered = false;
      }
      expect(ordered, true);
      expect(g.eventLog.length >= 4, true);
    });

    test('card conservation (2p quick, 1 deck + special)', () {
      final g = newGame();
      final all = <int>{
        for (final p in g.players) ...p.hand.cards.map((e) => e.id),
      };
      all.add(g.topDiscard!.id);
      expect(all.length, 15 + g.config.specialCount);
      expect(g.stockSize + 15 + g.config.specialCount, g.config.deckSize);
    });

    test('special decay: unusable special discards after 4 owner turns', () {
      final g = newGame(123);
      final p1 = g.players[0];
      // Replace p1's hand with controlled distinct-rank cards + a lone special.
      while (p1.hand.size > 0) p1.hand.remove(p1.hand.cards.first);
      p1.hand.add(Card(100, Rank.ace, Suit.hearts, 0));
      p1.hand.add(Card(101, Rank.two, Suit.hearts, 0));
      p1.hand.add(Card(102, Rank.three, Suit.hearts, 0));
      p1.hand.add(Card(103, Rank.four, Suit.hearts, 0));
      p1.hand.add(Card(104, Rank.five, Suit.hearts, 0));
      p1.hand.add(Card(105, Rank.six, Suit.hearts, 0));
      p1.hand.add(Card(106, Rank.eight, Suit.hearts, 0));
      final special = Card(9999, Rank.ace, Suit.hearts, 0, isSpecial: true);
      p1.hand.add(special);

      Card safeDiscard(PlayerState p) =>
          p.hand.cards.firstWhere((c) => !c.isSpecial);

      // Play turns, counting only p1 owner turns.
      var p1Turns = 0;
      var discarded = false;
      while (p1Turns < 6 && !discarded) {
        final p = g.currentPlayer;
        if (p == p1) p1Turns++;
        g.apply(p.playerId, const DrawStock());
        g.apply(p.playerId, Discard(safeDiscard(p)));
        final before = g.eventLog.whereType<SpecialDiscarded>().length;
        g.passTurn();
        discarded = g.eventLog.whereType<SpecialDiscarded>().length > before;
      }
      expect(discarded, true);
    });

    test('special decay: timer pauses while a valid pair exists', () {
      final g = newGame(456);
      final p1 = g.players[0];
      // Replace p1's hand: one valid pair + many distinct other cards + special.
      while (p1.hand.size > 0) p1.hand.remove(p1.hand.cards.first);
      p1.hand.add(Card(200, Rank.seven, Suit.hearts, 0));
      p1.hand.add(Card(201, Rank.seven, Suit.diamonds, 0));
      p1.hand.add(Card(202, Rank.ace, Suit.clubs, 0));
      p1.hand.add(Card(203, Rank.two, Suit.spades, 0));
      p1.hand.add(Card(204, Rank.three, Suit.hearts, 0));
      p1.hand.add(Card(205, Rank.four, Suit.diamonds, 0));
      p1.hand.add(Card(206, Rank.five, Suit.clubs, 0));
      p1.hand.add(Card(207, Rank.six, Suit.spades, 0));
      p1.hand.add(Card(208, Rank.eight, Suit.hearts, 0));
      p1.hand.add(Card(209, Rank.nine, Suit.diamonds, 0));
      p1.hand.add(Card(210, Rank.ten, Suit.clubs, 0));
      final special = Card(9999, Rank.ace, Suit.hearts, 0, isSpecial: true);
      p1.hand.add(special);

      Card safeDiscard(PlayerState p) => p.hand.cards.firstWhere(
          (c) => !c.isSpecial && c.rank != Rank.seven);

      // Play several full rounds; the usable special must never auto-discard.
      for (var i = 0; i < 14; i++) {
        final p = g.currentPlayer;
        g.apply(p.playerId, const DrawStock());
        g.apply(p.playerId, Discard(safeDiscard(p)));
        g.passTurn();
      }
      expect(p1.hand.cards.any((c) => c.isSpecial), true);
    });

    test('4p 13-card match completes with fractional second deck', () {
      final g = GameSession(
          GameConfig.classicPlay(4), ['a', 'b', 'c', 'd'], 7);
      expect(g.config.deckSize, 66); // 65 normal + 1 special
      final ai = AiDecider.of(DifficultyProfile.normal, 0);
      var guard = 0;
      while (!g.isOver && guard++ < 5000) {
        final p = g.currentPlayer;
        switch (g.phase) {
          case Phase.draw:
            final top = g.topDiscard!;
            if (ai.shouldTakeDiscard(p.hand, top)) {
              g.apply(p.playerId, const DrawDiscard());
            } else {
              g.apply(p.playerId, const DrawStock());
            }
          case Phase.discard:
            g.apply(p.playerId, Discard(ai.chooseDiscard(p.hand)));
          case Phase.post:
            if (ai.shouldShow(p.hand, g.config.handSize)) {
              g.apply(p.playerId, const Show());
            } else {
              g.passTurn();
            }
          default:
            fail('unexpected phase ${g.phase} mid-match');
        }
      }
      expect(g.isOver, true);
      expect(guard < 5000, true);
    });
  });

  group('E1.4 AI parity', () {
    final easy = AiDecider(DifficultyProfile.easy, 1.2);
    final normal = AiDecider(DifficultyProfile.normal, 1.0);
    final hard = AiDecider(DifficultyProfile.hard, 0.85);

    test('hard takes group-completing card', () {
      expect(
          hard.shouldTakeDiscard(hand([c(5, 0), c(5, 1), c(9, 0)]), c(5, 2)),
          true);
    });

    test('bestAfterDraw 2,3,4+K = 9', () {
      expect(hard.bestAfterDraw(hand([c(2, 0), c(3, 0), c(4, 0)]), c(13, 0)), 9);
    });

    test('bestAfterDraw completes group', () {
      expect(hard.bestAfterDraw(hand([c(5, 0), c(5, 1), c(9, 0)]), c(5, 2)), 0);
    });

    test('easy discards K (highest face)', () {
      expect(easy.chooseDiscard(hand([c(2, 0), c(13, 0), c(4, 0)])).rank,
          Rank.king);
    });

    test('hard keeps group over lone high card', () {
      final chosen = hard.chooseDiscard(hand([c(5, 0), c(5, 1), c(9, 0)]));
      expect(chosen.rank, Rank.nine);
    });

    test('show thresholds (V1 exact)', () {
      expect(easy.showThreshold(7), 7);
      expect(normal.showThreshold(7), 4);
      expect(hard.showThreshold(7), 2);
      expect(AiDecider(DifficultyProfile.hard, 0.1).showThreshold(7), 2);
    });

    test('shouldShow: always on 0; per-threshold otherwise', () {
      expect(hard.shouldShow(hand([c(5, 0), c(5, 1), c(5, 2)]), 7), true);
      expect(easy.shouldShow(hand([c(4, 0), c(2, 1)]), 7), true);
      expect(hard.shouldShow(hand([c(4, 0), c(2, 1)]), 7), false);
      expect(
          normal.shouldShow(
              hand([c(4, 0), c(5, 0), c(5, 1), c(5, 2)]), 7),
          true);
    });

    test('rejects zero aggression', () {
      expect(() => AiDecider(DifficultyProfile.normal, 0), throwsArgumentError);
    });
  });

  group('DrawBrain (V2.2 §32–39)', () {
    test('draws a group-completing card over noise from stock top', () {
      final h = hand([c(7, 0), c(7, 1), c(3, 0), c(11, 2)]);
      // Stock ordered so top (last) is a useless K, but a 7 sits deeper.
      final stock = [c(2, 2), c(8, 1), c(7, 2), c(9, 0), c(13, 3)];
      final picked = DrawBrain.drawFromStock(stock, h, 0);
      expect(picked.rank, Rank.seven, reason: 'should surface the 7');
      expect(stock.length, 4, reason: 'exactly one card removed');
    });

    test('opening balancer creates a pair when possible', () {
      final h = hand([c(2, 0), c(5, 1), c(7, 2), c(9, 3), c(13, 0)]); // no pair
      // Stock contains a 5 the balancer can swap in.
      final stock = <Card>[c(3, 0), c(5, 2), c(11, 1), c(4, 2)];
      // A deterministic RNG that always fires the 72% roll (nextDouble → 0).
      final rng = _AlwaysHitRng();
      DrawBrain.balanceOpeningHand(h, stock, rng);
      final ranks = h.cards.map((e) => e.rank).toList()..sort((a, b) => a.value - b.value);
      expect(ranks.where((r) => r == Rank.five).length, 2);
    });

    test('opening balancer leaves a hand that already has a pair', () {
      final h = hand([c(5, 0), c(5, 1), c(7, 2), c(9, 3)]);
      final before = h.cards.map((e) => e.id).toList();
      final stock = <Card>[c(5, 2), c(11, 1)];
      DrawBrain.balanceOpeningHand(h, stock, Random(0));
      expect(h.cards.map((e) => e.id).toList(), before);
    });

    test('session exposes per-player dry-draw counter', () {
      final g = GameSession(GameConfig.quickPlay(2), ['p1', 'p2'], 7);
      expect(g.dryDrawsFor('p1'), 0);
      expect(g.dryDrawsFor('p2'), 0);
    });
  });

  group('E1.5 simulation (scaled): invariants over 500 matches', () {
    test('card conservation + seq order + termination', () {
      for (var seed = 0; seed < 500; seed++) {
        final g = GameSession(
            GameConfig.quickPlay(4), ['a', 'b', 'c', 'd'], seed);
        final ai = [
          for (var i = 0; i < 4; i++)
            AiDecider.of(DifficultyProfile.values[seed % 3], i)
        ];
        var guard = 0;
        while (!g.isOver && guard++ < 5000) {
          final idx = g.currentPlayerIdx;
          final p = g.currentPlayer;
          final decider = ai[idx];
          switch (g.phase) {
            case Phase.draw:
              final top = g.topDiscard!;
              decider.shouldTakeDiscard(p.hand, top)
                  ? g.apply(p.playerId, const DrawDiscard())
                  : g.apply(p.playerId, const DrawStock());
            case Phase.discard:
              g.apply(p.playerId, Discard(decider.chooseDiscard(p.hand)));
            case Phase.post:
              decider.shouldShow(p.hand, g.config.handSize)
                  ? g.apply(p.playerId, const Show())
                  : g.passTurn();
            default:
              fail('unexpected phase');
          }

          // invariant: card conservation at every step (specials included)
          final ids = <int>{
            for (final pl in g.players) ...pl.hand.cards.map((e) => e.id),
          };
          final top = g.topDiscard;
          if (top != null) ids.add(top.id);
          // ids = hands ∪ {topDiscard}; |hands| = ids − (topDiscard?1:0)
          final handCards = ids.length - (top != null ? 1 : 0);
          final totalCards = handCards + g.discardSize + g.stockSize;
          expect(totalCards, g.config.deckSize,
              reason: 'seed=$seed turn=$guard');
          // visible specials never exceed the configured amount
          final visibleSpecials = g.players
                  .expand((p) => p.hand.cards)
                  .where((c) => c.isSpecial)
                  .length +
              (top?.isSpecial == true ? 1 : 0);
          expect(visibleSpecials, lessThanOrEqualTo(g.config.specialCount),
              reason: 'seed=$seed turn=$guard');
        }
        expect(g.isOver, true, reason: 'seed=$seed must terminate');

        // invariant: event seq strictly increasing
        for (var i = 1; i < g.eventLog.length; i++) {
          expect(g.eventLog[i].seq > g.eventLog[i - 1].seq, true,
              reason: 'seed=$seed event $i');
        }
        // invariant: scores non-negative
        for (final p in g.players) {
          expect(p.matchScore >= 0, true);
        }
      }
    });
  });
}
