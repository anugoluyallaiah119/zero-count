package com.zerocount.server.admin;

import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Internal admin endpoints — protected by ADMIN role (checked in WebConfig).
 *
 * GET /api/admin/adaptive-cohort
 *   Returns a per-user breakdown of the adaptive draw A/B cohorts so the
 *   product team can see which rules are firing and correlate with retention.
 *
 *   Response: list of {userId, cohort, matchesPlayed, avgShowCount,
 *             dryDrawRate, specialUsageRate, adaptiveEnabled}
 */
@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final JdbcTemplate db;

    public AdminController(JdbcTemplate db) {
        this.db = db;
    }

    @GetMapping("/adaptive-cohort")
    public Map<String, Object> adaptiveCohort() {
        List<Map<String, Object>> rows = db.queryForList("""
            SELECT
                p.user_id,
                u.name,
                p.matches_played,
                p.avg_show_count,
                p.dry_draw_rate,
                p.special_usage_rate,
                CASE
                    WHEN p.matches_played < 5                    THEN 'new_user'
                    WHEN p.dry_draw_rate > 0.35                  THEN 'frustrated'
                    WHEN p.avg_show_count > 15                   THEN 'weak'
                    WHEN p.avg_show_count < 6
                         AND p.matches_played >= 20              THEN 'strong'
                    WHEN p.special_usage_rate < 0.3              THEN 'special_ignoring'
                    ELSE                                              'baseline'
                END AS cohort,
                p.updated_at
            FROM player_gameplay_profile p
            JOIN users u ON u.id = p.user_id
            ORDER BY p.updated_at DESC
            LIMIT 500
            """);

        // Aggregate counts per cohort for the summary header.
        Map<String, Long> summary = new java.util.LinkedHashMap<>();
        for (var row : rows) {
            String cohort = (String) row.get("cohort");
            summary.merge(cohort, 1L, Long::sum);
        }

        return Map.of(
            "total", rows.size(),
            "cohortSummary", summary,
            "users", rows
        );
    }

    @GetMapping("/iap-transactions")
    public List<Map<String, Object>> iapTransactions() {
        return db.queryForList("""
            SELECT t.id, t.user_id, u.name, t.type, t.amount, t.ref, t.ts
            FROM transactions t
            JOIN users u ON u.id = t.user_id
            WHERE t.type IN ('purchase', 'purchase_gems')
            ORDER BY t.ts DESC
            LIMIT 200
            """);
    }

    @GetMapping("/ad-rewards")
    public List<Map<String, Object>> adRewards() {
        return db.queryForList("""
            SELECT user_id, ads_today, coins_today
            FROM daily_ad_rewards
            ORDER BY coins_today DESC
            LIMIT 200
            """);
    }
}
