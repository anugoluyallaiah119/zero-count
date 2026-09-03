package com.zerocount.server.auth;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Refresh-token persistence (E2.3). Stores ONLY SHA-256 hashes — a database
 * leak never exposes a usable token (standards §3.3).
 */
@Repository
public class RefreshTokenRepository {

    private final JdbcTemplate jdbc;

    public RefreshTokenRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record TokenRow(UUID id, UUID userId, Instant expiresAt) {}

    public static String sha256Hex(String raw) {
        try {
            return HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(raw.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    public void insert(UUID userId, String rawToken, Instant expiresAt) {
        jdbc.update(
            "INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES (?, ?, ?)",
            userId, sha256Hex(rawToken), UserRepository.ts(expiresAt));
    }

    /** Find an ACTIVE (non-revoked, non-expired) token by its raw value. */
    public Optional<TokenRow> findActive(String rawToken) {
        return jdbc.query(
                "SELECT id, user_id, expires_at FROM refresh_tokens "
                + "WHERE token_hash = ? AND revoked_at IS NULL AND expires_at > now()",
                (rs, i) -> new TokenRow(
                    rs.getObject("id", UUID.class),
                    rs.getObject("user_id", UUID.class),
                    rs.getTimestamp("expires_at").toInstant()),
                sha256Hex(rawToken))
            .stream().findFirst();
    }

    /** Rotation: the presented token is consumed exactly once. */
    public void revoke(UUID id) {
        jdbc.update("UPDATE refresh_tokens SET revoked_at = now() WHERE id = ? AND revoked_at IS NULL", id);
    }
}
