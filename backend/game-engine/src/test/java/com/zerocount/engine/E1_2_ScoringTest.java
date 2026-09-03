package com.zerocount.engine;

import com.zerocount.engine.model.*;
import com.zerocount.engine.scoring.ScoringEngine;
import java.util.*;

/**
 * E1.2 acceptance gate — the 15 locked V1 rule tests, ported verbatim.
 * These are THE rule contract; if any fails, the port is wrong.
 */
public class E1_2_ScoringTest {
    static int pass = 0, fail = 0;
    static int nextId = 0;

    static Card c(int rank, int suitOrd) {
        return new Card(nextId++, Rank.fromInt(rank), Suit.values()[suitOrd], 0);
    }

    static void t(String name, Object got, Object want) {
        if (Objects.equals(got, want)) pass++;
        else { fail++; System.out.println("FAIL " + name + " got=" + got + " want=" + want); }
    }

    static int score(Card... cards) { return ScoringEngine.count(List.of(cards)); }

    public static void main(String[] args) {
        t("A=1",                         score(c(1,0)), 1);
        t("2-9 face value",              score(c(7,0)), 7);
        t("10=10",                       score(c(10,0)), 10);
        t("J/Q/K=10",                    score(c(11,0), c(12,1), c(13,2)), 30);
        t("3 same rank = 0",             score(c(5,0), c(5,1), c(5,2)), 0);
        t("4 same rank = 0",             score(c(5,0), c(5,1), c(5,2), c(5,3)), 0);
        t("7+8+9=24 (seq no special)",   score(c(7,0), c(8,0), c(9,0)), 24);
        t("10+J+Q=30",                   score(c(10,0), c(11,0), c(12,0)), 30);
        t("J+Q+K=30 (distinct ranks)",   score(c(11,0), c(12,0), c(13,0)), 30);
        t("JJJ=0",                       score(c(11,0), c(11,1), c(11,2)), 0);
        t("10 10 10=0",                  score(c(10,0), c(10,1), c(10,2)), 0);
        t("pair counts fully",           score(c(5,0), c(5,1)), 10);
        t("JJQK mixed",                  score(c(11,0), c(11,1), c(12,0), c(13,0)), 40);
        t("group + leftover",            score(c(5,0), c(5,1), c(5,2), c(9,1)), 9);
        t("user scenario 777+333+4+2=6", score(c(7,0),c(7,1),c(7,2),c(3,0),c(3,1),c(3,2),c(4,2),c(2,0)), 6);

        // structural checks: groups vs loose
        var r = ScoringEngine.optimize(List.of(c(5,0), c(5,1), c(5,2), c(9,1)));
        t("one group found", r.groupCount(), 1);
        t("one loose card", r.loose().size(), 1);
        t("loose card is the 9", r.loose().get(0).rank(), Rank.NINE);

        var r2 = ScoringEngine.optimize(List.of(c(3,0), c(3,1), c(3,2), c(7,0), c(7,1), c(7,2)));
        t("two triples both zero", r2.count(), 0);
        t("two groups found", r2.groupCount(), 2);

        System.out.println("E1.2 TESTS: " + pass + " pass, " + fail + " fail");
        if (fail > 0) System.exit(1);
    }
}
