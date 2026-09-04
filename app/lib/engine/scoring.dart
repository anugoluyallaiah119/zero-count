import 'model.dart';

/// Result of optimizing a hand: minimal count, zero groups, loose cards.
class ScoreResult {
  const ScoreResult(this.count, this.groups, this.loose);

  final int count;
  final List<List<Card>> groups;
  final List<Card> loose;
}

/// Scoring engine — V1 rules + Special card pair completion.
///
/// V1 rules (locked for normal cards):
///  - 3+ cards of the same rank form a ZERO group (count 0), any size.
///  - Sequences have NO special meaning (7+8+9 = 24).
///  - Pairs count fully (5+5 = 10).
///
/// Special rule:
///  - A Special card + exactly 2 cards of the same rank form a ZERO group of 3.
///  - A lone Special counts as 10.
///  - Specials do not join existing 3+ groups and do not pair with each other.
///
/// With at most 2 specials per hand, brute-force assignment is trivial and
/// keeps the optimizer obviously correct.
abstract final class ScoringEngine {
  /// Optimise [cards]. When [pinRank] is non-null and the hand contains
  /// exactly two normal cards of that rank plus at least one Special, the
  /// Special is *forced* to complete that pair (used by the "Choose your
  /// Zero" pair-picker). Otherwise the engine finds the lowest-count
  /// assignment on its own.
  static ScoreResult optimize(List<Card> cards, {Rank? pinRank}) {
    final specials = cards.where((c) => c.isSpecial).toList();
    final normal = cards.where((c) => !c.isSpecial).toList();

    if (specials.isEmpty) return _optimizeNormal(normal);

    final normalByRank = <Rank, List<Card>>{};
    for (final c in normal) {
      normalByRank.putIfAbsent(c.rank, () => []).add(c);
    }

    // V2.2: a Special can only complete a pair of exactly 2 matching normal
    // cards. Ranks with 3+ normal cards already form a natural zero group.
    final pairableRanks = normalByRank.entries
        .where((e) => e.value.length == 2)
        .map((e) => e.key)
        .toList();

    // If the caller pinned a rank and it's a valid pair, honour it by only
    // exploring that one assignment for the first special.
    final effectivePin =
        pinRank != null && pairableRanks.contains(pinRank) ? pinRank : null;

    ScoreResult? best;
    final assignment = List<int?>.filled(specials.length, null);
    final usedPerRank = <Rank, int>{};

    void search(int idx) {
      if (idx == specials.length) {
        final result = _scoreAssignment(
          normal,
          specials,
          normalByRank,
          pairableRanks,
          assignment,
        );
        if (best == null || result.count < best!.count) best = result;
        return;
      }

      // Pin only applies to the first special.
      if (idx == 0 && effectivePin != null) {
        final r = pairableRanks.indexOf(effectivePin);
        usedPerRank[effectivePin] = 1;
        assignment[idx] = r;
        search(idx + 1);
        usedPerRank.remove(effectivePin);
        assignment[idx] = null;
        return;
      }

      // Option 1: this special stays unused.
      assignment[idx] = -1;
      search(idx + 1);

      // Option 2: assign it to any rank that still has unpaired cards.
      for (var r = 0; r < pairableRanks.length; r++) {
        final rank = pairableRanks[r];
        final availablePairs = normalByRank[rank]!.length ~/ 2;
        if ((usedPerRank[rank] ?? 0) < availablePairs) {
          usedPerRank[rank] = (usedPerRank[rank] ?? 0) + 1;
          assignment[idx] = r;
          search(idx + 1);
          usedPerRank[rank] = (usedPerRank[rank] ?? 0) - 1;
          if (usedPerRank[rank] == 0) usedPerRank.remove(rank);
        }
      }
      assignment[idx] = null;
    }

    search(0);
    return best!;
  }

  static int count(List<Card> cards, {Rank? pinRank}) =>
      optimize(cards, pinRank: pinRank).count;

  /// V1 optimizer for hands without specials.
  static ScoreResult _optimizeNormal(List<Card> cards) {
    final byRank = <Rank, List<Card>>{};
    for (final c in cards) {
      byRank.putIfAbsent(c.rank, () => []).add(c);
    }

    final groups = <List<Card>>[];
    final loose = <Card>[];
    var count = 0;

    for (final sameRank in byRank.values) {
      if (sameRank.length >= 3) {
        groups.add(List.unmodifiable(sameRank));
      } else {
        loose.addAll(sameRank);
        for (final c in sameRank) {
          count += c.value;
        }
      }
    }
    return ScoreResult(count, List.unmodifiable(groups), List.unmodifiable(loose));
  }

  /// Score one assignment of specials to ranks (or unused).
  static ScoreResult _scoreAssignment(
    List<Card> normal,
    List<Card> specials,
    Map<Rank, List<Card>> normalByRank,
    List<Rank> pairableRanks,
    List<int?> assignment,
  ) {
    // Count specials assigned to each rank.
    final usedByRank = <Rank, int>{};
    final unusedSpecials = <Card>[];
    for (var i = 0; i < assignment.length; i++) {
      final a = assignment[i];
      if (a == null || a < 0) {
        unusedSpecials.add(specials[i]);
      } else {
        final rank = pairableRanks[a];
        usedByRank[rank] = (usedByRank[rank] ?? 0) + 1;
      }
    }

    // Build special groups (2 normal + 1 special) and remaining normal cards.
    final groups = <List<Card>>[];
    final consumedCount = <Rank, int>{};
    final remainingNormal = <Card>[];

    for (final c in normal) {
      final rank = c.rank;
      final need = (usedByRank[rank] ?? 0) * 2;
      final consumed = consumedCount[rank] ?? 0;
      if (consumed < need) {
        consumedCount[rank] = consumed + 1;
        // Append to an open special group for this rank, or start one.
        var placed = false;
        for (final g in groups) {
          if (!g.any((x) => x.isSpecial) &&
              g.any((x) => x.rank == rank) &&
              g.length < 3) {
            g.add(c);
            placed = true;
            break;
          }
        }
        if (!placed) groups.add([c]);
      } else {
        remainingNormal.add(c);
      }
    }

    // Attach specials to their groups.
    for (var i = 0; i < assignment.length; i++) {
      final a = assignment[i];
      if (a == null || a < 0) continue;
      final rank = pairableRanks[a];
      for (final g in groups) {
        if (!g.any((x) => x.isSpecial) && g.any((x) => x.rank == rank)) {
          g.add(specials[i]);
          break;
        }
      }
    }

    final normalResult = _optimizeNormal(remainingNormal);
    final allGroups = [
      ...groups.map((g) => List<Card>.unmodifiable(g)),
      ...normalResult.groups,
    ];
    final loose = [...normalResult.loose, ...unusedSpecials];
    final count = normalResult.count + unusedSpecials.length * 10;

    return ScoreResult(count, List.unmodifiable(allGroups), List.unmodifiable(loose));
  }
}
