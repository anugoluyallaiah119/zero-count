package com.zerocount.server.auth;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Persistence for users + statistics rows created on first login (E2.3),
 * using JdbcTemplate directly — no ORM magic, SQL stays explicit and auditable
 * (standards §2.2).
 */
@Repository
public class UserRepository {

    private final JdbcTemplate jdbc;

    public UserRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record UserRow(UUID id, String phone, String name, String avatar) {}

    public Optional<UserRow> findByPhone(String phone) {
        return jdbc.query(
                "SELECT id, phone, name, avatar FROM users WHERE phone = ?",
                (rs, i) -> new UserRow(
                    rs.getObject("id", UUID.class), rs.getString("phone"),
                    rs.getString("name"), rs.getString("avatar")),
                phone)
            .stream().findFirst();
    }

    /** Create user + empty statistics row atomically (same connection/tx from caller). */
    public UserRow create(String phone) {
        UUID id = jdbc.queryForObject(
            "INSERT INTO users (phone) VALUES (?) RETURNING id", UUID.class, phone);
        jdbc.update("INSERT INTO statistics (user_id) VALUES (?)", id);
        return new UserRow(id, phone, null, null);
    }

    public Optional<UserRow> findById(UUID id) {
        return jdbc.query(
                "SELECT id, phone, name, avatar FROM users WHERE id = ?",
                (rs, i) -> new UserRow(
                    rs.getObject("id", UUID.class), rs.getString("phone"),
                    rs.getString("name"), rs.getString("avatar")),
                id)
            .stream().findFirst();
    }

    // Timestamp helper kept explicit for readers of the SQL call-sites.
    static Timestamp ts(Instant i) {
        return Timestamp.from(i);
    }
}
