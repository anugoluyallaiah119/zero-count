package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import io.zonky.test.db.postgres.embedded.EmbeddedPostgres;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Set;
import java.util.TreeSet;
import javax.sql.DataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;

/**
 * E2.2 — verifies V1__init_schema.sql against a REAL PostgreSQL instance
 * (embedded binaries, no Docker), exactly as production will run it.
 */
class FlywayMigrationTest {

    private static final Set<String> EXPECTED_TABLES = Set.of(
        "users", "games", "game_players", "rounds", "game_events", "statistics",
        "friendships", "achievements", "daily_challenges",
        "wallets", "transactions", "contests", "contest_entries",
        "refresh_tokens", "analytics_events",
        "daily_reward_claims", "daily_challenge_progress", "device_tokens",
        "notification_mutes", "notification_log", "shop_items", "owned_items", "sponsors"
    );

    @Test
    void migrationCreatesFullSchemaAndEnforcesAppendOnly() throws Exception {
        try (EmbeddedPostgres pg = EmbeddedPostgres.start()) {
            DataSource ds = pg.getPostgresDatabase();
            Flyway flyway = Flyway.configure().dataSource(ds).load();
            int applied = flyway.migrate().migrationsExecuted;
            assertThat(applied).isEqualTo(5);

            try (Connection c = ds.getConnection()) {
                // 1. All 15 tables exist (flyway_schema_history is Flyway's own).
                Set<String> tables = new TreeSet<>();
                try (ResultSet rs = c.getMetaData().getTables(null, "public", "%", new String[]{"TABLE"})) {
                    while (rs.next()) tables.add(rs.getString("TABLE_NAME"));
                }
                assertThat(tables).containsAll(EXPECTED_TABLES);

                // 2. Sanity: insert a user and read it back.
                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO users (phone, name) VALUES ('+919000000001', 'Test') RETURNING id")) {
                    ResultSet rs = ps.executeQuery();
                    assertThat(rs.next()).isTrue();
                }

                // 3. Append-only enforcement: UPDATE on transactions must fail.
                try (PreparedStatement ins = c.prepareStatement(
                        "INSERT INTO transactions (user_id, type, amount) "
                        + "VALUES ((SELECT id FROM users LIMIT 1), 'seed', 100)")) {
                    ins.executeUpdate();
                }
                assertThatThrownBy(() -> {
                    try (PreparedStatement upd = c.prepareStatement("UPDATE transactions SET amount = 0")) {
                        upd.executeUpdate();
                    }
                }).hasMessageContaining("append-only");
                assertThatThrownBy(() -> {
                    try (PreparedStatement del = c.prepareStatement("DELETE FROM transactions")) {
                        del.executeUpdate();
                    }
                }).hasMessageContaining("append-only");

                // 4. Balance constraint: negative coins rejected.
                assertThatThrownBy(() -> {
                    try (PreparedStatement bad = c.prepareStatement(
                            "INSERT INTO users (phone, coins) VALUES ('+919000000002', -5)")) {
                        bad.executeUpdate();
                    }
                }).hasMessageContaining("users_coins_check");

                // 5. flyway_schema_history records a successful V1.
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT version, success FROM flyway_schema_history WHERE version = '1'")) {
                    ResultSet rs = ps.executeQuery();
                    assertThat(rs.next()).isTrue();
                    assertThat(rs.getBoolean("success")).isTrue();
                }
            }
        }
    }
}
