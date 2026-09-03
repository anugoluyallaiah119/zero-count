package com.zerocount.engine.model;

/**
 * Turn phases (V1 locked flow): DEALING → DRAW → DISCARD → POST → (next player's
 * DRAW) or SHOWDOWN. GAME_OVER when someone crosses the target.
 */
public enum Phase {
    DEALING,    // cards being dealt; no moves legal
    DRAW,       // current player must draw (stock or top discard)
    DISCARD,    // current player must discard one card
    POST,       // discard done; current player may SHOW, else turn passes
    SHOWDOWN,   // round ended; scores being applied
    GAME_OVER   // match ended; someone crossed the target
}
