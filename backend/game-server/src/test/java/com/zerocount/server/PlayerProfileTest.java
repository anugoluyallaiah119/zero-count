package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

/**
 * E2.4 acceptance: profile read/update + stats read path behind Bearer auth.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class PlayerProfileTest extends EmbeddedPostgresSupport {

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate rest;

    private String url(String path) {
        return "http://localhost:" + port + path;
    }

    /** Run the dev OTP flow and return a valid access token for a fresh user. */
    @SuppressWarnings("unchecked")
    private String freshAccessToken(String phone) {
        Map<String, String> r1 = rest.postForEntity(url("/api/auth/otp/request"),
            Map.of("phone", phone), Map.class).getBody();
        Map<String, Object> v = rest.postForEntity(url("/api/auth/otp/verify"),
            Map.of("session", r1.get("session"), "code", "123456"), Map.class).getBody();
        return (String) v.get("accessToken");
    }

    private HttpHeaders bearer(String token) {
        HttpHeaders h = new HttpHeaders();
        h.setBearerAuth(token);
        h.setContentType(MediaType.APPLICATION_JSON);
        return h;
    }

    @Test
    @SuppressWarnings("unchecked")
    void profileReadUpdateAndStats() {
        String token = freshAccessToken("+919111111111");

        // 1. GET me → profile + freshly-initialized zero stats
        ResponseEntity<Map> me = rest.exchange(url("/api/players/me"), HttpMethod.GET,
            new HttpEntity<>(bearer(token)), Map.class);
        assertThat(me.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map<String, Object> body = me.getBody();
        assertThat((String) body.get("phone")).startsWith("+919").endsWith("11").doesNotContain("8765432");
        Map<String, Object> stats = (Map<String, Object>) body.get("stats");
        assertThat(stats.get("matches")).isEqualTo(0);
        assertThat(stats.get("elo")).isEqualTo(1200);
        assertThat(stats.get("bestCount")).isEqualTo(-1); // never showed yet

        // 2. PATCH name + avatar
        ResponseEntity<Map> patched = rest.exchange(url("/api/players/me"), HttpMethod.PATCH,
            new HttpEntity<>(Map.of("name", "Meera", "avatar", "mascot-fox"), bearer(token)),
            Map.class);
        assertThat(patched.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(patched.getBody().get("name")).isEqualTo("Meera");
        assertThat(patched.getBody().get("avatar")).isEqualTo("mascot-fox");

        // 3. Partial PATCH: avatar only, name preserved
        ResponseEntity<Map> partial = rest.exchange(url("/api/players/me"), HttpMethod.PATCH,
            new HttpEntity<>(Map.of("avatar", "mascot-owl"), bearer(token)), Map.class);
        assertThat(partial.getBody().get("name")).isEqualTo("Meera");
        assertThat(partial.getBody().get("avatar")).isEqualTo("mascot-owl");

        // 4. Invalid name → 400
        ResponseEntity<Map> bad = rest.exchange(url("/api/players/me"), HttpMethod.PATCH,
            new HttpEntity<>(Map.of("name", ""), bearer(token)), Map.class);
        assertThat(bad.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void rejectsUnauthenticated() {
        // no token at all
        ResponseEntity<String> r1 = rest.getForEntity(url("/api/players/me"), String.class);
        assertThat(r1.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // garbage token
        ResponseEntity<String> r2 = rest.exchange(url("/api/players/me"), HttpMethod.GET,
            new HttpEntity<>(bearer("not-a-real-token")), String.class);
        assertThat(r2.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
