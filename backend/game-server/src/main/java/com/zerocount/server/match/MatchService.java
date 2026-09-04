package com.zerocount.server.match;

import com.zerocount.engine.model.Card;
import com.zerocount.engine.model.GameConfig;
import com.zerocount.engine.model.Move;
import com.zerocount.engine.session.GameEvent;
import com.zerocount.engine.session.GameSession;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

/**
 * Server-authoritative match registry (M1.2). One {@link GameSession} per
 * room code; the Java engine is the single source of truth — every client
 * move is validated by the engine (actor, phase, card ownership) and every
 * resulting transition is an immutable event the clients render.
 *
 * Clients never see other players' cards: the public topic gets events with
 * hidden-card information stripped; private hands go over per-session queues
 * ({@link MatchBroadcaster}).
 */
@Service
public class MatchService {

    public static class MatchNotFoundException extends RuntimeException {
        public MatchNotFoundException(String code) {
            super("no active match in room " + code);
        }
    }

    public static class IllegalMoveException extends RuntimeException {
        public IllegalMoveException(String message) {
            super(message);
        }
    }

    private final Map<String, GameSession> matches = new ConcurrentHashMap<>();
    private final Map<String, List<String>> seatOrder = new ConcurrentHashMap<>();
    private final Map<String, UUID> gameIds = new ConcurrentHashMap<>();
    private final Map<String, java.util.Set<UUID>> rematchVotes = new ConcurrentHashMap<>();
    private final Map<String, GameConfig> lastConfig = new ConcurrentHashMap<>();

    private final MatchEventRepository eventLog;
    private final List<MatchHook> hooks;
    private com.zerocount.server.analytics.GameplayAnalyticsService gameplayAnalytics;
    private com.zerocount.server.player.AdaptiveDrawService adaptiveDraw;
    private boolean adaptiveEnabled = true;

    public MatchService(MatchEventRepository eventLog, List<MatchHook> hooks) {
        this.eventLog = eventLog;
        this.hooks = hooks == null ? List.of() : hooks;
    }

    /** V2.2 Phase 2 telemetry — nullable so existing tests that don't wire it still pass. */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setGameplayAnalytics(
            com.zerocount.server.analytics.GameplayAnalyticsService svc) {
        this.gameplayAnalytics = svc;
    }

    /** V2.2 Phase 4 adaptive per-user DrawBrain tuning — nullable for tests. */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setAdaptiveDraw(com.zerocount.server.player.AdaptiveDrawService svc) {
        this.adaptiveDraw = svc;
    }

    /** Feature flag: {@code app.adaptive.enabled} — see application.yml. */
    @org.springframework.beans.factory.annotation.Value("${app.adaptive.enabled:true}")
    public void setAdaptiveEnabled(boolean enabled) {
        this.adaptiveEnabled = enabled;
    }

    /** Start a match for a room. Seat order is the caller's (lobby order). */
    public synchronized List<GameEvent> start(String code, GameConfig config,
                                              List<UUID> seats) {
        if (matches.containsKey(code)) {
            throw new IllegalStateException("match already running in room " + code);
        }
        List<String> ids = seats.stream().map(UUID::toString).toList();
        GameSession session = new GameSession(config, ids, System.nanoTime());
        // Phase 4: per-user adaptive DrawBrain tuning (falls through to
        // AdaptiveDrawParams.DEFAULTS when the service isn't wired or the
        // feature flag is off — useful as an A/B control cohort).
        if (adaptiveDraw != null && adaptiveEnabled) {
            session.setAdaptiveParams(pid -> {
                try {
                    return adaptiveDraw.paramsFor(UUID.fromString(pid));
                } catch (RuntimeException e) {
                    return com.zerocount.engine.session.AdaptiveDrawParams.DEFAULTS;
                }
            });
        }
        matches.put(code, session);
        seatOrder.put(code, ids);
        lastConfig.put(code, config);
        rematchVotes.remove(code);
        // M1.3: open the games row + persist the deal events.
        String configJson = "{\"players\":" + config.players()
            + ",\"handSize\":" + config.handSize()
            + ",\"target\":" + config.target() + "}";
        gameIds.put(code, eventLog.createGame(configJson, seats));
        persist(code, null, List.copyOf(session.eventLog()));
        return List.copyOf(session.eventLog());
    }

    /** Apply a player's move; the engine throws on anything illegal. */
    public List<GameEvent> apply(String code, UUID userId, Move move) {
        GameSession s = get(code);
        List<GameEvent> events;
        try {
            events = s.apply(userId.toString(), move);
        } catch (IllegalStateException | IllegalArgumentException e) {
            throw new IllegalMoveException(e.getMessage());
        }
        afterEvents(code, userId, events);
        return events;
    }

    /** POST-window pass (end turn without showing). */
    public List<GameEvent> pass(String code, UUID userId) {
        GameSession s = get(code);
        if (!s.currentPlayer().playerId().equals(userId.toString())) {
            throw new IllegalMoveException("not your turn");
        }
        List<GameEvent> events;
        try {
            events = s.passTurn();
        } catch (IllegalStateException e) {
            throw new IllegalMoveException(e.getMessage());
        }
        afterEvents(code, userId, events);
        return events;
    }

    /** "Choose your Zero" — pin the caller's Special to [rank]. */
    public List<GameEvent> pinSpecial(String code, UUID userId,
                                     com.zerocount.engine.model.Rank rank) {
        GameSession s = get(code);
        List<GameEvent> events;
        try {
            events = s.pinSpecial(userId.toString(), rank);
        } catch (IllegalStateException | IllegalArgumentException e) {
            throw new IllegalMoveException(e.getMessage());
        }
        afterEvents(code, userId, events);
        return events;
    }

    /** Clear the caller's pin, if any. */
    public List<GameEvent> clearSpecialPin(String code, UUID userId) {
        GameSession s = get(code);
        List<GameEvent> events;
        try {
            events = s.clearSpecialPin(userId.toString());
        } catch (IllegalStateException | IllegalArgumentException e) {
            throw new IllegalMoveException(e.getMessage());
        }
        afterEvents(code, userId, events);
        return events;
    }

    private void afterEvents(String code, UUID actor, List<GameEvent> events) {
        persist(code, actor, events);
        // V2.2 Phase 2: capture structured gameplay telemetry (best-effort).
        if (gameplayAnalytics != null) {
            try { gameplayAnalytics.record(code, this, events); }
            catch (RuntimeException tel) {
                org.slf4j.LoggerFactory.getLogger(MatchService.class)
                    .warn("gameplay telemetry failed: {}", tel.toString());
            }
        }
        for (GameEvent e : events) {
            try {
                if (e instanceof GameEvent.MatchEnded me) {
                    List<UUID> seats = seatOrder.get(code).stream()
                        .map(UUID::fromString).toList();
                    eventLog.closeGame(gameIds.get(code), UUID.fromString(me.winnerId()),
                        me.totals(), seats);
                    int winnerIdx = seats.indexOf(UUID.fromString(me.winnerId()));
                    for (MatchHook h : hooks) {
                        h.onMatchEnded(seats, winnerIdx, me.totals());
                    }
                    // Phase 4: Phase 3 just refreshed the model → drop cached params.
                    if (adaptiveDraw != null) {
                        for (UUID seat : seats) adaptiveDraw.invalidate(seat);
                    }
                } else if (e instanceof GameEvent.Showed sh) {
                    for (MatchHook h : hooks) {
                        h.onShowed(UUID.fromString(sh.playerId()));
                    }
                }
            } catch (RuntimeException hookFailure) {
                // Hooks are side-effects (challenges, ratings, contests) —
                // a failure there must never invalidate a legal move.
                org.slf4j.LoggerFactory.getLogger(MatchService.class)
                    .warn("match hook failed: {}", hookFailure.toString());
            }
        }
    }

    private void persist(String code, UUID actor, List<GameEvent> events) {
        if (events.isEmpty()) return;
        eventLog.append(gameIds.get(code), actor, events);
    }

    /** M1.3 replay protocol: events after a seq, for reconnect resync. */
    public List<MatchEventRepository.StoredEvent> replay(String code, long sinceSeq) {
        UUID gameId = gameIds.get(code);
        if (gameId == null) throw new MatchNotFoundException(code);
        return eventLog.eventsSince(gameId, sinceSeq);
    }

    /** All room codes where this user is seated (for presence announcements). */
    public List<String> roomsOf(UUID userId) {
        String id = userId.toString();
        List<String> out = new ArrayList<>();
        seatOrder.forEach((code, seats) -> {
            if (seats.contains(id)) out.add(code);
        });
        return out;
    }

    public GameSession get(String code) {
        GameSession s = matches.get(code);
        if (s == null) throw new MatchNotFoundException(code);
        return s;
    }

    public List<String> seats(String code) {
        List<String> seats = seatOrder.get(code);
        if (seats == null) throw new MatchNotFoundException(code);
        return seats;
    }

    public synchronized void end(String code) {
        matches.remove(code);
        seatOrder.remove(code);
        gameIds.remove(code);
        rematchVotes.remove(code);
        lastConfig.remove(code);
    }

    // ---------- rematch ----------

    public record RematchState(int votes, int seats, List<String> voters, boolean ready) {}

    /** Record a rematch vote for [userId] in [code]. Returns the new state.
     *  Only seated players may vote; votes are only accepted after the match is over. */
    public synchronized RematchState voteRematch(String code, UUID userId) {
        GameSession s = get(code);
        List<String> seats = seatOrder.get(code);
        String uid = userId.toString();
        if (seats == null || !seats.contains(uid)) {
            throw new IllegalMoveException("not seated in room " + code);
        }
        if (!s.isOver()) {
            throw new IllegalMoveException("match still in progress");
        }
        var voters = rematchVotes.computeIfAbsent(code, k -> new java.util.LinkedHashSet<>());
        voters.add(userId);
        List<String> voterIds = voters.stream().map(UUID::toString).toList();
        boolean ready = voters.size() >= seats.size();
        return new RematchState(voters.size(), seats.size(), voterIds, ready);
    }

    public synchronized RematchState rematchState(String code) {
        List<String> seats = seatOrder.get(code);
        if (seats == null) throw new MatchNotFoundException(code);
        var voters = rematchVotes.getOrDefault(code, java.util.Collections.emptySet());
        List<String> voterIds = voters.stream().map(UUID::toString).toList();
        boolean ready = voters.size() >= seats.size();
        return new RematchState(voters.size(), seats.size(), voterIds, ready);
    }

    /** Prepare a rematch: return (config, seats) and end the current match so
     *  {@link #start(String, GameConfig, List)} can be called for a fresh session. */
    public synchronized Rematch prepareRematch(String code) {
        List<String> seats = seatOrder.get(code);
        GameConfig cfg = lastConfig.get(code);
        if (seats == null || cfg == null) throw new MatchNotFoundException(code);
        List<UUID> seatUuids = seats.stream().map(UUID::fromString).toList();
        end(code);
        return new Rematch(cfg, seatUuids);
    }

    public record Rematch(GameConfig config, List<UUID> seats) {}

    // ---------- views ----------

    /** Public table view — safe to broadcast (no hidden cards). */
    public Map<String, Object> publicView(String code) {
        GameSession s = get(code);
        Map<String, Object> v = new LinkedHashMap<>();
        v.put("phase", s.phase().name());
        v.put("round", s.round());
        v.put("currentPlayerIdx", s.currentPlayerIdx());
        v.put("stockSize", s.stockSize());
        v.put("topDiscard", s.topDiscard() == null ? null : cardJson(s.topDiscard()));
        v.put("over", s.isOver());
        List<Map<String, Object>> players = new ArrayList<>();
        for (var p : s.players()) {
            players.add(Map.of(
                "id", p.playerId(),
                "cards", p.hand().size(),
                "matchScore", p.matchScore()));
        }
        v.put("players", players);
        return v;
    }

    /** Private view — one player's full hand. Never broadcast. */
    public Map<String, Object> handView(String code, UUID userId) {
        GameSession s = get(code);
        for (var p : s.players()) {
            if (p.playerId().equals(userId.toString())) {
                Map<String, Object> v = new LinkedHashMap<>();
                v.put("hand", p.hand().cards().stream()
                    .map(MatchService::cardJson).toList());
                // Special timer — only meaningful during this player's turn.
                Card special = p.hand().cards().stream()
                    .filter(Card::isSpecial).findFirst().orElse(null);
                if (special != null && s.currentPlayer().playerId().equals(p.playerId())) {
                    v.put("specialTurnsRemaining", s.specialTurnsRemaining(special));
                }
                // "Choose your Zero": expose the current pin + valid targets.
                if (special != null) {
                    var pinnedRank = s.specialPinnedRank(special);
                    if (pinnedRank != null) v.put("specialPinnedRank", pinnedRank.label());
                    var pairs = s.validPairsFor(p.playerId());
                    if (!pairs.isEmpty()) {
                        v.put("validPairRanks",
                            pairs.stream().map(com.zerocount.engine.model.Rank::label).toList());
                    }
                }
                return v;
            }
        }
        throw new IllegalMoveException("not seated in room " + code);
    }

    /** Event → JSON. Hidden information stays out of public events. */
    public static Map<String, Object> eventJson(GameEvent e) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("seq", e.seq());
        // JDK 17: plain instanceof chains (pattern-switch is preview-only).
        if (e instanceof GameEvent.RoundStarted r) {
            m.put("type", "round_started");
            m.put("round", r.round());
            m.put("firstPlayerIdx", r.firstPlayerIdx());
        } else if (e instanceof GameEvent.DrewStock d) {
            m.put("type", "drew_stock");
            m.put("playerId", d.playerId()); // card stays hidden
        } else if (e instanceof GameEvent.DrewDiscard d) {
            m.put("type", "drew_discard");
            m.put("playerId", d.playerId());
            m.put("card", cardJson(d.card()));
        } else if (e instanceof GameEvent.Discarded d) {
            m.put("type", "discarded");
            m.put("playerId", d.playerId());
            m.put("card", cardJson(d.card()));
        } else if (e instanceof GameEvent.SpecialDiscarded d) {
            m.put("type", "special_discarded");
            m.put("playerId", d.playerId());
            m.put("card", cardJson(d.card()));
        } else if (e instanceof GameEvent.SpecialPinned sp) {
            m.put("type", "special_pinned");
            m.put("playerId", sp.playerId());
            m.put("cardId", sp.cardId());
            m.put("rank", sp.rank().label());
        } else if (e instanceof GameEvent.SpecialUnpinned su) {
            m.put("type", "special_unpinned");
            m.put("playerId", su.playerId());
            m.put("cardId", su.cardId());
        } else if (e instanceof GameEvent.TurnPassed t) {
            m.put("type", "turn_passed");
            m.put("nextPlayerId", t.nextPlayerId());
        } else if (e instanceof GameEvent.Showed sh) {
            m.put("type", "showed");
            m.put("playerId", sh.playerId());
        } else if (e instanceof GameEvent.StockRecycled r) {
            m.put("type", "stock_recycled");
            m.put("newStockSize", r.newStockSize());
        } else if (e instanceof GameEvent.RoundEnded r) {
            m.put("type", "round_ended");
            m.put("counts", r.counts());
            m.put("totals", r.totals());
        } else if (e instanceof GameEvent.MatchEnded me) {
            m.put("type", "match_ended");
            m.put("winnerId", me.winnerId());
            m.put("totals", me.totals());
            // R1.5 near-miss / rivalry message: runner-up within 5 points.
            List<Integer> totals = me.totals();
            int winnerIdx = -1, best = Integer.MAX_VALUE, second = Integer.MAX_VALUE;
            for (int i = 0; i < totals.size(); i++) {
                int t = totals.get(i);
                if (t < best) { second = best; best = t; winnerIdx = i; }
                else if (t < second) { second = t; }
            }
            if (totals.size() > 1 && second - best <= 5) {
                m.put("nearMiss", true);
                m.put("message", "So close! Runner-up finished only "
                    + (second - best) + " point" + (second - best == 1 ? "" : "s")
                    + " behind — rematch?");
            }
        } else if (e instanceof GameEvent.StalemateForced st) {
            m.put("type", "stalemate_forced");
            m.put("turnCap", st.turnCap());
        } else {
            throw new IllegalArgumentException("unknown event " + e);
        }
        return m;
    }

    static Map<String, Object> cardJson(Card c) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", c.id());
        m.put("rank", c.rank().label());
        m.put("suit", c.suit().name().toLowerCase());
        m.put("value", c.value());
        m.put("isSpecial", c.isSpecial());
        return m;
    }
}
