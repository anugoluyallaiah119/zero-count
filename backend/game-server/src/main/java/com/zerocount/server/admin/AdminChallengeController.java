package com.zerocount.server.admin;

import com.zerocount.server.notification.CappedNotificationService;
import com.zerocount.server.notification.Notification;
import jakarta.servlet.http.HttpServletRequest;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Admin challenge management — protected by X-Admin-Token header.
 *
 *   POST /api/admin/challenges        — create a new challenge
 *   GET  /api/admin/challenges        — list all challenges (any cadence)
 *   POST /api/admin/challenges/push   — manually re-send push for a challenge
 *
 * On creation with notify_on_start=true the push fires immediately if
 * active_from <= today, or is queued for the DailyChallengeScheduler otherwise.
 *
 * Reward fields (all optional, defaults to 0 / null):
 *   reward_coins, reward_gems, reward_cosmetic_id
 *
 * Sponsored challenge: include sponsor_id (UUID of an existing sponsor row).
 * If sponsor_id is supplied, the push notification title includes the brand name.
 */
@RestController
@RequestMapping("/api/admin/challenges")
public class AdminChallengeController {

    private static final Logger log =
        LoggerFactory.getLogger(AdminChallengeController.class);

    private final JdbcTemplate db;
    private final CappedNotificationService notif;
    private final String adminToken;

    public AdminChallengeController(
            JdbcTemplate db,
            CappedNotificationService notif,
            @Value("${app.admin-token:dev-admin-token}") String adminToken) {
        this.db = db;
        this.notif = notif;
        this.adminToken = adminToken;
    }

    // ── Request body ─────────────────────────────────────────────────────────

    public record CreateChallengeBody(
        String type,            // play_matches | win_matches | call_show | custom
        int    target,          // how many times
        String cadence,         // daily | weekly | monthly
        String title,           // display title (optional — auto-generated if null)
        String description,     // display description
        int    rewardCoins,
        int    rewardGems,
        String rewardCosmeticId,// optional cosmetic item id
        String sponsorId,       // optional UUID string
        String activeFrom,      // ISO date yyyy-MM-dd (default: today)
        String activeUntil,     // ISO date (default: activeFrom + cadence window)
        boolean notifyOnStart,  // send push to all users? (default true)
        String createdBy        // admin name / note
    ) {}

    // ── Endpoints ─────────────────────────────────────────────────────────────

    @PostMapping
    public Map<String, Object> create(@RequestBody CreateChallengeBody body,
                                      HttpServletRequest req) {
        guard(req);
        validate(body);

        LocalDate from = body.activeFrom() != null
            ? LocalDate.parse(body.activeFrom())
            : LocalDate.now(ZoneOffset.UTC);

        LocalDate until = body.activeUntil() != null
            ? LocalDate.parse(body.activeUntil())
            : defaultUntil(from, body.cadence());

        String title = body.title() != null ? body.title() : autoTitle(body);
        String desc  = body.description() != null ? body.description()
            : autoDesc(body);

        UUID sponsorUuid = body.sponsorId() != null && !body.sponsorId().isBlank()
            ? UUID.fromString(body.sponsorId()) : null;

        // Upsert: if a challenge already exists for this date+type+cadence, update it.
        UUID id = db.queryForObject("""
            INSERT INTO daily_challenges
                (date, type, target, reward,
                 title, description, cadence,
                 active_from, active_until,
                 reward_coins, reward_gems, reward_cosmetic_id,
                 sponsor_id, notify_on_start, created_by, push_sent)
            VALUES (?,?,?,?::jsonb, ?,?,?, ?,?, ?,?,?, ?,?,?,false)
            ON CONFLICT (date) DO UPDATE SET
                type              = EXCLUDED.type,
                target            = EXCLUDED.target,
                reward            = EXCLUDED.reward,
                title             = EXCLUDED.title,
                description       = EXCLUDED.description,
                cadence           = EXCLUDED.cadence,
                active_from       = EXCLUDED.active_from,
                active_until      = EXCLUDED.active_until,
                reward_coins      = EXCLUDED.reward_coins,
                reward_gems       = EXCLUDED.reward_gems,
                reward_cosmetic_id= EXCLUDED.reward_cosmetic_id,
                sponsor_id        = EXCLUDED.sponsor_id,
                notify_on_start   = EXCLUDED.notify_on_start,
                created_by        = EXCLUDED.created_by,
                push_sent         = false
            RETURNING id
            """,
            UUID.class,
            from, body.type(), body.target(),
            "{\"coins\":" + body.rewardCoins() + ", \"gems\":" + body.rewardGems() + "}",
            title, desc, body.cadence(),
            from, until,
            body.rewardCoins(), body.rewardGems(), body.rewardCosmeticId(),
            sponsorUuid, body.notifyOnStart(), body.createdBy());

        log.info("Admin created challenge {} ({}): {} × {} from {} to {}",
            id, body.cadence(), body.type(), body.target(), from, until);

        // Fire push immediately if active window has started.
        boolean pushed = false;
        if (body.notifyOnStart() && !from.isAfter(LocalDate.now(ZoneOffset.UTC))) {
            String sponsorName = resolveSponsorName(sponsorUuid);
            pushToAllUsers(id, title, desc, sponsorName);
            pushed = true;
        }

        return Map.of(
            "id", id.toString(),
            "title", title,
            "cadence", body.cadence(),
            "activeFrom", from.toString(),
            "activeUntil", until.toString(),
            "rewardCoins", body.rewardCoins(),
            "rewardGems", body.rewardGems(),
            "pushSent", pushed
        );
    }

    @GetMapping
    public List<Map<String, Object>> list(HttpServletRequest req) {
        guard(req);
        return db.queryForList("""
            SELECT c.id, c.title, c.description, c.type, c.target, c.cadence,
                   c.active_from, c.active_until, c.reward_coins, c.reward_gems,
                   c.reward_cosmetic_id, c.notify_on_start, c.push_sent,
                   c.created_by, c.created_at,
                   s.name AS sponsor_name
            FROM daily_challenges c
            LEFT JOIN sponsors s ON s.id = c.sponsor_id
            ORDER BY c.active_from DESC
            LIMIT 200
            """);
    }

    /** Manually re-push an existing challenge to all users. */
    @PostMapping("/push")
    public Map<String, Object> repush(@RequestBody Map<String, String> body,
                                      HttpServletRequest req) {
        guard(req);
        UUID id = UUID.fromString(body.get("id"));
        var row = db.queryForMap(
            "SELECT c.title, c.description, s.name AS sponsor_name "
            + "FROM daily_challenges c LEFT JOIN sponsors s ON s.id = c.sponsor_id "
            + "WHERE c.id = ?", id);
        String title = (String) row.get("title");
        String desc  = (String) row.get("description");
        String sponsor = (String) row.get("sponsor_name");
        pushToAllUsers(id, title, desc, sponsor);
        return Map.of("pushed", true, "challengeId", id.toString());
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    private void pushToAllUsers(UUID challengeId, String title, String desc,
                                String sponsorName) {
        List<UUID> userIds = db.queryForList(
            "SELECT id FROM users WHERE created_at > now() - interval '90 days'",
            UUID.class);

        String pushTitle = sponsorName != null
            ? "🎯 " + sponsorName + " Challenge!"
            : "🎯 New Challenge!";
        String pushBody = title + " — " + desc;

        for (UUID uid : userIds) {
            notif.notifyUser(uid, new Notification(
                Notification.Kind.CHALLENGE_NUDGE,
                pushTitle,
                pushBody,
                Map.of("screen", "events", "challengeId", challengeId.toString())
            ));
        }

        db.update("UPDATE daily_challenges SET push_sent = true WHERE id = ?",
            challengeId);
        log.info("Push sent for challenge {} to {} users", challengeId, userIds.size());
    }

    private String resolveSponsorName(UUID sponsorId) {
        if (sponsorId == null) return null;
        List<String> names = db.queryForList(
            "SELECT name FROM sponsors WHERE id = ?", String.class, sponsorId);
        return names.isEmpty() ? null : names.get(0);
    }

    private static LocalDate defaultUntil(LocalDate from, String cadence) {
        return switch (cadence) {
            case "weekly"  -> from.plusDays(7);
            case "monthly" -> from.plusDays(30);
            default        -> from.plusDays(1);
        };
    }

    private static String autoTitle(CreateChallengeBody b) {
        return switch (b.type()) {
            case "play_matches" -> "DAILY PLAY";
            case "win_matches"  -> "ZERO STREAK";
            case "call_show"    -> "CALL SHOW";
            default             -> b.type().toUpperCase().replace("_", " ");
        };
    }

    private static String autoDesc(CreateChallengeBody b) {
        return switch (b.type()) {
            case "play_matches" -> "Play " + b.target() + " matches";
            case "win_matches"  -> "Win " + b.target() + " match" + (b.target() > 1 ? "es" : "");
            case "call_show"    -> "Call Show " + b.target() + " time" + (b.target() > 1 ? "s" : "");
            default             -> "Complete " + b.target() + " times";
        };
    }

    private static void validate(CreateChallengeBody b) {
        if (b.type() == null || b.type().isBlank())
            throw new IllegalArgumentException("type is required");
        if (b.target() < 1)
            throw new IllegalArgumentException("target must be >= 1");
        if (b.cadence() == null || !List.of("daily","weekly","monthly").contains(b.cadence()))
            throw new IllegalArgumentException("cadence must be daily, weekly, or monthly");
        if (b.rewardCoins() < 0 || b.rewardGems() < 0)
            throw new IllegalArgumentException("rewards must be >= 0");
    }

    private void guard(HttpServletRequest req) {
        String token = req.getHeader("X-Admin-Token");
        if (token == null || !token.equals(adminToken))
            throw new ForbiddenException();
    }

    static class ForbiddenException extends RuntimeException {}

    @ExceptionHandler(ForbiddenException.class)
    public ResponseEntity<Map<String, Object>> forbidden() {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
            .body(Map.of("error", "admin token required"));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }
}
