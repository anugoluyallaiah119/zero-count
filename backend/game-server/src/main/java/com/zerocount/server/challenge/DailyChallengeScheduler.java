package com.zerocount.server.challenge;

import java.time.LocalDate;
import java.time.ZoneOffset;
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

    public DailyChallengeScheduler(JdbcTemplate db) {
        this.db = db;
    }

    /** Seed today's and tomorrow's challenge rows so they are ready in advance. */
    @Scheduled(cron = "5 0 0 * * *", zone = "UTC")
    public void seedDaily() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        seed(today);
        seed(today.plusDays(1));
        log.info("Daily challenges seeded for {} and {}", today, today.plusDays(1));
    }

    /** Also seed on startup so restarts mid-day don't leave today missing. */
    @jakarta.annotation.PostConstruct
    public void seedOnStartup() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        seed(today);
        seed(today.plusDays(1));
        log.info("Daily challenge startup seed: {}", today);
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
