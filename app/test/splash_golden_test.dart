import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/features/splash/splash_screen.dart';

import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'widget_test.dart' show FakeAuthRepository;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Golden capture of the new splash screen at phone-ish resolution for
/// visual comparison against the Main_screen mockup.
void main() {
  testWidgets('splash golden', (tester) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );
      // Let asset images decode, but stay mid-animation (before routing).
      await tester.pump(const Duration(milliseconds: 800));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();
    });

    await expectLater(
      find.byType(SplashScreen),
      matchesGoldenFile('goldens/splash_screen.png'),
    );
  });
}
