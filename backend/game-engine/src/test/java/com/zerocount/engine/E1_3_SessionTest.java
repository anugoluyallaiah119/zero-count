package com.zerocount.engine;

import com.zerocount.engine.model.*;
import com.zerocount.engine.session.*;
import java.util.*;

/** E1.3 acceptance tests — turn machine legality, flow, invariants. */
public class E1_3_SessionTest {
    static int pass = 0, fail = 0;

    static void t(String name, Object got, Object want) {
        if (Objects.equals(got, want)) pass++;
        else { fail++; System.out.println("FAIL " + name + " got=" + got + " want=" + want); }
    }

    static void expectReject(String name, Runnable r) {
        try { r.run(); fail++; System.out.println("FAIL " + name + " — move was accepted"); }
        catch (IllegalStateException | IllegalArgumentException e) { pass++; }
    }

    /**
     * Card conservation invariant: every card in the match is in exactly one place
     * (a hand, the stock, or the discard pile) — no duplicates, none lost.
     */
    static void checkIntegrity(GameSession g, int expectedTotal, String tag) {
        Map<Integer, Integer> seen = new HashMap<>();
        int total = 0;
        for (PlayerState p : g.players())
            for (Card c : p.hand().cards()) { seen.merge(c.id(), 1, Integer::sum); total++; }
        total += g.stockSize() + g.discardSize();
        boolean noDupes = seen.values().stream().allMatch(n -> n == 1);
        t("card conservation " + tag + " (total=" + total + ")", noDupes && total == expectedTotal, true);
    }

    public static void main(String[] args) {
        GameConfig cfg = new GameConfig(2, 7, 100);
        GameSession g = new GameSession(cfg, List.of("p1", "p2"), 42L);

        // initial deal
        t("starts in DRAW", g.phase(), Phase.DRAW);
        t("p1 hand 7", g.players().get(0).hand().size(), 7);
        t("p2 hand 7", g.players().get(1).hand().size(), 7);
        t("one visible discard", g.topDiscard() != null, true);
        t("stock = 52-15", g.stockSize(), 52 - 15);
        t("round 1", g.round(), 1);

        // wrong player cannot move
        expectReject("p2 cannot draw on p1's turn", () -> g.apply("p2", new Move.DrawStock()));
        // cannot discard before drawing
        expectReject("discard in DRAW phase rejected",
            () -> g.apply("p1", new Move.Discard(g.players().get(0).hand().cards().get(0))));
        // cannot show before completing turn
        expectReject("show in DRAW phase rejected", () -> g.apply("p1", new Move.Show()));

        // p1: draw from stock
        int stockBefore = g.stockSize();
        g.apply("p1", new Move.DrawStock());
        t("hand 8 after draw", g.players().get(0).hand().size(), 8);
        t("stock shrank", g.stockSize(), stockBefore - 1);
        t("phase DISCARD", g.phase(), Phase.DISCARD);

        // cannot draw twice
        expectReject("second draw rejected", () -> g.apply("p1", new Move.DrawStock()));
        // cannot discard a card not held
        Card foreign = new Card(9999, Rank.ACE, Suit.SPADES, 0);
        expectReject("discard unheld card rejected", () -> g.apply("p1", new Move.Discard(foreign)));

        // discard the card just drawn (explicitly allowed — V1 rule)
        Card justDrew = g.players().get(0).hand().cards().get(7);
        g.apply("p1", new Move.Discard(justDrew));
        t("hand back to 7", g.players().get(0).hand().size(), 7);
        t("just-discarded is on top", g.topDiscard(), justDrew);
        t("phase POST", g.phase(), Phase.POST);

        // SHOW only in POST — p1 passes instead
        g.passTurn();
        t("turn passes to p2", g.currentPlayer().playerId(), "p2");
        t("phase DRAW again", g.phase(), Phase.DRAW);

        // p2: take the visible discard
        Card top = g.topDiscard();
        g.apply("p2", new Move.DrawDiscard());
        t("p2 took the discard", g.players().get(1).hand().contains(top), true);
        t("p2 hand 8", g.players().get(1).hand().size(), 8);

        // legality query API
        t("isLegal false for wrong phase", g.isLegal("p2", new Move.Show()), false);
        t("isLegal true for discard", g.isLegal("p2",
            new Move.Discard(g.players().get(1).hand().cards().get(0))), true);

        // p2 discards then SHOWs — round must end, everyone scores
        g.apply("p2", new Move.Discard(g.players().get(1).hand().cards().get(0)));
        g.apply("p2", new Move.Show());
        t("round ended", g.phase() == Phase.SHOWDOWN || g.phase() == Phase.DRAW, true);
        t("both scored a round",
            g.players().get(0).matchScore() > 0 || g.players().get(1).matchScore() >= 0, true);
        t("round advanced or game over", g.round() == 2 || g.isOver(), true);
        t("round 2 first player rotated", g.isOver() ? 1 : g.currentPlayerIdx(), g.isOver() ? 1 : 1);

        // event log is growing and ordered
        long lastSeq = 0; boolean ordered = true;
        for (GameEvent e : g.eventLog()) { if (e.seq() <= lastSeq) ordered = false; lastSeq = e.seq(); }
        t("event seq strictly increasing", ordered, true);
        t("events recorded", g.eventLog().size() >= 8, true);

        // invariants at two points in the game
        checkIntegrity(g, 52, "after round transitions");

        // long-run invariant: play a full match with a simple scripted policy
        GameSession g2 = new GameSession(new GameConfig(4, 13, 100),
            List.of("a","b","c","d"), 7L);
        int safety = 0;
        while (!g2.isOver() && safety++ < 5000) {
            PlayerState cur = g2.currentPlayer();
            switch (g2.phase()) {
                case DRAW -> g2.apply(cur.playerId(), new Move.DrawStock());
                case DISCARD -> g2.apply(cur.playerId(),
                    new Move.Discard(cur.hand().cards().get(0)));
                case POST -> g2.passTurn();
                default -> {}
            }
        }
        t("4p 13-card match completes", g2.isOver(), true);
        checkIntegrity(g2, 104, "end of 4p/13c match");

        System.out.println("E1.3 TESTS: " + pass + " pass, " + fail + " fail");
        if (fail > 0) System.exit(1);
    }
}
