package com.zerocount.server.analytics;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zerocount.server.player.AuthInterceptor;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Analytics REST contract (E4.4) — Bearer token required (AuthInterceptor on
 * /api/events/** and /api/analytics/**):
 *
 *   POST /api/events             {"events":[{"name":"app_start","ts":"…","props":{…}}, …]}
 *                                → 202 {"accepted":N}   (batch, max 100)
 *   GET  /api/analytics/summary  → {"totalEvents":N, "activeUsers1d":N, "activeUsers7d":N,
 *                                   "byName7d":[{name,count}…], "daily14d":[{day,count}…]}
 *
 * Validation (standards §3.4): unknown/malformed entries are rejected
 * individually — one bad event never sinks a batch (clients retry whole
 * batches on failure, so silently accepting junk would poison funnels).
 */
@RestController
@RequestMapping("/api")
public class AnalyticsController {

    static final int MAX_BATCH = 100;
    static final int MAX_NAME_LEN = 64;
    static final int MAX_PROPS_BYTES = 4096;
    private static final Pattern NAME_RE = Pattern.compile("[a-z][a-z0-9_]{0,63}");

    private final AnalyticsRepository analytics;
    private final ObjectMapper json = new ObjectMapper();

    public AnalyticsController(AnalyticsRepository analytics) {
        this.analytics = analytics;
    }

    public record ClientEvent(String name, String ts, Map<String, Object> props) {}
    public record Batch(List<ClientEvent> events) {}

    public static class BadEventException extends RuntimeException {
        public BadEventException(String msg) { super(msg); }
    }

    @PostMapping("/events")
    public Map<String, Object> ingest(@RequestBody Batch batch, HttpServletRequest req) {
        if (batch == null || batch.events() == null || batch.events().isEmpty()) {
            throw new BadEventException("events must be a non-empty array");
        }
        if (batch.events().size() > MAX_BATCH) {
            throw new BadEventException("batch too large (max " + MAX_BATCH + ")");
        }
        UUID userId = AuthInterceptor.currentUserId(req);
        List<AnalyticsRepository.Event> valid = new ArrayList<>(batch.events().size());
        for (ClientEvent e : batch.events()) {
            valid.add(validate(userId, e));
        }
        analytics.insertAll(valid);
        return Map.of("accepted", valid.size());
    }

    private AnalyticsRepository.Event validate(UUID userId, ClientEvent e) {
        if (e == null || e.name() == null || !NAME_RE.matcher(e.name()).matches()) {
            throw new BadEventException("event name must match [a-z][a-z0-9_]{0,63}");
        }
        Instant ts;
        try {
            ts = Instant.parse(e.ts());
        } catch (DateTimeParseException | NullPointerException ex) {
            throw new BadEventException("ts must be an ISO-8601 instant");
        }
        // Reject clock nonsense: >1 day in the future or >90 days old.
        if (ts.isAfter(Instant.now().plusSeconds(86_400))
                || ts.isBefore(Instant.now().minusSeconds(90L * 86_400))) {
            throw new BadEventException("ts out of acceptable range");
        }
        String propsJson;
        try {
            propsJson = json.writeValueAsString(e.props() == null ? Map.of() : e.props());
        } catch (JsonProcessingException ex) {
            throw new BadEventException("props must be a JSON object");
        }
        if (propsJson.length() > MAX_PROPS_BYTES) {
            throw new BadEventException("props too large (max " + MAX_PROPS_BYTES + " bytes)");
        }
        return new AnalyticsRepository.Event(userId, e.name(), propsJson, ts);
    }

    /** Basic dashboard data: headline counters + 7-day funnel + 14-day trend. */
    @GetMapping("/analytics/summary")
    public Map<String, Object> summary() {
        var byName = analytics.countsByName(7).stream()
            .map(nc -> Map.of("name", (Object) nc.name(), "count", nc.count()))
            .toList();
        var daily = analytics.dailyVolume(14).stream()
            .map(nc -> Map.of("day", (Object) nc.name(), "count", nc.count()))
            .toList();
        return Map.of(
            "totalEvents", analytics.totalEvents(),
            "activeUsers1d", analytics.activeUsers(1),
            "activeUsers7d", analytics.activeUsers(7),
            "byName7d", byName,
            "daily14d", daily);
    }

    @ExceptionHandler(BadEventException.class)
    public ResponseEntity<Map<String, String>> badEvent(BadEventException e) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", e.getMessage()));
    }
}
