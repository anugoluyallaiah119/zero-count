package com.zerocount.server.auth;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Auth orchestration (E2.3): OTP request/verify → find-or-create user →
 * issue access + refresh tokens → rotate on refresh.
 *
 * Phone format is validated fail-fast (E.164) before any provider call.
 */
@Service
public class AuthService {

    private static final java.util.regex.Pattern E164 =
        java.util.regex.Pattern.compile("^\\+[1-9]\\d{7,14}$");

    private final PhoneAuthProvider provider;
    private final UserRepository users;
    private final RefreshTokenRepository tokens;
    private final JwtService jwt;

    public AuthService(PhoneAuthProvider provider, UserRepository users,
                       RefreshTokenRepository tokens, JwtService jwt) {
        this.provider = provider;
        this.users = users;
        this.tokens = tokens;
        this.jwt = jwt;
    }

    public record TokenBundle(String accessToken, long accessExpiresInSec,
                              String refreshToken, UUID userId, boolean newUser) {}

    /** Step 1: request OTP. Returns the session handle for step 2. */
    public String requestOtp(String rawPhone) {
        String phone = normalizePhone(rawPhone);
        return provider.startVerification(phone);
    }

    /** Step 2: verify OTP, find-or-create the user, issue tokens. */
    @Transactional
    public TokenBundle verifyOtp(String session, String code) {
        String phone = provider.confirmVerification(session, code); // throws on failure
        var existing = users.findByPhone(phone);
        boolean newUser = existing.isEmpty();
        UserRepository.UserRow user = existing.orElseGet(() -> users.create(phone));
        return issue(user.id(), newUser);
    }

    /** Refresh rotation: validate, revoke the presented token, issue a new pair. */
    @Transactional
    public TokenBundle refresh(String rawRefreshToken) {
        var row = tokens.findActive(rawRefreshToken)
            .orElseThrow(() -> new JwtService.InvalidTokenException("refresh token not active"));
        tokens.revoke(row.id()); // single-use: reuse of an old token is detected as "not active"
        return issue(row.userId(), false);
    }

    private TokenBundle issue(UUID userId, boolean newUser) {
        String access = jwt.issueAccessToken(userId);
        String refresh = jwt.newRefreshToken();
        tokens.insert(userId, refresh, Instant.now().plus(jwt.refreshTtl()));
        return new TokenBundle(access, jwt.accessTtl().toSeconds(), refresh, userId, newUser);
    }

    private static String normalizePhone(String phone) {
        if (phone == null) throw new IllegalArgumentException("phone is required");
        String p = phone.trim().replaceAll("[\\s()-]", "");
        if (!E164.matcher(p).matches()) {
            throw new IllegalArgumentException("phone must be E.164 (e.g. +919876543210)");
        }
        return p;
    }
}
