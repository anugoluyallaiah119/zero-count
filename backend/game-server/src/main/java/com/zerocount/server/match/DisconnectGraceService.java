package com.zerocount.server.match;

import com.zerocount.server.ws.WsAuthInterceptor;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.stereotype.Service;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

/**
 * Reconnect protection (M1.4): a dropped connection starts a 60-second grace
 * window. The room is told immediately ({@code player_disconnected} with the
 * grace deadline); reconnecting inside the window cancels the forfeit and
 * announces {@code player_reconnected}; expiry announces
 * {@code player_forfeited}. This service is also the single terminal owner
 * of session teardown (via {@link WsAuthInterceptor#endSession}), so grace
 * works identically for clean closes and hard network drops.
 *
 * Resync after reconnect uses the M1.3 replay protocol — the Flutter client
 * reconnects with the same JWT, replays events since its last seq, and gets
 * a fresh private hand (M1.8).
 */
@Service
public class DisconnectGraceService {

    /** Grace window before a disconnected player is marked forfeited. */
    public static final long GRACE_SECONDS = 60;

    private record GraceEntry(UUID userId, Instant deadline, ScheduledFuture<?> expiry) {}

    private final Map<UUID, GraceEntry> grace = new ConcurrentHashMap<>();
    private final WsAuthInterceptor sessions;
    private final SimpMessagingTemplate broker;
    private final MatchService matches;
    private final ScheduledExecutorService scheduler =
        Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "disconnect-grace");
            t.setDaemon(true);
            return t;
        });

    public DisconnectGraceService(WsAuthInterceptor sessions,
                                  SimpMessagingTemplate broker,
                                  @org.springframework.context.annotation.Lazy MatchService matches) {
        this.sessions = sessions;
        this.broker = broker;
        this.matches = matches;
    }

    @EventListener
    public void onDisconnect(SessionDisconnectEvent event) {
        StompHeaderAccessor accessor = StompHeaderAccessor.wrap(event.getMessage());
        WsAuthInterceptor.StompPrincipal principal =
            sessions.endSession(accessor.getSessionId());
        if (principal == null) return; // unknown or already closed session
        UUID userId = principal.userId();
        if (!sessions.sessionsOf(userId).isEmpty()) return; // other device live

        Instant deadline = Instant.now().plusSeconds(GRACE_SECONDS);
        ScheduledFuture<?> expiry = scheduler.schedule(
            () -> expire(userId), GRACE_SECONDS, TimeUnit.SECONDS);
        GraceEntry old = grace.put(userId, new GraceEntry(userId, deadline, expiry));
        if (old != null) old.expiry().cancel(false);
        announce(userId, "player_disconnected", deadline);
    }

    @EventListener
    public void onConnected(
            org.springframework.web.socket.messaging.SessionConnectedEvent event) {
        // Fired after the broker processes CONNECT — simpUser is attached.
        StompHeaderAccessor accessor = StompHeaderAccessor.wrap(event.getMessage());
        if (accessor.getUser() instanceof WsAuthInterceptor.StompPrincipal p) {
            userConnected(p.userId());
        }
    }

    @EventListener
    public void onSubscribe(
            org.springframework.web.socket.messaging.SessionSubscribeEvent event) {
        // Belt and braces: subscriptions always carry the session principal
        // (attached by WsAuthInterceptor), so a reconnect is also caught here
        // even if SessionConnectedEvent raced the interceptor.
        StompHeaderAccessor accessor = StompHeaderAccessor.wrap(event.getMessage());
        if (accessor.getUser() instanceof WsAuthInterceptor.StompPrincipal p) {
            userConnected(p.userId());
        }
    }

    /** Called by MatchService when any session for a user (re)connects. */
    public void userConnected(UUID userId) {
        GraceEntry e = grace.remove(userId);
        if (e != null) {
            e.expiry().cancel(false);
            announce(userId, "player_reconnected", null);
        }
    }

    /** True while the user is inside their grace window (UI badges). */
    public boolean inGrace(UUID userId) {
        return grace.containsKey(userId);
    }

    private void expire(UUID userId) {
        GraceEntry e = grace.remove(userId);
        if (e == null) return;
        announce(userId, "player_forfeited", null);
    }

    private void announce(UUID userId, String type, Instant deadline) {
        for (String code : matches.roomsOf(userId)) {
            Object msg = deadline == null
                ? Map.of("type", type, "userId", userId.toString())
                : Map.of("type", type, "userId", userId.toString(),
                    "graceEndsAt", deadline.toString());
            broker.convertAndSend("/topic/room." + code, msg);
        }
    }
}
