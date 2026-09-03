package com.zerocount.engine.session;

import com.zerocount.engine.model.Hand;

/** Per-player state within a match. matchScore accumulates across rounds. */
public final class PlayerState {
    private final String playerId;
    private final Hand hand = new Hand();
    private int matchScore;

    public PlayerState(String playerId) {
        if (playerId == null || playerId.isBlank())
            throw new IllegalArgumentException("playerId required");
        this.playerId = playerId;
    }

    public String playerId() { return playerId; }
    public Hand hand() { return hand; }
    public int matchScore() { return matchScore; }

    /** Adds the round's count to the cumulative match score. */
    public void addRoundScore(int roundCount) {
        if (roundCount < 0) throw new IllegalArgumentException("round count cannot be negative");
        matchScore += roundCount;
    }

    public void resetHandForNewRound() {
        while (hand.size() > 0) hand.removeAt(0);
    }
}
