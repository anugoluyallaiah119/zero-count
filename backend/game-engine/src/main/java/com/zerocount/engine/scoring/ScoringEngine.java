package com.zerocount.engine.scoring;

import com.zerocount.engine.model.Card;
import com.zerocount.engine.model.Rank;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Scoring engine — V1 rules + Special card pair completion.
 *
 * V1 rules (locked for normal cards):
 *  - 3+ cards of the same rank form a ZERO group (count 0), regardless of size.
 *  - Sequences have NO special meaning (7+8+9 = 24).
 *  - Pairs count fully (5+5 = 10).
 *  - A=1, 2-9 face value, 10/J/Q/K=10; J/Q/K are distinct ranks.
 *
 * Special rule:
 *  - A Special card + exactly 2 cards of the same rank form a ZERO group of 3.
 *  - A lone Special counts as 10.
 *  - Specials do not join existing 3+ groups and do not pair with each other.
 */
public final class ScoringEngine {

    private ScoringEngine() {}

    /** Optimal score for a hand. */
    public static ScoreResult optimize(List<Card> cards) {
        return optimize(cards, null);
    }

    /** Optimal score with an optional pin: force the Special onto that rank's
     *  pair if it's a valid target ("Choose your Zero"). Ignored otherwise. */
    public static ScoreResult optimize(List<Card> cards, Rank pinRank) {
        List<Card> specials = new ArrayList<>();
        List<Card> normal = new ArrayList<>();
        for (Card c : cards) {
            if (c.isSpecial()) specials.add(c);
            else normal.add(c);
        }

        if (specials.isEmpty()) return optimizeNormal(normal);

        Map<Rank, List<Card>> normalByRank = new LinkedHashMap<>();
        for (Card c : normal) normalByRank.computeIfAbsent(c.rank(), k -> new ArrayList<>()).add(c);

        // V2.2: a Special can only complete a pair of exactly 2 matching normal
        // cards. Ranks with 3+ normal cards already form a natural zero group.
        List<Rank> pairableRanks = new ArrayList<>();
        for (Map.Entry<Rank, List<Card>> e : normalByRank.entrySet()) {
            if (e.getValue().size() == 2) pairableRanks.add(e.getKey());
        }
        Rank effectivePin = (pinRank != null && pairableRanks.contains(pinRank))
            ? pinRank : null;

        final ScoreResult[] best = { null };
        int[] assignment = new int[specials.size()];
        java.util.Arrays.fill(assignment, -1);
        search(0, effectivePin, assignment, specials, normal, normalByRank, pairableRanks,
            new HashMap<>(), r -> {
                if (best[0] == null || r.count() < best[0].count()) best[0] = r;
            });
        return best[0];
    }

    private static void search(int idx, Rank pin, int[] assignment,
                               List<Card> specials, List<Card> normal,
                               Map<Rank, List<Card>> normalByRank, List<Rank> pairableRanks,
                               Map<Rank, Integer> usedPerRank, java.util.function.Consumer<ScoreResult> sink) {
        if (idx == assignment.length) {
            sink.accept(scoreAssignment(normal, specials, normalByRank, pairableRanks, assignment));
            return;
        }
        // "Choose your Zero" pin only applies to the first special.
        if (idx == 0 && pin != null) {
            int r = pairableRanks.indexOf(pin);
            usedPerRank.put(pin, 1);
            assignment[idx] = r;
            search(idx + 1, pin, assignment, specials, normal, normalByRank, pairableRanks,
                usedPerRank, sink);
            usedPerRank.remove(pin);
            assignment[idx] = -1;
            return;
        }

        // Option 1: this special stays unused.
        assignment[idx] = -1;
        search(idx + 1, pin, assignment, specials, normal, normalByRank, pairableRanks,
            usedPerRank, sink);

        // Option 2: assign it to any rank that still has unpaired cards.
        for (int r = 0; r < pairableRanks.size(); r++) {
            Rank rank = pairableRanks.get(r);
            int availablePairs = normalByRank.get(rank).size() / 2;
            int used = usedPerRank.getOrDefault(rank, 0);
            if (used < availablePairs) {
                usedPerRank.put(rank, used + 1);
                assignment[idx] = r;
                search(idx + 1, pin, assignment, specials, normal, normalByRank, pairableRanks,
                    usedPerRank, sink);
                int after = usedPerRank.get(rank) - 1;
                if (after == 0) usedPerRank.remove(rank);
                else usedPerRank.put(rank, after);
            }
        }
        assignment[idx] = -1;
    }

    private static ScoreResult scoreAssignment(List<Card> normal, List<Card> specials,
                                               Map<Rank, List<Card>> normalByRank,
                                               List<Rank> pairableRanks, int[] assignment) {
        Map<Rank, Integer> usedByRank = new HashMap<>();
        List<Card> unusedSpecials = new ArrayList<>();
        for (int i = 0; i < assignment.length; i++) {
            int a = assignment[i];
            if (a < 0) {
                unusedSpecials.add(specials.get(i));
            } else {
                Rank rank = pairableRanks.get(a);
                usedByRank.put(rank, usedByRank.getOrDefault(rank, 0) + 1);
            }
        }

        List<List<Card>> groups = new ArrayList<>();
        Map<Rank, Integer> consumedCount = new HashMap<>();
        List<Card> remainingNormal = new ArrayList<>();

        for (Card c : normal) {
            Rank rank = c.rank();
            int need = usedByRank.getOrDefault(rank, 0) * 2;
            int consumed = consumedCount.getOrDefault(rank, 0);
            if (consumed < need) {
                consumedCount.put(rank, consumed + 1);
                boolean placed = false;
                for (List<Card> g : groups) {
                    if (g.stream().noneMatch(Card::isSpecial) &&
                        g.stream().anyMatch(x -> x.rank() == rank) &&
                        g.size() < 3) {
                        g.add(c);
                        placed = true;
                        break;
                    }
                }
                if (!placed) {
                    List<Card> g = new ArrayList<>();
                    g.add(c);
                    groups.add(g);
                }
            } else {
                remainingNormal.add(c);
            }
        }

        for (int i = 0; i < assignment.length; i++) {
            int a = assignment[i];
            if (a < 0) continue;
            Rank rank = pairableRanks.get(a);
            for (List<Card> g : groups) {
                if (g.stream().noneMatch(Card::isSpecial) && g.stream().anyMatch(x -> x.rank() == rank)) {
                    g.add(specials.get(i));
                    break;
                }
            }
        }

        ScoreResult normalResult = optimizeNormal(remainingNormal);
        List<List<Card>> allGroups = new ArrayList<>(groups);
        allGroups.addAll(normalResult.groups());
        List<Card> loose = new ArrayList<>(normalResult.loose());
        loose.addAll(unusedSpecials);
        int count = normalResult.count() + unusedSpecials.size() * 10;

        return new ScoreResult(count, List.copyOf(allGroups), List.copyOf(loose));
    }

    private static ScoreResult optimizeNormal(List<Card> cards) {
        Map<Rank, List<Card>> byRank = new LinkedHashMap<>();
        for (Card c : cards) byRank.computeIfAbsent(c.rank(), k -> new ArrayList<>()).add(c);

        List<List<Card>> groups = new ArrayList<>();
        List<Card> loose = new ArrayList<>();
        int count = 0;

        for (List<Card> sameRank : byRank.values()) {
            if (sameRank.size() >= 3) {
                groups.add(List.copyOf(sameRank));
            } else {
                loose.addAll(sameRank);
                for (Card c : sameRank) count += c.value();
            }
        }
        return new ScoreResult(count, List.copyOf(groups), List.copyOf(loose));
    }

    /** Convenience: just the count. */
    public static int count(List<Card> cards) {
        return optimize(cards).count();
    }

    /** Convenience: count with an optional pin ("Choose your Zero"). */
    public static int count(List<Card> cards, Rank pinRank) {
        return optimize(cards, pinRank).count();
    }
}
