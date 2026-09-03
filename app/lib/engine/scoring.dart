import 'model.dart';

/// Result of optimizing a hand: minimal count, zero groups, loose cards.
class ScoreResult {
  const ScoreResult(this.count, this.groups, this.loose);

  final int count;
  final List<List<Card>> groups;
  final List<Card> loose;
}

/// Scoring engine — direct port of the frozen V1 optimize().
///
/// V1 rules (locked):
///  - 3+ cards of the same rank form a ZERO group (count 0), any size.
///  - Sequences have NO special meaning (7+8+9 = 24).
///  - Pairs count fully (5+5 = 10).
///
/// Optimality (proven in V1): groups are rank-disjoint and cost 0 regardless
/// of size, so grouping every rank held 3+ times is trivially optimal — O(n).
abstract final class ScoringEngine {
  static ScoreResult optimize(List<Card> cards) {
    final byRank = <Rank, List<Card>>{};
    for (final c in cards) {
      byRank.putIfAbsent(c.rank, () => []).add(c);
    }

    final groups = <List<Card>>[];
    final loose = <Card>[];
    var count = 0;

    for (final sameRank in byRank.values) {
      if (sameRank.length >= 3) {
        groups.add(List.unmodifiable(sameRank)); // ZERO group
      } else {
        loose.addAll(sameRank); // singles/pairs count fully
        for (final c in sameRank) {
          count += c.value;
        }
      }
    }
    return ScoreResult(count, List.unmodifiable(groups), List.unmodifiable(loose));
  }

  static int count(List<Card> cards) => optimize(cards).count;
}
