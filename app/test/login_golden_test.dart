import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/auth/login_screen.dart';

import 'widget_test.dart' show FakeAuthRepository;

/// Golden render of the redesigned Login screen (mockup: login_screen.png)
/// at a 852x1846 phone viewport.
void main() {
  testWidgets('login screen matches mockup', (tester) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('loginLogo')), findsOneWidget);
    expect(find.byKey(const Key('phoneField')), findsOneWidget);
    expect(find.byKey(const Key('sendOtpButton')), findsOneWidget);
    expect(find.text('Login / Sign Up'), findsOneWidget);
    expect(find.text('Why play Zero Count?'), findsOneWidget);

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_screen.png'),
    );
  });
}
