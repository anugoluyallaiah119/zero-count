package com.zerocount.engine.model;

/**
 * Match configuration. Ported from V1 (frozen):
 *  - players: 2..4
 *  - handSize: 7 (quick) or 13 (classic)
 *  - target: 100 / 200 / 500
 *  - decks: auto — 2 decks when players*handSize + 15 > 52
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

    /** V1 multi-deck rule. */
    public int deckCount() {
        return players * handSize + 15 > 52 ? 2 : 1;
    }

    public static GameConfig quickPlay(int players)   { return new GameConfig(players, 7, 100); }
    public static GameConfig classicPlay(int players) { return new GameConfig(players, 13, 200); }
}
