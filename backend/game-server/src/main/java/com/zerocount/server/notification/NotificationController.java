package com.zerocount.server.notification;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.zerocount.server.player.AuthInterceptor;

/**
 * R1.6 notification endpoints (Bearer-guarded):
 *
 *   POST /api/notifications/device    {"token":"…fcm…"}
 *   POST /api/notifications/mute      {"kind":"CHALLENGE_NUDGE"}
 *   POST /api/notifications/unmute    {"kind":"CHALLENGE_NUDGE"}
 *   GET  /api/notifications/mutes     → ["CHALLENGE_NUDGE", …]
 */
@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final CappedNotificationService notifications;

    public NotificationController(CappedNotificationService notifications) {
        this.notifications = notifications;
    }

    public record TokenBody(String token) {}
    public record KindBody(String kind) {}

    @PostMapping("/device")
    public Map<String, Object> register(@RequestBody TokenBody body,
                                        HttpServletRequest req) {
        notifications.registerDevice(AuthInterceptor.currentUserId(req), body.token());
        return Map.of("registered", true);
    }

    @PostMapping("/mute")
    public Map<String, Object> mute(@RequestBody KindBody body, HttpServletRequest req) {
        notifications.muteKind(AuthInterceptor.currentUserId(req), parse(body.kind()));
        return Map.of("muted", true);
    }

    @PostMapping("/unmute")
    public Map<String, Object> unmute(@RequestBody KindBody body, HttpServletRequest req) {
        notifications.unmuteKind(AuthInterceptor.currentUserId(req), parse(body.kind()));
        return Map.of("muted", false);
    }

    @GetMapping("/mutes")
    public List<String> mutes(HttpServletRequest req) {
        return notifications.mutes(AuthInterceptor.currentUserId(req));
    }

    private static Notification.Kind parse(String kind) {
        try {
            return Notification.Kind.valueOf(kind == null ? "" : kind.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("unknown kind: " + kind);
        }
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }
}
