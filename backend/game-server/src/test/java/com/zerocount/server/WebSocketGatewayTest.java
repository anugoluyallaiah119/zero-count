package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.lang.reflect.Type;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.messaging.converter.MappingJackson2MessageConverter;
import org.springframework.messaging.simp.stomp.StompFrameHandler;
import org.springframework.messaging.simp.stomp.StompHeaders;
import org.springframework.messaging.simp.stomp.StompSession;
import org.springframework.messaging.simp.stomp.StompSessionHandlerAdapter;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;

/**
 * M1.1 acceptance: STOMP gateway rejects unauthenticated CONNECTs, accepts a
 * valid access JWT, and round-trips an authenticated ping.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class WebSocketGatewayTest extends EmbeddedPostgresSupport {

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate rest;

    @SuppressWarnings("unchecked")
    private String freshAccessToken(String phone) {
        Map<String, String> r1 = rest.postForEntity(
            "http://localhost:" + port + "/api/auth/otp/request",
            Map.of("phone", phone), Map.class).getBody();
        Map<String, Object> v = rest.postForEntity(
            "http://localhost:" + port + "/api/auth/otp/verify",
            Map.of("session", r1.get("session"), "code", "123456"), Map.class).getBody();
        return (String) v.get("accessToken");
    }

    private WebSocketStompClient stompClient() {
        WebSocketStompClient client =
            new WebSocketStompClient(new StandardWebSocketClient());
        client.setMessageConverter(new MappingJackson2MessageConverter());
        return client;
    }

    @Test
    void authenticatedConnectAndPing() throws Exception {
        String token = freshAccessToken("+919444444444");
        WebSocketStompClient client = stompClient();

        StompHeaders connectHeaders = new StompHeaders();
        connectHeaders.add("Authorization", "Bearer " + token);
        StompSession session = client
            .connectAsync("ws://localhost:" + port + "/ws",
                new WebSocketHttpHeaders(), connectHeaders,
                new StompSessionHandlerAdapter() {})
            .get(5, TimeUnit.SECONDS);

        CompletableFuture<Map<String, Object>> pong = new CompletableFuture<>();
        session.subscribe("/user/queue/pong", new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) {
                return Map.class;
            }

            @Override
            @SuppressWarnings("unchecked")
            public void handleFrame(StompHeaders headers, Object payload) {
                pong.complete((Map<String, Object>) payload);
            }
        });
        session.send("/app/ping", null);

        Map<String, Object> body = pong.get(5, TimeUnit.SECONDS);
        assertThat(body.get("pong")).isEqualTo(true);
        assertThat((String) body.get("userId")).isNotBlank();
        session.disconnect();
    }

    @Test
    void rejectsConnectWithoutToken() {
        WebSocketStompClient client = stompClient();
        assertThatThrownBy(() -> client
            .connectAsync("ws://localhost:" + port + "/ws",
                new StompSessionHandlerAdapter() {})
            .get(5, TimeUnit.SECONDS))
            .isInstanceOf(Exception.class); // unauthenticated CONNECT must fail
    }
}
