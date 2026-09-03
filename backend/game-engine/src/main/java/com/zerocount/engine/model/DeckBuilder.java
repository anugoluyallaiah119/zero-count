package com.zerocount.engine.model;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

/**
 * Builds and shuffles decks. Ported from V1 buildDeck/shuffle.
 * Server-side shuffle uses SecureRandom (anti-cheat); tests use a seeded Random
 * so simulation runs are reproducible.
 */
public final class DeckBuilder {

    private DeckBuilder() {}

    /** Ordered, unshuffled deck: deckCount × 52 cards, unique ids. */
    public static List<Card> build(int deckCount) {
        if (deckCount < 1 || deckCount > 2)
            throw new IllegalArgumentException("deckCount must be 1 or 2, got " + deckCount);
        List<Card> deck = new ArrayList<>(deckCount * 52);
        int id = 0;
        for (int d = 0; d < deckCount; d++)
            for (Suit s : Suit.values())
                for (Rank r : Rank.values())
                    deck.add(new Card(id++, r, s, d));
        return deck;
    }

    public static List<Card> buildFor(GameConfig config) {
        return build(config.deckCount());
    }

    /** Fisher-Yates, anti-cheat grade (server). */
    public static List<Card> shuffle(List<Card> deck) {
        return shuffle(deck, new SecureRandom());
    }

    /** Fisher-Yates, reproducible (tests / replays). */
    public static List<Card> shuffle(List<Card> deck, Random rng) {
        List<Card> d = new ArrayList<>(deck);
        for (int i = d.size() - 1; i > 0; i--) {
            int j = rng.nextInt(i + 1);
            Collections.swap(d, i, j);
        }
        return d;
    }
}
