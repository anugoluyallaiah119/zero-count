package com.zerocount.server.player;

import com.zerocount.server.match.MatchBroadcaster;
import com.zerocount.server.match.MatchHook;
import com.zerocount.server.match.MatchService;
import com.zerocount.server.wallet.WalletService;
import com.zerocount.server.wallet.WalletTxType;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.annotation.Lazy;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * R1.6 — consecutive-win streak with milestone rewards.
 *
 * Winner's streak += 1, losers' streaks reset to 0, best_win_streak is bumped
 * to the new peak. Milestones (3/5/10 consecutive wins) also credit a coin
 * bonus and broadcast a {@code streak_bonus} event on the room topic so the
 * live UI can celebrate.
 */
@Service
public class WinStreakService implements MatchHook {

    /** streak value → bonus coins. */
    static final Map<Integer, Long> MILESTONES = Map.of(
        3, 50L, 5, 100L, 10, 250L);

    private final JdbcTemplate db;
    private final WalletService wallet;
    private final MatchBroadcaster broadcaster;
    private final MatchService matches;

    public WinStreakService(JdbcTemplate db, WalletService wallet,
                            MatchBroadcaster broadcaster,
                            @Lazy MatchService matches) {
        this.db = db;
        this.wallet = wallet;
        this.broadcaster = broadcaster;
        this.matches = matches;
    }

    @Override
    @Transactional
    public void onMatchEnded(List<UUID> seats, int winnerIdx, List<Integer> totals) {
        UUID winner = seats.get(winnerIdx);
        for (int i = 0; i < seats.size(); i++) {
            db.update("INSERT INTO statistics (user_id) VALUES (?) "
                + "ON CONFLICT (user_id) DO NOTHING", seats.get(i));
        }
        // Winner's streak grows; best_win_streak tracks the peak.
        db.update("""
            UPDATE statistics
               SET win_streak = win_streak + 1,
                   best_win_streak = GREATEST(best_win_streak, win_streak + 1)
             WHERE user_id = ?
            """, winner);
        // Losers reset.
        for (int i = 0; i < seats.size(); i++) {
            if (i == winnerIdx) continue;
            db.update("UPDATE statistics SET win_streak = 0 WHERE user_id = ?",
                seats.get(i));
        }
        Integer newStreak = db.queryForObject(
            "SELECT win_streak FROM statistics WHERE user_id = ?",
            Integer.class, winner);
        if (newStreak == null) return;

        Long bonus = MILESTONES.get(newStreak);
        if (bonus != null && bonus > 0) {
            wallet.creditCoins(winner, bonus, WalletTxType.STREAK_BONUS,
                "streak-" + winner + "-" + newStreak);
        }
        String code = roomOf(winner);
        if (code != null) {
            Map<String, Object> payload = new HashMap<>();
            payload.put("type", "streak_bonus");
            payload.put("userId", winner.toString());
            payload.put("streak", newStreak);
            payload.put("bonusCoins", bonus == null ? 0L : bonus);
            broadcaster.announce(code, payload);
        }
    }

    private String roomOf(UUID userId) {
        List<String> rooms = matches.roomsOf(userId);
        return rooms.isEmpty() ? null : rooms.get(0);
    }
}
