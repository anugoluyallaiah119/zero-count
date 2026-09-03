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

    public record Today(UUID id, String type, int target, int reward,
                        int progress, boolean claimed) {
        public boolean canClaim() { return !claimed && progress >= target; }
    }

    /** Today's challenge, creating it on first access (idempotent). */
    public Today today(UUID userId) {
        LocalDate date = LocalDate.now(ZoneOffset.UTC);
        UUID id = ensureChallenge(date);
        db.update("INSERT INTO daily_challenge_progress (user_id, challenge_id) "
                + "VALUES (?,?) ON CONFLICT DO NOTHING", userId, id);
        return db.queryForObject("""
            SELECT c.id, c.type, c.target, (c.reward->>'coins')::int AS coins,
                   p.progress, p.claimed
            FROM daily_challenges c
            JOIN daily_challenge_progress p ON p.challenge_id = c.id
            WHERE c.id = ? AND p.user_id = ?
            """, (rs, n) -> new Today(
                rs.getObject("id", UUID.class), rs.getString("type"),
                rs.getInt("target"), rs.getInt("coins"),
                rs.getInt("progress"), rs.getBoolean("claimed")),
            id, userId);
    }

    private UUID ensureChallenge(LocalDate date) {
        int idx = (int) (date.toEpochDay() % POOL.length);
        Object[] def = POOL[idx];
        db.update("INSERT INTO daily_challenges (date, type, target, reward) "
                + "VALUES (?,?,?, ?::jsonb) ON CONFLICT (date) DO NOTHING",
            date, def[0], def[1], "{\"coins\": " + def[2] + "}");
        return db.queryForObject("SELECT id FROM daily_challenges WHERE date = ?",
            UUID.class, date);
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
            ON CONFLICT (user_id, challenge_id) DO UPDATE
            SET progress = daily_challenge_progress.progress + ?
            WHERE EXISTS (SELECT 1 FROM daily_challenges
                          WHERE id = ? AND type = ?)
              AND NOT daily_challenge_progress.claimed
            """, userId, id, delta, id, type, delta, id, type);
    }

    /** Claim today's reward. Idempotent. */
    @Transactional
    public synchronized Today claim(UUID userId) {
        Today t = today(userId);
        if (!t.canClaim()) return t;
        db.update("UPDATE daily_challenge_progress SET claimed = true "
                + "WHERE user_id = ? AND challenge_id = ? AND claimed = false",
            userId, t.id());
        wallet.creditCoins(userId, t.reward(), WalletTxType.DAILY_BONUS,
            "challenge:" + userId + ":" + LocalDate.now(ZoneOffset.UTC));
        return today(userId);
    }
}
