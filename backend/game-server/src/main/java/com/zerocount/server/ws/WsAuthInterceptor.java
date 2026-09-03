package com.zerocount.server.ws;

import com.zerocount.server.auth.JwtService;
import java.security.Principal;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.stereotype.Component;

/**
 * STOMP CONNECT authentication (M1.1): the client sends its REST access JWT
 * as the CONNECT frame's Authorization header. A valid token binds the
 * WebSocket session to a {@link StompPrincipal} carrying the user id;
 * anything else is rejected before the session is established — same uniform
 * failure as the REST guard (standards §3.4).
 *
 * The CONNECT principal is remembered per STOMP session and re-attached to
 * every subsequent frame, so downstream handlers always see an authenticated
 * user.
 */
@Component
public class WsAuthInterceptor implements ChannelInterceptor {

    public record StompPrincipal(UUID userId) implements Principal {
        @Override
        public String getName() {
            return userId.toString();
        }
    }

    private final JwtService jwt;
    private final Map<String, StompPrincipal> sessions = new ConcurrentHashMap<>();

    public WsAuthInterceptor(JwtService jwt) {
        this.jwt = jwt;
    }

    /** All live WebSocket session ids for a user (multi-device safe). */
    public java.util.Set<String> sessionsOf(UUID userId) {
        var out = new java.util.HashSet<String>();
        sessions.forEach((sid, p) -> {
            if (p.userId().equals(userId)) out.add(sid);
        });
        return out;
    }

    /** Who owns this session? (null if unknown/closed). */
    public StompPrincipal principalOf(String sessionId) {
        return sessionId == null ? null : sessions.get(sessionId);
    }

    /**
     * Session teardown — called once per WebSocket close by
     * DisconnectGraceService (the session's terminal owner). Returns the
     * principal that was bound, or null.
     */
    public StompPrincipal endSession(String sessionId) {
        return sessionId == null ? null : sessions.remove(sessionId);
    }

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = StompHeaderAccessor.wrap(message);
        StompCommand command = accessor.getCommand();
        String sessionId = accessor.getSessionId();

        if (StompCommand.CONNECT.equals(command)) {
            String header = accessor.getFirstNativeHeader("Authorization");
            if (header == null || !header.startsWith("Bearer ")) {
                throw new MessageDeliveryException("missing bearer token");
            }
            try {
                UUID userId = jwt.validateAccessToken(header.substring(7));
                StompPrincipal principal = new StompPrincipal(userId);
                if (sessionId != null) {
                    sessions.put(sessionId, principal);
                }
                accessor.setUser(principal);
            } catch (JwtService.InvalidTokenException e) {
                throw new MessageDeliveryException("invalid bearer token");
            }
        } else if (StompCommand.DISCONNECT.equals(command)) {
            // Map cleanup happens on the WebSocket-level close event
            // (DisconnectGraceService), which is the single terminal point —
            // a hard network drop never sends a STOMP DISCONNECT.
            StompPrincipal p = sessionId == null ? null : sessions.get(sessionId);
            if (p != null) accessor.setUser(p);
        } else {
            StompPrincipal principal = sessionId == null ? null : sessions.get(sessionId);
            if (principal == null) {
                throw new MessageDeliveryException("not authenticated");
            }
            accessor.setUser(principal);
            if (StompCommand.SUBSCRIBE.equals(command)) {
                String dest = accessor.getDestination();
                boolean allowed = dest != null
                    && WebSocketConfig.SUB_PREFIXES.stream().anyMatch(dest::startsWith);
                if (!allowed) {
                    throw new MessageDeliveryException("destination not allowed: " + dest);
                }
            }
        }
        return MessageBuilder.createMessage(
            message.getPayload(), accessor.toMessageHeaders());
    }
}
