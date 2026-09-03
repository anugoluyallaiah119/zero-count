package com.zerocount.server.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Issues and validates Zero Count tokens (E2.3).
 *
 * Access token: HS256 JWT, short-lived (default 15 min), sub = user id.
 * Refresh token: 256-bit opaque random string — NOT a JWT. Only its SHA-256
 * hash is stored (RefreshTokenRepository); rotation revokes the predecessor.
 *
 * The signing secret comes from JWT_SECRET (never hardcoded, standards §3.1).
 * If unset in a dev profile, an ephemeral random secret is generated and a
 * loud warning is logged — tokens simply stop validating across restarts.
 */
@Service
public class JwtService {

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);

    private final SecretKey key;
    private final Duration accessTtl;
    private final Duration refreshTtl;
    private final SecureRandom random = new SecureRandom();

    public JwtService(
            @Value("${app.auth.jwt-secret:}") String secret,
            @Value("${app.auth.access-ttl-minutes:15}") long accessTtlMinutes,
            @Value("${app.auth.refresh-ttl-days:7}") long refreshTtlDays) {
        if (secret == null || secret.isBlank()) {
            log.warn("JWT_SECRET is not set — generating an ephemeral dev secret. "
                + "All tokens invalidate on restart. Set JWT_SECRET in any real environment.");
            byte[] k = new byte[32];
            new SecureRandom().nextBytes(k);
            this.key = Keys.hmacShaKeyFor(k);
        } else {
            byte[] raw = secret.getBytes(StandardCharsets.UTF_8);
            if (raw.length < 32) {
                // Fail fast: a short secret weakens HS256 (standards §3.1).
                throw new IllegalStateException("JWT_SECRET must be at least 32 bytes");
            }
            this.key = Keys.hmacShaKeyFor(raw);
        }
        this.accessTtl = Duration.ofMinutes(accessTtlMinutes);
        this.refreshTtl = Duration.ofDays(refreshTtlDays);
    }

    public String issueAccessToken(UUID userId) {
        Instant now = Instant.now();
        return Jwts.builder()
            .subject(userId.toString())
            .issuedAt(Date.from(now))
            .expiration(Date.from(now.plus(accessTtl)))
            .claim("typ", "access")
            .signWith(key)
            .compact();
    }

    /** Validate an access token; return the user id it belongs to. */
    public UUID validateAccessToken(String token) {
        try {
            Claims c = Jwts.parser().verifyWith(key).build()
                .parseSignedClaims(token).getPayload();
            if (!"access".equals(c.get("typ"))) throw new JwtException("not an access token");
            return UUID.fromString(c.getSubject());
        } catch (JwtException | IllegalArgumentException e) {
            throw new InvalidTokenException("invalid or expired access token");
        }
    }

    /** New opaque refresh token (URL-safe, 43 chars). Hash it before storing. */
    public String newRefreshToken() {
        byte[] t = new byte[32];
        random.nextBytes(t);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(t);
    }

    public Duration accessTtl() { return accessTtl; }
    public Duration refreshTtl() { return refreshTtl; }

    /** Thrown when a presented token fails validation. */
    public static class InvalidTokenException extends RuntimeException {
        public InvalidTokenException(String message) { super(message); }
    }
}
