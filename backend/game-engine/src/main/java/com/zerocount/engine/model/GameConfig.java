package com.zerocount.engine.model;

/**
 * Match configuration. Ported from V1/V2.2:
 *  - players: 2..4
 *  - handSize: 7 (quick) or 13 (classic)
 *  - target: 100 / 200 / 500
 *  - normal cards: 52 for 2/3 players; fractional second deck for 4 players
 *  - specials: exactly 1 in every match
 */
public record GameConfig(int players, int handSize, int target) {

    public GameConfig {
        if (players < 2 || players > 4)
            throw new IllegalArgumentException("players must be 2..4, got " + players);
        if (handSize != 7 && handSize != 13)
            throw new IllegalArgumentException("handSize must be 7 or 13, got " + handSize);
        if (target != 100 && target != 200 && target != 500)
            throw new IllegalArgumentException("target must be 100/200/500, got " + target);
    }

    /** Normal (non-special) cards. 4p modes add a small fractional second deck. */
    public int normalCardCount() {
        if (players == 4) {
            return handSize == 7 ? 60 : 65; // 1 deck + 15%/25% second deck
        }
        return 52;
    }

    /** Total cards in play = normal cards + special cards. */
    public int deckSize() {
        return normalCardCount() + specialCount();
    }

    /** V2.2 spec: exactly one Special card in every match. */
    public int specialCount() {
        return 1;
    }

    public static GameConfig quickPlay(int players)   { return new GameConfig(players, 7, 100); }
    public static GameConfig classicPlay(int players) { return new GameConfig(players, 13, 200); }
}
