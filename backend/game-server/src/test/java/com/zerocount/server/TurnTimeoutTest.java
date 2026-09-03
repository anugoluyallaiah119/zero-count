package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Type;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.messaging.converter.MappingJackson2MessageConverter;
import org.springframework.messaging.simp.stomp.StompFrameHandler;
import org.springframework.messaging.simp.stomp.StompHeaders;
import org.springframework.messaging.simp.stomp.StompSession;
import org.springframework.messaging.simp.stomp.StompSessionHandlerAdapter;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;
import com.zerocount.server.match.MoveRateLimiter;

/**
 * M1.5 acceptance: turn timeout auto-moves an idle seat (2s test override),
 * and the rate limiter caps command flooding.
 */
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "app.match.turn-timeout-seconds=2")
class TurnTimeoutTest extends EmbeddedPostgresSupport {

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate rest;

    private String url(String path) {
        return "http://localhost:" + port + path;
    }

    @Test
    void rateLimiterCapsFlooding() {
        MoveRateLimiter limiter = new MoveRateLimiter();
        UUID user = UUID.randomUUID();
        for (int i = 0; i < MoveRateLimiter.MAX_COMMANDS; i++) {
            assertThat(limiter.allow(user)).isTrue();
        }
        assertThat(limiter.allow(user)).isFalse();
        assertThat(limiter.allow(user)).isFalse();
        // A different user is unaffected.
        assertThat(limiter.allow(UUID.randomUUID())).isTrue();
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

    @Test
    void idleTurnIsAutoPlayed() throws Exception {
        String host = freshAccessToken("+919777777771", "Host");
        String guest = freshAccessToken("+919777777772", "Guest");

        Map<String, Object> room = rest.exchange(url("/api/rooms"), HttpMethod.POST,
            new HttpEntity<>(Map.of("maxPlayers", 2, "handSize", 7, "target", 100),
                bearer(host)), Map.class).getBody();
        String code = (String) room.get("code");
        rest.exchange(url("/api/rooms/" + code + "/join"), HttpMethod.POST,
            new HttpEntity<>(Map.of(), bearer(guest)), Map.class);
        rest.exchange(url("/api/rooms/" + code + "/ready"), HttpMethod.POST,
            new HttpEntity<>(Map.of("ready", true), bearer(host)), Map.class);
        rest.exchange(url("/api/rooms/" + code + "/ready"), HttpMethod.POST,
            new HttpEntity<>(Map.of("ready", true), bearer(guest)), Map.class);

        WebSocketStompClient client =
            new WebSocketStompClient(new StandardWebSocketClient());
        client.setMessageConverter(new MappingJackson2MessageConverter());
        StompHeaders h = new StompHeaders();
        h.add("Authorization", "Bearer " + host);
        StompSession session = client
            .connectAsync("ws://localhost:" + port + "/ws",
                new WebSocketHttpHeaders(), h, new StompSessionHandlerAdapter() {})
            .get(5, TimeUnit.SECONDS);

        BlockingQueue<Map<String, Object>> topic = new LinkedBlockingQueue<>();
        session.subscribe("/topic/room." + code, new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) { return Map.class; }

            @Override
            @SuppressWarnings("unchecked")
            public void handleFrame(StompHeaders headers, Object payload) {
                topic.offer((Map<String, Object>) payload);
            }
        });
        Thread.sleep(300);

        session.send("/app/room/" + code + "/start", null);

        // Nobody moves. Within ~2s×3 the timeout should auto-play the first
        // turn: draw (drew_stock), discard (discarded), pass (turn_passed),
        // each announced with a turn_timeout marker.
        long deadline = System.currentTimeMillis() + 20_000;
        boolean sawDraw = false, sawDiscard = false, sawTimeout = false;
        while (System.currentTimeMillis() < deadline
            && !(sawDraw && sawDiscard && sawTimeout)) {
            Map<String, Object> m = topic.poll(500, TimeUnit.MILLISECONDS);
            if (m == null) continue;
            Object t = m.get("type");
            if ("drew_stock".equals(t) || "drew_discard".equals(t)) sawDraw = true;
            if ("discarded".equals(t)) sawDiscard = true;
            if ("turn_timeout".equals(t)) sawTimeout = true;
        }
        assertThat(sawDraw).as("timeout auto-draw").isTrue();
        assertThat(sawDiscard).as("timeout auto-discard").isTrue();
        assertThat(sawTimeout).as("turn_timeout announcement").isTrue();
        session.disconnect();
    }
}
