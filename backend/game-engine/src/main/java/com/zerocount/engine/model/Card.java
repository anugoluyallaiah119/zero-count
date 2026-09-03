package com.zerocount.engine.model;

import java.util.Objects;

/**
 * Immutable card with a globally unique id (per match).
 * Ids are assigned by DeckBuilder — required for the card-conservation invariant
 * (no duplicates, no missing cards across stock/discard/hands).
 */
public final class Card {
    private final int id;
    private final Rank rank;
    private final Suit suit;
    private final int deck; // which physical deck (0 or 1) — matters for 13-card games

    public Card(int id, Rank rank, Suit suit, int deck) {
        this.id = id;
        this.rank = Objects.requireNonNull(rank);
        this.suit = Objects.requireNonNull(suit);
        this.deck = deck;
    }

    public int id() { return id; }
    public Rank rank() { return rank; }
    public Suit suit() { return suit; }
    public int deck() { return deck; }

    /** V1 rule: A=1, 2-9 face value, 10/J/Q/K=10. */
    public int value() { return rank.value(); }

    @Override
    public boolean equals(Object o) {
        return o instanceof Card c && c.id == id; // identity by unique id
    }

    @Override
    public int hashCode() { return Integer.hashCode(id); }

    @Override
    public String toString() { return rank.label() + suit.symbol(); }
}
