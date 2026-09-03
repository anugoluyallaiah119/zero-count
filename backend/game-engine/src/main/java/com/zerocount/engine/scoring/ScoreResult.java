package com.zerocount.engine.scoring;

import com.zerocount.engine.model.Card;
import java.util.List;

/**
 * Result of scoring a hand.
 * @param count   total points the hand costs (lower is better)
 * @param groups  completed zero-groups (3+ same rank) found in the hand
 * @param loose   cards not part of any group — these are what `count` sums
 */
public record ScoreResult(int count, List<List<Card>> groups, List<Card> loose) {

    public int groupCount() { return groups.size(); }
}
