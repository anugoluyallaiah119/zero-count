import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/player/profile_repository.dart';
import 'package:zerocount_app/features/social/invite_screen.dart';

import 'widget_test.dart' show FakeAuthRepository, FakeProfileRepository;

/// Golden render of the Invite Friends screen (Invite_friends mockup) with
/// sample stats + friends injected via provider overrides.
void main() {
  testWidgets('invite friends screen matches mockup', (tester) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            profileRepositoryProvider
                .overrideWithValue(FakeProfileRepository()),
            inviteStatsProvider.overrideWith(
                (ref) => const InviteStats(
                    invited: 12, joined: 5, points: 1000)),
            inviteFriendsProvider.overrideWith((ref) => const [
                  InviteFriend(
                      name: 'Arjun Patel',
                      status: 'joined',
                      detail: 'Joined 2 days ago',
                      avatarIndex: 4),
                  InviteFriend(
                      name: 'Sneha Verma',
                      status: 'joined',
                      detail: 'Joined 3 days ago',
                      avatarIndex: 1),
                  InviteFriend(
                      name: 'Karan Singh',
                      status: 'joined',
                      detail: 'Joined 5 days ago',
                      avatarIndex: 0),
                  InviteFriend(
                      name: 'Priya Sharma',
                      status: 'pending',
                      detail: 'Invited',
                      avatarIndex: 6),
                ]),
          ],
          child: const MaterialApp(home: InviteFriendsScreen()),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });

    expect(find.text('INVITE FRIENDS'), findsOneWidget);
    expect(find.text('SHARE YOUR INVITE LINK'), findsOneWidget);
    expect(find.text('YOUR INVITE STATS'), findsOneWidget);
    expect(find.text('FRIENDS LIST'), findsOneWidget);
    expect(find.text('Arjun Patel'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.byKey(const Key('copyInviteLink')), findsOneWidget);
    expect(find.byKey(const Key('inviteBackToHome')), findsOneWidget);

    await expectLater(
      find.byType(InviteFriendsScreen),
      matchesGoldenFile('goldens/invite_friends_screen.png'),
    );
  });
}
