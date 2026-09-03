import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/match/countdown_screen.dart';
import 'package:zerocount_app/features/player/profile_repository.dart';
import 'package:zerocount_app/features/room/room_repository.dart';

import 'lobby_golden_test.dart' show FakeRoomRepository;
import 'widget_test.dart' show FakeAuthRepository, FakeProfileRepository;

/// Golden render of the countdown screen (Trigger_game_from_room mockup).
/// Uses a long countdown so the test captures the mid-state without firing
/// the navigation.
void main() {
  testWidgets('countdown screen matches mockup', (tester) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            profileRepositoryProvider
                .overrideWithValue(FakeProfileRepository()),
            roomRepositoryProvider.overrideWithValue(FakeRoomRepository()),
          ],
          child: const MaterialApp(
              home: CountdownScreen(code: '7X4K2B', seconds: 900)),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });

    expect(find.text('Game Starts In'), findsOneWidget);
    expect(find.text('Wait for other players...'), findsOneWidget);
    expect(find.text('SEQUENCES ARE NOT ALLOWED'), findsOneWidget);
    expect(find.text('YOUR CARDS  '), findsOneWidget);
    expect(find.byKey(const Key('countdownValue')), findsOneWidget);
    expect(find.byKey(const Key('leaveRoomButton')), findsOneWidget);
    expect(find.byKey(const Key('chatButton')), findsOneWidget);

    await expectLater(
      find.byType(CountdownScreen),
      matchesGoldenFile('goldens/countdown_screen.png'),
    );
  });
}
