package com.zerocount.engine.model;

/** All legal player intents. Sealed so the compiler forces exhaustive handling. */
public sealed interface Move {

    /** Draw the top (face-down) card from the stock. Legal only in Phase.DRAW. */
    record DrawStock() implements Move {}

    /** Take the visible top card of the discard pile. Legal only in Phase.DRAW. */
    record DrawDiscard() implements Move {}

    /** Discard a card the player holds. Legal only in Phase.DISCARD.
     *  Discarding the card just drawn is explicitly allowed (V1 rule). */
    record Discard(Card card) implements Move {}

    /** End the round by showing. Legal only in Phase.POST. */
    record Show() implements Move {}
}
