package com.zerocount.server.notification;

import com.zerocount.server.match.MatchHook;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.springframework.stereotype.Service;

/**
 * Fires push notifications after a match ends:
 *
 *  • MATCH_RESULT → winner + all players immediately (unsolicited cap applies).
 *  • REMATCH_NUDGE → non-voting players 30 s after match ends, capped at 1/day.
 *
 * The actual FCM transport is handled by CappedNotificationService.deliver().
 */
@Service
public class NotificationMatchHook implements MatchHook {

    private final CappedNotificationService notif;
    private final ScheduledExecutorService scheduler =
        Executors.newSingleThreadScheduledExecutor();

    public NotificationMatchHook(CappedNotificationService notif) {
        this.notif = notif;
    }

    @Override
    public void onMatchEnded(List<UUID> seats, int winnerIdx, List<Integer> totals) {
        UUID winner = seats.get(winnerIdx);
        int winnerScore = totals.get(winnerIdx);

        for (int i = 0; i < seats.size(); i++) {
            UUID seat = seats.get(i);
            boolean isWinner = i == winnerIdx;
            notif.notifyUser(seat, new Notification(
                Notification.Kind.MATCH_RESULT,
                isWinner ? "You won! 🏆" : "Match over",
                isWinner
                    ? "Score: " + winnerScore + " — check the leaderboard!"
                    : "Tap to see how you did.",
                Map.of("screen", "leaderboard")
            ));
        }

        // 30-second nudge: ask non-voters to rematch.
        scheduler.schedule(() -> {
            for (UUID seat : seats) {
                if (seat.equals(winner)) continue;
                notif.notifyUser(seat, new Notification(
                    Notification.Kind.REMATCH_NUDGE,
                    "Up for a rematch? 🎴",
                    "Your opponent wants to play again!",
                    Map.of("screen", "match")
                ));
            }
        }, 30, TimeUnit.SECONDS);
    }
}
