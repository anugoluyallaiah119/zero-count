package com.zerocount.server.user;

import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * User bootstrap: find-or-create by verified phone. Uses plain JDBC
 * (JdbcClient) — JPA arrives only if a later story proves the need.
 */
@Service
public class UserService {

    private final JdbcClient jdbc;

    public UserService(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public record BootstrapResult(UUID userId, boolean isNewUser) {}

    @Transactional
    public BootstrapResult findOrCreate(String phone) {
        var existing = jdbc.sql("SELECT id FROM users WHERE phone = :phone")
            .param("phone", phone)
            .query(UUID.class)
            .optional();
        if (existing.isPresent()) {
            return new BootstrapResult(existing.get(), false);
        }
        UUID id = jdbc.sql("INSERT INTO users (phone) VALUES (:phone) RETURNING id")
            .param("phone", phone)
            .query(UUID.class)
            .single();
        jdbc.sql("INSERT INTO statistics (user_id) VALUES (:id)")
            .param("id", id)
            .update();
        return new BootstrapResult(id, true);
    }
}
