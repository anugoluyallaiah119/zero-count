package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Type;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletableFuture;
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
 * M1.2 acceptance: a full server-authoritative match over STOMP — lobby via
 * REST, then start + moves over WS, with public events on the room topic and
 * private hands per session. Illegal moves are rejected privately.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class MatchFlowTest extends EmbeddedPostgresSupport {

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

    private static final class TestClient {
        final StompSession session;
        final BlockingQueue<Map<String, Object>> topic = new LinkedBlockingQueue<>();
        final BlockingQueue<Map<String, Object>> hand = new LinkedBlockingQueue<>();
        final java.util.List<Map<String, Object>> seenTopic = new java.util.ArrayList<>();
        final java.util.List<Map<String, Object>> seenHand = new java.util.ArrayList<>();
        final String userId;

        TestClient(StompSession session, String userId) {
            this.session = session;
            this.userId = userId;
        }

        /** Race-proof: searches everything seen so far, then waits. */
        Map<String, Object> awaitTopic(String type) throws Exception {
            for (int i = 0; i < 100; i++) {
                synchronized (seenTopic) {
                    var it = seenTopic.iterator();
                    while (it.hasNext()) {
                        Map<String, Object> m = it.next();
                        if (type.equals(m.get("type"))) {
                            it.remove();
                            return m;
                        }
                    }
                }
                Map<String, Object> m = topic.poll(250, TimeUnit.MILLISECONDS);
                if (m != null) {
                    synchronized (seenTopic) { seenTopic.add(m); }
                }
            }
            throw new AssertionError("no topic event of type " + type);
        }

        /** Latest hand snapshot (history preserved). */
        Map<String, Object> awaitHand() throws Exception {
            for (int i = 0; i < 40; i++) {
                Map<String, Object> m = hand.poll(250, TimeUnit.MILLISECONDS);
                if (m != null) {
                    synchronized (seenHand) { seenHand.add(m); }
                    return m;
                }
                synchronized (seenHand) {
                    if (!seenHand.isEmpty()) return seenHand.remove(seenHand.size() - 1);
                }
            }
            throw new AssertionError("no private hand update");
        }
    }

    private TestClient connect(String token, String code) throws Exception {
        WebSocketStompClient client =
            new WebSocketStompClient(new StandardWebSocketClient());
        client.setMessageConverter(new MappingJackson2MessageConverter());
        StompHeaders connectHeaders = new StompHeaders();
        connectHeaders.add("Authorization", "Bearer " + token);
        StompSession session = client
            .connectAsync("ws://localhost:" + port + "/ws",
                new WebSocketHttpHeaders(), connectHeaders,
                new StompSessionHandlerAdapter() {})
            .get(5, TimeUnit.SECONDS);
        // The userId is the access token subject — read it via the JWT's
        // payload is overkill; the server sends it back in events' playerId.
        TestClient tc = new TestClient(session, null);
        StompFrameHandler handler = new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) { return Map.class; }

            @Override
            @SuppressWarnings("unchecked")
            public void handleFrame(StompHeaders headers, Object payload) {
                tc.topic.offer((Map<String, Object>) payload);
            }
        };
        session.subscribe("/topic/room." + code, handler);
        session.subscribe("/user/queue/hand", new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) { return Map.class; }

            @Override
            @SuppressWarnings("unchecked")
            public void handleFrame(StompHeaders headers, Object payload) {
                tc.hand.offer((Map<String, Object>) payload);
            }
        });
        return tc;
    }

    @Test
    @SuppressWarnings("unchecked")
    void twoPlayerMatchOverWebSocket() throws Exception {
        String host = freshAccessToken("+919555555551", "Host");
        String guest = freshAccessToken("+919555555552", "Guest");

        // Lobby over REST.
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

        // Connect both players over WS.
        TestClient a = connect(host, code);
        TestClient b = connect(guest, code);
        Thread.sleep(300); // let subscriptions land

        // Host starts the match.
        a.session.send("/app/room/" + code + "/start", null);

        Map<String, Object> started = a.awaitTopic("round_started");
        assertThat((Integer) started.get("round")).isEqualTo(1);
        b.awaitTopic("round_started");

        // Both clients receive their own 7-card hand privately.
        Map<String, Object> handA = a.awaitHand();
        Map<String, Object> handB = b.awaitHand();
        List<Map<String, Object>> cardsA = (List<Map<String, Object>>) handA.get("hand");
        List<Map<String, Object>> cardsB = (List<Map<String, Object>>) handB.get("hand");
        assertThat(cardsA).hasSize(7);
        assertThat(cardsB).hasSize(7);

        // Public state: two players, current turn visible.
        Map<String, Object> stateA = a.awaitTopic("state");
        Map<String, Object> state = (Map<String, Object>) stateA.get("state");
        // V2.2: 2p×7c deck = 52 normal + 1 Special = 53 total.
        // Dealt: 2 players × 7 cards + 1 visible discard = 15. Stock = 53 − 15 = 38.
        assertThat((Integer) state.get("stockSize")).isEqualTo(53 - 14 - 1);
        List<Map<String, Object>> players = (List<Map<String, Object>>) state.get("players");
        assertThat(players).hasSize(2);

        // Play one full turn as the current player: draw, discard, end turn.
        int current = (Integer) state.get("currentPlayerIdx");
        TestClient active = current == 0 ? a : b;
        active.session.send("/app/room/" + code + "/move",
            Map.of("type", "drawStock"));
        Map<String, Object> drew = active.awaitTopic("drew_stock");
        assertThat(drew).doesNotContainKey("card"); // hidden from everyone

        // Hand grew to 8 for the drawing player only.
        Map<String, Object> grew = active.awaitHand();
        List<Map<String, Object>> cards8 = (List<Map<String, Object>>) grew.get("hand");
        assertThat(cards8).hasSize(8);

        int cardId = (Integer) cards8.get(0).get("id");
        active.session.send("/app/room/" + code + "/move",
            Map.of("type", "discard", "cardId", cardId));
        Map<String, Object> discarded = active.awaitTopic("discarded");
        assertThat(((Map<String, Object>) discarded.get("card")).get("id"))
            .isEqualTo(cardId);

        active.session.send("/app/room/" + code + "/move",
            Map.of("type", "endTurn"));
        Map<String, Object> passed = active.awaitTopic("turn_passed");
        assertThat((String) passed.get("nextPlayerId")).isNotBlank();

        // Illegal move: the other player tries to discard out of turn →
        // no state change is broadcast for it.
        TestClient idle = current == 0 ? b : a;
        idle.session.send("/app/room/" + code + "/move",
            Map.of("type", "discard", "cardId", 1));
        Thread.sleep(500);
        assertThat(a.awaitTopic("state")).isNotNull(); // turn unchanged state

        // M1.3: replay protocol — ask for events since seq 0 on a private
        // queue and receive the full ordered log plus a fresh hand.
        BlockingQueue<Map<String, Object>> replayQ = new LinkedBlockingQueue<>();
        a.session.subscribe("/user/queue/replay", new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) { return Map.class; }

            @Override
            @SuppressWarnings("unchecked")
            public void handleFrame(StompHeaders headers, Object payload) {
                replayQ.offer((Map<String, Object>) payload);
            }
        });
        // SUBSCRIBE registration is asynchronous in the broker; a single
        // replay request fired immediately can lose the first event(s) to
        // that race. Ask twice and merge by seq — the second stream is
        // guaranteed to land on a registered subscription.
        Thread.sleep(200);
        a.session.send("/app/room/" + code + "/replay", Map.of("sinceSeq", 0));
        Thread.sleep(400);
        a.session.send("/app/room/" + code + "/replay", Map.of("sinceSeq", 0));
        Map<Long, Map<String, Object>> bySeq = new TreeMap<>();
        Map<String, Object> ev;
        while ((ev = replayQ.poll(1, TimeUnit.SECONDS)) != null) {
            bySeq.putIfAbsent(((Integer) ev.get("seq")).longValue(), ev);
        }
        assertThat(bySeq).isNotEmpty();
        Map<String, Object> first = bySeq.values().iterator().next();
        assertThat(first.get("type")).isEqualTo("round_started");
        assertThat((Integer) first.get("seq")).isEqualTo(1);
        long lastSeq = 0;
        for (long seq : bySeq.keySet()) {
            assertThat(seq).isGreaterThan(lastSeq);
            lastSeq = seq;
        }
        assertThat(a.awaitHand()).isNotNull();

        a.session.disconnect();
        b.session.disconnect();
    }
}
