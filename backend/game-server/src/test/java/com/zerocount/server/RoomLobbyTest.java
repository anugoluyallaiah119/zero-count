package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

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
 * E2.5 acceptance: room create/join/ready/leave lifecycle over HTTP with the
 * in-memory store (dev default), behind Bearer auth.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class RoomLobbyTest extends EmbeddedPostgresSupport {

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate rest;

    private String url(String path) {
        return "http://localhost:" + port + path;
    }

    @SuppressWarnings("unchecked")
    private String freshAccessToken(String phone, String name) {
        Map<String, String> r1 = rest.postForEntity(url("/api/auth/otp/request"),
            Map.of("phone", phone), Map.class).getBody();
        Map<String, Object> v = rest.postForEntity(url("/api/auth/otp/verify"),
            Map.of("session", r1.get("session"), "code", "123456"), Map.class).getBody();
        String token = (String) v.get("accessToken");
        rest.exchange(url("/api/players/me"), HttpMethod.PATCH,
            new HttpEntity<>(Map.of("name", name), bearer(token)), Map.class);
        return token;
    }

    private HttpHeaders bearer(String token) {
        HttpHeaders h = new HttpHeaders();
        h.setBearerAuth(token);
        h.setContentType(MediaType.APPLICATION_JSON);
        return h;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> createRoom(String token, int maxPlayers) {
        ResponseEntity<Map> r = rest.exchange(url("/api/rooms"), HttpMethod.POST,
            new HttpEntity<>(Map.of("maxPlayers", maxPlayers, "handSize", 7, "target", 100),
                bearer(token)), Map.class);
        assertThat(r.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return r.getBody();
    }

    @Test
    @SuppressWarnings("unchecked")
    void fullLobbyLifecycle() {
        String host = freshAccessToken("+919200000001", "Host");
        String guest = freshAccessToken("+919200000002", "Guest");

        // 1. Create: 6-char unambiguous code, host is first member
        Map<String, Object> room = createRoom(host, 2);
        String code = (String) room.get("code");
        assertThat(code).hasSize(6).matches("[A-HJ-NP-Z2-9]+");
        assertThat(room.get("startable")).isEqualTo(false);

        // 2. Guest joins with their profile name
        Map<String, Object> afterJoin = rest.exchange(url("/api/rooms/" + code + "/join"),
            HttpMethod.POST, new HttpEntity<>(bearer(guest)), Map.class).getBody();
        List<Map<String, Object>> members = (List<Map<String, Object>>) afterJoin.get("members");
        assertThat(members).hasSize(2);
        assertThat(members.get(0).get("host")).isEqualTo(true);
        assertThat(members.get(1).get("name")).isEqualTo("Guest");
        assertThat(afterJoin.get("full")).isEqualTo(true);

        // 3. Room full → a third player is rejected
        String third = freshAccessToken("+919200000003", "Third");
        ResponseEntity<Map> full = rest.exchange(url("/api/rooms/" + code + "/join"),
            HttpMethod.POST, new HttpEntity<>(bearer(third)), Map.class);
        assertThat(full.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // 4. Both ready → startable
        rest.exchange(url("/api/rooms/" + code + "/ready"), HttpMethod.POST,
            new HttpEntity<>(Map.of("ready", true), bearer(host)), Map.class);
        Map<String, Object> started = rest.exchange(url("/api/rooms/" + code + "/ready"),
            HttpMethod.POST, new HttpEntity<>(Map.of("ready", true), bearer(guest)), Map.class)
            .getBody();
        assertThat(started.get("startable")).isEqualTo(true);

        // 5. Host leaves → host transfers to the remaining member
        Map<String, Object> afterLeave = rest.exchange(url("/api/rooms/" + code + "/leave"),
            HttpMethod.POST, new HttpEntity<>(bearer(host)), Map.class).getBody();
        List<Map<String, Object>> remaining =
            (List<Map<String, Object>>) afterLeave.get("members");
        assertThat(remaining).hasSize(1);
        assertThat(remaining.get(0).get("host")).isEqualTo(true);
        assertThat(remaining.get(0).get("name")).isEqualTo("Guest");

        // 6. Last member leaves → room is deleted (204), then GET → 404
        ResponseEntity<Map> last = rest.exchange(url("/api/rooms/" + code + "/leave"),
            HttpMethod.POST, new HttpEntity<>(bearer(guest)), Map.class);
        assertThat(last.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        ResponseEntity<Map> gone = rest.exchange(url("/api/rooms/" + code),
            HttpMethod.GET, new HttpEntity<>(bearer(guest)), Map.class);
        assertThat(gone.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void unknownRoomIs404AndUnauthIs401() {
        String token = freshAccessToken("+919200000004", "Solo");
        ResponseEntity<Map> r = rest.exchange(url("/api/rooms/ZZZZZZ/join"),
            HttpMethod.POST, new HttpEntity<>(bearer(token)), Map.class);
        assertThat(r.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        ResponseEntity<String> noAuth = rest.postForEntity(url("/api/rooms"),
            Map.of("maxPlayers", 2, "handSize", 7, "target", 100), String.class);
        assertThat(noAuth.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void invalidSettingsRejected() {
        String token = freshAccessToken("+919200000005", "Cfg");
        ResponseEntity<Map> r = rest.exchange(url("/api/rooms"), HttpMethod.POST,
            new HttpEntity<>(Map.of("maxPlayers", 9, "handSize", 7, "target", 100),
                bearer(token)), Map.class);
        assertThat(r.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
