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

    /**
     * Ordered, unshuffled deck: {@code deckCount} full 52-card decks as normal
     * cards, followed by {@code specialCount} Special cards appended at the end.
     */
    public static List<Card> build(int deckCount, int specialCount) {
        if (deckCount < 1 || deckCount > 2)
            throw new IllegalArgumentException("deckCount must be 1 or 2, got " + deckCount);
        if (specialCount < 0)
            throw new IllegalArgumentException("specialCount cannot be negative: " + specialCount);
        List<Card> deck = new ArrayList<>(deckCount * 52 + specialCount);
        int id = 0;
        for (int d = 0; d < deckCount; d++)
            for (Suit s : Suit.values())
                for (Rank r : Rank.values())
                    deck.add(new Card(id++, r, s, d, false));
        for (int i = 0; i < specialCount; i++)
            deck.add(new Card(id++, Rank.ACE, Suit.HEARTS, 0, true));
        return deck;
    }

    public static List<Card> buildFor(GameConfig config) {
        int normal = config.normalCardCount();
        int extra = normal > 52 ? normal - 52 : 0;
        List<Card> deck = build(1, 0);
        if (extra > 0) {
            for (Card c : build(1, 0)) {
                deck.add(new Card(deck.size(), c.rank(), c.suit(), 1, false));
                if (deck.size() == 52 + extra) break;
            }
        }
        for (int i = 0; i < config.specialCount(); i++)
            deck.add(new Card(deck.size(), Rank.ACE, Suit.HEARTS, 0, true));
        return deck;
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
