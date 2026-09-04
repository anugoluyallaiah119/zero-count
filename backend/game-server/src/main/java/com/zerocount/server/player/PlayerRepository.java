package com.zerocount.server.player;

import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Player profile + statistics read path (E2.4). Explicit SQL via JdbcTemplate
 * (standards §2.2) — no ORM.
 */
@Repository
public class PlayerRepository {

    private final JdbcTemplate jdbc;

    public PlayerRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record Profile(UUID id, String phone, String name, String avatar,
                          long coins, long gems, java.time.Instant createdAt) {}

    public record Stats(int matches, int wins, int zerosMade, Integer bestCount,
                        int streakDays, int elo,
                        int winStreak, int bestWinStreak) {}

    public Optional<Profile> findProfile(UUID userId) {
        return jdbc.query(
                "SELECT id, phone, name, avatar, coins, gems, created_at FROM users WHERE id = ?",
                (rs, i) -> new Profile(
                    rs.getObject("id", UUID.class), rs.getString("phone"),
                    rs.getString("name"), rs.getString("avatar"),
                    rs.getLong("coins"), rs.getLong("gems"),
                    rs.getTimestamp("created_at").toInstant()),
                userId)
            .stream().findFirst();
    }

    public Optional<Stats> findStats(UUID userId) {
        return jdbc.query(
                "SELECT matches, wins, zeros_made, best_count, streak_days, elo, "
                + "win_streak, best_win_streak "
                + "FROM statistics WHERE user_id = ?",
                (rs, i) -> new Stats(
                    rs.getInt("matches"), rs.getInt("wins"), rs.getInt("zeros_made"),
                    (Integer) rs.getObject("best_count"),
                    rs.getInt("streak_days"), rs.getInt("elo"),
                    rs.getInt("win_streak"), rs.getInt("best_win_streak")),
                userId)
            .stream().findFirst();
    }

    /** Partial update: null fields are left unchanged (COALESCE keeps old value). */
    public void updateProfile(UUID userId, String name, String avatar) {
        int n = jdbc.update(
            "UPDATE users SET name = COALESCE(?, name), avatar = COALESCE(?, avatar) WHERE id = ?",
            name, avatar, userId);
        if (n == 0) throw new IllegalStateException("user not found: " + userId);
    }
}
