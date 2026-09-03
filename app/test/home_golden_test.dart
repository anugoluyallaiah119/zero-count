import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/home/home_screen.dart';
import 'package:zerocount_app/features/player/profile_repository.dart';

import 'widget_test.dart' show FakeAuthRepository, FakeProfileRepository;

/// Golden render of the redesigned Home screen (Home_screen1 + Home_screen2
/// combination) at a 852x1846 phone viewport.
void main() {
  testWidgets('home screen matches mockup', (tester) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
    });

    expect(find.byKey(const Key('playVsAiButton')), findsOneWidget);
    expect(find.byKey(const Key('playWithFriendsButton')), findsOneWidget);
    expect(find.text('QUICK PLAY'), findsOneWidget);
    expect(find.text('CLASSIC PLAY'), findsOneWidget);
    expect(find.text('CREATE ROOM'), findsNWidgets(2));
    expect(find.text('DAILY CHALLENGE'), findsOneWidget);

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen.png'),
    );
  });
}
