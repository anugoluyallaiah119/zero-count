package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

/**
 * E4.4 acceptance: analytics batch ingestion + summary dashboard behind
 * Bearer auth, with validation rejecting malformed events.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class AnalyticsPipelineTest extends EmbeddedPostgresSupport {

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate rest;

    private String url(String path) {
        return "http://localhost:" + port + path;
    }

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
    void ingestBatchAndReadSummary() {
        String token = freshAccessToken("+919222222222");
        String now = Instant.now().toString();

        // 1. Valid batch of two events → 202 accepted=2
        Map<String, Object> batch = Map.of("events", List.of(
            Map.of("name", "app_start", "ts", now, "props", Map.of("flavor", "dev")),
            Map.of("name", "login_success", "ts", now, "props", Map.of())));
        ResponseEntity<Map> ok = rest.exchange(url("/api/events"), HttpMethod.POST,
            new HttpEntity<>(batch, bearer(token)), Map.class);
        assertThat(ok.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(ok.getBody().get("accepted")).isEqualTo(2);

        // 2. Summary reflects the events
        ResponseEntity<Map> sum = rest.exchange(url("/api/analytics/summary"), HttpMethod.GET,
            new HttpEntity<>(bearer(token)), Map.class);
        assertThat(sum.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(((Number) sum.getBody().get("totalEvents")).longValue()).isGreaterThanOrEqualTo(2);
        assertThat(((Number) sum.getBody().get("activeUsers7d")).longValue()).isGreaterThanOrEqualTo(1);
        List<Map<String, Object>> byName = (List<Map<String, Object>>) sum.getBody().get("byName7d");
        assertThat(byName).anySatisfy(m -> {
            assertThat(m.get("name")).isEqualTo("app_start");
            assertThat(((Number) m.get("count")).longValue()).isGreaterThanOrEqualTo(1);
        });
    }

    @Test
    @SuppressWarnings("unchecked")
    void rejectsMalformedEvents() {
        String token = freshAccessToken("+919333333333");

        // Bad name (uppercase) → 400 with error message
        Map<String, Object> bad = Map.of("events", List.of(
            Map.of("name", "AppStart", "ts", Instant.now().toString())));
        ResponseEntity<Map> r1 = rest.exchange(url("/api/events"), HttpMethod.POST,
            new HttpEntity<>(bad, bearer(token)), Map.class);
        assertThat(r1.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat((String) r1.getBody().get("error")).contains("name");

        // Empty batch → 400
        ResponseEntity<Map> r2 = rest.exchange(url("/api/events"), HttpMethod.POST,
            new HttpEntity<>(Map.of("events", List.of()), bearer(token)), Map.class);
        assertThat(r2.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void requiresAuth() {
        ResponseEntity<Map> r = rest.postForEntity(url("/api/events"),
            Map.of("events", List.of(Map.of("name", "app_start", "ts", Instant.now().toString()))),
            Map.class);
        assertThat(r.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
