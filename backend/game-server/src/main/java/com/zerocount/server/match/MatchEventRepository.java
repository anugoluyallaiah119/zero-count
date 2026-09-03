package com.zerocount.server.match;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zerocount.engine.session.GameEvent;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Postgres-backed match event log (M1.3). Every engine event is persisted
 * append-only with its engine seq — the replay protocol and the audit trail
 * share one source of truth (standards §3.2).
 */
@Repository
public class MatchEventRepository {

    private final JdbcTemplate jdbc;
    private static final ObjectMapper json = new ObjectMapper();

    public MatchEventRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }


    /** Open a games row + seat the players. Returns the game id. */
    public UUID createGame(String configJson, List<UUID> seats) {
        UUID gameId = jdbc.queryForObject(
            "INSERT INTO games (config_json) VALUES (?::jsonb) RETURNING id",
            UUID.class, configJson);
        for (UUID seat : seats) {
            jdbc.update("INSERT INTO game_players (game_id, user_id) VALUES (?, ?)",
                gameId, seat);
        }
        return gameId;
    }

    /** Append engine events. seq continuity is enforced by the PK. */
    public void append(UUID gameId, UUID actorId, List<GameEvent> events) {
        jdbc.batchUpdate(
            "INSERT INTO game_events (game_id, seq, actor_id, type, payload_json) "
                + "VALUES (?, ?, ?, ?, ?::jsonb)",
            events, events.size(),
            (ps, e) -> {
                ps.setObject(1, gameId);
                ps.setLong(2, e.seq());
                ps.setObject(3, actorId);
                ps.setString(4, type(e));
                ps.setString(5, payload(e));
            });
    }

    /** Finalize a match: winner + per-seat scores/placements. */
    public void closeGame(UUID gameId, UUID winnerId, List<Integer> totals,
                          List<UUID> seats) {
        jdbc.update("UPDATE games SET ended_at = now() WHERE id = ?", gameId);
        int winnerIdx = seats.indexOf(winnerId);

        // Placements: lowest match total ranks best (V1 scoring), the engine's
        // winnerId breaks any tie at the top.
        Integer[] order = new Integer[seats.size()];
        for (int i = 0; i < order.length; i++) order[i] = i;
        java.util.Arrays.sort(order, (x, y) -> {
            if (x == winnerIdx) return -1;
            if (y == winnerIdx) return 1;
            return Integer.compare(totals.get(x), totals.get(y));
        });
        int[] placement = new int[seats.size()];
        for (int rank = 0; rank < order.length; rank++) placement[order[rank]] = rank + 1;

        for (int i = 0; i < seats.size(); i++) {
            jdbc.update(
                "UPDATE game_players SET final_score = ?, placement = ? "
                    + "WHERE game_id = ? AND user_id = ?",
                totals.get(i), placement[i], gameId, seats.get(i));
        }

        // R1.5 ELO-lite: K=24, multiplayer actual score = (n - place)/(n - 1),
        // expectation averaged pairwise. Also bumps matches/wins.
        int n = seats.size();
        List<Long> elos = new java.util.ArrayList<>();
        for (UUID seat : seats) {
            jdbc.update("INSERT INTO statistics (user_id) VALUES (?) "
                + "ON CONFLICT (user_id) DO NOTHING", seat);
            Long e = jdbc.queryForObject(
                "SELECT elo FROM statistics WHERE user_id = ?", Long.class, seat);
            elos.add(e == null ? 1200L : e);
        }
        for (int i = 0; i < n; i++) {
            double expected = 0;
            for (int j = 0; j < n; j++) {
                if (i == j) continue;
                expected += 1.0 / (1.0 + Math.pow(10, (elos.get(j) - elos.get(i)) / 400.0));
            }
            expected /= Math.max(1, n - 1);
            double actual = n == 1 ? 1.0 : (double) (n - placement[i]) / (n - 1);
            long next = Math.max(100, Math.round(elos.get(i) + 24 * (actual - expected)));
            jdbc.update(
                "UPDATE statistics SET elo = ?, matches = matches + 1, "
                    + "wins = wins + ? WHERE user_id = ?",
                (int) next, i == winnerIdx ? 1 : 0, seats.get(i));
        }
    }

    public record StoredEvent(long seq, String type, Map<String, Object> payload,
                              Instant ts) {}

    /** Replay: all events with seq > sinceSeq, in order (M1.3 protocol). */
    public List<StoredEvent> eventsSince(UUID gameId, long sinceSeq) {
        return jdbc.query(
            "SELECT seq, type, payload_json, ts FROM game_events "
                + "WHERE game_id = ? AND seq > ? ORDER BY seq",
            (rs, i) -> {
                try {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> payload =
                        json.readValue(rs.getString("payload_json"), Map.class);
                    return new StoredEvent(rs.getLong("seq"), rs.getString("type"),
                        payload, rs.getTimestamp("ts").toInstant());
                } catch (JsonProcessingException e) {
                    throw new IllegalStateException(e);
                }
            },
            gameId, sinceSeq);
    }

    private static String type(GameEvent e) {
        @SuppressWarnings("unchecked")
        Map<String, Object> m = (Map<String, Object>) MatchService.eventJson(e);
        return (String) m.get("type");
    }

    private static String payload(GameEvent e) {
        try {
            return json.writeValueAsString(MatchService.eventJson(e));
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("event not serializable", ex);
        }
    }
}
