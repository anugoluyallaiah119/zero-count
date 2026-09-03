import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/features/match/match_models.dart';
import 'package:zerocount_app/shared/widgets/mini_card.dart';

void main() {
  group('LiveCard', () {
    test('parses wire json', () {
      final c = LiveCard.fromJson(
          {'id': 7, 'rank': 'Q', 'suit': 'hearts', 'value': 10});
      expect(c.id, 7);
      expect(c.rank, 'Q');
      expect(c.suit, CardSuit.hearts);
      expect(c.value, 10);
    });

    test('suit name is case-insensitive', () {
      final c = LiveCard.fromJson(
          {'id': 1, 'rank': 'A', 'suit': 'SPADES', 'value': 1});
      expect(c.suit, CardSuit.spades);
    });
  });

  group('LiveMatchState.applyPublicView', () {
    test('folds the broadcast state into the snapshot', () {
      final s = LiveMatchState.initial('ABC123').applyPublicView({
        'phase': 'DRAW',
        'round': 2,
        'currentPlayerIdx': 1,
        'stockSize': 30,
        'topDiscard': {'id': 9, 'rank': '5', 'suit': 'clubs', 'value': 5},
        'over': false,
        'players': [
          {'id': 'u1', 'cards': 7, 'matchScore': 12},
          {'id': 'u2', 'cards': 6, 'matchScore': 0},
        ],
      });
      expect(s.phase, 'DRAW');
      expect(s.round, 2);
      expect(s.currentPlayerIdx, 1);
      expect(s.stockSize, 30);
      expect(s.topDiscard!.rank, '5');
      expect(s.seats, hasLength(2));
      expect(s.seats[1].cards, 6);
      expect(s.mySeatIndex('u2'), 1);
      expect(s.mySeatIndex('nobody'), -1);
    });

    test('null topDiscard clears the pile', () {
      final s = LiveMatchState.initial('X').applyPublicView({
        'phase': 'DRAW',
        'round': 1,
        'currentPlayerIdx': 0,
        'stockSize': 40,
        'topDiscard': null,
        'over': false,
        'players': const <Map<String, dynamic>>[],
      });
      expect(s.topDiscard, isNull);
    });
  });

  group('M1.8 reconnecting flag', () {
    test('false on initial connect, true when dropped mid-match', () {
      final fresh = LiveMatchState.initial('ABC123');
      expect(fresh.reconnecting, isFalse);
      final midMatch = fresh.copyWith(lastSeq: 12, connected: false);
      expect(midMatch.reconnecting, isTrue);
      final healed = midMatch.copyWith(connected: true);
      expect(healed.reconnecting, isFalse);
    });
  });

  group('LiveMatchState helpers', () {
    test('myCount sums card values', () {
      final s = LiveMatchState.initial('X').copyWith(myHand: const [
        LiveCard(id: 1, rank: 'A', suit: CardSuit.hearts, value: 1),
        LiveCard(id: 2, rank: 'K', suit: CardSuit.clubs, value: 10),
        LiveCard(id: 3, rank: '7', suit: CardSuit.spades, value: 7),
      ]);
      expect(s.myCount, 18);
    });
  });
}
