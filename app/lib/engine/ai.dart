import 'model.dart';
import 'scoring.dart';

/// AI difficulty — parameters ported verbatim from frozen V1 DIFFS.
class DifficultyProfile {
  const DifficultyProfile(this.drawMargin, this.naive, this.showMul);

  /// Take the visible discard only if it improves the hand by at least this
  /// much (HARD takes smaller gains = sharper play).
  final int drawMargin;

  /// EASY mode: discard highest face value, ignore group potential.
  final bool naive;

  /// SHOW threshold multiplier (lower = bolder SHOWs).
  final double showMul;

  static const easy = DifficultyProfile(3, true, 1.4);
  static const normal = DifficultyProfile(2, false, 1.0);
  static const hard = DifficultyProfile(1, false, 0.7);

  static const values = [easy, normal, hard];
}

/// AI personality — difficulty + per-seat aggression (V1: 1.2/1.0/0.85).
class AiPlayer {
  AiPlayer(this.playerId, this.difficulty, this.aggression) {
    if (aggression <= 0 || aggression > 2.0) {
      throw ArgumentError('aggression out of sane range: $aggression');
    }
  }

  final String playerId;
  final DifficultyProfile difficulty;
  final double aggression;

  /// V1 seat personalities, indexed by seat order.
  static const seatAggression = [1.2, 1.0, 0.85];

  static double aggressionForSeat(int seat) =>
      seatAggression[seat < seatAggression.length ? seat : seatAggression.length - 1];

  static AiPlayer forSeat(String playerId, DifficultyProfile diff, int seat) =>
      AiPlayer(playerId, diff, aggressionForSeat(seat));
}

/// AI decision engine — direct port of frozen V1. All methods pure:
/// same hand + same inputs = same decision.
class AiDecider {
  AiDecider(this.profile, this.aggression) {
    if (aggression <= 0) {
      throw ArgumentError('aggression must be > 0');
    }
  }

  final DifficultyProfile profile;
  final double aggression;

  static AiDecider of(DifficultyProfile profile, int seatIndex) =>
      AiDecider(profile, AiPlayer.aggressionForSeat(seatIndex));

  /// Should the AI take the visible discard instead of drawing from stock?
  bool shouldTakeDiscard(Hand hand, Card topDiscard) {
    final now = ScoringEngine.count(hand.cards);
    return bestAfterDraw(hand, topDiscard) <= now - profile.drawMargin;
  }

  /// Best achievable count after drawing `drawn` then discarding one card.
  int bestAfterDraw(Hand hand, Card drawn) {
    final h = [...hand.cards, drawn];
    var best = 1 << 30;
    for (var i = 0; i < h.length; i++) {
      final rest = [...h]..removeAt(i);
      final c = ScoringEngine.count(rest);
      if (c < best) best = c;
    }
    return best;
  }

  /// Which card to discard. EASY: highest face value. NORMAL/HARD: the card
  /// whose removal minimizes the count.
  Card chooseDiscard(Hand hand) {
    final cards = hand.cards;
    if (cards.isEmpty) throw ArgumentError('empty hand');
    if (profile.naive) {
      var worst = cards[0];
      for (final c in cards) {
        if (c.value > worst.value) worst = c;
      }
      return worst;
    }
    var best = cards[0];
    var bestCount = 1 << 30;
    for (final c in cards) {
      final rest = [...cards]..remove(c);
      final count = ScoringEngine.count(rest);
      if (count < bestCount) {
        bestCount = count;
        best = c;
      }
    }
    return best;
  }

  /// SHOW threshold (V1: max(2, round(handSize * 0.6 * aggression * showMul))).
  int showThreshold(int handSize) {
    final v = (handSize * 0.6 * aggression * profile.showMul).round();
    return v > 2 ? v : 2;
  }

  /// Should the AI SHOW now? V1: always on 0, else when count <= threshold.
  bool shouldShow(Hand hand, int handSize) {
    final now = ScoringEngine.count(hand.cards);
    return now == 0 || now <= showThreshold(handSize);
  }
}
