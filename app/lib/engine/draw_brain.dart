import 'dart:math';

import 'model.dart';
import 'scoring.dart';

/// V2.2 §32–39 anti-starvation draw system.
///
/// The stock stays shuffled, but every stock draw examines a small
/// look-ahead window (default 9) and picks the most useful card for the
/// drawing player. Utility rewards: group-formers > pair-formers > score
/// reduction > low-value cards. Dry-draw soft pity gradually shifts the
/// bias toward useful cards after repeated unproductive draws; it never
/// guarantees a specific rank.
///
/// Opening balancer (§38–39): a fresh hand with no duplicate rank has a
/// configurable chance of being nudged toward at least one pair.
abstract final class DrawBrain {
  /// V2.2: examines the top N stock cards to smooth out dry streaks.
  static const int lookAheadWindow = 9;

  /// Dry draws below this count use pure utility ordering.
  static const int dryDrawThreshold = 3;

  /// Dry draws above this cap deliver a maximum-boost pick.
  static const int dryDrawCap = 6;

  /// A drawn card is "productive" when it beats this delta (score reduction).
  static const int productiveDelta = 1;

  /// V2.2 §38 opening balancer: chance to nudge a dead opening toward a pair.
  static const double openingBalancerChance = 0.72;

  // ---------- stock draw ------------------------------------------------

  /// Choose which card to serve from [stock] to [hand]. The chosen card is
  /// removed from [stock] (which uses last-element = top ordering) and the
  /// remainder keeps its relative order. [dryStreak] biases the pick toward
  /// higher-utility cards after repeated unproductive draws.
  ///
  /// Returns the served card. Does NOT modify [hand] — the caller adds it.
  static Card drawFromStock(List<Card> stock, Hand hand, int dryStreak) {
    if (stock.isEmpty) {
      throw StateError('DrawBrain.drawFromStock: empty stock');
    }
    if (stock.length == 1) return stock.removeLast();

    final windowSize = min(lookAheadWindow, stock.length);
    // Stock top = last element; window is the last [windowSize] entries.
    final start = stock.length - windowSize;
    var bestIdx = stock.length - 1;
    var bestScore = _score(stock[bestIdx], hand, dryStreak);
    for (var i = start; i < stock.length - 1; i++) {
      final s = _score(stock[i], hand, dryStreak);
      // Prefer higher score; break ties by staying closer to the top.
      if (s > bestScore) {
        bestScore = s;
        bestIdx = i;
      }
    }
    return stock.removeAt(bestIdx);
  }

  /// Returns true if drawing [drawn] into [hand] meaningfully lowered the
  /// player's optimised count. Used by the session to increment or reset the
  /// per-player dry-draw counter.
  static bool wasProductive(Card drawn, Hand handBeforeDraw) {
    final before = ScoringEngine.count(handBeforeDraw.cards);
    // "Best if we discarded the drawn card immediately" is the worst case.
    final withDraw = [...handBeforeDraw.cards, drawn];
    var bestAfter = 1 << 30;
    for (var i = 0; i < withDraw.length; i++) {
      final rest = [...withDraw]..removeAt(i);
      final c = ScoringEngine.count(rest);
      if (c < bestAfter) bestAfter = c;
    }
    return before - bestAfter >= productiveDelta;
  }

  // ---------- opening balancer -----------------------------------------

  /// V2.2 §38–39: if [hand] has no pair, with [openingBalancerChance] search
  /// the remaining [stock] for a card whose rank matches one already in the
  /// hand and swap it with the highest-value card. Never guarantees a pair
  /// (only nudges), preserves card conservation, and only mutates on hit.
  static void balanceOpeningHand(Hand hand, List<Card> stock, Random rng) {
    if (hand.size == 0 || stock.isEmpty) return;
    if (_hasAnyPair(hand)) return;
    if (rng.nextDouble() >= openingBalancerChance) return;

    // Ranks the player already holds — any duplicate makes an instant pair.
    final ranksHeld = <Rank>{for (final c in hand.cards) c.rank};
    // Find any matching-rank card in the stock; first match is fine.
    var stockIdx = -1;
    for (var i = stock.length - 1; i >= 0; i--) {
      if (!stock[i].isSpecial && ranksHeld.contains(stock[i].rank)) {
        stockIdx = i;
        break;
      }
    }
    if (stockIdx < 0) return;

    // Swap with the highest face-value non-special card in hand.
    Card? victim;
    for (final c in hand.cards) {
      if (c.isSpecial) continue;
      if (victim == null || c.value > victim.value) victim = c;
    }
    if (victim == null || victim.value < stock[stockIdx].value) return;

    final promoted = stock[stockIdx];
    hand.remove(victim);
    hand.add(promoted);
    stock[stockIdx] = victim;
  }

  // ---------- internals --------------------------------------------------

  /// Utility score for [c] entering [hand]. Higher = more useful.
  ///  - completes a 3+ group (rank already has ≥2)                 +40
  ///  - forms a fresh pair (rank has exactly 1)                    +25
  ///  - would complete a pair for a held Special                   +30
  ///  - low face value (A, 2, 3)                                    +6
  ///  - mid face value (4-6)                                        +2
  ///  - high value with no partner already                          −6
  ///  - dry-pity bonus: scales useful picks after repeated dry draws
  static int _score(Card c, Hand hand, int dryStreak) {
    final rankCount = <Rank, int>{};
    var hasSpecial = false;
    for (final h in hand.cards) {
      if (h.isSpecial) {
        hasSpecial = true;
        continue;
      }
      rankCount[h.rank] = (rankCount[h.rank] ?? 0) + 1;
    }

    var utility = 0;
    var useful = false;

    if (c.isSpecial) {
      // A Special is only useful when the hand has an exact pair to consume.
      final hasExactPair = rankCount.values.any((n) => n == 2);
      utility += hasExactPair ? 35 : -10;
      useful = hasExactPair;
    } else {
      final n = rankCount[c.rank] ?? 0;
      if (n >= 2) {
        utility += 40;
        useful = true;
      } else if (n == 1) {
        utility += 25;
        useful = true;
        if (hasSpecial) utility += 30; // completes the Special's pair target
      } else if (c.value <= 3) {
        utility += 6;
        useful = true;
      } else if (c.value <= 6) {
        utility += 2;
      } else {
        utility -= 6;
      }
    }

    if (dryStreak >= dryDrawThreshold && useful) {
      final level = min(dryStreak, dryDrawCap) - dryDrawThreshold + 1;
      utility += level * 8;
    }
    return utility;
  }

  static bool _hasAnyPair(Hand hand) {
    final counts = <Rank, int>{};
    for (final c in hand.cards) {
      if (c.isSpecial) continue;
      counts[c.rank] = (counts[c.rank] ?? 0) + 1;
      if (counts[c.rank]! >= 2) return true;
    }
    return false;
  }
}
