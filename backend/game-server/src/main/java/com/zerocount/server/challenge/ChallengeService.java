package com.zerocount.server.challenge;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.zerocount.server.match.MatchHook;
import com.zerocount.server.wallet.WalletService;
import com.zerocount.server.wallet.WalletTxType;

/**
 * R1.4 — daily challenge + rotating quest pool.
 *
 * One global challenge per UTC date, picked deterministically from a
 * rotating pool (day-of-year % pool size) so every player chases the same
 * quest. Progress accrues from completed matches / SHOW calls via the
 * {@code onMatchEnded}/{@code onShowed} hooks wired into MatchService.
 * Claiming pays the reward through the wallet with an idempotent ref.
 */
@Service
public class ChallengeService implements MatchHook {

    /** Rotating quest pool: {type, target, coins}. */
    static final Object[][] POOL = {
        {"play_matches", 2, 40},
        {"win_matches", 1, 60},
        {"call_show", 1, 50},
        {"play_matches", 3, 70},
        {"win_matches", 2, 120},
    };

    private final JdbcTemplate db;
    private final WalletService wallet;

    public ChallengeService(JdbcTemplate db, WalletService wallet) {
        this.db = db;
        this.wallet = wallet;
    }

    public record Today(
        UUID id, String type, String title, String description,
        int target, int rewardCoins, int rewardGems, String rewardCosmeticId,
        String sponsorName, String cadence,
        int progress, boolean claimed
    ) {
        public boolean canClaim() { return !claimed && progress >= target; }
        /** Back-compat: single reward int used by ChallengeController. */
        public int reward() { return rewardCoins; }
    }

    /** Active challenge for today (admin-created wins over auto-generated). */
    public Today today(UUID userId) {
        LocalDate now = LocalDate.now(ZoneOffset.UTC);
        UUID id = ensureChallenge(now);
        db.update("INSERT INTO daily_challenge_progress (user_id, challenge_id) "
                + "VALUES (?,?) ON CONFLICT DO NOTHING", userId, id);
        return db.queryForObject("""
            SELECT c.id, c.type,
                   COALESCE(c.title, c.type) AS title,
                   COALESCE(c.description, '') AS description,
                   c.target,
                   COALESCE(c.reward_coins, (c.reward->>'coins')::int, 0) AS reward_coins,
                   COALESCE(c.reward_gems, 0) AS reward_gems,
                   c.reward_cosmetic_id,
                   s.name AS sponsor_name,
                   COALESCE(c.cadence, 'daily') AS cadence,
                   p.progress, p.claimed
            FROM daily_challenges c
            JOIN daily_challenge_progress p ON p.challenge_id = c.id
            LEFT JOIN sponsors s ON s.id = c.sponsor_id
            WHERE c.id = ? AND p.user_id = ?
            """,
            (rs, n) -> new Today(
                rs.getObject("id", UUID.class),
                rs.getString("type"),
                rs.getString("title"),
                rs.getString("description"),
                rs.getInt("target"),
                rs.getInt("reward_coins"),
                rs.getInt("reward_gems"),
                rs.getString("reward_cosmetic_id"),
                rs.getString("sponsor_name"),
                rs.getString("cadence"),
                rs.getInt("progress"),
                rs.getBoolean("claimed")),
            id, userId);
    }

    /**
     * Finds the active admin-created challenge for today first; falls back to
     * the auto-seeded rotating pool entry.
     */
    private UUID ensureChallenge(LocalDate date) {
        // Admin-created challenge active today takes priority.
        List<UUID> admin = db.queryForList(
            "SELECT id FROM daily_challenges "
            + "WHERE active_from <= ? AND active_until > ? "
            + "  AND created_by IS NOT NULL "
            + "ORDER BY active_from DESC LIMIT 1",
            UUID.class, date, date);
        if (!admin.isEmpty()) return admin.get(0);

        // Auto-seed from rotating pool.
        int idx = (int) (date.toEpochDay() % POOL.length);
        Object[] def = POOL[idx];
        db.update("""
            INSERT INTO daily_challenges
                (date, type, target, reward, active_from, active_until, reward_coins)
            VALUES (?,?,?,?::jsonb, ?,?,?)
            ON CONFLICT (date) DO NOTHING
            """,
            date, def[0], def[1], "{\"coins\": " + def[2] + "}",
            date, date.plusDays(1), def[2]);
        return db.queryForObject(
            "SELECT id FROM daily_challenges WHERE date = ?", UUID.class, date);
    }

    /** Match-ended hook — every seated player progresses "play", the winner
     *  also progresses "win". */
    @Override
    @Transactional
    public void onMatchEnded(List<UUID> seats, int winnerIdx, List<Integer> totals) {
        for (int i = 0; i < seats.size(); i++) {
            bump(seats.get(i), "play_matches", 1);
            if (i == winnerIdx) bump(seats.get(i), "win_matches", 1);
        }
    }

    /** SHOW hook. */
    @Override
    @Transactional
    public void onShowed(UUID userId) {
        bump(userId, "call_show", 1);
    }

    private void bump(UUID userId, String type, int delta) {
        LocalDate date = LocalDate.now(ZoneOffset.UTC);
        UUID id = ensureChallenge(date);
        db.update("""
            INSERT INTO daily_challenge_progress (user_id, challenge_id, progress)
            SELECT ?, ?, ?
            WHERE EXISTS (SELECT 1 FROM daily_challenges WHERE id = ? AND type = ?)
              AND EXISTS (SELECT 1 FROM users WHERE id = ?)
            ON CONFLICT (user_id, challenge_id) DO UPDATE
            SET progress = daily_challenge_progress.progress + ?
            WHERE EXISTS (SELECT 1 FROM daily_challenges
                          WHERE id = ? AND type = ?)
              AND NOT daily_challenge_progress.claimed
            """, userId, id, delta, id, type, userId, delta, id, type);
    }

    /** Claim today's reward — coins + gems + optional cosmetic unlock. */
    @Transactional
    public synchronized Today claim(UUID userId) {
        Today t = today(userId);
        if (!t.canClaim()) return t;
        db.update("UPDATE daily_challenge_progress SET claimed = true "
                + "WHERE user_id = ? AND challenge_id = ? AND claimed = false",
            userId, t.id());
        String ref = "challenge:" + userId + ":" + LocalDate.now(ZoneOffset.UTC);
        if (t.rewardCoins() > 0)
            wallet.creditCoins(userId, t.rewardCoins(), WalletTxType.DAILY_BONUS, ref);
        if (t.rewardGems() > 0)
            db.update("UPDATE wallets SET gems = gems + ? WHERE user_id = ?",
                t.rewardGems(), userId);
        if (t.rewardCosmeticId() != null) {
            db.update("INSERT INTO owned_items (user_id, item_id) VALUES (?,?) "
                + "ON CONFLICT DO NOTHING", userId, t.rewardCosmeticId());
        }
        return today(userId);
    }
}
