package com.zerocount.server.auth;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Dev-only OTP provider: no SMS leaves the building. Every phone accepts the
 * configured fixed code (default 123456). Sessions expire after 10 minutes.
 *
 * Activated when app.auth.provider=dev (the local default). NEVER enable in
 * production — application-prod.yml pins provider=firebase.
 */
@Component
@ConditionalOnProperty(name = "app.auth.provider", havingValue = "dev", matchIfMissing = true)
public class DevPhoneAuthProvider implements PhoneAuthProvider {

    private static final Duration SESSION_TTL = Duration.ofMinutes(10);

    private final String devCode;
    private final SecureRandom random = new SecureRandom();
    private final Map<String, Pending> sessions = new ConcurrentHashMap<>();

    private record Pending(String phone, Instant expiresAt) {}

    public DevPhoneAuthProvider(@Value("${app.auth.dev-code:123456}") String devCode) {
        this.devCode = devCode;
    }

    @Override
    public String startVerification(String phone) {
        byte[] sid = new byte[16];
        random.nextBytes(sid);
        String session = HexFormat.of().formatHex(sid);
        sessions.put(session, new Pending(phone, Instant.now().plus(SESSION_TTL)));
        return session;
    }

    @Override
    public String confirmVerification(String session, String code) {
        Pending p = sessions.remove(session); // single-use: one attempt consumes the session
        if (p == null) throw new OtpVerificationException("unknown or already-used session");
        if (Instant.now().isAfter(p.expiresAt())) throw new OtpVerificationException("session expired");
        if (!devCode.equals(code)) throw new OtpVerificationException("invalid code");
        return p.phone();
    }
}
