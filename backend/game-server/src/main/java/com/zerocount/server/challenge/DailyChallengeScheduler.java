package com.zerocount.server.challenge;

import com.zerocount.server.notification.CappedNotificationService;
import com.zerocount.server.notification.Notification;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Pre-seeds daily challenges at midnight UTC so the first user to load the
 * Daily tab never waits on a blocking INSERT.
 *
 * Fires once at startup (to cover restarts mid-day) and then at 00:00:05 UTC
 * every day (5-second offset avoids exact-midnight thundering-herd).
 */
@Component
public class DailyChallengeScheduler {

    private static final Logger log =
        LoggerFactory.getLogger(DailyChallengeScheduler.class);

    private final JdbcTemplate db;
    private final CappedNotificationService notif;

    public DailyChallengeScheduler(JdbcTemplate db, CappedNotificationService notif) {
        this.db = db;
        this.notif = notif;
    }

    /** Seed auto-pool challenges and fire pending admin pushes at midnight UTC. */
    @Scheduled(cron = "5 0 0 * * *", zone = "UTC")
    public void seedDaily() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        seed(today);
        seed(today.plusDays(1));
        fireScheduledPushes(today);
        log.info("Daily challenges seeded for {} and {}", today, today.plusDays(1));
    }

    /** Seed on startup so restarts mid-day don't leave today missing. */
    @jakarta.annotation.PostConstruct
    public void seedOnStartup() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        seed(today);
        seed(today.plusDays(1));
        fireScheduledPushes(today);
        log.info("Daily challenge startup seed: {}", today);
    }

    /**
     * Push notifications for admin-created challenges whose window opens today
     * and haven't been notified yet (push_sent = false, notify_on_start = true).
     */
    private void fireScheduledPushes(LocalDate today) {
        List<Map<String, Object>> pending = db.queryForList("""
            SELECT c.id, c.title, c.description, s.name AS sponsor_name
            FROM daily_challenges c
            LEFT JOIN sponsors s ON s.id = c.sponsor_id
            WHERE c.active_from = ?
              AND c.notify_on_start = true
              AND c.push_sent = false
              AND c.created_by IS NOT NULL
            """, today);

        for (var row : pending) {
            UUID challengeId = (UUID) row.get("id");
            String title = (String) row.get("title");
            String desc  = (String) row.get("description");
            String sponsor = (String) row.get("sponsor_name");

            String pushTitle = sponsor != null ? "🎯 " + sponsor + " Challenge!" : "🎯 New Challenge!";
            String pushBody  = title + (desc != null ? " — " + desc : "");

            List<UUID> userIds = db.queryForList(
                "SELECT id FROM users WHERE created_at > now() - interval '90 days'",
                UUID.class);

            for (UUID uid : userIds) {
                notif.notifyUser(uid, new Notification(
                    Notification.Kind.CHALLENGE_NUDGE,
                    pushTitle, pushBody,
                    Map.of("screen", "events", "challengeId", challengeId.toString())
                ));
            }
            db.update("UPDATE daily_challenges SET push_sent = true WHERE id = ?",
                challengeId);
            log.info("Scheduled push sent for challenge {} to {} users",
                challengeId, userIds.size());
        }
    }

    private void seed(LocalDate date) {
        int idx = (int) (date.toEpochDay() % ChallengeService.POOL.length);
        Object[] def = ChallengeService.POOL[idx];
        db.update(
            "INSERT INTO daily_challenges (date, type, target, reward) "
            + "VALUES (?,?,?,?::jsonb) ON CONFLICT (date) DO NOTHING",
            date, def[0], def[1], "{\"coins\": " + def[2] + "}");
    }
}
