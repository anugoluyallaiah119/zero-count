package com.zerocount.engine.model;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** A player's hand. Mutable during a turn (draw adds, discard removes); exposes read-only view. */
public final class Hand {
    private final List<Card> cards = new ArrayList<>();

    public void add(Card c) { cards.add(c); }

    public Card remove(Card c) {
        if (!cards.remove(c)) throw new IllegalStateException("card not in hand: " + c);
        return c;
    }

    public Card removeAt(int index) { return cards.remove(index); }

    public List<Card> cards() { return Collections.unmodifiableList(cards); }

    public int size() { return cards.size(); }

    public boolean contains(Card c) { return cards.contains(c); }

    @Override
    public String toString() { return cards.toString(); }
}
