@Tags(["golden"])
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/auth/otp_screen.dart';

import 'widget_test.dart' show FakeAuthRepository;

/// Golden render of the redesigned OTP screen (mockup: otp_verification.png)
/// at a 852x1846 phone viewport.
void main() {
  testWidgets('otp screen matches mockup', (tester) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const MaterialApp(
            home: OtpScreen(
              args: OtpArgs(phone: '+919876543210', session: 's-1'),
            ),
          ),
        ),
      );
      await tester.pump();
    });

    expect(find.byKey(const Key('otpField')), findsOneWidget);
    expect(find.byKey(const Key('verifyButton')), findsOneWidget);
    expect(find.text('OTP Verification'), findsOneWidget);
    expect(find.text('Why OTP Verification?'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);

    await expectLater(
      find.byType(OtpScreen),
      matchesGoldenFile('goldens/otp_screen.png'),
    );
  });
}
