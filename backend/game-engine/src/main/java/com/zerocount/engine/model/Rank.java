package com.zerocount.engine.model;

/**
 * Card rank. V1 rule (locked): value A=1, 2-9 face, 10/J/Q/K=10.
 * J/Q/K are DISTINCT ranks even though their values are equal — J+Q+K = 30, JJJ = 0.
 */
public enum Rank {
    ACE(1, "A"), TWO(2, "2"), THREE(3, "3"), FOUR(4, "4"), FIVE(5, "5"),
    SIX(6, "6"), SEVEN(7, "7"), EIGHT(8, "8"), NINE(9, "9"), TEN(10, "10"),
    JACK(10, "J"), QUEEN(10, "Q"), KING(10, "K");

    private final int value;
    private final String label;

    Rank(int value, String label) {
        this.value = value;
        this.label = label;
    }

    public int value() { return value; }
    public String label() { return label; }

    public static Rank fromInt(int r) {
        if (r < 1 || r > 13) throw new IllegalArgumentException("rank 1..13, got " + r);
        return values()[r - 1];
    }
}
