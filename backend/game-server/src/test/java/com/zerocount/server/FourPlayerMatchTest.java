package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CopyOnWriteArrayList;
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
 * M1.9 — E2E: a FULL 4-player match over WebSocket, including a mid-match
 * kill-app rejoin (disconnect → grace → reconnect → replay resync).
 *
 * Real devices aren't available in CI; this drives four real STOMP clients
 * through the same protocol the Flutter app speaks: lobby over REST, moves
 * over /app, state over the room topic, private hands on /user/queue/hand,
 * replay on /user/queue/replay. A background driver plays every client's
 * turns until the engine emits match_ended.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class FourPlayerMatchTest extends EmbeddedPostgresSupport {

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

    private static final class Client {
        volatile StompSession session;
        final String token;
        final int seat;
        final BlockingQueue<Map<String, Object>> topic = new LinkedBlockingQueue<>();
        final BlockingQueue<Map<String, Object>> hand = new LinkedBlockingQueue<>();
        final List<Map<String, Object>> seenTopic = new CopyOnWriteArrayList<>();
        volatile boolean stop;
        volatile boolean showedOnce;

        Client(String token, int seat) {
            this.token = token;
            this.seat = seat;
        }

        void connect(int port, String code) throws Exception {
            WebSocketStompClient ws =
                new WebSocketStompClient(new StandardWebSocketClient());
            ws.setMessageConverter(new MappingJackson2MessageConverter());
            StompHeaders headers = new StompHeaders();
            headers.add("Authorization", "Bearer " + token);
            session = ws.connectAsync("ws://localhost:" + port + "/ws",
                    new WebSocketHttpHeaders(), headers,
                    new StompSessionHandlerAdapter() {})
                .get(5, TimeUnit.SECONDS);
            session.subscribe("/topic/room." + code, new StompFrameHandler() {
                @Override
                public Type getPayloadType(StompHeaders h) { return Map.class; }

                @Override
                @SuppressWarnings("unchecked")
                public void handleFrame(StompHeaders h, Object payload) {
                    topic.offer((Map<String, Object>) payload);
                    seenTopic.add((Map<String, Object>) payload);
                }
            });
            session.subscribe("/user/queue/hand", new StompFrameHandler() {
                @Override
                public Type getPayloadType(StompHeaders h) { return Map.class; }

                @Override
                @SuppressWarnings("unchecked")
                public void handleFrame(StompHeaders h, Object payload) {
                    hand.offer((Map<String, Object>) payload);
                }
            });
            session.subscribe("/user/queue/replay", new StompFrameHandler() {
                @Override
                public Type getPayloadType(StompHeaders h) { return Map.class; }

                @Override
                public void handleFrame(StompHeaders h, Object payload) {
                    // resync stream — the hand snapshot that follows is the
                    // authoritative state
                }
            });
        }

    }

    @Test
    @SuppressWarnings("unchecked")
    void fourPlayerFullMatchWithKillAndRejoin() throws Exception {
        String[] tokens = new String[4];
        for (int i = 0; i < 4; i++) {
            tokens[i] = freshAccessToken("+91970000000" + i, "P" + i);
        }

        // Lobby: host creates, three join, everyone readies.
        Map<String, Object> room = rest.exchange(url("/api/rooms"), HttpMethod.POST,
            new HttpEntity<>(Map.of("maxPlayers", 4, "handSize", 7, "target", 100),
                bearer(tokens[0])), Map.class).getBody();
        String code = (String) room.get("code");
        for (int i = 1; i < 4; i++) {
            rest.exchange(url("/api/rooms/" + code + "/join"), HttpMethod.POST,
                new HttpEntity<>(Map.of(), bearer(tokens[i])), Map.class);
        }
        for (int i = 0; i < 4; i++) {
            rest.exchange(url("/api/rooms/" + code + "/ready"), HttpMethod.POST,
                new HttpEntity<>(Map.of("ready", true), bearer(tokens[i])), Map.class);
        }

        // Connect four real STOMP clients.
        Client[] clients = new Client[4];
        for (int i = 0; i < 4; i++) {
            clients[i] = new Client(tokens[i], i);
            clients[i].connect(port, code);
        }
        Thread.sleep(300);

        // Host starts.
        clients[0].session.send("/app/room/" + code + "/start", Map.of());

        // Driver: react to every state broadcast until match_ended.
        long deadline = System.currentTimeMillis() + 90_000;
        boolean[] rejoined = {false};
        boolean ended = false;
        while (System.currentTimeMillis() < deadline && !ended) {
            for (Client c : clients) {
                Map<String, Object> msg = c.topic.poll(100, TimeUnit.MILLISECONDS);
                if (msg == null) continue;
                String type = (String) msg.get("type");
                if ("match_ended".equals(type)) { ended = true; break; }
                if ("state".equals(type)) {
                    Map<String, Object> s = (Map<String, Object>) msg.get("state");
                    Object idx = s.get("currentPlayerIdx");
                    String phase = (String) s.get("phase");
                    if (idx instanceof Number n && n.intValue() == c.seat
                            && c.session != null && c.session.isConnected()) {
                        drive(code, c, phase);
                    }
                }
            }
            // Mid-match: kill player 2's app once the game is underway.
            if (!rejoined[0] && clients[0].seenTopic.stream()
                    .anyMatch(m -> "round_started".equals(m.get("type")))) {
                rejoined[0] = true;
                clients[2].session.disconnect();
                Thread.sleep(400);
                boolean announced = clients[0].seenTopic.stream()
                    .anyMatch(m -> "player_disconnected".equals(m.get("type")))
                    || waitFor(clients[0], "player_disconnected", 3000);
                assertThat(announced).as("disconnect announced").isTrue();
                // Rejoin: new connection + replay resync + fresh hand.
                clients[2].connect(port, code);
                Thread.sleep(300);
                clients[2].session.send("/app/room/" + code + "/replay",
                    Map.of("sinceSeq", 0));
                Map<String, Object> hand = clients[2].hand.poll(5, TimeUnit.SECONDS);
                assertThat(hand).as("hand resync after rejoin").isNotNull();
                assertThat((List<?>) hand.get("hand")).isNotEmpty();
            }
        }

        if (!ended) {
            // Diagnostics: what did each client last see?
            for (int i = 0; i < 4; i++) {
                List<String> types = clients[i].seenTopic.stream()
                    .map(m -> String.valueOf(m.get("type")))
                    .toList();
                int n = types.size();
                System.out.println("client" + i + " saw " + n + " topic msgs, last: "
                    + (n == 0 ? "none" : types.subList(Math.max(0, n - 5), n)));
                final int fi = i;
                clients[i].seenTopic.stream()
                    .filter(m -> "state".equals(m.get("type")))
                    .reduce((a, b) -> b)
                    .ifPresent(m -> System.out.println("client" + fi + " lastState=" + m));
            }
        }
        assertThat(ended).as("full 4-player match completed end-to-end").isTrue();
        for (Client c : clients) {
            if (c.session != null && c.session.isConnected()) c.session.disconnect();
        }
    }

    /** One legal move for the current phase: draw → discard → end turn. */
    @SuppressWarnings("unchecked")
    private void drive(String code, Client c, String phase) throws Exception {
        switch (phase) {
            case "DRAW" -> c.session.send("/app/room/" + code + "/move",
                Map.of("type", "drawStock"));
            case "DISCARD" -> {
                // Drain to the LATEST hand snapshot — hands from earlier
                // rounds contain cards we no longer hold.
                Map<String, Object> hand = c.hand.poll(2, TimeUnit.SECONDS);
                Map<String, Object> newer;
                while (hand != null && (newer = c.hand.poll()) != null) hand = newer;
                if (hand == null) {
                    System.out.println("DEBUG seat" + c.seat + " DISCARD with no hand");
                    return;
                }
                List<Map<String, Object>> cards =
                    (List<Map<String, Object>>) hand.get("hand");
                // Discard the highest-value card (simple heuristic).
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
            case "POST" -> {
                // Seat 0 calls SHOW at every opportunity — rounds end fast,
                // totals cross the target after a few rounds.
                if (c.seat == 0) {
                    c.session.send("/app/room/" + code + "/move",
                        Map.of("type", "show"));
                } else {
                    c.session.send("/app/room/" + code + "/move",
                        Map.of("type", "endTurn"));
                }
            }
            default -> { }
        }
    }

    private static boolean waitFor(Client c, String type, long millis)
            throws Exception {
        long end = System.currentTimeMillis() + millis;
        while (System.currentTimeMillis() < end) {
            Map<String, Object> m = c.topic.poll(200, TimeUnit.MILLISECONDS);
            if (m != null && type.equals(m.get("type"))) return true;
        }
        return false;
    }
}
