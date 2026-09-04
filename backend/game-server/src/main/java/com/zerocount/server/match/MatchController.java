package com.zerocount.server.match;

import com.zerocount.engine.model.Card;
import com.zerocount.engine.model.GameConfig;
import com.zerocount.engine.model.Move;
import com.zerocount.engine.session.GameEvent;
import com.zerocount.server.room.Room;
import com.zerocount.server.room.RoomService;
import com.zerocount.server.ws.WsUserMessenger;
import java.security.Principal;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.MessageExceptionHandler;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.stereotype.Controller;

/**
 * Match commands over STOMP (M1.2). The client is a thin renderer: it sends
 * intents, the engine validates, and the resulting events are fanned out by
 * {@link MatchBroadcaster}.
 *
 *   /app/room/{code}/start   {} → starts the match from the room lobby
 *   /app/room/{code}/move    {"type":"drawStock"|"drawDiscard"|"show"|"endTurn"}
 *                            {"type":"discard","cardId":N}
 *
 * Illegal moves bounce back to the sender on /user/queue/errors.
 */
@Controller
public class MatchController {

    private final MatchService matches;
    private final MatchBroadcaster broadcaster;
    private final RoomService rooms;
    private final WsUserMessenger messenger;
    private final TurnTimeoutService turnTimeouts;
    private final MoveRateLimiter rateLimiter;

    public MatchController(MatchService matches, MatchBroadcaster broadcaster,
                           RoomService rooms, WsUserMessenger messenger,
                           TurnTimeoutService turnTimeouts,
                           MoveRateLimiter rateLimiter) {
        this.matches = matches;
        this.broadcaster = broadcaster;
        this.rooms = rooms;
        this.messenger = messenger;
        this.turnTimeouts = turnTimeouts;
        this.rateLimiter = rateLimiter;
    }

    private void guardRateLimit(UUID userId) {
        if (!rateLimiter.allow(userId)) {
            throw new MatchService.IllegalMoveException(
                "too many commands — slow down");
        }
    }

    /** Illegal moves / missing matches bounce back to the sender privately. */
    @MessageExceptionHandler
    public void onError(RuntimeException e, Principal principal,
                        @Header(SimpMessageHeaderAccessor.SESSION_ID_HEADER) String sessionId) {
        if (sessionId != null) {
            messenger.toSession(sessionId, "/queue/errors",
                Map.of("error", e.getMessage() == null ? "rejected" : e.getMessage()));
        }
    }

    public record MoveCommand(String type, Integer cardId) {}
    public record ReplayCommand(long sinceSeq) {}

    /**
     * M1.3 replay protocol: a (re)connecting client asks for every event
     * after the last seq it saw; the server streams them to the requester's
     * private queue in order, followed by a fresh hand snapshot.
     */
    @MessageMapping("/room/{code}/replay")
    public void replay(@DestinationVariable String code, @Payload ReplayCommand cmd,
                       Principal principal,
                       @Header(SimpMessageHeaderAccessor.SESSION_ID_HEADER) String sessionId) {
        UUID userId = UUID.fromString(principal.getName());
        long since = cmd == null ? 0 : cmd.sinceSeq();
        for (MatchEventRepository.StoredEvent e : matches.replay(code, since)) {
            messenger.toSession(sessionId, "/queue/replay", Map.of(
                "seq", e.seq(), "type", e.type(), "payload", e.payload()));
        }
        // Always end with the private hand so the client is fully resynced.
        messenger.toSession(sessionId, "/queue/hand", matches.handView(code, userId));
    }

    @MessageMapping("/room/{code}/start")
    public void start(@DestinationVariable String code, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        guardRateLimit(userId);
        Room room = rooms.get(code);
        if (!room.hostId().equals(userId)) {
            throw new MatchService.IllegalMoveException("only the host can start");
        }
        if (!room.startable()) {
            throw new MatchService.IllegalMoveException("room is not ready to start");
        }
        List<UUID> seats = room.members().stream().map(Room.Member::userId).toList();
        Room.GameSettings gs = room.settings();
        List<GameEvent> events = matches.start(code,
            new GameConfig(seats.size(), gs.handSize(), gs.target()), seats);
        broadcaster.fanOut(code, matches, events);
        turnTimeouts.arm(code);
    }

    @MessageMapping("/room/{code}/move")
    public void move(@DestinationVariable String code, @Payload MoveCommand cmd,
                     Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        guardRateLimit(userId);
        Move move = toMove(code, userId, cmd);
        List<GameEvent> events = cmd != null && "endTurn".equals(cmd.type())
            ? matches.pass(code, userId)
            : matches.apply(code, userId, move);
        broadcaster.fanOut(code, matches, events);
        turnTimeouts.arm(code);
    }

    /** R1.7 — emotes / quick chat. Whitelisted kinds only, rate-limited,
     *  broadcast to the room topic; never touches engine state. */
    public record EmoteCommand(String kind) {}

    static final java.util.Set<String> EMOTE_KINDS = java.util.Set.of(
        "gg", "nice", "oops", "wow", "hurry", "thanks",
        "laugh", "cry", "think", "zero");

    @MessageMapping("/room/{code}/emote")
    public void emote(@DestinationVariable String code,
                      @Payload EmoteCommand cmd, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        guardRateLimit(userId);
        String kind = cmd == null || cmd.kind() == null ? "" : cmd.kind().toLowerCase();
        if (!EMOTE_KINDS.contains(kind)) {
            throw new MatchService.IllegalMoveException("unknown emote: " + kind);
        }
        // Only seated players may emote.
        matches.handView(code, userId); // throws when not seated
        broadcaster.announce(code, Map.of(
            "type", "emote", "userId", userId.toString(), "kind", kind));
    }

    /** Rematch vote. When every seated player has voted, the server ends the
     *  finished match and starts a fresh session with the same config + seats. */
    @MessageMapping("/room/{code}/rematch")
    public void rematch(@DestinationVariable String code, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        guardRateLimit(userId);
        MatchService.RematchState st = matches.voteRematch(code, userId);
        broadcaster.announce(code, Map.of(
            "type", "rematch_state",
            "votes", st.votes(),
            "seats", st.seats(),
            "voters", st.voters(),
            "ready", st.ready()));
        if (st.ready()) {
            turnTimeouts.cancel(code);
            MatchService.Rematch r = matches.prepareRematch(code);
            List<GameEvent> events = matches.start(code, r.config(), r.seats());
            broadcaster.fanOut(code, matches, events);
            turnTimeouts.arm(code);
        }
    }

    /** "Choose your Zero" pin/unpin the caller's Special.
     *  Body {rank: "K"} pins, {clear: true} clears. */
    public record PinSpecialCommand(String rank, Boolean clear) {}

    @MessageMapping("/room/{code}/pin-special")
    public void pinSpecial(@DestinationVariable String code,
                           @Payload PinSpecialCommand cmd, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        guardRateLimit(userId);
        List<GameEvent> events;
        if (cmd != null && Boolean.TRUE.equals(cmd.clear())) {
            events = matches.clearSpecialPin(code, userId);
        } else if (cmd != null && cmd.rank() != null && !cmd.rank().isEmpty()) {
            com.zerocount.engine.model.Rank rank;
            try {
                rank = com.zerocount.engine.model.Rank.fromLabel(cmd.rank());
            } catch (RuntimeException e) {
                throw new MatchService.IllegalMoveException("unknown rank: " + cmd.rank());
            }
            events = matches.pinSpecial(code, userId, rank);
        } else {
            throw new MatchService.IllegalMoveException("pin-special needs rank or clear");
        }
        broadcaster.fanOut(code, matches, events);
    }

    private Move toMove(String code, UUID userId, MoveCommand cmd) {
        if (cmd == null || cmd.type() == null) {
            throw new MatchService.IllegalMoveException("missing move type");
        }
        return switch (cmd.type()) {
            case "drawStock" -> new Move.DrawStock();
            case "drawDiscard" -> new Move.DrawDiscard();
            case "show" -> new Move.Show();
            case "discard" -> {
                if (cmd.cardId() == null) {
                    throw new MatchService.IllegalMoveException("discard needs cardId");
                }
                yield new Move.Discard(findCard(code, userId, cmd.cardId()));
            }
            case "endTurn" -> null; // handled via pass()
            default -> throw new MatchService.IllegalMoveException(
                "unknown move type: " + cmd.type());
        };
    }

    private Card findCard(String code, UUID userId, int cardId) {
        var s = matches.get(code);
        for (var p : s.players()) {
            if (p.playerId().equals(userId.toString())) {
                for (Card c : p.hand().cards()) {
                    if (c.id() == cardId) return c;
                }
            }
        }
        throw new MatchService.IllegalMoveException("card not in your hand");
    }
}
