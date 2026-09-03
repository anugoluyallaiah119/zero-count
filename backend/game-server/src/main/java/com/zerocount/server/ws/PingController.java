package com.zerocount.server.ws;

import java.security.Principal;
import java.util.Map;
import java.util.UUID;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.stereotype.Controller;

/**
 * Connectivity check over STOMP (M1.1): proves the authenticated channel
 * works end to end. Clients send to /app/ping and receive their own user id
 * back on /user/queue/pong.
 */
@Controller
public class PingController {

    private final WsUserMessenger messenger;

    public PingController(WsUserMessenger messenger) {
        this.messenger = messenger;
    }

    @MessageMapping("/ping")
    public void ping(Principal principal,
                     @Header(SimpMessageHeaderAccessor.SESSION_ID_HEADER) String sessionId) {
        UUID userId = UUID.fromString(principal.getName());
        messenger.toSession(sessionId, "/queue/pong",
            Map.of("pong", true, "userId", userId.toString()));
    }
}
