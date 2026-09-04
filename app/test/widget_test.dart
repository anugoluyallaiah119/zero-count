import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/player/profile_repository.dart';
import 'package:zerocount_app/main.dart';

/// Offline fake of the E2.3 auth backend. Dev code is 123456.
class FakeAuthRepository implements AuthRepository {
  int requestCalls = 0;
  int verifyCalls = 0;
  bool newUser = true;

  @override
  Future<String> requestOtp(String phone) async {
    requestCalls++;
    return 'test-session-$requestCalls';
  }

  @override
  Future<TokenBundle> verifyOtp(String session, String code) async {
    verifyCalls++;
    if (code != '123456') {
      throw const AuthException('Invalid or expired code');
    }
    return TokenBundle(
      accessToken: 'access',
      refreshToken: 'refresh',
      userId: 'user-1',
      expiresInSec: 900,
      newUser: newUser,
    );
  }

  @override
  Future<TokenBundle> refresh(String refreshToken) async {
    if (refreshToken != 'stored-refresh') {
      throw const AuthException('Refresh token expired');
    }
    return const TokenBundle(
      accessToken: 'access-2',
      refreshToken: 'refresh-2',
      userId: 'user-1',
      expiresInSec: 900,
      newUser: false,
    );
  }
}

/// Offline fake of the E2.4 player profile backend.
class FakeProfileRepository implements ProfileRepository {
  PlayerProfile profile = const PlayerProfile(
    id: 'user-1',
    phoneMasked: '+919******10',
    name: '',
    avatar: '',
    coins: 2500,
    gems: 50,
    matches: 23,
    wins: 9,
    zerosMade: 4,
    bestCount: 0,
    streakDays: 3,
    elo: 1315,
    winStreak: 0,
    bestWinStreak: 0,
  );
  String? patchedName;

  @override
  Future<PlayerProfile> me() async => profile;

  @override
  Future<PlayerProfile> update({String? name, String? avatar}) async {
    patchedName = name;
    profile = PlayerProfile(
      id: profile.id,
      phoneMasked: profile.phoneMasked,
      name: name ?? profile.name,
      avatar: avatar ?? profile.avatar,
      coins: profile.coins,
      gems: profile.gems,
      matches: profile.matches,
      wins: profile.wins,
      zerosMade: profile.zerosMade,
      bestCount: profile.bestCount,
      streakDays: profile.streakDays,
      elo: profile.elo,
      winStreak: profile.winStreak,
      bestWinStreak: profile.bestWinStreak,
    );
    return profile;
  }
}

Future<void> typeOtp(WidgetTester tester, String code) async {
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(find.byType(TextField).at(i), code[i]);
    await tester.pump();
  }
}

Future<void> reachOtp(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4)); // margin over splash min-time
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('phoneField')), '9876543210');
  await tester.tap(find.byKey(const Key('sendOtpButton')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository fakeAuth;
  late FakeProfileRepository fakeProfile;

  ProviderScope app() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          profileRepositoryProvider.overrideWithValue(fakeProfile),
        ],
        child: const ZeroCountApp(),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeAuth = FakeAuthRepository();
    fakeProfile = FakeProfileRepository();
  });

  testWidgets('app boots to splash with brand mark', (tester) async {
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('splashLogo')), findsOneWidget);
    expect(find.text('L O A D I N G . . .'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('no saved session → splash routes to login', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phoneField')), findsOneWidget);
  });

  testWidgets('new user: login → OTP → profile setup → home (name saved)',
      (tester) async {
    fakeAuth.newUser = true;
    await tester.pumpWidget(app());
    await reachOtp(tester);
    expect(fakeAuth.requestCalls, 1);

    await typeOtp(tester, '123456');
    await tester.tap(find.byKey(const Key('verifyButton')));
    await tester.pumpAndSettle();

    // new users land on profile setup, not home
    expect(find.byKey(const Key('nameField')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('nameField')), 'Arjun');
    await tester.ensureVisible(find.byKey(const Key('saveProfileButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveProfileButton')));
    await tester.pumpAndSettle();

    expect(fakeProfile.patchedName, 'Arjun');
    expect(find.byKey(const Key('playVsAiButton')), findsOneWidget);
    expect(find.byKey(const Key('profileSummary')), findsOneWidget);
    expect(find.text('Arjun'), findsOneWidget); // live name on home
    expect(find.text('2500'), findsOneWidget); // live coins chip
    expect(find.text('Level 3 · ELO 1315'), findsOneWidget); // 23 matches → L3
  });

  testWidgets('returning user: OTP routes straight to home', (tester) async {
    fakeAuth.newUser = false;
    fakeProfile.profile = PlayerProfile(
      id: 'user-1',
      phoneMasked: '+919******10',
      name: 'Meera',
      avatar: 'star',
      coins: 800,
      gems: 12,
      matches: 41,
      wins: 20,
      zerosMade: 9,
      bestCount: 0,
      streakDays: 6,
      elo: 1420,
      winStreak: 0,
      bestWinStreak: 0,
    );
    await tester.pumpWidget(app());
    await reachOtp(tester);
    await typeOtp(tester, '123456');
    await tester.tap(find.byKey(const Key('verifyButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nameField')), findsNothing);
    expect(find.text('Meera'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
  });

  testWidgets('wrong OTP shows server error and stays on the OTP screen',
      (tester) async {
    await tester.pumpWidget(app());
    await reachOtp(tester);
    await typeOtp(tester, '000000');
    await tester.tap(find.byKey(const Key('verifyButton')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid or expired code'), findsOneWidget);
    expect(find.byKey(const Key('otpField')), findsOneWidget);
    expect(find.byKey(const Key('playVsAiButton')), findsNothing);
  });

  testWidgets('short phone number is rejected client-side', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('phoneField')), '12345');
    await tester.tap(find.byKey(const Key('sendOtpButton')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
    expect(fakeAuth.requestCalls, 0); // server never called
  });

  testWidgets('game screen: setup panel, then live table driven by engine',
      (tester) async {
    fakeAuth.newUser = false;
    await tester.pumpWidget(app());
    await reachOtp(tester);
    await typeOtp(tester, '123456');
    await tester.tap(find.byKey(const Key('verifyButton')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('playVsAiButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('playVsAiButton')));
    await tester.pumpAndSettle();

    // Choose game type screen (mockup Choose_game), then CONTINUE.
    expect(find.byKey(const Key('chooseQuick')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('chooseContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chooseContinue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Direct to live table (no intermediate setup screen).
    expect(find.byKey(const Key('turnBanner')), findsOneWidget);
    expect(find.byKey(const Key('playerHand')), findsOneWidget);
    expect(find.byKey(const Key('sortButton')), findsOneWidget);
    expect(find.byKey(const Key('feltTable')), findsOneWidget);
    expect(find.text('Rahul'), findsOneWidget); // opponent seats
    expect(find.text('Sneha'), findsWidgets); // opponent seat
    expect(find.text('DRAW DECK'), findsOneWidget);
    expect(find.text('DISCARD PILE'), findsOneWidget);

    // SORT button toggles the hand ordering internally.
    await tester.tap(find.byKey(const Key('sortButton')));
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('saved refresh token → splash skips login, lands on home',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'zc.access': 'old-access',
      'zc.refresh': 'stored-refresh',
      'zc.userId': 'user-1',
    });
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('phoneField')), findsNothing);
    expect(find.byKey(const Key('playVsAiButton')), findsOneWidget);
  });
  testWidgets('tutorial: 4 pages, swipe through, GOT IT closes', (tester) async {
    fakeAuth.newUser = false;
    await tester.pumpWidget(app());
    await reachOtp(tester);
    await typeOtp(tester, '123456');
    await tester.tap(find.byKey(const Key('verifyButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('howToPlayButton')));
    await tester.pumpAndSettle();
    expect(find.text('KEEP YOUR COUNT LOW'), findsOneWidget);

    for (final title in ['MAKE A ZERO', 'DRAW → DISCARD', 'CALL SHOW!']) {
      await tester.tap(find.byKey(const Key('tutorialNext')));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('tutorialNext'))); // GOT IT
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('playVsAiButton')), findsOneWidget);
  });
}
