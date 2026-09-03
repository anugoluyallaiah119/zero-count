package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
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
 * L1.2 — load smoke (sandbox scale): 25 concurrent 2-player matches
 * (50 simultaneous STOMP connections + 50 users), each driven to
 * match_ended. Verifies the server sustains many parallel matches without
 * errors, and reports wall-clock throughput.
 *
 * The full 500-concurrent-match target needs staging hardware; this test
 * is the CI-feasible gate. Scaling note is recorded in the tracker.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class LoadSmokeTest extends EmbeddedPostgresSupport {

    private static final int MATCHES = Integer.parseInt(System.getProperty("load.matches", "25"));

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate rest;

    private String url(String path) {
        return "http://localhost:" + port + path;
    }

    private HttpHeaders bearer(String token) {
        HttpHeaders h = new HttpHeaders();
        h.setBearerAuth(token);
        h.setContentType(MediaType.APPLICATION_JSON);
        return h;
    }

    @SuppressWarnings("unchecked")
    private String freshAccessToken(String phone) {
        Map<String, String> r1 = rest.postForEntity(url("/api/auth/otp/request"),
            Map.of("phone", phone), Map.class).getBody();
        Map<String, Object> v = rest.postForEntity(url("/api/auth/otp/verify"),
            Map.of("session", r1.get("session"), "code", "123456"), Map.class).getBody();
        return (String) v.get("accessToken");
    }

    /** Minimal WS client for the load driver. */
    private static final class LClient {
        StompSession session;
        final int seat;
        final BlockingQueue<Map<String, Object>> topic = new LinkedBlockingQueue<>();
        final BlockingQueue<Map<String, Object>> hand = new LinkedBlockingQueue<>();

        LClient(int seat) { this.seat = seat; }

        void connect(int port, String code, String token) throws Exception {
            WebSocketStompClient ws =
                new WebSocketStompClient(new StandardWebSocketClient());
            ws.setMessageConverter(new MappingJackson2MessageConverter());
            StompHeaders h = new StompHeaders();
            h.add("Authorization", "Bearer " + token);
            session = ws.connectAsync("ws://localhost:" + port + "/ws",
                    new WebSocketHttpHeaders(), h, new StompSessionHandlerAdapter() {})
                .get(10, TimeUnit.SECONDS);
            session.subscribe("/topic/room." + code, new StompFrameHandler() {
                @Override
                public Type getPayloadType(StompHeaders sh) { return Map.class; }

                @Override
                @SuppressWarnings("unchecked")
                public void handleFrame(StompHeaders sh, Object payload) {
                    topic.offer((Map<String, Object>) payload);
                }
            });
            session.subscribe("/user/queue/errors", new StompFrameHandler() {
                @Override
                public Type getPayloadType(StompHeaders sh) { return Map.class; }

                @Override
                @SuppressWarnings("unchecked")
                public void handleFrame(StompHeaders sh, Object payload) {
                    System.out.println("LOAD seat" + seat + " error: " + payload);
                }
            });
            session.subscribe("/user/queue/hand", new StompFrameHandler() {
                @Override
                public Type getPayloadType(StompHeaders sh) { return Map.class; }

                @Override
                @SuppressWarnings("unchecked")
                public void handleFrame(StompHeaders sh, Object payload) {
                    hand.offer((Map<String, Object>) payload);
                }
            });
        }
    }

    /** Drive one 2-player match to completion on its own thread. */
    @SuppressWarnings("unchecked")
    private boolean runMatch(int idx) throws Exception {
        String t0 = freshAccessToken("+9198" + String.format("%06d", idx * 2));
        String t1 = freshAccessToken("+9198" + String.format("%06d", idx * 2 + 1));
        Map<String, Object> room = rest.exchange(url("/api/rooms"), HttpMethod.POST,
            new HttpEntity<>(Map.of("maxPlayers", 2, "handSize", 7, "target", 100),
                bearer(t0)), Map.class).getBody();
        if (room == null || room.get("code") == null) {
            System.out.println("LOAD room creation failed for " + idx + ": " + room);
            return false;
        }
        String code = (String) room.get("code");
        rest.exchange(url("/api/rooms/" + code + "/join"), HttpMethod.POST,
            new HttpEntity<>(Map.of(), bearer(t1)), Map.class);
        rest.exchange(url("/api/rooms/" + code + "/ready"), HttpMethod.POST,
            new HttpEntity<>(Map.of("ready", true), bearer(t0)), Map.class);
        rest.exchange(url("/api/rooms/" + code + "/ready"), HttpMethod.POST,
            new HttpEntity<>(Map.of("ready", true), bearer(t1)), Map.class);

        LClient a = new LClient(0), b = new LClient(1);
        a.connect(port, code, t0);
        b.connect(port, code, t1);
        a.session.send("/app/room/" + code + "/start", Map.of());

        long deadline = System.currentTimeMillis() + 180_000;
        while (System.currentTimeMillis() < deadline) {
            for (LClient c : new LClient[]{a, b}) {
                Map<String, Object> msg = c.topic.poll(80, TimeUnit.MILLISECONDS);
                if (msg == null) continue;
                if ("match_ended".equals(msg.get("type"))) {
                    a.session.disconnect();
                    b.session.disconnect();
                    return true;
                }
                if ("state".equals(msg.get("type"))) {
                    Map<String, Object> s = (Map<String, Object>) msg.get("state");
                    Object ci = s.get("currentPlayerIdx");
                    if (ci instanceof Number n && n.intValue() == c.seat) {
                        drive(code, c, (String) s.get("phase"));
                    }
                }
            }
        }
        System.out.println("LOAD match " + idx + " timed out; a-topic-pending="
            + a.topic.size() + " b-topic-pending=" + b.topic.size());
        a.session.disconnect();
        b.session.disconnect();
        return false;
    }

    @SuppressWarnings("unchecked")
    private void drive(String code, LClient c, String phase) throws Exception {
        switch (phase) {
            case "DRAW" -> c.session.send("/app/room/" + code + "/move",
                Map.of("type", "drawStock"));
            case "DISCARD" -> {
                Map<String, Object> hand = c.hand.poll(2, TimeUnit.SECONDS);
                Map<String, Object> newer;
                while (hand != null && (newer = c.hand.poll()) != null) hand = newer;
                if (hand == null) return;
                List<Map<String, Object>> cards =
                    (List<Map<String, Object>>) hand.get("hand");
                Map<String, Object> worst = cards.get(0);
                for (Map<String, Object> card : cards) {
                    if (((Number) card.get("value")).intValue()
                            > ((Number) worst.get("value")).intValue()) {
                        worst = card;
                    }
                }
                c.session.send("/app/room/" + code + "/move",
                    Map.of("type", "discard", "cardId", worst.get("id")));
            }
            case "POST" -> c.session.send("/app/room/" + code + "/move",
                Map.of("type", c.seat == 0 ? "show" : "endTurn"));
            default -> { }
        }
    }

    @Test
    void twentyFiveConcurrentMatches() throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(12);
        AtomicInteger completed = new AtomicInteger();
        AtomicInteger failed = new AtomicInteger();
        List<Throwable> errors = new CopyOnWriteArrayList<>();
        long start = System.currentTimeMillis();

        List<java.util.concurrent.Future<?>> futures = new ArrayList<>();
        for (int i = 0; i < MATCHES; i++) {
            final int idx = i;
            futures.add(pool.submit(() -> {
                try {
                    if (runMatch(idx)) completed.incrementAndGet();
                    else failed.incrementAndGet();
                } catch (Throwable t) {
                    failed.incrementAndGet();
                    errors.add(t);
                }
            }));
        }
        for (var f : futures) f.get(4, TimeUnit.MINUTES);
        pool.shutdownNow();

        long elapsed = System.currentTimeMillis() - start;
        System.out.printf("LOAD SMOKE: %d/%d matches completed in %d ms "
                + "(%d failed, %d errors)%n",
            completed.get(), MATCHES, elapsed, failed.get(), errors.size());
        errors.stream().limit(3).forEach(Throwable::printStackTrace);

        // Gate: at least 92% of matches finish (allows a couple of strays on
        // a loaded CI box), zero hard errors.
        assertThat(completed.get()).isGreaterThanOrEqualTo((int) (MATCHES * 0.92));
        assertThat(errors).isEmpty();
    }
}
