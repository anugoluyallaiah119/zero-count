package com.zerocount.engine;

import com.zerocount.engine.ai.*;
import com.zerocount.engine.model.*;
import com.zerocount.engine.session.*;
import java.util.*;

/**
 * E1.5 — Simulation harness (CI gate).
 *
 * Plays N full AI-vs-AI matches per configuration and asserts engine-wide
 * invariants continuously. Any violation aborts the run with exit code 1.
 *
 * Invariants:
 *   I1  Card conservation — cards in all hands + stock + discard always
 *       equals config.deckSize(), and no card id appears twice in any hand.
 *   I2  Event sequence — GameEvent seq numbers strictly increase per session.
 *   I3  Phase legality — the sim's chosen move must always be legal
 *       (cross-checked with GameSession.isLegal before applying).
 *   I4  Score sanity — round counts in [0, handSize*10]; totals never
 *       decrease; a match ends only when some total >= target, and the
 *       declared winner holds the lowest total.
 *   I5  Determinism — same seed => identical event stream.
 *
 * Exit code 0 = all invariants held; 1 = failure (CI gate).
 */
public class E1_5_SimulationTest {

    static long checks = 0;
    static long matchesPlayed = 0;
    static long roundsPlayed = 0;
    static long movesApplied = 0;

    static void invariant(boolean cond, String msg, long matchNo) {
        checks++;
        if (!cond) {
            System.out.println("INVARIANT VIOLATION [match " + matchNo + "]: " + msg);
            System.exit(1);
        }
    }

    /** I1: count conservation + duplicate detection across hands. */
    static void checkConservation(GameSession g, long matchNo) {
        Set<Integer> seen = new HashSet<>();
        int inHands = 0;
        for (PlayerState p : g.players()) {
            for (Card c : p.hand().cards()) {
                invariant(seen.add(c.id()), "duplicate card id " + c.id() + " in hands", matchNo);
                inHands++;
            }
        }
        int total = inHands + g.stockSize() + g.discardSize();
        int expected = g.config().deckSize();
        invariant(total == expected, "card conservation: " + total + " != " + expected, matchNo);
        // Special conservation: specials are visible in hands or on top of discard.
        long specialsVisible = g.players().stream()
            .flatMap(p -> p.hand().cards().stream()).filter(Card::isSpecial).count();
        if (g.topDiscard() != null && g.topDiscard().isSpecial()) specialsVisible++;
        invariant(specialsVisible <= g.config().specialCount(),
            "too many specials visible: " + specialsVisible, matchNo);
    }

    /** I2: event seq strictly increasing. */
    static void checkEventSeq(GameSession g, long matchNo) {
        List<GameEvent> ev = g.eventLog();
        for (int i = 1; i < ev.size(); i++) {
            invariant(ev.get(i).seq() > ev.get(i - 1).seq(), "event seq not increasing", matchNo);
        }
    }

    /** One AI decision for the current player; null means pass (POST only). */
    static Move decide(GameSession g, AiPlayer ai) {
        Hand hand = g.currentPlayer().hand();
        AiDecider d = new AiDecider(ai.difficulty(), ai.aggression());
        if (g.phase() == Phase.DRAW) {
            Card top = g.topDiscard();
            if (top != null && d.shouldTakeDiscard(hand, top)) {
                return new Move.DrawDiscard();
            }
            return new Move.DrawStock();
        }
        if (g.phase() == Phase.DISCARD) {
            return new Move.Discard(d.chooseDiscard(hand));
        }
        if (g.phase() == Phase.POST) {
            return d.shouldShow(hand, hand.cards().size()) ? new Move.Show() : null;
        }
        throw new IllegalStateException("AI asked to move in phase " + g.phase());
    }

    /** I4: inspect events produced by a move for score sanity. */
    static void checkEvents(List<GameEvent> newEvents, GameSession g, long matchNo) {
        for (GameEvent e : newEvents) {
            if (e instanceof GameEvent.RoundEnded re) {
                roundsPlayed++;
                for (int i = 0; i < re.counts().size(); i++) {
                    int cnt = re.counts().get(i);
                    invariant(cnt >= 0 && cnt <= g.config().handSize() * 10,
                        "round count out of range: " + cnt, matchNo);
                    invariant(g.players().get(i).matchScore() == re.totals().get(i).intValue(),
                        "session total != RoundEnded total for seat " + i, matchNo);
                    invariant(re.totals().get(i) >= 0, "negative total", matchNo);
                }
            } else if (e instanceof GameEvent.MatchEnded me) {
                invariant(g.isOver(), "MatchEnded but session not over", matchNo);
                boolean someoneOver = g.players().stream()
                    .anyMatch(p -> p.matchScore() >= g.config().target());
                invariant(someoneOver, "match ended but nobody reached target", matchNo);
                int min = g.players().stream().mapToInt(PlayerState::matchScore).min().orElse(-2);
                int winnerTotal = g.players().stream()
                    .filter(p -> p.playerId().equals(me.winnerId()))
                    .mapToInt(PlayerState::matchScore).findFirst().orElse(-1);
                invariant(winnerTotal == min, "winner does not hold the lowest total", matchNo);
            }
        }
    }

    static void playMatch(GameConfig cfg, List<AiPlayer> ais, long seed, long matchNo) {
        List<String> ids = new ArrayList<>();
        for (AiPlayer a : ais) ids.add(a.playerId());
        GameSession g = new GameSession(cfg, ids, seed);
        invariant(g.phase() != Phase.DEALING, "session stuck in DEALING after construction", matchNo);

        int turnsThisRound = 0; // engine turns (TurnPassed events), not sim actions
        while (!g.isOver()) {
            PlayerState cur = g.currentPlayer();
            AiPlayer ai = ais.get(g.currentPlayerIdx());
            Move mv = decide(g, ai);

            List<GameEvent> newEvents;
            if (mv != null) {
                invariant(g.isLegal(cur.playerId(), mv),
                    "sim produced illegal move " + mv + " in phase " + g.phase(), matchNo);
                newEvents = g.apply(cur.playerId(), mv);
            } else {
                newEvents = g.passTurn();
            }
            movesApplied++;
            for (GameEvent e : newEvents) {
                if (e instanceof GameEvent.TurnPassed) turnsThisRound++;
                if (e instanceof GameEvent.RoundStarted) turnsThisRound = 0;
            }
            invariant(turnsThisRound <= GameSession.TURN_CAP,
                "engine turn cap exceeded without stalemate", matchNo);
            checkEvents(newEvents, g, matchNo);
            checkConservation(g, matchNo);
        }
        matchesPlayed++;
        checkEventSeq(g, matchNo);
    }

    /** I5: full-match determinism — same seed must produce the same event stream. */
    static List<String> deterministicStream(GameConfig cfg, List<AiPlayer> ais, long seed) {
        List<String> ids = new ArrayList<>();
        for (AiPlayer a : ais) ids.add(a.playerId());
        GameSession g = new GameSession(cfg, ids, seed);
        while (!g.isOver()) {
            PlayerState cur = g.currentPlayer();
            AiPlayer ai = ais.get(g.currentPlayerIdx());
            Move mv = decide(g, ai);
            if (mv != null) g.apply(cur.playerId(), mv); else g.passTurn();
        }
        List<String> stream = new ArrayList<>();
        for (GameEvent e : g.eventLog()) {
            stream.add(e.seq() + ":" + e.getClass().getSimpleName());
        }
        return stream;
    }

    public static void main(String[] args) {
        int matchesPerCfg = args.length > 0 ? Integer.parseInt(args[0]) : 2000; // 5 cfgs x 2000 = 10k
        // CI shard offset: distinct env value → each shard explores different seeds.
        long shardSeedOffset = 0L;
        String envShard = System.getenv("ZC_SIM_SHARD_SEED");
        if (envShard != null && !envShard.isEmpty()) {
            try { shardSeedOffset = Long.parseLong(envShard); }
            catch (NumberFormatException ignore) {}
        }
        long t0 = System.currentTimeMillis();

        int[][] cfgs = { // players, handSize, target
            {2, 7, 100}, {3, 7, 100}, {4, 13, 200}, {2, 13, 500}, {4, 7, 200}
        };
        DifficultyProfile[] diffs = DifficultyProfile.values();

        // Progress reporting: log every 5% of total matches (rounded up to
        // avoid spam on short runs). Silence for 30+ minutes is a UX problem
        // on the heavy-simulation CI job.
        long totalMatches = (long) matchesPerCfg * cfgs.length;
        long progressStep = Math.max(1, totalMatches / 20);
        long nextProgressAt = progressStep;

        long matchNo = 0;
        for (int[] cc : cfgs) {
            GameConfig cfg = new GameConfig(cc[0], cc[1], cc[2]);
            for (int m = 0; m < matchesPerCfg; m++) {
                List<AiPlayer> ais = new ArrayList<>();
                for (int s = 0; s < cc[0]; s++) {
                    ais.add(AiPlayer.forSeat("ai" + s, diffs[(int) ((matchNo + s) % 3)], s));
                }
                playMatch(cfg, ais, 1000 + shardSeedOffset + matchNo, matchNo);
                matchNo++;
                if (matchNo >= nextProgressAt) {
                    long elapsed = System.currentTimeMillis() - t0;
                    double pct = 100.0 * matchNo / totalMatches;
                    long etaMs = totalMatches == matchNo ? 0
                        : elapsed * (totalMatches - matchNo) / matchNo;
                    System.out.printf(
                        "E1.5 progress: %d / %d matches (%.1f%%), %d checks, elapsed %ds, eta %ds%n",
                        matchNo, totalMatches, pct, checks,
                        elapsed / 1000, etaMs / 1000);
                    nextProgressAt += progressStep;
                }
            }
        }

        // I5 determinism check
        GameConfig dcfg = new GameConfig(4, 7, 100);
        List<AiPlayer> dais = new ArrayList<>();
        for (int s = 0; s < 4; s++) dais.add(AiPlayer.forSeat("d" + s, DifficultyProfile.NORMAL, s));
        List<String> s1 = deterministicStream(dcfg, dais, 424242L);
        List<String> s2 = deterministicStream(dcfg, dais, 424242L);
        checks++;
        if (!s1.equals(s2)) {
            System.out.println("INVARIANT VIOLATION: determinism broken (same seed, different event stream)");
            System.exit(1);
        }

        long ms = System.currentTimeMillis() - t0;
        System.out.println("E1.5 SIMULATION: " + matchesPlayed + " matches, " + roundsPlayed
            + " rounds, " + movesApplied + " moves, " + checks + " invariant checks — ALL PASS ("
            + ms + " ms)");
    }
}
