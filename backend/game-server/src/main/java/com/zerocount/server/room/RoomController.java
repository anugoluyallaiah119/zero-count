package com.zerocount.server.room;

import com.zerocount.server.player.AuthInterceptor;
import com.zerocount.server.player.PlayerRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Room REST contract (E2.5) — all endpoints require Bearer auth:
 *
 *   POST /api/rooms                 {"maxPlayers":4,"handSize":7,"target":100} → room
 *   POST /api/rooms/{code}/join     {}                                          → room
 *   POST /api/rooms/{code}/ready    {"ready":true}                              → room
 *   POST /api/rooms/{code}/leave    {}                                          → room | 204 if room closed
 *   GET  /api/rooms/{code}                                                      → lobby state
 */
@RestController
@RequestMapping("/api/rooms")
public class RoomController {

    private final RoomService rooms;
    private final PlayerRepository players;

    public RoomController(RoomService rooms, PlayerRepository players) {
        this.rooms = rooms;
        this.players = players;
    }

    public record CreateRequest(int maxPlayers, int handSize, int target) {}
    public record ReadyRequest(boolean ready) {}

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(HttpServletRequest req,
                                                      @RequestBody CreateRequest body) {
        var userId = AuthInterceptor.currentUserId(req);
        Room room = rooms.create(userId, displayName(userId),
            new Room.GameSettings(body.maxPlayers(), body.handSize(), body.target()));
        return ResponseEntity.status(HttpStatus.CREATED).body(toBody(room));
    }

    @PostMapping("/{code}/join")
    public Map<String, Object> join(HttpServletRequest req, @PathVariable String code) {
        var userId = AuthInterceptor.currentUserId(req);
        return toBody(rooms.join(code, userId, displayName(userId)));
    }

    @PostMapping("/{code}/ready")
    public Map<String, Object> ready(HttpServletRequest req, @PathVariable String code,
                                     @RequestBody ReadyRequest body) {
        return toBody(rooms.setReady(code, AuthInterceptor.currentUserId(req), body.ready()));
    }

    @PostMapping("/{code}/leave")
    public ResponseEntity<Map<String, Object>> leave(HttpServletRequest req,
                                                     @PathVariable String code) {
        Room room = rooms.leave(code, AuthInterceptor.currentUserId(req));
        return room == null
            ? ResponseEntity.noContent().build()
            : ResponseEntity.ok(toBody(room));
    }

    @GetMapping("/{code}")
    public Map<String, Object> get(@PathVariable String code) {
        return toBody(rooms.get(code));
    }

    private String displayName(java.util.UUID userId) {
        return players.findProfile(userId).map(PlayerRepository.Profile::name).orElse(null);
    }

    private static Map<String, Object> toBody(Room room) {
        List<Map<String, Object>> members = room.members().stream()
            .map(m -> Map.<String, Object>of(
                "userId", m.userId().toString(),
                "name", m.displayName(),
                "ready", m.ready(),
                "host", m.userId().equals(room.hostId())))
            .toList();
        return Map.of(
            "code", room.code(),
            "settings", Map.of(
                "maxPlayers", room.settings().maxPlayers(),
                "handSize", room.settings().handSize(),
                "target", room.settings().target()),
            "members", members,
            "full", room.isFull(),
            "startable", room.startable()
        );
    }

    @ExceptionHandler(RoomService.RoomNotFoundException.class)
    public ResponseEntity<Map<String, String>> notFound(RoomService.RoomNotFoundException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", e.getMessage()));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, String>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, String>> conflict(IllegalStateException e) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("error", e.getMessage()));
    }
}
