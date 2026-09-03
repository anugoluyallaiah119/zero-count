package com.zerocount.engine.model;

/** Card suit. Order matches V1 engine (HEARTS first) so seeded shuffles stay comparable. */
public enum Suit {
    HEARTS, DIAMONDS, CLUBS, SPADES;

    public boolean isRed() {
        return this == HEARTS || this == DIAMONDS;
    }

    public String symbol() {
        return switch (this) {
            case HEARTS -> "♥";
            case DIAMONDS -> "♦";
            case CLUBS -> "♣";
            case SPADES -> "♠";
        };
    }
}
