package com.zerocount.engine.ai;

/**
 * AI personality — difficulty + aggression. Aggression is per-seat (V1: 1.2/1.0/0.85)
 * so multiple AIs in one match behave differently and feel human.
 */
public record AiPlayer(String playerId, DifficultyProfile difficulty, double aggression) {

    public AiPlayer {
        if (aggression <= 0 || aggression > 2.0)
            throw new IllegalArgumentException("aggression out of sane range: " + aggression);
    }

    /** V1 seat personalities, indexed by seat order. */
    public static final double[] SEAT_AGGRESSION = {1.2, 1.0, 0.85};

    public static AiPlayer forSeat(String playerId, DifficultyProfile diff, int aiSeatIdx) {
        double aggr = SEAT_AGGRESSION[Math.min(aiSeatIdx, SEAT_AGGRESSION.length - 1)];
        return new AiPlayer(playerId, diff, aggr);
    }
}
