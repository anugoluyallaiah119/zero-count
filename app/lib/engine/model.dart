import 'dart:math';

/// ===========================================================================
/// Zero Count engine — Dart port of the frozen V1 rules (E3.6).
///
/// Direct port of `backend/game-engine` (E1). Same locked rules:
///  - A=1, 2-9 face, 10/J/Q/K=10; J/Q/K distinct ranks
///  - 3+ same-rank = ZERO group; sequences meaningless; pairs count fully
///  - Turn flow DRAW → DISCARD → POST(SHOW?) → next player
///  - Stock recycle keeps top discard; TURN_CAP=200 stalemate guard
///  - Round: everyone scores own count; match ends at target, lowest wins
///
/// NOTE: seeded shuffles use Dart's Random — NOT bit-identical to Java's
/// Random. Parity is behavioral (rules/invariants), not shuffle sequences.
/// ===========================================================================

enum Suit {
  hearts,
  diamonds,
  clubs,
  spades;

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;

  String get symbol => switch (this) {
        Suit.hearts => '♥',
        Suit.diamonds => '♦',
        Suit.clubs => '♣',
        Suit.spades => '♠',
      };
}

/// V1 rule (locked): value A=1, 2-9 face, 10/J/Q/K=10.
enum Rank {
  ace(1, 'A'),
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(10, 'J'),
  queen(10, 'Q'),
  king(10, 'K');

  const Rank(this.value, this.label);

  final int value;
  final String label;
}

/// Immutable card with a globally unique id (per match) — required for the
/// card-conservation invariant (no duplicates, no missing cards).
class Card {
  const Card(this.id, this.rank, this.suit, this.deck);

  final int id;
  final Rank rank;
  final Suit suit;

  /// Which physical deck (0 or 1) — matters for 13-card games.
  final int deck;

  int get value => rank.value;

  @override
  bool operator ==(Object other) => other is Card && other.id == id;

  @override
  int get hashCode => id;

  @override
  String toString() => '${rank.label}${suit.symbol}';
}

enum Phase {
  dealing,
  draw,
  discard,
  post,
  showdown,
  gameOver,
}

/// All legal player intents. Sealed so pattern matching stays exhaustive.
sealed class Move {
  const Move();
}

/// Draw the top (face-down) card from the stock. Legal only in Phase.draw.
class DrawStock extends Move {
  const DrawStock();
}

/// Take the visible top card of the discard pile. Legal only in Phase.draw.
class DrawDiscard extends Move {
  const DrawDiscard();
}

/// Discard a held card. Legal only in Phase.discard.
/// Discarding the card just drawn is explicitly allowed (V1 rule).
class Discard extends Move {
  const Discard(this.card);
  final Card card;
}

/// End the round by showing. Legal only in Phase.post.
class Show extends Move {
  const Show();
}

/// Match configuration (V1 frozen).
class GameConfig {
  GameConfig(this.players, this.handSize, this.target) {
    if (players < 2 || players > 4) {
      throw ArgumentError('players must be 2..4, got $players');
    }
    if (handSize != 7 && handSize != 13) {
      throw ArgumentError('handSize must be 7 or 13, got $handSize');
    }
    if (target != 100 && target != 200 && target != 500) {
      throw ArgumentError('target must be 100/200/500, got $target');
    }
  }

  final int players;
  final int handSize;
  final int target;

  /// V1 multi-deck rule.
  int get deckCount => players * handSize + 15 > 52 ? 2 : 1;

  static GameConfig quickPlay(int players) => GameConfig(players, 7, 100);
  static GameConfig classicPlay(int players) => GameConfig(players, 13, 200);
}

/// A player's hand — mutable during a turn, read-only view exposed.
class Hand {
  final List<Card> _cards = [];

  void add(Card c) => _cards.add(c);

  Card remove(Card c) {
    if (!_cards.remove(c)) {
      throw StateError('card not in hand: $c');
    }
    return c;
  }

  List<Card> get cards => List.unmodifiable(_cards);

  int get size => _cards.length;

  bool contains(Card c) => _cards.contains(c);

  @override
  String toString() => _cards.toString();
}

/// Builds and shuffles decks (V1 buildDeck/shuffle). Fisher-Yates with an
/// injected RNG so tests/simulations are reproducible.
abstract final class DeckBuilder {
  /// Ordered, unshuffled deck: deckCount × 52 cards, unique ids.
  static List<Card> build(int deckCount) {
    if (deckCount < 1 || deckCount > 2) {
      throw ArgumentError('deckCount must be 1 or 2, got $deckCount');
    }
    final deck = <Card>[];
    var id = 0;
    for (var d = 0; d < deckCount; d++) {
      for (final s in Suit.values) {
        for (final r in Rank.values) {
          deck.add(Card(id++, r, s, d));
        }
      }
    }
    return deck;
  }

  static List<Card> buildFor(GameConfig config) => build(config.deckCount);

  static List<Card> shuffle(List<Card> deck, [Random? rng]) {
    final r = rng ?? Random.secure();
    final d = List<Card>.of(deck);
    for (var i = d.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final tmp = d[i];
      d[i] = d[j];
      d[j] = tmp;
    }
    return d;
  }
}
