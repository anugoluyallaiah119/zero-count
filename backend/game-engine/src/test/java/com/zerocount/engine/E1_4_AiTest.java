package com.zerocount.engine;

import com.zerocount.engine.ai.*;
import com.zerocount.engine.model.*;
import java.util.*;

/** E1.4 acceptance tests — AI decisions match frozen V1 behavior. */
public class E1_4_AiTest {
    static int pass = 0, fail = 0;
    static int nextId = 0;

    static Card c(int rank, int suitOrd) {
        return new Card(nextId++, Rank.fromInt(rank), Suit.values()[suitOrd], 0);
    }
    static Hand hand(Card... cards) {
        Hand h = new Hand();
        for (Card c : cards) h.add(c);
        return h;
    }
    static void t(String name, Object got, Object want) {
        if (Objects.equals(got, want)) pass++;
        else { fail++; System.out.println("FAIL " + name + " got=" + got + " want=" + want); }
    }

    public static void main(String[] args) {
        AiDecider easy = AiDecider.of(DifficultyProfile.EASY, 0);
        AiDecider normal = AiDecider.of(DifficultyProfile.NORMAL, 1);
        AiDecider hard = AiDecider.of(DifficultyProfile.HARD, 2);

        // --- take-discard decision ---
        // hand 5,5,9 + visible 5 → completes ZERO group; all levels should take
        Card fiveD = c(5,3);
        t("hard takes group-completing card",
            hard.shouldTakeDiscard(hand(c(5,0), c(5,1), c(9,0)), fiveD), true);
        t("easy takes big improvement",
            easy.shouldTakeDiscard(hand(c(5,0), c(5,1), c(9,0)), fiveD), true);
        // hand 2,3,4 + visible K (no improvement) → nobody takes
        t("hard declines useless K",
            hard.shouldTakeDiscard(hand(c(2,0), c(3,0), c(4,0)), c(13,0)), false);

        // --- bestAfterDraw (V1 test case: 2,3,4 + K → best 9 by discarding K) ---
        t("bestAfterDraw 2,3,4+K = 9", hard.bestAfterDraw(hand(c(2,0), c(3,0), c(4,0)), c(13,0)), 9);
        // 5,5,9 + 5 → discard 9 → 0
        t("bestAfterDraw completes group", hard.bestAfterDraw(hand(c(5,0), c(5,1), c(9,0)), c(5,2)), 0);

        // --- discard choice ---
        // naive: throws highest face value
        t("easy discards K", easy.chooseDiscard(hand(c(2,0), c(13,0), c(4,0))).rank(), Rank.KING);
        // smart: discarding 9 from 5,5,5,9 leaves ZERO group
        t("hard discards the 9 to keep group",
            hard.chooseDiscard(hand(c(5,0), c(5,1), c(5,2), c(9,0))).rank(), Rank.NINE);
        // smart: from K,Q,2 — discarding K or Q both leave 12+... 2,3? use 2,3,K:
        // discard K → 2+3=5; discard 2 → 3+13=16 → must discard K
        t("hard discards highest when no groups",
            hard.chooseDiscard(hand(c(2,0), c(3,0), c(13,0))).rank(), Rank.KING);
        // smart keeps pairs: from 5,5,9,K → discard K (9 keeps pair alive? 5,5,9=19 vs 5,5,K... )
        // best: discard K → count 5+5+9=19... wait discarding 9 → 5+5+13=23; K → 19; 5 → 5+9+13=27. So K.
        t("hard keeps pair over lone 9",
            hard.chooseDiscard(hand(c(5,0), c(5,1), c(9,0), c(13,0))).rank(), Rank.KING);

        // --- SHOW thresholds (V1: max(2, handSize*0.6*aggr*showMul)) ---
        // easy seat0: 7*0.6*1.2*1.4 = 7.06 → 7
        t("easy show threshold (7 cards, aggr 1.2)", easy.showThreshold(7), 7);
        // normal seat1: 7*0.6*1.0*1.0 = 4.2 → 4
        t("normal show threshold", normal.showThreshold(7), 4);
        // hard seat2: 7*0.6*0.85*0.7 = 2.499 → 2 (verified against V1 IEEE math)
        t("hard show threshold", hard.showThreshold(7), 2);
        // floor of 2
        t("threshold floor 2", new AiDecider(DifficultyProfile.HARD, 0.1).showThreshold(7), 2);

        // --- SHOW decisions ---
        t("always SHOW on zero", hard.shouldShow(hand(c(5,0), c(5,1), c(5,2)), 7), true);
        // count 6: easy (threshold 7) shows, hard (threshold 2) waits
        t("easy shows at 6 (<=7)", easy.shouldShow(hand(c(4,0), c(2,1)), 7), true);
        t("hard waits at 6 (>2)", hard.shouldShow(hand(c(4,0), c(2,1)), 7), false);
        // count 4: group of three 5s + loose 4; normal (threshold 4) shows
        t("normal shows at 4", normal.shouldShow(hand(c(4,0), c(5,0), c(5,1), c(5,2)), 7), true);

        // invalid aggression rejected (fail-fast, standards §1.4)
        boolean threw = false;
        try { new AiDecider(DifficultyProfile.NORMAL, 0); }
        catch (IllegalArgumentException e) { threw = true; }
        t("rejects zero aggression", threw, true);

        System.out.println("E1.4 TESTS: " + pass + " pass, " + fail + " fail");
        if (fail > 0) System.exit(1);
    }
}
