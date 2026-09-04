package com.zerocount.engine;

import com.zerocount.engine.model.*;
import com.zerocount.engine.session.DrawBrain;
import com.zerocount.engine.session.GameSession;
import java.util.*;

/**
 * E1.6 — DrawBrain (V2.2 §32–39) acceptance tests. Mirrors the Dart tests in
 * {@code app/test/engine_test.dart} so behaviour stays in sync.
 */
public class E1_6_DrawBrainTest {
    static int pass = 0, fail = 0;
    static int nextId = 100;

    static Card c(int rank, int suitOrd) {
        return new Card(nextId++, Rank.fromInt(rank), Suit.values()[suitOrd], 0);
    }

    static Card special() {
        return new Card(nextId++, Rank.ACE, Suit.HEARTS, 0, true);
    }

    static Hand hand(Card... cards) {
        Hand h = new Hand();
        for (Card cc : cards) h.add(cc);
        return h;
    }

    static void t(String name, Object got, Object want) {
        if (Objects.equals(got, want)) pass++;
        else { fail++; System.out.println("FAIL " + name + " got=" + got + " want=" + want); }
    }

    /** RNG that always returns 0.0 for {@code nextDouble()} so the balancer fires. */
    static final class HitRng extends Random {
        @Override public double nextDouble() { return 0.0; }
    }

    public static void main(String[] args) {
        // 1) Stock look-ahead surfaces a group-completing card over noise on top.
        Hand h1 = hand(c(7, 0), c(7, 1), c(3, 0), c(11, 2));
        List<Card> stock1 = new ArrayList<>(List.of(
            c(2, 2), c(8, 1), c(7, 2), c(9, 0), c(13, 3)));
        // Layout: [2, 8, 7, 9, 13] — top = last = 13 (K). The 7 sits 2 below top.
        Card picked = DrawBrain.drawFromStock(stock1, h1, 0);
        t("look-ahead picks 7 over K", picked.rank(), Rank.SEVEN);
        t("stock shrank by 1", stock1.size(), 4);

        // 2) Opening balancer swaps a matching-rank card into a pair-less hand.
        Hand h2 = hand(c(2, 0), c(5, 1), c(7, 2), c(9, 3), c(13, 0));
        List<Card> stock2 = new ArrayList<>(List.of(c(3, 0), c(5, 2), c(11, 1), c(4, 2)));
        DrawBrain.balanceOpeningHand(h2, stock2, new HitRng());
        long fives = h2.cards().stream().filter(x -> x.rank() == Rank.FIVE).count();
        t("balancer created a pair of 5s", fives, 2L);

        // 3) Balancer leaves an already-paired hand alone.
        Hand h3 = hand(c(5, 0), c(5, 1), c(7, 2), c(9, 3));
        List<Integer> before = h3.cards().stream().map(Card::id).toList();
        List<Card> stock3 = new ArrayList<>(List.of(c(5, 2), c(11, 1)));
        DrawBrain.balanceOpeningHand(h3, stock3, new HitRng());
        List<Integer> after = h3.cards().stream().map(Card::id).toList();
        t("balancer no-op when pair exists", after, before);

        // 4) Session exposes the dry-draw counter.
        GameSession g = new GameSession(new GameConfig(2, 7, 100),
            List.of("p1", "p2"), 42L);
        t("dryDraws starts at 0 (p1)", g.dryDrawsFor("p1"), 0);
        t("dryDraws starts at 0 (p2)", g.dryDrawsFor("p2"), 0);

        // 5) wasProductive detects real improvement.
        Hand h5 = hand(c(7, 0), c(7, 1), c(9, 0));
        t("productive when draw completes a group",
            DrawBrain.wasProductive(c(7, 2), h5), true);
        t("unproductive when draw adds pure noise",
            DrawBrain.wasProductive(c(13, 3), hand(c(2, 0), c(3, 0))), false);

        System.out.println("E1.6 TESTS: " + pass + " pass, " + fail + " fail");
        if (fail > 0) System.exit(1);
    }
}
