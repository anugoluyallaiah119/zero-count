package com.zerocount.server.analytics;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Analytics event store (E4.4). Explicit SQL via JdbcTemplate — append-only
 * writes into analytics_events, aggregate reads for the dashboard summary.
 */
@Repository
public class AnalyticsRepository {

    /** One validated event ready to insert. */
    public record Event(UUID userId, String name, String propsJson, Instant clientTs) {}

    public record NameCount(String name, long count) {}

    private final JdbcTemplate jdbc;

    public AnalyticsRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Batch-insert a client's event batch in a single round trip per event. */
    public void insertAll(List<Event> events) {
        jdbc.batchUpdate(
            "INSERT INTO analytics_events (user_id, name, props, client_ts) "
                + "VALUES (?, ?, ?::jsonb, ?)",
            events, events.size(),
            (ps, e) -> {
                if (e.userId() == null) {
                    ps.setObject(1, null);
                } else {
                    ps.setObject(1, e.userId());
                }
                ps.setString(2, e.name());
                ps.setString(3, e.propsJson());
                ps.setTimestamp(4, Timestamp.from(e.clientTs()));
            });
    }

    /** Distinct users with any event in the last {@code days} days (DAU/WAU-style). */
    public long activeUsers(int days) {
        Long n = jdbc.queryForObject(
            "SELECT count(DISTINCT user_id) FROM analytics_events "
                + "WHERE received_at >= now() - make_interval(days => ?)",
            Long.class, days);
        return n == null ? 0 : n;
    }

    /** Event totals grouped by name over the last {@code days} days. */
    public List<NameCount> countsByName(int days) {
        return jdbc.query(
            "SELECT name, count(*) AS c FROM analytics_events "
                + "WHERE received_at >= now() - make_interval(days => ?) "
                + "GROUP BY name ORDER BY c DESC",
            (rs, i) -> new NameCount(rs.getString("name"), rs.getLong("c")),
            days);
    }

    /** Daily event volume for the last {@code days} days (for the trend chart). */
    public List<NameCount> dailyVolume(int days) {
        return jdbc.query(
            "SELECT to_char(date_trunc('day', received_at), 'YYYY-MM-DD') AS d, count(*) AS c "
                + "FROM analytics_events "
                + "WHERE received_at >= now() - make_interval(days => ?) "
                + "GROUP BY 1 ORDER BY 1",
            (rs, i) -> new NameCount(rs.getString("d"), rs.getLong("c")),
            days);
    }

    public long totalEvents() {
        Long n = jdbc.queryForObject("SELECT count(*) FROM analytics_events", Long.class);
        return n == null ? 0 : n;
    }
}
