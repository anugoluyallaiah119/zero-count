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

    /** V2.2: Special cards expire after 4 owner turns while unusable.
     *  The timer pauses whenever the special has at least one valid pair target. */
    public static final int SPECIAL_DECAY_TURNS = 4;

    private final GameConfig config;
    private final Random rng;
    private final List<PlayerState> players;
    private final Deque<Card> stock = new ArrayDeque<>();    // pop() = draw top
    private final Deque<Card> discard = new ArrayDeque<>();  // peek() = visible top
    private final List<GameEvent> eventLog = new ArrayList<>();
    private final Map<Integer, Integer> specialAge = new HashMap<>();
    /** V2.2 §36 dry-draw counter per seat, aligned with {@code players}. */
    private final int[] dryDraws;
    /** "Choose your Zero": special card id -> the rank the owner pinned it to. */
    private final Map<Integer, Rank> specialPins = new HashMap<>();
    /** Phase 4: per-user DrawBrain tuning. Defaults to {@code DEFAULTS} for everyone. */
    private java.util.function.Function<String, AdaptiveDrawParams> paramsFor =
        pid -> AdaptiveDrawParams.DEFAULTS;

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
        this.dryDraws = new int[players.size()];
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

    /** Phase 4: install a per-user DrawBrain params supplier. Null → defaults. */
    public void setAdaptiveParams(
            java.util.function.Function<String, AdaptiveDrawParams> supplier) {
        this.paramsFor = supplier == null
            ? pid -> AdaptiveDrawParams.DEFAULTS
            : pid -> {
                AdaptiveDrawParams p = supplier.apply(pid);
                return p == null ? AdaptiveDrawParams.DEFAULTS : p;
            };
    }

    /** V2.2 §36 — consecutive unproductive stock draws for a seated player. */
    public int dryDrawsFor(String playerId) {
        for (int i = 0; i < players.size(); i++) {
            if (players.get(i).playerId().equals(playerId)) return dryDraws[i];
        }
        return 0;
    }

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
        // V2.2 §32: DrawBrain looks ahead N cards in the stock for a useful pick.
        // The deque is head=top; DrawBrain wants a List with last=top.
        List<Card> stockList = new ArrayList<>(stock.size());
        Iterator<Card> it = stock.descendingIterator();
        while (it.hasNext()) stockList.add(it.next());

        Hand handBefore = snapshotHand(currentPlayer().hand());
        AdaptiveDrawParams p = paramsFor.apply(currentPlayer().playerId());
        Card c = DrawBrain.drawFromStock(stockList, currentPlayer().hand(),
            dryDraws[turnIdx], p);

        // Rebuild deque: push in list order so stockList[last] ends up at head.
        stock.clear();
        for (Card sc : stockList) stock.push(sc);

        currentPlayer().hand().add(c);
        if (c.isSpecial()) { specialAge.remove(c.id()); specialPins.remove(c.id()); }
        dryDraws[turnIdx] = DrawBrain.wasProductive(c, handBefore) ? 0 : dryDraws[turnIdx] + 1;
        phase = Phase.DISCARD;
        log(new GameEvent.DrewStock(nextSeq(), currentPlayer().playerId()));
    }

    private void doDrawDiscard() {
        Card c = discard.pop();
        currentPlayer().hand().add(c);
        dryDraws[turnIdx] = 0; // an active choice resets the pity counter
        if (c.isSpecial()) { specialAge.remove(c.id()); specialPins.remove(c.id()); }
        phase = Phase.DISCARD;
        log(new GameEvent.DrewDiscard(nextSeq(), currentPlayer().playerId(), c));
    }

    /** Deep-copy of a hand — used for {@link DrawBrain#wasProductive}. */
    private static Hand snapshotHand(Hand src) {
        Hand copy = new Hand();
        for (Card c : src.cards()) copy.add(c);
        return copy;
    }

    private void doDiscard(Card card) {
        currentPlayer().hand().remove(card);
        discard.push(card);
        if (card.isSpecial()) specialPins.remove(card.id());
        pruneStalePins();
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
        decaySpecials();
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

    private void decaySpecials() {
        Hand hand = currentPlayer().hand();
        List<Card> specials = hand.cards().stream().filter(Card::isSpecial).toList();
        boolean hasValidPair = hasExactPair(hand);
        for (Card special : specials) {
            if (hasValidPair) {
                // Timer is frozen while the special can be used.
                continue;
            }
            int age = specialAge.getOrDefault(special.id(), 0) + 1;
            if (age >= SPECIAL_DECAY_TURNS) {
                hand.remove(special);
                discard.push(special);
                specialAge.remove(special.id());
                specialPins.remove(special.id());
                log(new GameEvent.SpecialDiscarded(nextSeq(), currentPlayer().playerId(), special));
            } else {
                specialAge.put(special.id(), age);
            }
        }
    }

    /** Returns true if the hand contains at least one rank with exactly 2 normal
     *  cards — a valid target for a Special card. */
    private boolean hasExactPair(Hand hand) {
        Map<Rank, Integer> counts = new HashMap<>();
        for (Card c : hand.cards()) {
            if (c.isSpecial()) continue;
            counts.merge(c.rank(), 1, Integer::sum);
        }
        return counts.values().stream().anyMatch(n -> n == 2);
    }

    /** Remaining owner turns before the given special would auto-discard. */
    public int specialTurnsRemaining(Card special) {
        if (!currentPlayer().hand().contains(special) || !special.isSpecial()) return 0;
        if (hasExactPair(currentPlayer().hand())) return 0;
        int age = specialAge.getOrDefault(special.id(), 0);
        return Math.max(0, SPECIAL_DECAY_TURNS - age);
    }

    /** "Choose your Zero": the rank {@code special} is pinned to, or null. */
    public Rank specialPinnedRank(Card special) {
        return special == null ? null : specialPins.get(special.id());
    }

    /** Ranks in [playerId]'s hand with exactly 2 normal cards — valid pin targets. */
    public List<Rank> validPairsFor(String playerId) {
        PlayerState p = playerByIdOrThrow(playerId);
        Map<Rank, Integer> counts = new HashMap<>();
        for (Card c : p.hand().cards()) {
            if (c.isSpecial()) continue;
            counts.merge(c.rank(), 1, Integer::sum);
        }
        List<Rank> out = new ArrayList<>();
        for (var e : counts.entrySet()) if (e.getValue() == 2) out.add(e.getKey());
        return out;
    }

    /** Pin [playerId]'s Special to [rank]. Throws when they don't hold one or
     *  the rank isn't a valid pair target. Emits {@link GameEvent.SpecialPinned}. */
    public List<GameEvent> pinSpecial(String playerId, Rank rank) {
        PlayerState p = playerByIdOrThrow(playerId);
        Card special = null;
        for (Card c : p.hand().cards()) if (c.isSpecial()) { special = c; break; }
        if (special == null) throw new IllegalStateException("NO_SPECIAL");
        if (!validPairsFor(playerId).contains(rank))
            throw new IllegalStateException("INVALID_PIN");
        int before = eventLog.size();
        specialPins.put(special.id(), rank);
        log(new GameEvent.SpecialPinned(nextSeq(), playerId, special.id(), rank));
        return List.copyOf(eventLog.subList(before, eventLog.size()));
    }

    /** Clear the pin (if any). Emits {@link GameEvent.SpecialUnpinned}. */
    public List<GameEvent> clearSpecialPin(String playerId) {
        PlayerState p = playerByIdOrThrow(playerId);
        int before = eventLog.size();
        for (Card c : p.hand().cards()) {
            if (c.isSpecial() && specialPins.remove(c.id()) != null) {
                log(new GameEvent.SpecialUnpinned(nextSeq(), playerId, c.id()));
            }
        }
        return List.copyOf(eventLog.subList(before, eventLog.size()));
    }

    private PlayerState playerByIdOrThrow(String playerId) {
        for (PlayerState p : players) {
            if (p.playerId().equals(playerId)) return p;
        }
        throw new IllegalArgumentException("unknown player: " + playerId);
    }

    /** Drop pins whose pair was broken since they were placed. */
    private void pruneStalePins() {
        if (specialPins.isEmpty()) return;
        List<Integer> stale = new ArrayList<>();
        for (var entry : specialPins.entrySet()) {
            PlayerState owner = null;
            for (PlayerState p : players) {
                for (Card c : p.hand().cards()) {
                    if (c.id() == entry.getKey()) { owner = p; break; }
                }
                if (owner != null) break;
            }
            if (owner == null) { stale.add(entry.getKey()); continue; }
            long n = owner.hand().cards().stream()
                .filter(c -> !c.isSpecial() && c.rank() == entry.getValue()).count();
            if (n != 2) stale.add(entry.getKey());
        }
        stale.forEach(specialPins::remove);
    }

    /** Rank pin for [p]'s Special (if any) — used at scoring time. */
    private Rank pinRankFor(PlayerState p) {
        for (Card c : p.hand().cards()) if (c.isSpecial()) return specialPins.get(c.id());
        return null;
    }

    private void endRound() {
        phase = Phase.SHOWDOWN;
        List<Integer> counts = players.stream()
            .map(p -> ScoringEngine.count(p.hand().cards(), pinRankFor(p))).toList();
        players.forEach(p -> p.addRoundScore(
            ScoringEngine.count(p.hand().cards(), pinRankFor(p))));
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
        stock.clear(); discard.clear(); specialAge.clear();
        specialPins.clear();
        java.util.Arrays.fill(dryDraws, 0);

        List<Card> deck = DeckBuilder.shuffle(DeckBuilder.buildFor(config), rng);
        int pos = 0;
        for (int k = 0; k < config.handSize(); k++)
            for (PlayerState p : players)
                p.hand().add(deck.get(pos++));
        discard.push(deck.get(pos++));                            // first visible card
        for (int i = pos; i < deck.size(); i++) stock.push(deck.get(i));

        // V2.2 §38 opening balancer: 72% chance to nudge dead openings toward a pair.
        List<Card> stockList = new ArrayList<>(stock.size());
        Iterator<Card> sit = stock.descendingIterator();
        while (sit.hasNext()) stockList.add(sit.next());
        for (PlayerState p : players) {
            DrawBrain.balanceOpeningHand(p.hand(), stockList, rng,
                paramsFor.apply(p.playerId()));
        }
        stock.clear();
        for (Card sc : stockList) stock.push(sc);

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
