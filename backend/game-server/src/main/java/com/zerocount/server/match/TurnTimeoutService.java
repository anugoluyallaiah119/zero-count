package com.zerocount.server.match;

import com.zerocount.engine.ai.AiDecider;
import com.zerocount.engine.ai.DifficultyProfile;
import com.zerocount.engine.model.Card;
import com.zerocount.engine.model.Move;
import com.zerocount.engine.model.Phase;
import com.zerocount.engine.session.GameEvent;
import com.zerocount.engine.session.GameSession;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import org.springframework.stereotype.Service;

/**
 * Turn timeout (M1.5): 30 seconds after a turn starts, the server plays a
 * competent default move for that seat (normal-profile AI) so matches never
 * stall on an idle or disconnected player. The task cancels itself if the
 * turn has already advanced.
 *
 * Turn identity = (round, currentPlayerIdx, phase, event seq) captured when
 * scheduled; any change means the timeout is stale.
 */
@Service
public class TurnTimeoutService {

    public static final long DEFAULT_TURN_SECONDS = 30;

    private final long turnSeconds;

    private record TurnMark(int round, int playerIdx, Phase phase, long seq) {}

    private final Map<String, TurnMark> marks = new ConcurrentHashMap<>();
    private final Map<String, ScheduledFuture<?>> pending = new ConcurrentHashMap<>();
    private final MatchService matches;
    private final MatchBroadcaster broadcaster;
    private final ScheduledExecutorService scheduler =
        Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "turn-timeout");
            t.setDaemon(true);
            return t;
        });

    public TurnTimeoutService(MatchService matches, MatchBroadcaster broadcaster,
                              org.springframework.messaging.simp.SimpMessagingTemplate broker,
                              @org.springframework.beans.factory.annotation.Value(
                                  "${app.match.turn-timeout-seconds:30}") long turnSeconds) {
        this.matches = matches;
        this.broadcaster = broadcaster;
        this.broker = broker;
        this.turnSeconds = turnSeconds;
    }

    /** (Re)arm the timeout for the current turn of a room's match. */
    public void arm(String code) {
        cancel(code);
        GameSession s;
        try {
            s = matches.get(code);
        } catch (MatchService.MatchNotFoundException e) {
            return;
        }
        if (s.isOver() || s.phase() == Phase.SHOWDOWN) return;
        TurnMark mark = new TurnMark(s.round(), s.currentPlayerIdx(), s.phase(),
            s.eventLog().get(s.eventLog().size() - 1).seq());
        marks.put(code, mark);
        ScheduledFuture<?> f = scheduler.schedule(
            () -> fire(code, mark), turnSeconds, TimeUnit.SECONDS);
        pending.put(code, f);
    }

    public void cancel(String code) {
        ScheduledFuture<?> f = pending.remove(code);
        if (f != null) f.cancel(false);
        marks.remove(code);
    }

    private void fire(String code, TurnMark mark) {
        GameSession s;
        try {
            s = matches.get(code);
        } catch (MatchService.MatchNotFoundException e) {
            return;
        }
        if (!mark.equals(marks.get(code))) return; // turn moved on
        if (s.isOver()) return;

        UUID userId = UUID.fromString(s.currentPlayer().playerId());
        AiDecider ai = AiDecider.of(DifficultyProfile.NORMAL, s.currentPlayerIdx());
        try {
            List<GameEvent> events;
            if (s.phase() == Phase.DRAW) {
                Card top = s.topDiscard();
                Move move = top != null && ai.shouldTakeDiscard(s.currentPlayer().hand(), top)
                    ? new Move.DrawDiscard()
                    : new Move.DrawStock();
                events = matches.apply(code, userId, move);
            } else if (s.phase() == Phase.DISCARD) {
                events = matches.apply(code, userId,
                    new Move.Discard(ai.chooseDiscard(s.currentPlayer().hand())));
            } else { // POST
                events = ai.shouldShow(s.currentPlayer().hand(), s.config().handSize())
                    ? matches.apply(code, userId, new Move.Show())
                    : matches.pass(code, userId);
            }
            broadcaster.fanOut(code, matches, events);
            brokerAnnounce(code, userId.toString());
            arm(code); // next turn gets its own clock
        } catch (RuntimeException ignored) {
            // Turn moved concurrently — stale timer, nothing to do.
        }
    }

    private final org.springframework.messaging.simp.SimpMessagingTemplate broker;

    /** Announce an auto-move so clients can render it distinctly. */
    private void brokerAnnounce(String code, String autoMovedUserId) {
        broker.convertAndSend("/topic/room." + code, (Object) Map.of(
            "type", "turn_timeout", "userId", autoMovedUserId));
    }
}
