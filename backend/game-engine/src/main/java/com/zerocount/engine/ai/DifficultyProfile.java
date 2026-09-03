package com.zerocount.engine.ai;

/**
 * AI difficulty — parameters ported verbatim from frozen V1 DIFFS.
 *
 * @param drawMargin  take the visible discard only if it improves the hand by
 *                    at least this much (HARD takes smaller gains = sharper play)
 * @param naive       EASY mode: discard highest face value, ignore group potential
 * @param showMul     SHOW threshold multiplier (lower = bolder SHOWs)
 */
public record DifficultyProfile(int drawMargin, boolean naive, double showMul) {

    public static final DifficultyProfile EASY   = new DifficultyProfile(3, true,  1.4);
    public static final DifficultyProfile NORMAL = new DifficultyProfile(2, false, 1.0);
    public static final DifficultyProfile HARD   = new DifficultyProfile(1, false, 0.7);

    /** All profiles in difficulty order (enum-style access for harnesses). */
    public static DifficultyProfile[] values() {
        return new DifficultyProfile[]{EASY, NORMAL, HARD};
    }

    public static DifficultyProfile of(String name) {
        return switch (name.toLowerCase()) {
            case "easy"   -> EASY;
            case "hard"   -> HARD;
            default       -> NORMAL;
        };
    }
}
