package com.zerocount.engine.session;

import com.zerocount.engine.model.Card;
import com.zerocount.engine.model.Hand;
import com.zerocount.engine.model.Rank;
import com.zerocount.engine.scoring.ScoringEngine;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;

/**
 * V2.2 §32–39 anti-starvation draw brain — Java parity of Dart {@code
 * DrawBrain}. See {@code app/lib/engine/draw_brain.dart} for the design
 * doc. Weights, thresholds, and behaviour must stay in sync so live matches
 * feel identical to offline.
 */
public final class DrawBrain {

    public static final int LOOK_AHEAD_WINDOW = 9;
    public static final int DRY_DRAW_THRESHOLD = 3;
    public static final int DRY_DRAW_CAP = 6;
    public static final int PRODUCTIVE_DELTA = 1;
    public static final double OPENING_BALANCER_CHANCE = 0.72;

    private DrawBrain() {}

    /**
     * Serve a card from [stock] to [hand], examining the top {@link
     * #LOOK_AHEAD_WINDOW} entries. Stock uses last-element-as-top ordering
     * (mirrors the ArrayDeque semantics in {@code GameSession}). Removes and
     * returns the chosen card.
     */
    public static Card drawFromStock(List<Card> stock, Hand hand, int dryStreak) {
        return drawFromStock(stock, hand, dryStreak, AdaptiveDrawParams.DEFAULTS);
    }

    /** Phase 4 overload: per-user tuning via [params]. */
    public static Card drawFromStock(List<Card> stock, Hand hand, int dryStreak,
                                     AdaptiveDrawParams params) {
        if (stock.isEmpty()) throw new IllegalStateException("empty stock");
        if (stock.size() == 1) return stock.remove(stock.size() - 1);
        int windowSize = Math.min(params.lookAheadWindow(), stock.size());
        int start = stock.size() - windowSize;
        int bestIdx = stock.size() - 1;
        int bestScore = score(stock.get(bestIdx), hand, dryStreak, params);
        for (int i = start; i < stock.size() - 1; i++) {
            int s = score(stock.get(i), hand, dryStreak, params);
            if (s > bestScore) {
                bestScore = s;
                bestIdx = i;
            }
        }
        return stock.remove(bestIdx);
    }

    /** True if drawing [drawn] into [handBefore] would reduce the optimised count. */
    public static boolean wasProductive(Card drawn, Hand handBefore) {
        int before = ScoringEngine.count(handBefore.cards());
        List<Card> withDraw = new ArrayList<>(handBefore.cards());
        withDraw.add(drawn);
        int bestAfter = Integer.MAX_VALUE;
        for (int i = 0; i < withDraw.size(); i++) {
            List<Card> rest = new ArrayList<>(withDraw);
            rest.remove(i);
            bestAfter = Math.min(bestAfter, ScoringEngine.count(rest));
        }
        return before - bestAfter >= PRODUCTIVE_DELTA;
    }

    /**
     * V2.2 §38–39: if [hand] has no pair, with {@link
     * #OPENING_BALANCER_CHANCE} search [stock] for a matching-rank card and
     * swap it with the hand's highest-value card. Never guarantees a pair;
     * preserves card conservation; only mutates on hit.
     */
    public static void balanceOpeningHand(Hand hand, List<Card> stock, Random rng) {
        balanceOpeningHand(hand, stock, rng, AdaptiveDrawParams.DEFAULTS);
    }

    /** Phase 4 overload: per-user tuning via [params]. */
    public static void balanceOpeningHand(Hand hand, List<Card> stock, Random rng,
                                          AdaptiveDrawParams params) {
        if (hand.size() == 0 || stock.isEmpty()) return;
        if (hasAnyPair(hand)) return;
        if (rng.nextDouble() >= params.openingBalancerChance()) return;

        Set<Rank> ranksHeld = new HashSet<>();
        for (Card c : hand.cards()) ranksHeld.add(c.rank());
        int stockIdx = -1;
        for (int i = stock.size() - 1; i >= 0; i--) {
            Card s = stock.get(i);
            if (!s.isSpecial() && ranksHeld.contains(s.rank())) { stockIdx = i; break; }
        }
        if (stockIdx < 0) return;

        Card victim = null;
        for (Card c : hand.cards()) {
            if (c.isSpecial()) continue;
            if (victim == null || c.value() > victim.value()) victim = c;
        }
        if (victim == null || victim.value() < stock.get(stockIdx).value()) return;

        Card promoted = stock.get(stockIdx);
        hand.remove(victim);
        hand.add(promoted);
        stock.set(stockIdx, victim);
    }

    // ---------- utility scoring (mirrors Dart weights) --------------------

    static int score(Card c, Hand hand, int dryStreak) {
        return score(c, hand, dryStreak, AdaptiveDrawParams.DEFAULTS);
    }

    static int score(Card c, Hand hand, int dryStreak, AdaptiveDrawParams params) {
        Map<Rank, Integer> rankCount = new HashMap<>();
        boolean hasSpecial = false;
        for (Card h : hand.cards()) {
            if (h.isSpecial()) { hasSpecial = true; continue; }
            rankCount.merge(h.rank(), 1, Integer::sum);
        }
        int utility = 0;
        boolean useful = false;

        if (c.isSpecial()) {
            boolean hasExactPair = rankCount.values().stream().anyMatch(n -> n == 2);
            utility += hasExactPair ? (35 + params.specialUtilityBoost()) : -10;
            useful = hasExactPair;
        } else {
            int n = rankCount.getOrDefault(c.rank(), 0);
            if (n >= 2) {
                utility += 40; useful = true;
            } else if (n == 1) {
                utility += 25; useful = true;
                if (hasSpecial) utility += 30 + params.specialUtilityBoost();
            } else if (c.value() <= 3) {
                utility += 6; useful = true;
            } else if (c.value() <= 6) {
                utility += 2;
            } else {
                utility -= 6;
            }
        }
        if (dryStreak >= params.dryDrawThreshold() && useful) {
            int level = Math.min(dryStreak, DRY_DRAW_CAP) - params.dryDrawThreshold() + 1;
            utility += (int) Math.round(level * 8 * params.dryPityMultiplier());
        }
        return utility;
    }

    private static boolean hasAnyPair(Hand hand) {
        Map<Rank, Integer> counts = new HashMap<>();
        for (Card c : hand.cards()) {
            if (c.isSpecial()) continue;
            int n = counts.merge(c.rank(), 1, Integer::sum);
            if (n >= 2) return true;
        }
        return false;
    }
}
