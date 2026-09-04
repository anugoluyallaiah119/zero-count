package com.zerocount.server.contest;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.zerocount.server.player.AuthInterceptor;

/**
 * Contest endpoints (C1.1/C1.3, Bearer-guarded):
 *
 *   GET  /api/contests                      → live contests
 *   POST /api/contests/{id}/enter           → join (idempotent)
 *   GET  /api/contests/{id}/standings       → top 50 + my rank
 *   GET  /api/sponsors                      → public sponsor list (no auth)
 */
@RestController
@RequestMapping("/api/contests")
public class ContestController {

    private final ContestService contests;

    @GetMapping
    public List<Map<String, Object>> list() {
        return contests.listActive().stream().map(c -> {
            Map<String, Object> m = new java.util.LinkedHashMap<>(Map.of(
                "id", c.id().toString(),
                "title", c.title(),
                "startsAt", c.startsAt().toString(),
                "endsAt", c.endsAt().toString()));
            // C1.2: surface the sponsor when this is a sponsored event.
            String sponsor = sponsorName(c.id());
            if (sponsor != null) m.put("sponsor", sponsor);
            return m;
        }).toList();
    }

    private final org.springframework.jdbc.core.JdbcTemplate db;

    public ContestController(ContestService contests,
                             org.springframework.jdbc.core.JdbcTemplate db) {
        this.contests = contests;
        this.db = db;
    }


    private String sponsorName(UUID contestId) {
        List<String> s = db.queryForList(
            "SELECT sp.name FROM contests c JOIN sponsors sp "
                + "ON sp.id = c.sponsor_id WHERE c.id = ?", String.class, contestId);
        return s.isEmpty() ? null : s.get(0);
    }

    /** Public — no Bearer token required; sponsors are display-only data. */
    @GetMapping("/sponsors")
    public List<Map<String, Object>> publicSponsors() {
        return db.queryForList(
            "SELECT id, name, logo_url, site_url FROM sponsors ORDER BY name");
    }

    @PostMapping("/{id}/enter")
    public Map<String, Object> enter(@PathVariable UUID id, HttpServletRequest req) {
        contests.enter(id, AuthInterceptor.currentUserId(req));
        return Map.of("entered", true);
    }

    @GetMapping("/{id}/standings")
    public Map<String, Object> standings(@PathVariable UUID id, HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        List<ContestService.Standing> top = contests.standings(id, 50);
        Integer myRank = top.stream()
            .filter(s -> s.userId().equals(userId))
            .map(ContestService.Standing::rank).findFirst().orElse(null);
        return Map.of(
            "standings", top.stream().map(s -> Map.<String, Object>of(
                "userId", s.userId().toString(),
                "score", s.score(),
                "rank", s.rank())).toList(),
            "myRank", myRank == null ? -1 : myRank);
    }
}
