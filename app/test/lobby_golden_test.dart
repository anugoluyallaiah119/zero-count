import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerocount_app/features/auth/auth_controller.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/player/profile_repository.dart';
import 'package:zerocount_app/features/room/lobby_screen.dart';
import 'package:zerocount_app/features/room/room_repository.dart';

import 'widget_test.dart' show FakeAuthRepository, FakeProfileRepository;

/// In-memory room repository serving a fixed two-player lobby.
class FakeRoomRepository implements RoomRepository {
  final lobby = const RoomLobby(
    code: '7X4K2B',
    hostId: 'user-1',
    maxPlayers: 4,
    handSize: 13,
    target: 200,
    members: [
      RoomMember(userId: 'user-1', displayName: 'Rahul', ready: true),
      RoomMember(userId: 'user-2', displayName: 'Ananya', ready: true),
    ],
  );

  @override
  Future<RoomLobby> get(String code) async => lobby;

  @override
  Future<RoomLobby> create(
          {required int maxPlayers,
          required int handSize,
          required int target}) async =>
      lobby;

  @override
  Future<RoomLobby> join(String code) async => lobby;

  @override
  Future<RoomLobby> setReady(String code, bool ready) async => lobby;

  @override
  Future<void> leave(String code) async {}
}

/// Golden render of the redesigned room lobby (Play_inside_room mockup).
void main() {
  testWidgets('lobby screen matches mockup', (tester) async {
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
          child: const MaterialApp(home: LobbyScreen(code: '7X4K2B')),
        ),
      );
      // Authenticate as the host (user-1) so the host START GAME card shows.
      final container = ProviderScope.containerOf(
          tester.element(find.byType(LobbyScreen)));
      await container
          .read(authControllerProvider.notifier)
          .verifyOtp('test-session', '123456');
      // Poll timer + large banner art decode.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });

    expect(find.text("Rahul's Room"), findsOneWidget);
    expect(find.text('Room is Ready!'), findsOneWidget);
    expect(find.text('CLASSIC PLAY'), findsOneWidget);
    expect(find.text('ROOM SETTINGS'), findsOneWidget);
    expect(find.text('INVITE FRIENDS'), findsOneWidget);
    // Host view (FakeAuthRepository user-1 is host): START GAME visible.
    expect(find.byKey(const Key('startMatchButton')), findsOneWidget);

    await expectLater(
      find.byType(LobbyScreen),
      matchesGoldenFile('goldens/lobby_screen.png'),
    );
  });
}
