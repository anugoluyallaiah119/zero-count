package com.zerocount.server.reward;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.zerocount.server.wallet.WalletService;
import com.zerocount.server.wallet.WalletTxType;

/**
 * R1.3 — daily reward calendar + streak flame counter.
 *
 * A 7-day reward cycle; claiming on consecutive UTC days grows the streak
 * (and the streak bonus), a missed day resets it to 1. One claim per user
 * per day — enforced by the PRIMARY KEY and by the idempotent wallet ref
 * ("daily:{user}:{date}"), so double-taps and retries are harmless.
 */
@Service
public class DailyRewardService {

    /** 7-day cycle, index 0 = cycle day 1. */
    public static final int[] CYCLE = {25, 35, 50, 65, 80, 100, 150};
    /** Extra coins per streak day beyond the base cycle reward (capped). */
    static final int STREAK_BONUS_PER_DAY = 5;
    static final int STREAK_BONUS_CAP = 50;

    private final JdbcTemplate db;
    private final WalletService wallet;

    public DailyRewardService(JdbcTemplate db, WalletService wallet) {
        this.db = db;
        this.wallet = wallet;
    }

    public record Status(boolean canClaim, int streak, int cycleDay,
                         int todayReward, String lastClaimOn) {}

    public Status status(UUID userId) {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        var rows = db.query(
            "SELECT claimed_on, streak FROM daily_reward_claims "
                + "WHERE user_id = ? ORDER BY claimed_on DESC LIMIT 1",
            (rs, n) -> new Object[]{
                rs.getObject("claimed_on", LocalDate.class), rs.getInt("streak")},
            userId);
        if (rows.isEmpty()) {
            return new Status(true, 0, 1, CYCLE[0], null);
        }
        LocalDate last = (LocalDate) rows.get(0)[0];
        int streak = (Integer) rows.get(0)[1];
        boolean claimedToday = last.equals(today);
        int effectiveStreak = last.equals(today.minusDays(1)) || claimedToday
            ? streak : 0; // streak broken — preview shows the reset value
        int nextStreak = claimedToday ? streak : effectiveStreak + 1;
        int cycleDay = ((nextStreak - 1) % CYCLE.length) + 1;
        return new Status(!claimedToday, claimedToday ? streak : effectiveStreak,
            cycleDay, rewardFor(nextStreak), last.toString());
    }

    /** Claim today's reward. Idempotent — a same-day repeat returns the
     *  current status without double-paying. */
    @Transactional
    public synchronized ClaimResult claim(UUID userId) {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        Status s = status(userId);
        if (!s.canClaim()) {
            return new ClaimResult(false, s.streak(), 0,
                wallet.balance(userId).coins());
        }
        int streak = s.streak() + 1;
        int reward = rewardFor(streak);
        db.update("INSERT INTO daily_reward_claims (user_id, claimed_on, streak, "
                + "reward_coins) VALUES (?,?,?,?)", userId, today, streak, reward);
        wallet.creditCoins(userId, reward, WalletTxType.DAILY_BONUS,
            "daily:" + userId + ":" + today);
        db.update("INSERT INTO statistics (user_id, streak_days) VALUES (?,?) "
                + "ON CONFLICT (user_id) DO UPDATE SET streak_days = ?",
            userId, streak, streak);
        return new ClaimResult(true, streak, reward,
            wallet.balance(userId).coins());
    }

    public record ClaimResult(boolean claimed, int streak, int coins, long balance) {}

    static int rewardFor(int streak) {
        int base = CYCLE[(streak - 1) % CYCLE.length];
        int bonus = Math.min((streak - 1) * STREAK_BONUS_PER_DAY, STREAK_BONUS_CAP);
        return base + bonus;
    }
}
