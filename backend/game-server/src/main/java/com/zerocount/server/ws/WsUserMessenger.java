package com.zerocount.server.ws;

import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

/**
 * Per-connection messaging helper (M1.1).
 *
 * User destinations ("/user/queue/…") resolve to "/queue/…-user{sessionId}"
 * under the simple broker. Rather than depend on the user registry, we send
 * to the translated destination directly — the only subscriber to it is that
 * session. Used for private state (your own hand) where broadcasting to the
 * room topic would leak information.
 */
@Component
public class WsUserMessenger {

    private final SimpMessagingTemplate broker;

    public WsUserMessenger(SimpMessagingTemplate broker) {
        this.broker = broker;
    }

    /**
     * Send a payload to one WebSocket session's private queue.
     *
     * @param sessionId  simpSessionId of the target connection
     * @param queue      e.g. "/queue/hand" — the client subscribes to
     *                   "/user/queue/hand" as usual
     */
    public void toSession(String sessionId, String queue, Object payload) {
        SimpMessageHeaderAccessor headers = SimpMessageHeaderAccessor.create();
        headers.setSessionId(sessionId);
        headers.setLeaveMutable(true);
        broker.convertAndSend(queue + "-user" + sessionId, payload,
            headers.getMessageHeaders());
    }
}
