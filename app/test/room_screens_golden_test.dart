import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/player/profile_repository.dart';
import 'package:zerocount_app/features/room/create_room_screen.dart';
import 'package:zerocount_app/features/room/join_room_screen.dart';
import 'package:zerocount_app/features/room/recent_rooms.dart';

import 'widget_test.dart' show FakeAuthRepository, FakeProfileRepository;

/// Golden renders of the Create Room and Join Room screens at a 852x1846
/// phone viewport, matched against the Create_room / Join_room mockups.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderScope scopeFor(Widget home, {List<Override> extra = const []}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        profileRepositoryProvider
            .overrideWithValue(FakeProfileRepository()),
        ...extra,
      ],
      child: MaterialApp(home: home),
    );
  }

  testWidgets('create room screen matches mockup', (tester) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    await tester.runAsync(() async {
      await tester.pumpWidget(scopeFor(const CreateRoomScreen(classic: true)));
      // Large 2K banner art needs a few decode frames in the test renderer.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });

    expect(find.text('CREATE ROOM'), findsNWidgets(2)); // header + CTA
    expect(find.text('CLASSIC PLAY'), findsOneWidget);
    expect(find.text('ROOM NAME'), findsOneWidget);
    expect(find.text('SELECT PLAYERS'), findsOneWidget);
    expect(find.text('GAME SETTINGS'), findsOneWidget);
    expect(find.text('TARGET SCORE'), findsOneWidget);
    expect(find.text('TURN TIME'), findsOneWidget);
    expect(find.text('WILD CARDS'), findsOneWidget);
    expect(find.text('INVITE FRIENDS'), findsOneWidget);
    expect(find.byKey(const Key('createRoomConfirm')), findsOneWidget);

    await expectLater(
      find.byType(CreateRoomScreen),
      matchesGoldenFile('goldens/create_room_screen.png'),
    );
  });

  testWidgets('join room screen matches mockup', (tester) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'recent_rooms_v1': jsonEncode([
        const RecentRoom(
                code: 'ABC123',
                name: "Ananya's Room",
                host: 'Ananya',
                players: 3,
                maxPlayers: 4)
            .toJson(),
        const RecentRoom(
                code: 'XYZ789',
                name: "Vikram's Room",
                host: 'Vikram',
                players: 2,
                maxPlayers: 4)
            .toJson(),
        const RecentRoom(
                code: 'QWE456',
                name: "Karthik's Room",
                host: 'Karthik',
                players: 4,
                maxPlayers: 4)
            .toJson(),
        const RecentRoom(
                code: 'PLM321',
                name: "Sneha's Room",
                host: 'Sneha',
                players: 2,
                maxPlayers: 4)
            .toJson(),
      ]),
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(scopeFor(const JoinRoomScreen()));
      // Let the recent-rooms store finish loading from SharedPreferences.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(find.text('JOIN ROOM'), findsNWidgets(2)); // header + CTA
    expect(find.text('ENTER ROOM CODE'), findsOneWidget);
    expect(find.text('RECENT ROOMS'), findsOneWidget);
    expect(find.text("Ananya's Room"), findsOneWidget);
    expect(find.text("Don't have a room code?"), findsOneWidget);
    expect(find.byKey(const Key('roomCodeField')), findsOneWidget);
    expect(find.byKey(const Key('joinRoomConfirm')), findsOneWidget);

    await expectLater(
      find.byType(JoinRoomScreen),
      matchesGoldenFile('goldens/join_room_screen.png'),
    );
  });
}
