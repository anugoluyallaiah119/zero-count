import 'dart:math';

import 'draw_brain.dart';
import 'model.dart';
import 'scoring.dart';

/// Append-only event log entry (V1 checklist #29). One per state change.
sealed class GameEvent {
  const GameEvent(this.seq);
  final int seq;
}

class RoundStarted extends GameEvent {
  const RoundStarted(super.seq, this.round, this.firstIdx);
  final int round;
  final int firstIdx;
}

class DrewStock extends GameEvent {
  const DrewStock(super.seq, this.playerId);
  final String playerId;
}

class DrewDiscard extends GameEvent {
  const DrewDiscard(super.seq, this.playerId, this.card);
  final String playerId;
  final Card card;
}

class Discarded extends GameEvent {
  const Discarded(super.seq, this.playerId, this.card);
  final String playerId;
  final Card card;
}

class SpecialDiscarded extends GameEvent {
  const SpecialDiscarded(super.seq, this.playerId, this.card);
  final String playerId;
  final Card card;
}

class Showed extends GameEvent {
  const Showed(super.seq, this.playerId);
  final String playerId;
}

class TurnPassed extends GameEvent {
  const TurnPassed(super.seq, this.playerId);
  final String playerId;
}

class StockRecycled extends GameEvent {
  const StockRecycled(super.seq, this.newSize);
  final int newSize;
}

class StalemateForced extends GameEvent {
  const StalemateForced(super.seq, this.turnCap);
  final int turnCap;
}

class RoundEnded extends GameEvent {
  const RoundEnded(super.seq, this.counts, this.totals);
  final List<int> counts;
  final List<int> totals;
}

class MatchEnded extends GameEvent {
  const MatchEnded(super.seq, this.winnerId, this.totals);
  final String winnerId;
  final List<int> totals;
}

/// Per-player state within a match. matchScore accumulates across rounds.
class PlayerState {
  PlayerState(this.playerId) {
    if (playerId.isEmpty) throw ArgumentError('playerId required');
  }

  final String playerId;
  final Hand hand = Hand();
  int matchScore = 0;

  void addRoundScore(int roundCount) {
    if (roundCount < 0) {
      throw ArgumentError('round count cannot be negative');
    }
    matchScore += roundCount;
  }

  void resetHandForNewRound() {
    while (hand.size > 0) {
      hand.remove(hand.cards.first);
    }
  }
}

/// Local match state machine (offline single-player vs AI) — Dart port of
/// the E1 GameSession. Authoritative: every illegal move throws, every
/// transition logged.
class GameSession {
  GameSession(this.config, List<String> playerIds, int seed)
      : _rng = Random(seed),
        players = List.unmodifiable(playerIds.map(PlayerState.new)) {
    if (playerIds.length != config.players) {
      throw ArgumentError(
          'config expects ${config.players} players, got ${playerIds.length}');
    }
    _dealNewRound();
  }

  /// V1 stalemate guard — forced showdown after this many turns.
  static const turnCap = 200;

  final GameConfig config;
  final Random _rng;
  final List<PlayerState> players;
  final List<Card> _stock = []; // last element = top (draw end)
  final List<Card> _discard = []; // last element = visible top
  final List<GameEvent> eventLog = [];
  final Map<int, int> _specialAge = {}; // card id -> turns held this round
  // "Choose your Zero": maps special card id -> the rank the owner pinned it to.
  final Map<int, Rank> _specialPins = {};
  /// V2.2 §36 dry-draw counter per player (index-aligned with [players]).
  final List<int> _dryDraws = [];

  Phase phase = Phase.dealing;
  int _turnIdx = 0;
  int _firstIdx = 0;
  int round = 0;
  int _turnCount = 0;
  int _seq = 0;

  int get currentPlayerIdx => _turnIdx;
  PlayerState get currentPlayer => players[_turnIdx];
  Card? get topDiscard => _discard.isEmpty ? null : _discard.last;
  int get stockSize => _stock.length;
  int get discardSize => _discard.length;
  bool get isOver => phase == Phase.gameOver;

  /// V2.2 §36 — how many consecutive unproductive stock draws [playerId] has.
  int dryDrawsFor(String playerId) {
    for (var i = 0; i < players.length; i++) {
      if (players[i].playerId == playerId) {
        return i < _dryDraws.length ? _dryDraws[i] : 0;
      }
    }
    return 0;
  }

  bool isLegal(String playerId, Move move) {
    try {
      _validate(playerId, move);
      return true;
    } on StateError {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  /// Apply a move. Validates actor, phase, card ownership. Returns new events.
  List<GameEvent> apply(String playerId, Move move) {
    _validate(playerId, move);
    final before = eventLog.length;
    switch (move) {
      case DrawStock():
        _doDrawStock();
      case DrawDiscard():
        _doDrawDiscard();
      case Discard(:final card):
        _doDiscard(card);
      case Show():
        _doShow();
    }
    return List.unmodifiable(eventLog.sublist(before));
  }

  /// Pass the turn (POST window expires without SHOW).
  List<GameEvent> passTurn() {
    if (phase != Phase.post) {
      throw StateError('PHASE_MISMATCH: passTurn');
    }
    final before = eventLog.length;
    _endTurn();
    return List.unmodifiable(eventLog.sublist(before));
  }

  // ---------- internals ----------

  void _validate(String playerId, Move move) {
    if (phase == Phase.gameOver) throw StateError('GAME_OVER');
    if (phase == Phase.dealing) throw StateError('DEALING');
    if (currentPlayer.playerId != playerId) throw StateError('NOT_YOUR_TURN');
    switch (move) {
      case DrawStock():
        if (phase != Phase.draw) throw StateError('PHASE_MISMATCH');
      case DrawDiscard():
        if (phase != Phase.draw) throw StateError('PHASE_MISMATCH');
        if (_discard.isEmpty) {
          throw StateError('ILLEGAL_MOVE: empty discard pile');
        }
      case Discard(:final card):
        if (phase != Phase.discard) throw StateError('PHASE_MISMATCH');
        if (!currentPlayer.hand.contains(card)) {
          throw StateError('ILLEGAL_MOVE: card not in hand');
        }
      case Show():
        if (phase != Phase.post && phase != Phase.discard) {
          throw StateError('PHASE_MISMATCH');
        }
    }
  }

  void _doDrawStock() {
    _ensureStock();
    // V2.2 §32: look-ahead pick informed by this player's dry-draw streak.
    final handBefore = Hand();
    for (final c in currentPlayer.hand.cards) {
      handBefore.add(c);
    }
    final c = DrawBrain.drawFromStock(
        _stock, currentPlayer.hand, _dryDraws[_turnIdx]);
    currentPlayer.hand.add(c);
    if (c.isSpecial) {
      _specialAge.remove(c.id);
      _specialPins.remove(c.id);
    }
    // Dry-draw counter: soft pity when repeated stock draws yield nothing.
    if (DrawBrain.wasProductive(c, handBefore)) {
      _dryDraws[_turnIdx] = 0;
    } else {
      _dryDraws[_turnIdx] += 1;
    }
    phase = Phase.discard;
    _log(DrewStock(_nextSeq(), currentPlayer.playerId));
  }

  void _doDrawDiscard() {
    final c = _discard.removeLast();
    currentPlayer.hand.add(c);
    // Taking the visible discard is always an active choice → reset dry counter.
    _dryDraws[_turnIdx] = 0;
    if (c.isSpecial) {
      _specialAge.remove(c.id);
      _specialPins.remove(c.id);
    }
    phase = Phase.discard;
    _log(DrewDiscard(_nextSeq(), currentPlayer.playerId, c));
  }

  void _doDiscard(Card card) {
    currentPlayer.hand.remove(card);
    _discard.add(card);
    if (card.isSpecial) _specialPins.remove(card.id);
    _pruneStalePins();
    phase = Phase.post;
    _log(Discarded(_nextSeq(), currentPlayer.playerId, card));
  }

  void _doShow() {
    _log(Showed(_nextSeq(), currentPlayer.playerId));
    _endRound();
  }

  void _endTurn() {
    _decaySpecials();
    _turnCount++;
    if (_turnCount >= turnCap) {
      _log(StalemateForced(_nextSeq(), turnCap));
      _endRound();
      return;
    }
    _turnIdx = (_turnIdx + 1) % players.length;
    phase = Phase.draw;
    _log(TurnPassed(_nextSeq(), currentPlayer.playerId));
  }

  /// V2.2: Special cards expire after 4 owner turns while unusable.
  /// The timer pauses whenever the special has at least one valid pair target.
  static const int specialDecayTurns = 4;

  /// Pin rank for [p]'s Special, if any, for scoring.
  Rank? _pinRankFor(PlayerState p) {
    for (final c in p.hand.cards) {
      if (c.isSpecial) return _specialPins[c.id];
    }
    return null;
  }

  void _decaySpecials() {
    final hand = currentPlayer.hand;
    final specials = hand.cards.where((c) => c.isSpecial).toList();
    final hasValidPair = _hasExactPair(hand);
    for (final special in specials) {
      if (hasValidPair) {
        // Timer is frozen while the special can be used.
        continue;
      }
      final age = (_specialAge[special.id] ?? 0) + 1;
      if (age >= specialDecayTurns) {
        hand.remove(special);
        _discard.add(special);
        _specialAge.remove(special.id);
        _specialPins.remove(special.id);
        _log(SpecialDiscarded(_nextSeq(), currentPlayer.playerId, special));
      } else {
        _specialAge[special.id] = age;
      }
    }
  }

  /// Returns true if the hand contains at least one rank with exactly 2 normal
  /// cards — a valid target for a Special card.
  bool _hasExactPair(Hand hand) {
    final counts = <Rank, int>{};
    for (final c in hand.cards) {
      if (c.isSpecial) continue;
      counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    }
    return counts.values.any((n) => n == 2);
  }

  /// Remaining owner turns before [special] would auto-discard. Returns 0 if
  /// the special is not held by the current player or is already usable.
  int specialTurnsRemaining(Card special) {
    if (!currentPlayer.hand.contains(special) || !special.isSpecial) return 0;
    if (_hasExactPair(currentPlayer.hand)) return 0;
    final age = _specialAge[special.id] ?? 0;
    return (specialDecayTurns - age).clamp(0, specialDecayTurns);
  }

  /// The rank a player has pinned their Special to, or null. The pin locks
  /// the scoring engine to that pair when the round ends.
  Rank? specialPinnedRank(Card special) => _specialPins[special.id];

  /// Ranks in [playerId]'s hand that currently have exactly 2 normal cards.
  /// Returns the set of valid pin targets for the Special they hold.
  List<Rank> validPairsFor(String playerId) {
    final player = players.firstWhere((p) => p.playerId == playerId,
        orElse: () => throw ArgumentError('unknown player: $playerId'));
    final counts = <Rank, int>{};
    for (final c in player.hand.cards) {
      if (c.isSpecial) continue;
      counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    }
    return [for (final e in counts.entries) if (e.value == 2) e.key];
  }

  /// Pin [playerId]'s Special to [rank]. The player must currently hold a
  /// Special and have exactly 2 normal cards of that rank.
  void pinSpecial(String playerId, Rank rank) {
    final player = players.firstWhere((p) => p.playerId == playerId,
        orElse: () => throw ArgumentError('unknown player: $playerId'));
    Card? special;
    for (final c in player.hand.cards) {
      if (c.isSpecial) {
        special = c;
        break;
      }
    }
    if (special == null) throw StateError('NO_SPECIAL');
    if (!validPairsFor(playerId).contains(rank)) {
      throw StateError('INVALID_PIN');
    }
    _specialPins[special.id] = rank;
  }

  /// Clear the current player's Special pin, if any.
  void clearSpecialPin(String playerId) {
    final player = players.firstWhere((p) => p.playerId == playerId,
        orElse: () => throw ArgumentError('unknown player: $playerId'));
    for (final c in player.hand.cards) {
      if (c.isSpecial) _specialPins.remove(c.id);
    }
  }

  /// Drop pins whose rank no longer has exactly 2 normal cards in the holder's
  /// hand — the pair was broken by a discard so the pin is stale.
  void _pruneStalePins() {
    if (_specialPins.isEmpty) return;
    final stale = <int>[];
    for (final entry in _specialPins.entries) {
      // Find the owner of this special id.
      PlayerState? owner;
      for (final p in players) {
        if (p.hand.cards.any((c) => c.id == entry.key)) {
          owner = p;
          break;
        }
      }
      if (owner == null) {
        stale.add(entry.key);
        continue;
      }
      final rankCount = owner.hand.cards
          .where((c) => !c.isSpecial && c.rank == entry.value)
          .length;
      if (rankCount != 2) stale.add(entry.key);
    }
    for (final id in stale) {
      _specialPins.remove(id);
    }
  }

  void _endRound() {
    phase = Phase.showdown;
    final counts = [
      for (final p in players) ScoringEngine.count(p.hand.cards, pinRank: _pinRankFor(p))
    ];
    for (final p in players) {
      p.addRoundScore(ScoringEngine.count(p.hand.cards, pinRank: _pinRankFor(p)));
    }
    final totals = [for (final p in players) p.matchScore];
    _log(RoundEnded(_nextSeq(), counts, totals));

    final matchOver = totals.any((t) => t >= config.target);
    if (matchOver) {
      phase = Phase.gameOver;
      var winIdx = 0;
      for (var i = 1; i < totals.length; i++) {
        if (totals[i] < totals[winIdx]) winIdx = i; // lowest total wins
      }
      _log(MatchEnded(_nextSeq(), players[winIdx].playerId, totals));
    } else {
      _firstIdx = (_firstIdx + 1) % players.length; // rotate first player
      _dealNewRound();
    }
  }

  void _dealNewRound() {
    round++;
    for (final p in players) {
      p.resetHandForNewRound();
    }
    _stock.clear();
    _discard.clear();
    _specialAge.clear();
    _specialPins.clear();
    // V2.2 §36: reset dry-draw counters at the start of every round.
    if (_dryDraws.isEmpty) {
      _dryDraws.addAll(List.filled(players.length, 0));
    } else {
      for (var i = 0; i < _dryDraws.length; i++) {
        _dryDraws[i] = 0;
      }
    }

    final deck = DeckBuilder.shuffle(DeckBuilder.buildFor(config), _rng);
    var pos = 0;
    for (var k = 0; k < config.handSize; k++) {
      for (final p in players) {
        p.hand.add(deck[pos++]);
      }
    }
    _discard.add(deck[pos++]); // first visible card
    for (var i = deck.length - 1; i >= pos; i--) {
      _stock.add(deck[i]); // so removeLast() draws in deck order
    }

    // V2.2 §38 opening balancer: nudge dead openings toward a pair chance.
    for (final p in players) {
      DrawBrain.balanceOpeningHand(p.hand, _stock, _rng);
    }

    _turnIdx = _firstIdx;
    _turnCount = 0;
    phase = Phase.draw;
    _log(RoundStarted(_nextSeq(), round, _firstIdx));
  }

  /// V1 recycle rule: stock empty → keep top discard, shuffle the rest.
  void _ensureStock() {
    if (_stock.isNotEmpty) return;
    final top = _discard.removeLast(); // top stays visible
    final rest = List<Card>.of(_discard);
    _discard
      ..clear()
      ..add(top);
    final shuffled = DeckBuilder.shuffle(rest, _rng);
    // push so that removeLast() serves them in shuffled order
    for (var i = shuffled.length - 1; i >= 0; i--) {
      _stock.add(shuffled[i]);
    }
    _log(StockRecycled(_nextSeq(), _stock.length));
  }

  int _nextSeq() => ++_seq;
  void _log(GameEvent e) => eventLog.add(e);
}
