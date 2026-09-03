package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * E2.3 acceptance: full OTP auth flow over HTTP against real Postgres
 * (embedded) with the dev provider.
 *
 *   request OTP → verify (fixed dev code) → tokens → refresh rotation.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class AuthFlowTest extends EmbeddedPostgresSupport {

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate rest;

    @Autowired
    JdbcTemplate jdbc;

    private String url(String path) {
        return "http://localhost:" + port + path;
    }

    @Test
    @SuppressWarnings("unchecked")
    void fullOtpFlowRequestVerifyRefresh() {
        // 1. Request OTP
        ResponseEntity<Map> r1 = rest.postForEntity(url("/api/auth/otp/request"),
            Map.of("phone", "+91 98765 43210"), Map.class);
        assertThat(r1.getStatusCode()).isEqualTo(HttpStatus.OK);
        String session = (String) r1.getBody().get("session");
        assertThat(session).isNotBlank();

        // 2. Wrong code → 401, and the session is consumed (single-use)
        ResponseEntity<Map> bad = rest.postForEntity(url("/api/auth/otp/verify"),
            Map.of("session", session, "code", "000000"), Map.class);
        assertThat(bad.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<Map> r2 = rest.postForEntity(url("/api/auth/otp/request"),
            Map.of("phone", "+919876543210"), Map.class);
        String session2 = (String) r2.getBody().get("session");

        // 3. Correct code → token bundle; new user created in DB
        ResponseEntity<Map> v = rest.postForEntity(url("/api/auth/otp/verify"),
            Map.of("session", session2, "code", "123456"), Map.class);
        assertThat(v.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(v.getBody().get("accessToken")).isNotNull();
        assertThat(v.getBody().get("refreshToken")).isNotNull();
        assertThat(v.getBody().get("newUser")).isEqualTo(true);
        String userId = (String) v.getBody().get("userId");

        Integer userCount = jdbc.queryForObject(
            "SELECT count(*) FROM users WHERE phone = '+919876543210'", Integer.class);
        assertThat(userCount).isEqualTo(1);
        Integer statsCount = jdbc.queryForObject(
            "SELECT count(*) FROM statistics WHERE user_id = ?::uuid", Integer.class, userId);
        assertThat(statsCount).isEqualTo(1);

        // 4. Refresh rotation: new pair, old refresh token now dead
        String refresh1 = (String) v.getBody().get("refreshToken");
        ResponseEntity<Map> r3 = rest.postForEntity(url("/api/auth/refresh"),
            Map.of("refreshToken", refresh1), Map.class);
        assertThat(r3.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(r3.getBody().get("refreshToken")).isNotEqualTo(refresh1);

        ResponseEntity<Map> reuse = rest.postForEntity(url("/api/auth/refresh"),
            Map.of("refreshToken", refresh1), Map.class);
        assertThat(reuse.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // 5. Same phone verify again → existing user, not new
        String session3 = (String) rest.postForEntity(url("/api/auth/otp/request"),
            Map.of("phone", "+919876543210"), Map.class).getBody().get("session");
        ResponseEntity<Map> v2 = rest.postForEntity(url("/api/auth/otp/verify"),
            Map.of("session", session3, "code", "123456"), Map.class);
        assertThat(v2.getBody().get("newUser")).isEqualTo(false);
        assertThat(v2.getBody().get("userId")).isEqualTo(userId);
    }

    @Test
    void rejectsBadPhoneFormat() {
        ResponseEntity<Map> r = rest.postForEntity(url("/api/auth/otp/request"),
            Map.of("phone", "9876543210"), Map.class);
        assertThat(r.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
