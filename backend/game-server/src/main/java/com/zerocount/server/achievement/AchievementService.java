package com.zerocount.server.achievement;

import com.zerocount.server.match.MatchHook;
import com.zerocount.server.wallet.WalletService;
import com.zerocount.server.wallet.WalletTxType;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * V2.3 — Achievements engine.
 *
 * Called after every match ends (MatchHook) and on explicit trigger points
 * (special card used, store purchase, tournament entry). Grants the badge
 * and credits the reward_coins once only (idempotent INSERT).
 */
@Service
public class AchievementService implements MatchHook {

    private static final Logger log = LoggerFactory.getLogger(AchievementService.class);

    private final JdbcTemplate db;
    private final WalletService wallet;

    public AchievementService(JdbcTemplate db, WalletService wallet) {
        this.db = db;
        this.wallet = wallet;
    }

    // ── MatchHook ────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public void onMatchEnded(List<UUID> seats, int winnerIdx, List<Integer> totals) {
        UUID winner = seats.get(winnerIdx);
        int winnerScore = totals.get(winnerIdx);

        for (int i = 0; i < seats.size(); i++) {
            UUID seat = seats.get(i);
            Integer n = db.queryForObject(
                "SELECT count(*) FROM users WHERE id = ?", Integer.class, seat);
            if (n == null || n == 0) continue;

            boolean isWinner = i == winnerIdx;
            if (isWinner) {
                checkWinMilestones(seat);
                checkStreakMilestones(seat);
                if (winnerScore == 0) checkZeroMilestones(seat);
            }
        }
    }

    // ── Internal checkers ────────────────────────────────────────────────────

    private void checkWinMilestones(UUID userId) {
        int wins = queryInt("SELECT wins FROM statistics WHERE user_id = ?", userId);
        if (wins >= 1)   tryGrant(userId, "first_win");
        if (wins >= 5)   tryGrant(userId, "win_5");
        if (wins >= 25)  tryGrant(userId, "win_25");
        if (wins >= 100) tryGrant(userId, "win_100");
    }

    private void checkStreakMilestones(UUID userId) {
        int streak = queryInt("SELECT best_win_streak FROM statistics WHERE user_id = ?", userId);
        if (streak >= 3)  tryGrant(userId, "streak_3");
        if (streak >= 5)  tryGrant(userId, "streak_5");
        if (streak >= 10) tryGrant(userId, "streak_10");
    }

    private void checkZeroMilestones(UUID userId) {
        tryGrant(userId, "zero_score");
        int zeros = queryInt(
            "SELECT COUNT(*) FROM analytics_events "
            + "WHERE user_id = ? AND event_type = 'gameplay.show' AND payload->>'score' = '0'",
            userId);
        if (zeros >= 5) tryGrant(userId, "zero_5");
    }

    /** Called from ShopController after a successful purchase. */
    public void onStorePurchase(UUID userId, long coinsSpent) {
        int totalSpent = queryInt(
            "SELECT COALESCE(SUM(amount),0) FROM transactions "
            + "WHERE user_id = ? AND type = 'purchase'", userId);
        if (totalSpent >= 1000) tryGrant(userId, "coins_1000");

        int owned = queryInt(
            "SELECT COUNT(*) FROM owned_items WHERE user_id = ?", userId);
        if (owned >= 5) tryGrant(userId, "collector_5");
    }

    /** Called from MatchService when a special card is used. */
    public void onSpecialCardUsed(UUID userId) {
        tryGrant(userId, "special_used");
        int uses = queryInt(
            "SELECT COUNT(*) FROM analytics_events "
            + "WHERE user_id = ? AND event_type = 'gameplay.special_used'", userId);
        if (uses >= 10) tryGrant(userId, "special_10");
    }

    /** Called from ContestService on first entry. */
    public void onTournamentEntered(UUID userId) {
        tryGrant(userId, "tournament_entry");
    }

    /** Called from ContestService when a tournament is won. */
    public void onTournamentWon(UUID userId) {
        tryGrant(userId, "tournament_win");
    }

    // ── Core grant ───────────────────────────────────────────────────────────

    /**
     * Grants the achievement if not already earned. Credits reward_coins once.
     * Returns true if this was a new grant.
     */
    @Transactional
    public boolean tryGrant(UUID userId, String achievementId) {
        int inserted = db.update("""
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (?, ?)
            ON CONFLICT (user_id, achievement_id) DO NOTHING
            """, userId, achievementId);
        if (inserted == 0) return false; // already earned

        Integer reward = db.queryForObject(
            "SELECT reward_coins FROM achievement_definitions WHERE id = ?",
            Integer.class, achievementId);
        if (reward != null && reward > 0) {
            String ref = "achievement:" + achievementId;
            wallet.creditCoins(userId, reward, WalletTxType.ACHIEVEMENT_REWARD, ref);
        }
        log.info("Achievement unlocked: {} → {}", userId, achievementId);
        return true;
    }

    // ── Read API (for AchievementController) ─────────────────────────────────

    public record AchievementDto(
        String id, String title, String description, String icon,
        String rarity, int rewardCoins, boolean earned, String earnedAt
    ) {}

    public List<AchievementDto> listForUser(UUID userId) {
        return db.query("""
            SELECT d.id, d.title, d.description, d.icon, d.rarity, d.reward_coins,
                   ua.earned_at
            FROM achievement_definitions d
            LEFT JOIN user_achievements ua
                   ON ua.achievement_id = d.id AND ua.user_id = ?
            ORDER BY d.rarity DESC, d.id
            """,
            (rs, i) -> new AchievementDto(
                rs.getString("id"),
                rs.getString("title"),
                rs.getString("description"),
                rs.getString("icon"),
                rs.getString("rarity"),
                rs.getInt("reward_coins"),
                rs.getTimestamp("earned_at") != null,
                rs.getTimestamp("earned_at") != null
                    ? rs.getTimestamp("earned_at").toInstant().toString() : null
            ),
            userId);
    }

    public int earnedCount(UUID userId) {
        Integer n = db.queryForObject(
            "SELECT COUNT(*) FROM user_achievements WHERE user_id = ?",
            Integer.class, userId);
        return n != null ? n : 0;
    }

    // ── Utility ──────────────────────────────────────────────────────────────

    private int queryInt(String sql, Object... args) {
        Integer n = db.queryForObject(sql, Integer.class, args);
        return n != null ? n : 0;
    }
}
