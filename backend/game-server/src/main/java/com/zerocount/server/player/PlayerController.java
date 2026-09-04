package com.zerocount.server.player;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Player profile REST contract (E2.4) — all endpoints require a Bearer token
 * (AuthInterceptor on /api/players/**):
 *
 *   GET   /api/players/me          → profile + stats for the profile screen
 *   PATCH /api/players/me          {"name":"…","avatar":"…"} (partial update)
 */
@RestController
@RequestMapping("/api/players")
public class PlayerController {

    private static final int MAX_NAME_LEN = 50;
    private static final int MAX_AVATAR_LEN = 255;

    private final PlayerRepository players;

    public PlayerController(PlayerRepository players) {
        this.players = players;
    }

    public record ProfilePatch(String name, String avatar) {}

    @GetMapping("/me")
    public Map<String, Object> me(HttpServletRequest req) {
        var userId = AuthInterceptor.currentUserId(req);
        var profile = players.findProfile(userId)
            .orElseThrow(() -> new IllegalStateException("authenticated user missing from DB"));
        var stats = players.findStats(userId)
            .orElse(new PlayerRepository.Stats(0, 0, 0, null, 0, 1200, 0, 0));
        return Map.of(
            "id", profile.id().toString(),
            "phone", maskPhone(profile.phone()),
            "name", profile.name() == null ? "" : profile.name(),
            "avatar", profile.avatar() == null ? "" : profile.avatar(),
            "coins", profile.coins(),
            "gems", profile.gems(),
            "memberSince", profile.createdAt().toString(),
            "stats", Map.of(
                "matches", stats.matches(),
                "wins", stats.wins(),
                "zerosMade", stats.zerosMade(),
                "bestCount", stats.bestCount() == null ? -1 : stats.bestCount(),
                "streakDays", stats.streakDays(),
                "elo", stats.elo(),
                "winStreak", stats.winStreak(),
                "bestWinStreak", stats.bestWinStreak()
            )
        );
    }

    @PatchMapping("/me")
    public Map<String, Object> updateMe(HttpServletRequest req, @RequestBody ProfilePatch patch) {
        var userId = AuthInterceptor.currentUserId(req);
        String name = validateName(patch.name());
        String avatar = validateAvatar(patch.avatar());
        players.updateProfile(userId, name, avatar);
        return me(req);
    }

    /** Phone is PII (standards §3.4): never return it in full. */
    private static String maskPhone(String phone) {
        if (phone == null || phone.length() < 6) return "***";
        return phone.substring(0, 4) + "******" + phone.substring(phone.length() - 2);
    }

    private static String validateName(String name) {
        if (name == null) return null; // partial update: unchanged
        String n = name.trim();
        if (n.isEmpty() || n.length() > MAX_NAME_LEN) {
            throw new IllegalArgumentException("name must be 1–" + MAX_NAME_LEN + " characters");
        }
        return n;
    }

    private static String validateAvatar(String avatar) {
        if (avatar == null) return null;
        if (avatar.length() > MAX_AVATAR_LEN) {
            throw new IllegalArgumentException("avatar reference too long");
        }
        return avatar;
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, String>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, String>> notFound(IllegalStateException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "player not found"));
    }
}
