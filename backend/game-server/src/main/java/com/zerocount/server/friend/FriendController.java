package com.zerocount.server.friend;

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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.zerocount.server.player.AuthInterceptor;

/**
 * R1.1 friends REST contract (Bearer-guarded):
 *
 *   GET  /api/friends                 → {"friends":[…],"incoming":[…],"outgoing":[…]}
 *   GET  /api/friends/search?q=…      → up to 20 users by name
 *   POST /api/friends/request         {"userId":"…"} → {"result":"requested|accepted|…"}
 *   POST /api/friends/accept          {"userId":"…"}
 *   POST /api/friends/remove          {"userId":"…"}
 */
@RestController
@RequestMapping("/api/friends")
public class FriendController {

    private final FriendService friends;

    public FriendController(FriendService friends) {
        this.friends = friends;
    }

    public record IdBody(String userId) {}

    @GetMapping
    public Map<String, Object> lists(HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        FriendService.FriendLists l = friends.lists(userId);
        return Map.of(
            "friends", toJson(l.friends()),
            "incoming", toJson(l.incoming()),
            "outgoing", toJson(l.outgoing()));
    }

    @GetMapping("/search")
    public List<Map<String, Object>> search(@RequestParam String q,
                                            HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        if (q == null || q.isBlank() || q.length() > 50) return List.of();
        return toJson(friends.search(q.trim(), userId));
    }

    @PostMapping("/request")
    public Map<String, Object> request(@RequestBody IdBody body,
                                       HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        return Map.of("result",
            friends.request(userId, UUID.fromString(body.userId())));
    }

    @PostMapping("/accept")
    public Map<String, Object> accept(@RequestBody IdBody body,
                                      HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        friends.accept(userId, UUID.fromString(body.userId()));
        return Map.of("result", "accepted");
    }

    @PostMapping("/remove")
    public Map<String, Object> remove(@RequestBody IdBody body,
                                      HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        friends.remove(userId, UUID.fromString(body.userId()));
        return Map.of("result", "removed");
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(Map.of("error", e.getMessage()));
    }

    private static List<Map<String, Object>> toJson(List<FriendService.FriendEntry> l) {
        return l.stream().map(f -> Map.<String, Object>of(
            "userId", f.userId().toString(),
            "name", f.name() == null ? "" : f.name(),
            "avatar", f.avatar() == null ? "" : f.avatar(),
            "online", f.online())).toList();
    }
}
