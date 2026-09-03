package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Type;
import java.util.Map;
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

/**
 * M1.4 acceptance: dropping mid-match announces player_disconnected with a
 * 60s grace deadline; reconnecting announces player_reconnected and the
 * replay protocol resyncs state + private hand.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ReconnectGraceTest extends EmbeddedPostgresSupport {

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

    private StompSession connect(String token) throws Exception {
        WebSocketStompClient client =
            new WebSocketStompClient(new StandardWebSocketClient());
        client.setMessageConverter(new MappingJackson2MessageConverter());
        StompHeaders h = new StompHeaders();
        h.add("Authorization", "Bearer " + token);
        return client
            .connectAsync("ws://localhost:" + port + "/ws",
                new WebSocketHttpHeaders(), h, new StompSessionHandlerAdapter() {})
            .get(5, TimeUnit.SECONDS);
    }

    private void subscribe(StompSession session, String dest,
                           BlockingQueue<Map<String, Object>> out) {
        session.subscribe(dest, new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) { return Map.class; }

            @Override
            @SuppressWarnings("unchecked")
            public void handleFrame(StompHeaders headers, Object payload) {
                out.offer((Map<String, Object>) payload);
            }
        });
    }

    private final java.util.Map<BlockingQueue<Map<String, Object>>, java.util.List<Map<String, Object>>> seen =
        new java.util.concurrent.ConcurrentHashMap<>();

    private Map<String, Object> await(BlockingQueue<Map<String, Object>> q,
                                      String type) throws Exception {
        for (int i = 0; i < 100; i++) {
            var hist = seen.computeIfAbsent(q, k -> new java.util.ArrayList<>());
            synchronized (hist) {
                var it = hist.iterator();
                while (it.hasNext()) {
                    Map<String, Object> m = it.next();
                    if (type.equals(m.get("type"))) {
                        it.remove();
                        return m;
                    }
                }
            }
            Map<String, Object> m = q.poll(250, TimeUnit.MILLISECONDS);
            if (m != null) {
                synchronized (hist) { hist.add(m); }
            }
        }
        throw new AssertionError("no event of type " + type);
    }

    @Test
    @SuppressWarnings("unchecked")
    void disconnectGraceAndReconnectResync() throws Exception {
        String host = freshAccessToken("+919666666661", "Host");
        String guest = freshAccessToken("+919666666662", "Guest");

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

        StompSession a = connect(host);
        BlockingQueue<Map<String, Object>> topicA = new LinkedBlockingQueue<>();
        BlockingQueue<Map<String, Object>> handA = new LinkedBlockingQueue<>();
        subscribe(a, "/topic/room." + code, topicA);
        subscribe(a, "/user/queue/hand", handA);

        StompSession b = connect(guest);
        BlockingQueue<Map<String, Object>> topicB = new LinkedBlockingQueue<>();
        subscribe(b, "/topic/room." + code, topicB);
        Thread.sleep(300);

        a.send("/app/room/" + code + "/start", null);
        await(topicA, "round_started");
        await(topicB, "round_started");
        assertThat(handA.poll(5, TimeUnit.SECONDS)).isNotNull();

        // Guest drops (hard close — no STOMP DISCONNECT).
        b.disconnect();
        Map<String, Object> disc = await(topicA, "player_disconnected");
        assertThat((String) disc.get("graceEndsAt")).isNotBlank();

        // Guest reconnects with the same token inside the grace window.
        StompSession b2 = connect(guest);
        BlockingQueue<Map<String, Object>> topicB2 = new LinkedBlockingQueue<>();
        BlockingQueue<Map<String, Object>> handB2 = new LinkedBlockingQueue<>();
        BlockingQueue<Map<String, Object>> replayB = new LinkedBlockingQueue<>();
        subscribe(b2, "/topic/room." + code, topicB2);
        subscribe(b2, "/user/queue/hand", handB2);
        subscribe(b2, "/user/queue/replay", replayB);
        Thread.sleep(300);

        // The still-connected peer learns about the rebind. (The
        // reconnecting client's own announcement can race its topic
        // subscription — it resyncs via replay instead.)
        await(topicA, "player_reconnected");

        // Replay resyncs the reconnected client.
        b2.send("/app/room/" + code + "/replay", Map.of("sinceSeq", 0));
        Map<String, Object> first = replayB.poll(5, TimeUnit.SECONDS);
        assertThat(first).isNotNull();
        assertThat(first.get("type")).isEqualTo("round_started");
        Map<String, Object> hand = handB2.poll(5, TimeUnit.SECONDS);
        assertThat(hand).isNotNull();
        assertThat((java.util.List<?>) hand.get("hand")).hasSize(7);

        a.disconnect();
        b2.disconnect();
    }
}
