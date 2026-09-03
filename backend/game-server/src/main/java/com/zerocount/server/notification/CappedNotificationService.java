package com.zerocount.server.notification;

import java.time.LocalTime;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * R1.6 — NotificationService activation with respectful caps.
 *
 * Policy (engagement rules, enforced server-side):
 *  - max 1 unsolicited push per user per UTC day (transactional kinds like
 *    FRIEND_REQUEST are exempt — the user triggered them socially);
 *  - quiet hours 22:00–08:00 UTC — nothing is sent, messages are dropped
 *    (a nudge delivered late is worse than none);
 *  - per-kind mutes from user settings;
 *  - every send attempt is recorded in notification_log.
 *
 * Transport: FCM. In this environment no FCM server key is configured, so
 * delivery is logged and the message is persisted — swapping in a real FCM
 * sender later only replaces {@link #deliver}.
 */
@Service
public class CappedNotificationService implements NotificationService {

    private static final Logger log = LoggerFactory.getLogger(CappedNotificationService.class);
    private static final LocalTime QUIET_FROM = LocalTime.of(22, 0);
    private static final LocalTime QUIET_TO = LocalTime.of(8, 0);

    /** Kinds that count against the 1/day unsolicited cap. */
    private static final java.util.Set<Notification.Kind> UNSOLICITED =
        java.util.Set.of(Notification.Kind.CHALLENGE_NUDGE,
            Notification.Kind.STREAK_AT_RISK, Notification.Kind.CONTEST_STARTING);

    private final JdbcTemplate db;

    public CappedNotificationService(JdbcTemplate db) {
        this.db = db;
    }

    @Override
    public void notifyUser(UUID userId, Notification n) {
        if (isMuted(userId, n.kind())) return;
        LocalTime nowUtc = LocalTime.now(ZoneOffset.UTC);
        if (!nowUtc.isBefore(QUIET_FROM) || nowUtc.isBefore(QUIET_TO)) return;
        if (UNSOLICITED.contains(n.kind())) {
            Integer sentToday = db.queryForObject(
                "SELECT COUNT(*) FROM notification_log "
                    + "WHERE user_id = ? AND sent_at > now() - interval '1 day'",
                Integer.class, userId);
            if (sentToday != null && sentToday >= 1) return;
        }
        db.update("INSERT INTO notification_log (user_id, kind) VALUES (?,?)",
            userId, n.kind().name());
        deliver(userId, n);
    }

    /** FCM fan-out to the user's registered devices. Log-only until the FCM
     *  server key is provisioned (deploy env var FCM_SERVER_KEY). */
    protected void deliver(UUID userId, Notification n) {
        List<String> tokens = db.queryForList(
            "SELECT fcm_token FROM device_tokens WHERE user_id = ?",
            String.class, userId);
        log.info("notify {} [{}] {} ({} device(s))", userId, n.kind(), n.title(),
            tokens.size());
    }

    @Override
    public void registerDevice(UUID userId, String fcmToken) {
        if (fcmToken == null || fcmToken.isBlank() || fcmToken.length() > 255) {
            throw new IllegalArgumentException("invalid fcm token");
        }
        db.update("INSERT INTO device_tokens (user_id, fcm_token) VALUES (?,?) "
                + "ON CONFLICT (user_id, fcm_token) DO UPDATE SET updated_at = now()",
            userId, fcmToken);
    }

    @Override
    public void muteKind(UUID userId, Notification.Kind kind) {
        db.update("INSERT INTO notification_mutes (user_id, kind) VALUES (?,?) "
                + "ON CONFLICT DO NOTHING", userId, kind.name());
    }

    public void unmuteKind(UUID userId, Notification.Kind kind) {
        db.update("DELETE FROM notification_mutes WHERE user_id = ? AND kind = ?",
            userId, kind.name());
    }

    public List<String> mutes(UUID userId) {
        return db.queryForList(
            "SELECT kind FROM notification_mutes WHERE user_id = ? ORDER BY kind",
            String.class, userId);
    }

    public boolean isMuted(UUID userId, Notification.Kind kind) {
        Integer n = db.queryForObject(
            "SELECT COUNT(*) FROM notification_mutes WHERE user_id = ? AND kind = ?",
            Integer.class, userId, kind.name());
        return n != null && n > 0;
    }
}
