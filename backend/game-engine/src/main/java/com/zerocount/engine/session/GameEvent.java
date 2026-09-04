package com.zerocount.engine.session;

import com.zerocount.engine.model.Card;
import com.zerocount.engine.model.Rank;
import java.util.List;

/**
 * Append-only event log entry (V1 checklist #29). One per state change.
 * The server persists these per match — replays, debugging, dispute resolution.
 */
public sealed interface GameEvent {

    long seq();

    record RoundStarted(long seq, int round, int firstPlayerIdx) implements GameEvent {}
    record DrewStock(long seq, String playerId) implements GameEvent {}           // card hidden from others
    record DrewDiscard(long seq, String playerId, Card card) implements GameEvent {}
    record Discarded(long seq, String playerId, Card card) implements GameEvent {}
    record SpecialDiscarded(long seq, String playerId, Card card) implements GameEvent {}
    record SpecialPinned(long seq, String playerId, int cardId, Rank rank) implements GameEvent {}
    record SpecialUnpinned(long seq, String playerId, int cardId) implements GameEvent {}
    record TurnPassed(long seq, String nextPlayerId) implements GameEvent {}
    record Showed(long seq, String playerId) implements GameEvent {}
    record StockRecycled(long seq, int newStockSize) implements GameEvent {}
    record RoundEnded(long seq, List<Integer> counts, List<Integer> totals) implements GameEvent {}
    record MatchEnded(long seq, String winnerId, List<Integer> totals) implements GameEvent {}
    record StalemateForced(long seq, int turnCap) implements GameEvent {}
}
