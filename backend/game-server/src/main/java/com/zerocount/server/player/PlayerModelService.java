package com.zerocount.server.player;

import com.zerocount.server.match.MatchHook;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * V2.2 Phase 3 — Player Model derivation.
 *
 * At the end of every match, rolls up the raw {@code gameplay.*} rows in
 * {@code analytics_events} into a compact per-user projection in
 * {@code player_gameplay_profile}. Phase 4 (adaptive draw brain / AI /
 * opening balancer) reads this projection to tune per-user weights.
 *
 * Only re-scans this match's window (last 24h) per seat to keep updates
 * O(events-per-match), not O(all-time-events).
 */
@Service
public class PlayerModelService implements MatchHook {

    private final JdbcTemplate db;

    public PlayerModelService(JdbcTemplate db) {
        this.db = db;
    }

    @Override
    @Transactional
    public void onMatchEnded(List<UUID> seats, int winnerIdx, List<Integer> totals) {
        for (UUID seat : seats) {
            db.update("INSERT INTO player_gameplay_profile (user_id) VALUES (?) "
                + "ON CONFLICT (user_id) DO NOTHING", seat);
            rebuild(seat);
        }
    }

    /** Recompute the projection for one user from recent gameplay events. */
    void rebuild(UUID userId) {
        // Aggregate this user's raw rows over a rolling 24h window. Larger
        // windows are unnecessary — the model reacts to *current* behaviour.
        Long stockDraws = db.queryForObject("""
            SELECT count(*)
              FROM analytics_events
             WHERE user_id = ? AND name = 'gameplay.draw_stock'
               AND received_at >= now() - interval '24 hours'
            """, Long.class, userId);

        Long dryDraws = db.queryForObject("""
            SELECT COALESCE(sum((props->>'dryStreak')::int > 0)::int, 0)
              FROM analytics_events
             WHERE user_id = ? AND name = 'gameplay.draw_stock'
               AND received_at >= now() - interval '24 hours'
            """, Long.class, userId);

        Long specialsExpired = db.queryForObject("""
            SELECT count(*)
              FROM analytics_events
             WHERE user_id = ? AND name = 'gameplay.special_expired'
               AND received_at >= now() - interval '24 hours'
            """, Long.class, userId);

        Long specialsSeen = db.queryForObject("""
            SELECT
              (SELECT count(*)
                 FROM analytics_events
                WHERE user_id = ? AND name = 'gameplay.draw_discard'
                  AND (props->>'wasSpecial')::boolean = true
                  AND received_at >= now() - interval '24 hours')
              +
              (SELECT count(*)
                 FROM analytics_events
                WHERE user_id = ? AND name = 'gameplay.draw_stock'
                  AND (props->>'wasSpecial')::boolean = true
                  AND received_at >= now() - interval '24 hours')
            """, Long.class, userId, userId);

        Long shows = db.queryForObject("""
            SELECT count(*)
              FROM analytics_events
             WHERE user_id = ? AND name = 'gameplay.show'
               AND received_at >= now() - interval '24 hours'
            """, Long.class, userId);

        // Average count-at-show is currently approximated from round totals —
        // Phase 3.1 will publish the exact SHOW-time count in the event payload.
        Double avgShowCount = db.queryForObject("""
            SELECT COALESCE(AVG((props->'totals'->0)::text::int), 0)::double precision
              FROM analytics_events
             WHERE user_id = ? AND name = 'gameplay.round_ended'
               AND received_at >= now() - interval '24 hours'
            """, Double.class, userId);

        Long matches = db.queryForObject("""
            SELECT count(*)
              FROM analytics_events
             WHERE user_id = ? AND name = 'gameplay.match_ended'
               AND received_at >= now() - interval '24 hours'
            """, Long.class, userId);

        long sd = zero(stockDraws), dd = zero(dryDraws);
        double dryRate = sd > 0 ? (double) dd / sd : 0.0;
        long ss = zero(specialsSeen), se = zero(specialsExpired);
        double specialUsage = ss > 0 ? Math.max(0.0, 1.0 - (double) se / ss) : 0.0;

        db.update("""
            UPDATE player_gameplay_profile
               SET matches_played       = ?,
                   total_stock_draws    = ?,
                   total_dry_draws      = ?,
                   total_special_expired= ?,
                   total_special_seen   = ?,
                   total_show_events    = ?,
                   avg_show_count       = ?,
                   dry_draw_rate        = ?,
                   special_usage_rate   = ?,
                   last_session_at      = now(),
                   updated_at           = now()
             WHERE user_id = ?
            """,
            zero(matches), sd, dd, se, ss, zero(shows),
            avgShowCount == null ? 0.0 : avgShowCount,
            dryRate, specialUsage, userId);
    }

    /** Snapshot for the adaptive layer to read. Returns defaults if absent. */
    public Snapshot snapshot(UUID userId) {
        return db.query("""
            SELECT matches_played, total_stock_draws, total_dry_draws,
                   avg_show_count, dry_draw_rate, special_usage_rate,
                   draw_look_ahead_boost, dry_pity_multiplier, opening_balancer_chance
              FROM player_gameplay_profile WHERE user_id = ?
            """,
            (rs, i) -> new Snapshot(
                rs.getInt("matches_played"),
                rs.getInt("total_stock_draws"),
                rs.getInt("total_dry_draws"),
                rs.getDouble("avg_show_count"),
                rs.getDouble("dry_draw_rate"),
                rs.getDouble("special_usage_rate"),
                (Integer) rs.getObject("draw_look_ahead_boost"),
                (Double) rs.getObject("dry_pity_multiplier"),
                (Double) rs.getObject("opening_balancer_chance")),
            userId)
            .stream().findFirst().orElse(Snapshot.defaults());
    }

    /** Phase-4-consumable projection. Nullable overrides mean "use engine default". */
    public record Snapshot(
        int matchesPlayed,
        int totalStockDraws,
        int totalDryDraws,
        double avgShowCount,
        double dryDrawRate,
        double specialUsageRate,
        Integer drawLookAheadBoost,
        Double dryPityMultiplier,
        Double openingBalancerChance) {

        public static Snapshot defaults() {
            return new Snapshot(0, 0, 0, 0, 0, 0, null, null, null);
        }
    }

    private static long zero(Long l) { return l == null ? 0 : l; }
}
