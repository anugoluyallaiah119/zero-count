package com.zerocount.server.match;

import java.util.List;
import java.util.UUID;

/**
 * Side-effect SPI fired after engine events are persisted (R1.4 challenges,
 * R1.5 ratings, C1.1 contest scoring). Implementations must be idempotent
 * and must not throw — a failing hook never rolls back a legal move.
 */
public interface MatchHook {

    /** A match finished. {@code winnerIdx} indexes into {@code seats}. */
    default void onMatchEnded(List<UUID> seats, int winnerIdx, List<Integer> totals) {}

    /** A player called SHOW. */
    default void onShowed(UUID userId) {}
}
