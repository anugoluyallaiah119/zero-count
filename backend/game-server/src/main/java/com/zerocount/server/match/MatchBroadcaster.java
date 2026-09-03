package com.zerocount.server.match;

import com.zerocount.engine.session.GameEvent;
import com.zerocount.server.ws.WsAuthInterceptor;
import com.zerocount.server.ws.WsUserMessenger;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

/**
 * Match → wire fan-out (M1.2). Public events go to /topic/room.{code};
 * private hand updates go to each seated player's own session queues via
 * {@link WsUserMessenger} — opponents never receive hidden cards.
 */
@Component
public class MatchBroadcaster {

    private final SimpMessagingTemplate broker;
    private final WsUserMessenger messenger;
    private final WsAuthInterceptor sessions;

    public MatchBroadcaster(SimpMessagingTemplate broker,
                            WsUserMessenger messenger,
                            WsAuthInterceptor sessions) {
        this.broker = broker;
        this.messenger = messenger;
        this.sessions = sessions;
    }

    /** Broadcast an arbitrary public payload to the room topic (emotes R1.7,
     *  presence announcements M1.4). */
    public void announce(String code, Map<String, Object> payload) {
        broker.convertAndSend("/topic/room." + code, (Object) payload);
    }

    /** Broadcast public events + fresh public view; push private hands. */
    public void fanOut(String code, MatchService matches,
                       List<GameEvent> events) {
        for (GameEvent e : events) {
            broker.convertAndSend("/topic/room." + code,
                (Object) MatchService.eventJson(e));
        }
        broker.convertAndSend("/topic/room." + code,
            (Object) Map.of("type", "state", "state", matches.publicView(code)));
        for (String seatId : matches.seats(code)) {
            UUID userId = UUID.fromString(seatId);
            for (String sid : sessions.sessionsOf(userId)) {
                messenger.toSession(sid, "/queue/hand",
                    matches.handView(code, userId));
            }
        }
    }
}
