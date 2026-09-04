package com.zerocount.engine.ai;

import com.zerocount.engine.model.Card;
import com.zerocount.engine.model.Hand;
import com.zerocount.engine.scoring.ScoringEngine;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import com.zerocount.engine.model.Rank;

/**
 * AI decision engine — direct port of frozen V1 (bestAfterDraw, bestDiscardIdx,
 * show threshold). All methods are pure: same hand + same inputs = same decision.
 *
 * Personality: each AI has an `aggression` factor (V1 used 1.2 / 1.0 / 0.85 per
 * seat) which scales the SHOW threshold — aggressive AIs show earlier.
 */
public final class AiDecider {

    private final DifficultyProfile profile;
    private final double aggression;

    public AiDecider(DifficultyProfile profile, double aggression) {
        if (aggression <= 0) throw new IllegalArgumentException("aggression must be > 0");
        this.profile = profile;
        this.aggression = aggression;
    }

    public static AiDecider of(DifficultyProfile profile, int seatIndex) {
        double[] seatAggression = {1.2, 1.0, 0.85}; // V1 AI_POOL aggression per seat
        double aggr = seatAggression[Math.min(seatIndex, seatAggression.length - 1)];
        return new AiDecider(profile, aggr);
    }

    /** Should the AI take the visible discard instead of drawing from stock? (V1 rule) */
    public boolean shouldTakeDiscard(Hand hand, Card topDiscard) {
        int now = ScoringEngine.count(hand.cards());
        return bestAfterDraw(hand, topDiscard) <= now - profile.drawMargin();
    }

    /** Best achievable count after drawing `drawn` and then discarding one card. */
    public int bestAfterDraw(Hand hand, Card drawn) {
        List<Card> h = new ArrayList<>(hand.cards());
        h.add(drawn);
        int best = Integer.MAX_VALUE;
        for (int i = 0; i < h.size(); i++) {
            List<Card> rest = new ArrayList<>(h);
            rest.remove(i);
            best = Math.min(best, ScoringEngine.count(rest));
        }
        return best;
    }

    /**
     * Which card to discard.
     * EASY (naive): highest face value. NORMAL/HARD: card whose removal minimizes count.
     * Specials are kept when they can complete a pair and discarded as dead weight otherwise.
     */
    public Card chooseDiscard(Hand hand) {
        List<Card> cards = hand.cards();
        if (cards.isEmpty()) throw new IllegalArgumentException("empty hand");
        if (profile.naive()) {
            Card worst = cards.get(0);
            for (Card c : cards) if (c.value() > worst.value()) worst = c;
            return worst;
        }
        Card best = cards.get(0);
        int bestCount = Integer.MAX_VALUE;
        for (Card c : cards) {
            List<Card> rest = new ArrayList<>(cards);
            rest.remove(c);
            int count = ScoringEngine.count(rest);
            if (count < bestCount) { bestCount = count; best = c; }
        }
        if (best.isSpecial() && hasPairableRank(hand, best)) {
            Card fallback = null;
            int fallbackCount = Integer.MAX_VALUE;
            for (Card c : cards) {
                if (c.isSpecial() || c == best) continue;
                List<Card> rest = new ArrayList<>(cards);
                rest.remove(c);
                int count = ScoringEngine.count(rest);
                if (count <= fallbackCount) { fallbackCount = count; fallback = c; }
            }
            if (fallback != null && fallbackCount <= bestCount) best = fallback;
        }
        return best;
    }

    /**
     * V2.2: a Special is usable only when a rank has exactly 2 normal cards.
     * Ranks with 3+ cards already form a natural zero group.
     */
    private boolean hasPairableRank(Hand hand, Card exclude) {
        Map<Rank, Integer> counts = new HashMap<>();
        for (Card c : hand.cards()) {
            if (c.isSpecial() || c.equals(exclude)) continue;
            counts.merge(c.rank(), 1, Integer::sum);
        }
        return counts.values().stream().anyMatch(n -> n == 2);
    }

    /** SHOW threshold for this AI (V1: max(2, handSize * 0.6 * aggression * showMul)). */
    public int showThreshold(int handSize) {
        return Math.max(2, (int) Math.round(handSize * 0.6 * aggression * profile.showMul()));
    }

    /** Should the AI SHOW now? V1: always on 0, otherwise when count <= threshold. */
    public boolean shouldShow(Hand hand, int handSize) {
        int now = ScoringEngine.count(hand.cards());
        return now == 0 || now <= showThreshold(handSize);
    }
}
