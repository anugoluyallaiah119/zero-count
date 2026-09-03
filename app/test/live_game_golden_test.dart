import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerocount_app/features/auth/auth_controller.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/match/live_game_screen.dart';
import 'package:zerocount_app/features/match/live_match_controller.dart';
import 'package:zerocount_app/features/match/match_models.dart';
import 'package:zerocount_app/features/player/profile_repository.dart';
import 'package:zerocount_app/features/room/room_repository.dart';
import 'package:zerocount_app/shared/widgets/mini_card.dart' show CardSuit;

import 'lobby_golden_test.dart' show FakeRoomRepository;
import 'widget_test.dart' show FakeAuthRepository, FakeProfileRepository;

class FakeAuthController extends AuthController {
  @override
  AuthState build() =>
      const AuthState(status: AuthStatus.authenticated, userId: 'user-1');
}

/// Offline live-match controller serving a fixed mid-turn table state.
class FakeLiveMatchController extends LiveMatchController {
  @override
  LiveMatchState? build() => const LiveMatchState(
        code: '7X4K2B',
        connected: true,
        phase: 'DISCARD',
        round: 3,
        currentPlayerIdx: 0,
        stockSize: 31,
        topDiscard: LiveCard(id: 900, rank: 'K', suit: CardSuit.diamonds, value: 10),
        over: false,
        seats: [
          LiveSeat(id: 'user-1', cards: 7, matchScore: 44),
          LiveSeat(id: 'u-meera', cards: 7, matchScore: 32),
          LiveSeat(id: 'u-arjun', cards: 6, matchScore: 28),
        ],
        myHand: [
          LiveCard(id: 1, rank: '6', suit: CardSuit.diamonds, value: 6),
          LiveCard(id: 2, rank: 'J', suit: CardSuit.clubs, value: 10),
          LiveCard(id: 3, rank: '8', suit: CardSuit.clubs, value: 8),
          LiveCard(id: 4, rank: '7', suit: CardSuit.hearts, value: 7),
          LiveCard(id: 5, rank: '2', suit: CardSuit.diamonds, value: 2),
          LiveCard(id: 6, rank: '2', suit: CardSuit.hearts, value: 2),
          LiveCard(id: 7, rank: '9', suit: CardSuit.diamonds, value: 9),
        ],
        selectedCardId: 7,
        lastEvents: ['Arjun discarded K♦'],
        lastSeq: 41,
      );

  @override
  void connect(String code) {}

  @override
  void disconnect() {}
}

/// Golden render of the redesigned live game table (live-game mockups).
void main() {
  testWidgets('live game screen matches mockup', (tester) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          authControllerProvider.overrideWith(() => FakeAuthController()),
          profileRepositoryProvider
              .overrideWithValue(FakeProfileRepository()),
          roomRepositoryProvider.overrideWithValue(FakeRoomRepository()),
          liveMatchProvider.overrideWith(() => FakeLiveMatchController()),
        ],
        child: const MaterialApp(home: LiveGameScreen(code: '7X4K2B')),
      ),
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });

    expect(find.text('ROUND 3/10'), findsOneWidget);
    expect(find.text('LIVE ROOM'), findsOneWidget);
    expect(find.text('Your Turn'), findsOneWidget);
    expect(find.text('Discard one card'), findsOneWidget);
    expect(find.text('DRAW DECK'), findsOneWidget);
    expect(find.text('DISCARD PILE'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('Player 3'), findsOneWidget);
    expect(find.text('DISCARD'), findsOneWidget);
    expect(find.text('SHOW!'), findsOneWidget);

    await expectLater(
      find.byType(LiveGameScreen),
      matchesGoldenFile('goldens/live_game_screen.png'),
    );
  });
}
