package com.zerocount.engine;

import com.zerocount.engine.model.*;
import java.util.*;

/** E1.1 acceptance tests. Plain runner — swap for JUnit when Maven deps are available. */
public class E1_1_ModelTest {
    static int pass = 0, fail = 0;

    static void t(String name, Object got, Object want) {
        if (Objects.equals(got, want)) { pass++; }
        else { fail++; System.out.println("FAIL " + name + " got=" + got + " want=" + want); }
    }

    public static void main(String[] args) {
        // card values (V1 locked rules)
        t("A=1", new Card(0, Rank.ACE, Suit.HEARTS, 0).value(), 1);
        t("7=7", new Card(0, Rank.SEVEN, Suit.CLUBS, 0).value(), 7);
        t("10=10", new Card(0, Rank.TEN, Suit.SPADES, 0).value(), 10);
        t("J=10", new Card(0, Rank.JACK, Suit.HEARTS, 0).value(), 10);
        t("Q=10", new Card(0, Rank.QUEEN, Suit.HEARTS, 0).value(), 10);
        t("K=10", new Card(0, Rank.KING, Suit.HEARTS, 0).value(), 10);
        t("J/Q/K distinct ranks", Rank.JACK == Rank.QUEEN, false);

        // deck build: unique ids, correct size
        List<Card> d1 = DeckBuilder.build(1, 0);
        t("1 deck = 52", d1.size(), 52);
        t("unique ids", new HashSet<>(d1).size(), 52);
        List<Card> d2 = DeckBuilder.build(2, 0);
        t("2 decks = 104", d2.size(), 104);
        t("unique ids 2 decks", new HashSet<>(d2).size(), 104);
        // special cards: appended at the end of the deck
        List<Card> d1s = DeckBuilder.build(1, 2);
        long specials = d1s.stream().filter(Card::isSpecial).count();
        t("special count honored", specials, 2L);
        t("1 deck + 2 specials = 54", d1s.size(), 54);

        // V2.2 deck sizes: 2/3 players use one deck; 4 players use a fractional
        // second deck (65 for 7-card, 78 for 13-card). Special is always 1 extra card.
        t("2p×7c normal = 52", new GameConfig(2, 7, 100).normalCardCount(), 52);
        t("4p×7c normal = 60", new GameConfig(4, 7, 100).normalCardCount(), 60);
        t("3p×13c normal = 52", new GameConfig(3, 13, 200).normalCardCount(), 52);
        t("4p×13c normal = 65", new GameConfig(4, 13, 200).normalCardCount(), 65);
        t("2p×13c normal = 52", new GameConfig(2, 13, 100).normalCardCount(), 52);

        // special card distribution: exactly 1 in every match
        t("2p → 1 special", new GameConfig(2, 7, 100).specialCount(), 1);
        t("3p → 1 special", new GameConfig(3, 7, 100).specialCount(), 1);
        t("4p → 1 special", new GameConfig(4, 7, 100).specialCount(), 1);

        // config validation
        boolean threw = false;
        try { new GameConfig(5, 7, 100); } catch (IllegalArgumentException e) { threw = true; }
        t("rejects 5 players", threw, true);

        // shuffle: same cards, different order (seeded), reproducible
        List<Card> s1 = DeckBuilder.shuffle(d1, new Random(42));
        List<Card> s2 = DeckBuilder.shuffle(d1, new Random(42));
        t("shuffle keeps all cards", new HashSet<>(s1).size(), 52);
        t("seeded shuffle reproducible", s1.toString(), s2.toString());
        t("shuffle changes order", s1.toString().equals(d1.toString()), false);

        // hand ops
        Hand h = new Hand();
        Card c = d1.get(0);
        h.add(c);
        t("hand size", h.size(), 1);
        h.remove(c);
        t("hand remove", h.size(), 0);

        System.out.println("E1.1 TESTS: " + pass + " pass, " + fail + " fail");
        if (fail > 0) System.exit(1);
    }
}
