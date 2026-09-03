package com.zerocount.engine.scoring;

import com.zerocount.engine.model.Card;
import com.zerocount.engine.model.Rank;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Scoring engine — direct port of the frozen V1 optimize().
 *
 * V1 rules (locked):
 *  - 3+ cards of the same rank form a ZERO group (count 0), regardless of size.
 *  - Sequences have NO special meaning (7+8+9 = 24).
 *  - Pairs count fully (5+5 = 10).
 *  - A=1, 2-9 face value, 10/J/Q/K=10; J/Q/K are distinct ranks.
 *
 * Optimality note (proven in V1): groups are rank-disjoint and cost 0 regardless
 * of size, so grouping every rank held 3+ times is trivially optimal — O(n) greedy.
 */
public final class ScoringEngine {

    private ScoringEngine() {}

    /** Optimal score for a hand. */
    public static ScoreResult optimize(List<Card> cards) {
        Map<Rank, List<Card>> byRank = new LinkedHashMap<>();
        for (Card c : cards) byRank.computeIfAbsent(c.rank(), k -> new ArrayList<>()).add(c);

        List<List<Card>> groups = new ArrayList<>();
        List<Card> loose = new ArrayList<>();
        int count = 0;

        for (List<Card> sameRank : byRank.values()) {
            if (sameRank.size() >= 3) {
                groups.add(List.copyOf(sameRank));          // ZERO group
            } else {
                loose.addAll(sameRank);                      // singles/pairs count fully
                for (Card c : sameRank) count += c.value();
            }
        }
        return new ScoreResult(count, List.copyOf(groups), List.copyOf(loose));
    }

    /** Convenience: just the count. */
    public static int count(List<Card> cards) {
        return optimize(cards).count();
    }
}
