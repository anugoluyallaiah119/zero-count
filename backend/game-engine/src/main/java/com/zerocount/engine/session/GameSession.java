package com.zerocount.engine.session;

import com.zerocount.engine.model.*;
import com.zerocount.engine.scoring.ScoringEngine;
import java.util.*;

/**
 * Server-authoritative match state machine. Ported from frozen V1.
 *
 * Locked rules enforced here:
 *  - Turn flow DRAW → DISCARD → POST(SHOW?) → next player (blueprint §3.1)
 *  - Stock recycle: keep top discard, shuffle the rest into a new stock
 *  - TURN_CAP: forced showdown after 200 turns (stalemate guard)
 *  - Round scoring: EVERYONE scores their own count; lowest count wins the round
 *  - Match end: when any player crosses the target, lowest cumulative total wins
 *  - First player rotates each round
 *
 * Design (ENGINEERING_STANDARDS §1): no I/O, no clocks, randomness injected,
 * every illegal move rejected with an exception, every transition logged.
 */
public final class GameSession {

    /** V1 stalemate guard — forced showdown after this many turns. */
    public static final int TURN_CAP = 200;

    private final GameConfig config;
    private final Random rng;
    private final List<PlayerState> players;
    private final Deque<Card> stock = new ArrayDeque<>();    // pop() = draw top
    private final Deque<Card> discard = new ArrayDeque<>();  // peek() = visible top
    private final List<GameEvent> eventLog = new ArrayList<>();

    private Phase phase;
    private int turnIdx;
    private int firstIdx;
    private int round;
    private int turnCount;
    private long seq;
    private Integer showerIdx;

    public GameSession(GameConfig config, List<String> playerIds, long seed) {
        this.config = Objects.requireNonNull(config);
        if (playerIds.size() != config.players())
            throw new IllegalArgumentException(
                "config expects " + config.players() + " players, got " + playerIds.size());
        this.rng = new Random(seed);
        this.players = playerIds.stream().map(PlayerState::new).toList();
        this.firstIdx = 0;
        this.phase = Phase.DEALING;
        dealNewRound();
    }

    // ---------- queries ----------

    public Phase phase() { return phase; }
    public GameConfig config() { return config; }
    public int round() { return round; }
    public int currentPlayerIdx() { return turnIdx; }
    public PlayerState currentPlayer() { return players.get(turnIdx); }
    public List<PlayerState> players() { return Collections.unmodifiableList(players); }
    public Card topDiscard() { return discard.peek(); }
    public int stockSize() { return stock.size(); }
    public int discardSize() { return discard.size(); }
    public List<GameEvent> eventLog() { return Collections.unmodifiableList(eventLog); }
    public boolean isOver() { return phase == Phase.GAME_OVER; }

    public boolean isLegal(String playerId, Move move) {
        try { validate(playerId, move); return true; }
        catch (IllegalStateException | IllegalArgumentException e) { return false; }
    }

    // ---------- commands ----------

    /** Apply a move. Validates actor, phase, and card ownership. Returns emitted events. */
    public List<GameEvent> apply(String playerId, Move move) {
        validate(playerId, move);
        int before = eventLog.size();
        if (move instanceof Move.DrawStock)         doDrawStock();
        else if (move instanceof Move.DrawDiscard)  doDrawDiscard();
        else if (move instanceof Move.Discard d)    doDiscard(d.card());
        else if (move instanceof Move.Show)         doShow();
        return List.copyOf(eventLog.subList(before, eventLog.size()));
    }

    // ---------- internals ----------

    private void validate(String playerId, Move move) {
        Objects.requireNonNull(move, "move required");
        if (phase == Phase.GAME_OVER) throw new IllegalStateException("GAME_OVER");
        if (phase == Phase.DEALING)   throw new IllegalStateException("DEALING");
        if (!currentPlayer().playerId().equals(playerId))
            throw new IllegalStateException("NOT_YOUR_TURN");
        if (move instanceof Move.DrawStock) {
            if (phase != Phase.DRAW) throw new IllegalStateException("PHASE_MISMATCH");
        } else if (move instanceof Move.DrawDiscard) {
            if (phase != Phase.DRAW) throw new IllegalStateException("PHASE_MISMATCH");
            if (discard.isEmpty()) throw new IllegalStateException("ILLEGAL_MOVE: empty discard pile");
        } else if (move instanceof Move.Discard d) {
            if (phase != Phase.DISCARD) throw new IllegalStateException("PHASE_MISMATCH");
            if (!currentPlayer().hand().contains(d.card()))
                throw new IllegalStateException("ILLEGAL_MOVE: card not in hand");
        } else if (move instanceof Move.Show) {
            if (phase != Phase.POST) throw new IllegalStateException("PHASE_MISMATCH");
        }
    }

    private void doDrawStock() {
        ensureStock();
        currentPlayer().hand().add(stock.pop());
        phase = Phase.DISCARD;
        log(new GameEvent.DrewStock(nextSeq(), currentPlayer().playerId()));
    }

    private void doDrawDiscard() {
        Card c = discard.pop();
        currentPlayer().hand().add(c);
        phase = Phase.DISCARD;
        log(new GameEvent.DrewDiscard(nextSeq(), currentPlayer().playerId(), c));
    }

    private void doDiscard(Card card) {
        currentPlayer().hand().remove(card);
        discard.push(card);
        phase = Phase.POST;
        log(new GameEvent.Discarded(nextSeq(), currentPlayer().playerId(), card));
    }

    private void doShow() {
        showerIdx = turnIdx;
        log(new GameEvent.Showed(nextSeq(), currentPlayer().playerId()));
        endRound();
    }

    /** Pass the turn (called when the POST window expires without SHOW). */
    public List<GameEvent> passTurn() {
        if (phase != Phase.POST) throw new IllegalStateException("PHASE_MISMATCH: passTurn");
        int before = eventLog.size();
        endTurn();
        return List.copyOf(eventLog.subList(before, eventLog.size()));
    }

    private void endTurn() {
        turnCount++;
        if (turnCount >= TURN_CAP) {                    // V1 stalemate guard
            log(new GameEvent.StalemateForced(nextSeq(), TURN_CAP));
            showerIdx = -1;
            endRound();
            return;
        }
        turnIdx = (turnIdx + 1) % players.size();
        phase = Phase.DRAW;
        log(new GameEvent.TurnPassed(nextSeq(), currentPlayer().playerId()));
    }

    private void endRound() {
        phase = Phase.SHOWDOWN;
        List<Integer> counts = players.stream()
            .map(p -> ScoringEngine.count(p.hand().cards())).toList();
        players.forEach(p -> p.addRoundScore(
            ScoringEngine.count(p.hand().cards())));
        List<Integer> totals = players.stream().map(PlayerState::matchScore).toList();
        log(new GameEvent.RoundEnded(nextSeq(), counts, totals));

        boolean matchOver = totals.stream().anyMatch(t -> t >= config.target());
        if (matchOver) {
            phase = Phase.GAME_OVER;
            int winIdx = totals.indexOf(Collections.min(totals)); // lowest total wins
            log(new GameEvent.MatchEnded(nextSeq(), players.get(winIdx).playerId(), totals));
        } else {
            firstIdx = (firstIdx + 1) % players.size();           // rotate first player
            dealNewRound();
        }
    }

    private void dealNewRound() {
        round++;
        players.forEach(PlayerState::resetHandForNewRound);
        stock.clear(); discard.clear();

        List<Card> deck = DeckBuilder.shuffle(DeckBuilder.buildFor(config), rng);
        int pos = 0;
        for (int k = 0; k < config.handSize(); k++)
            for (PlayerState p : players)
                p.hand().add(deck.get(pos++));
        discard.push(deck.get(pos++));                            // first visible card
        for (int i = pos; i < deck.size(); i++) stock.push(deck.get(i));

        turnIdx = firstIdx;
        turnCount = 0;
        showerIdx = null;
        phase = Phase.DRAW;
        log(new GameEvent.RoundStarted(nextSeq(), round, firstIdx));
    }

    /** V1 recycle rule: stock empty → keep top discard, shuffle the rest as new stock. */
    private void ensureStock() {
        if (!stock.isEmpty()) return;
        Card top = discard.pop();                                 // top stays visible
        List<Card> rest = new ArrayList<>(discard);
        discard.clear();
        discard.push(top);
        DeckBuilder.shuffle(rest, rng).forEach(stock::push);
        log(new GameEvent.StockRecycled(nextSeq(), stock.size()));
    }

    private long nextSeq() { return ++seq; }
    private void log(GameEvent e) { eventLog.add(e); }
}
