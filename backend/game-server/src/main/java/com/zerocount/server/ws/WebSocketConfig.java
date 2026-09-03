package com.zerocount.server.ws;

import java.util.List;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * WebSocket/STOMP gateway (M1.1).
 *
 * Clients connect to /ws and authenticate with the same access JWT as the
 * REST API, passed as the CONNECT frame's Authorization header
 * (see {@link WsAuthInterceptor}).
 *
 * Broker layout:
 *   /topic/room.{code}   — room-scoped broadcasts (lobby + match events)
 *   /queue/…             — per-user messages (private state like your hand)
 *   /app/…               — client → server commands
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final WsAuthInterceptor auth;

    public WebSocketConfig(WsAuthInterceptor auth) {
        this.auth = auth;
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // No SockJS fallback: native WebSocket only (the Flutter client uses
        // stomp_dart_client; browsers connect natively).
        registry.addEndpoint("/ws").setAllowedOriginPatterns("*");
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        ThreadPoolTaskScheduler heartbeat = new ThreadPoolTaskScheduler();
        heartbeat.setPoolSize(1);
        heartbeat.setThreadNamePrefix("ws-heartbeat-");
        heartbeat.initialize();
        // 10s heartbeats both ways — dead connections are detected well
        // inside the 60s reconnect grace window (M1.4).
        registry.enableSimpleBroker("/topic", "/queue")
            .setHeartbeatValue(new long[]{10_000, 10_000})
            .setTaskScheduler(heartbeat);
        registry.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(auth);
        registration.taskExecutor().corePoolSize(4).maxPoolSize(8);
    }

    @Override
    public void configureClientOutboundChannel(ChannelRegistration registration) {
        registration.taskExecutor().corePoolSize(4).maxPoolSize(8);
    }

    /** Destinations a connection may subscribe to. */
    static final List<String> SUB_PREFIXES =
        List.of("/topic/room.", "/queue/", "/user/");
}
