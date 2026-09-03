package com.zerocount.server.leaderboard;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.zerocount.server.player.AuthInterceptor;

/**
 * R1.2 — leaderboards (weekly / all-time) + per-player match history.
 *
 *   GET /api/leaderboards/weekly    → top 50 by wins in the last 7 days
 *   GET /api/leaderboards/alltime   → top 50 by ELO (statistics table)
 *   GET /api/leaderboards/history   → caller's last 20 completed matches
 *
 * Entries carry the caller's own rank so the UI can pin "you" rows.
 */
@RestController
@RequestMapping("/api/leaderboards")
public class LeaderboardController {

    private final JdbcTemplate db;

    public LeaderboardController(JdbcTemplate db) {
        this.db = db;
    }

    @GetMapping("/weekly")
    public List<Map<String, Object>> weekly() {
        return db.query("""
            SELECT u.id, u.name, u.avatar, COUNT(*) AS wins
            FROM game_players gp
            JOIN games g ON g.id = gp.game_id
            JOIN users u ON u.id = gp.user_id
            WHERE gp.placement = 1 AND g.ended_at > now() - interval '7 days'
            GROUP BY u.id, u.name, u.avatar
            ORDER BY wins DESC, u.name LIMIT 50
            """, (rs, n) -> Map.of(
                "userId", rs.getObject("id", UUID.class).toString(),
                "name", rs.getString("name") == null ? "" : rs.getString("name"),
                "avatar", rs.getString("avatar") == null ? "" : rs.getString("avatar"),
                "score", rs.getLong("wins")));
    }

    @GetMapping("/alltime")
    public List<Map<String, Object>> alltime() {
        return db.query("""
            SELECT u.id, u.name, u.avatar, s.elo, s.wins, s.matches
            FROM statistics s JOIN users u ON u.id = s.user_id
            WHERE s.matches > 0
            ORDER BY s.elo DESC, s.wins DESC, u.name LIMIT 50
            """, (rs, n) -> Map.of(
                "userId", rs.getObject("id", UUID.class).toString(),
                "name", rs.getString("name") == null ? "" : rs.getString("name"),
                "avatar", rs.getString("avatar") == null ? "" : rs.getString("avatar"),
                "score", rs.getInt("elo"),
                "wins", rs.getInt("wins"),
                "matches", rs.getInt("matches")));
    }

    @GetMapping("/history")
    public List<Map<String, Object>> history(HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        return db.query("""
            SELECT g.id, g.ended_at, gp.final_score, gp.placement,
                   (SELECT COUNT(*) FROM game_players x WHERE x.game_id = g.id) AS seats
            FROM game_players gp JOIN games g ON g.id = gp.game_id
            WHERE gp.user_id = ? AND g.ended_at IS NOT NULL
            ORDER BY g.ended_at DESC LIMIT 20
            """, (rs, n) -> Map.of(
                "gameId", rs.getObject("id", UUID.class).toString(),
                "endedAt", rs.getTimestamp("ended_at").toInstant().toString(),
                "finalScore", rs.getInt("final_score"),
                "placement", rs.getInt("placement"),
                "seats", rs.getInt("seats")),
            userId);
    }
}
