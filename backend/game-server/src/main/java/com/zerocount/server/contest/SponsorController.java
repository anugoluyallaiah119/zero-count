package com.zerocount.server.contest;

import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
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
 * C1.2 — sponsored events + sponsor management.
 *
 * Admin-gated (X-Admin-Token header matching app.admin-token; dev default is
 * only for local/testing — set a real value in any shared environment):
 *
 *   POST /api/admin/sponsors   {"name":"Acme","logoUrl":"…","siteUrl":"…"}
 *   GET  /api/admin/sponsors   → all sponsors
 *   POST /api/admin/contests   {"title":"…","sponsorId":"…",
 *                               "startsAt":"ISO","endsAt":"ISO"}
 *
 * Sponsored contests surface their sponsor on the public /api/contests list.
 */
@RestController
@RequestMapping("/api/admin")
public class SponsorController {

    private final JdbcTemplate db;
    private final String adminToken;

    public SponsorController(JdbcTemplate db,
            @Value("${app.admin-token:dev-admin-token}") String adminToken) {
        this.db = db;
        this.adminToken = adminToken;
    }

    public record SponsorBody(String name, String logoUrl, String siteUrl) {}
    public record ContestBody(String title, String sponsorId,
                              String startsAt, String endsAt) {}

    @GetMapping("/sponsors")
    public List<Map<String, Object>> sponsors(HttpServletRequest req) {
        guard(req);
        return db.queryForList(
            "SELECT id, name, logo_url, site_url, created_at FROM sponsors "
                + "ORDER BY created_at");
    }

    @PostMapping("/sponsors")
    public Map<String, Object> createSponsor(@RequestBody SponsorBody body,
                                             HttpServletRequest req) {
        guard(req);
        if (body.name() == null || body.name().isBlank() || body.name().length() > 80) {
            throw new IllegalArgumentException("name required (≤80 chars)");
        }
        UUID id = db.queryForObject(
            "INSERT INTO sponsors (name, logo_url, site_url) VALUES (?,?,?) "
                + "RETURNING id", UUID.class,
            body.name().trim(), body.logoUrl(), body.siteUrl());
        return Map.of("id", id.toString(), "name", body.name().trim());
    }

    @PostMapping("/contests")
    public Map<String, Object> createContest(@RequestBody ContestBody body,
                                             HttpServletRequest req) {
        guard(req);
        if (body.title() == null || body.title().isBlank()) {
            throw new IllegalArgumentException("title required");
        }
        Instant start = Instant.parse(body.startsAt());
        Instant end = Instant.parse(body.endsAt());
        if (!end.isAfter(start)) {
            throw new IllegalArgumentException("endsAt must be after startsAt");
        }
        UUID id = db.queryForObject(
            "INSERT INTO contests (title, rules_json, starts_at, ends_at, sponsor_id) "
                + "VALUES (?, ?::jsonb, ?, ?, ?) RETURNING id", UUID.class,
            body.title().trim(),
            body.sponsorId() == null
                ? "{\"scoring\":\"win=3, play=1\"}"
                : "{\"scoring\":\"win=3, play=1\", \"sponsored\": true}",
            java.sql.Timestamp.from(start), java.sql.Timestamp.from(end),
            body.sponsorId() == null ? null : UUID.fromString(body.sponsorId()));
        return Map.of("id", id.toString(), "title", body.title().trim());
    }

    private void guard(HttpServletRequest req) {
        String token = req.getHeader("X-Admin-Token");
        if (token == null || !token.equals(adminToken)) {
            throw new ForbiddenException();
        }
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
