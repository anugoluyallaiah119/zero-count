package com.zerocount.server.analytics;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zerocount.engine.session.GameEvent;
import com.zerocount.engine.session.GameSession;
import com.zerocount.server.match.MatchService;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * V2.2 Phase 2 — server-side gameplay telemetry pipeline.
 *
 * Every engine event that MatchService fans out is also converted into a
 * structured {@code gameplay.*} row in {@code analytics_events}. These rows
 * are the source of truth the Phase 3 player-model derivation reads from
 * (avg count at SHOW, dry-draw rate, Special usage, session length, etc.).
 *
 * The table trigger enforces append-only, so mis-writes bounce.
 */
@Service
public class GameplayAnalyticsService {

    private static final Logger log = LoggerFactory.getLogger(GameplayAnalyticsService.class);

    private final AnalyticsRepository events;
    private final ObjectMapper json;

    public GameplayAnalyticsService(AnalyticsRepository events, ObjectMapper json) {
        this.events = events;
        this.json = json;
    }

    /**
     * Record a batch of engine events emitted for a single move. [seats]
     * gives us the seat → user id mapping so per-user aggregation is trivial.
     */
    public void record(String code, MatchService matches, List<GameEvent> engineEvents) {
        if (engineEvents.isEmpty()) return;
        List<String> seats;
        GameSession session;
        try {
            seats = matches.seats(code);
            session = matches.get(code);
        } catch (RuntimeException notFound) {
            return; // match already torn down between events → skip
        }
        List<AnalyticsRepository.Event> rows = new ArrayList<>();
        Instant now = Instant.now();
        for (GameEvent e : engineEvents) {
            var row = toRow(e, code, seats, session, now);
            if (row != null) rows.add(row);
        }
        if (rows.isEmpty()) return;
        try {
            events.insertAll(rows);
        } catch (RuntimeException ex) {
            // Telemetry is best-effort — a write failure must never stop the match.
            log.warn("gameplay analytics insert failed: {}", ex.toString());
        }
    }

    private AnalyticsRepository.Event toRow(GameEvent e, String code, List<String> seats,
                                            GameSession session, Instant now) {
        Map<String, Object> props = new LinkedHashMap<>();
        props.put("room", code);
        props.put("round", session.round());
        String name;
        UUID actor = null;

        if (e instanceof GameEvent.RoundStarted r) {
            name = "gameplay.round_started";
            props.put("firstIdx", r.firstPlayerIdx());
            props.put("players", session.config().players());
            props.put("handSize", session.config().handSize());
            props.put("target", session.config().target());
            props.put("deckSize", session.config().deckSize());
        } else if (e instanceof GameEvent.DrewStock d) {
            name = "gameplay.draw_stock";
            actor = safeUuid(d.playerId());
            int seat = seatIndex(seats, d.playerId());
            props.put("seat", seat);
            props.put("dryStreak", session.dryDrawsFor(d.playerId()));
            // DrewStock hides the drawn card from the public log; look at the
            // actor's hand (top of stack = last drawn) for the wasSpecial flag.
            if (seat >= 0) {
                var hand = session.players().get(seat).hand().cards();
                if (!hand.isEmpty()) {
                    var last = hand.get(hand.size() - 1);
                    props.put("wasSpecial", last.isSpecial());
                }
            }
        } else if (e instanceof GameEvent.DrewDiscard d) {
            name = "gameplay.draw_discard";
            actor = safeUuid(d.playerId());
            props.put("seat", seatIndex(seats, d.playerId()));
            props.put("cardValue", d.card().value());
            props.put("wasSpecial", d.card().isSpecial());
        } else if (e instanceof GameEvent.Discarded d) {
            name = "gameplay.discard";
            actor = safeUuid(d.playerId());
            props.put("seat", seatIndex(seats, d.playerId()));
            props.put("cardValue", d.card().value());
            props.put("wasSpecial", d.card().isSpecial());
        } else if (e instanceof GameEvent.SpecialDiscarded d) {
            name = "gameplay.special_expired";
            actor = safeUuid(d.playerId());
            props.put("seat", seatIndex(seats, d.playerId()));
        } else if (e instanceof GameEvent.SpecialPinned sp) {
            name = "gameplay.special_pinned";
            actor = safeUuid(sp.playerId());
            props.put("seat", seatIndex(seats, sp.playerId()));
            props.put("rank", sp.rank().label());
        } else if (e instanceof GameEvent.SpecialUnpinned su) {
            name = "gameplay.special_unpinned";
            actor = safeUuid(su.playerId());
            props.put("seat", seatIndex(seats, su.playerId()));
        } else if (e instanceof GameEvent.Showed sh) {
            name = "gameplay.show";
            actor = safeUuid(sh.playerId());
            props.put("seat", seatIndex(seats, sh.playerId()));
        } else if (e instanceof GameEvent.TurnPassed t) {
            name = "gameplay.turn_passed";
            actor = safeUuid(t.nextPlayerId());
        } else if (e instanceof GameEvent.StockRecycled r) {
            name = "gameplay.stock_recycled";
            props.put("newSize", r.newStockSize());
        } else if (e instanceof GameEvent.RoundEnded r) {
            name = "gameplay.round_ended";
            props.put("counts", r.counts());
            props.put("totals", r.totals());
        } else if (e instanceof GameEvent.MatchEnded me) {
            name = "gameplay.match_ended";
            props.put("winnerId", me.winnerId());
            props.put("totals", me.totals());
            actor = safeUuid(me.winnerId());
        } else if (e instanceof GameEvent.StalemateForced s) {
            name = "gameplay.stalemate";
            props.put("turnCap", s.turnCap());
        } else {
            return null;
        }
        String propsJson;
        try {
            propsJson = json.writeValueAsString(props);
        } catch (JsonProcessingException jpe) {
            propsJson = "{}";
        }
        return new AnalyticsRepository.Event(actor, name, propsJson, now);
    }

    private static int seatIndex(List<String> seats, String playerId) {
        for (int i = 0; i < seats.size(); i++) {
            if (seats.get(i).equals(playerId)) return i;
        }
        return -1;
    }

    private static UUID safeUuid(String s) {
        if (s == null || s.isEmpty()) return null;
        try { return UUID.fromString(s); } catch (Exception e) { return null; }
    }
}
