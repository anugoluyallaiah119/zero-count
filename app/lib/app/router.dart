import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/profile_setup_screen.dart';
import '../features/game/choose_game_screen.dart';
import '../features/game/game_screen.dart';
import '../features/tutorial/tutorial_screen.dart';
import '../features/home/home_screen.dart';
import '../features/room/create_room_screen.dart';
import '../features/room/join_room_screen.dart';
import '../features/room/lobby_screen.dart';
import '../features/match/countdown_screen.dart';
import '../features/match/live_game_screen.dart';
import '../features/social/invite_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/events/events_screen.dart';
import '../features/collection/store_screen.dart';
import '../features/player/leaderboard_screen.dart';
import '../shared/push/notification_settings_screen.dart';

/// App navigation. Routes:
///   /              splash → restores session, routes login vs home (E3.3)
///   /login         phone entry
///   /otp           OTP verification (requires OtpArgs via `extra`)
///   /profile-setup avatar + name for new users (E3.4)
///   /home          play modes + profile summary
///
/// Auth gate (E3.4): redirects re-run whenever auth state changes —
/// deep links/reloads can never reach a guarded screen without a session
/// (fixes: reload on /home fetching the profile before tokens restore).
/// The router is created ONCE and listens to auth via [refreshListenable];
/// rebuilding it per state change would reset navigation to '/'.
final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod auth state into a Listenable for go_router.
  final authChanges = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, __) => authChanges.value++);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (loc == '/') return null; // splash decides after restore
      switch (auth.status) {
        case AuthStatus.unknown:
          return '/'; // session restore still in flight
        case AuthStatus.unauthenticated:
          if (loc == '/login') return null;
          // Login flow: /otp is reachable with args from /login.
          if (loc == '/otp' && state.extra != null) return null;
          return '/login';
        case AuthStatus.authenticated:
          if (loc == '/login') return '/home';
          // /otp requires navigation args; a bare reload lands on home.
          if (loc == '/otp' && state.extra == null) return '/home';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) =>
            OtpScreen(args: state.extra! as OtpArgs),
      ),
      GoRoute(
          path: '/profile-setup',
          builder: (context, state) => const ProfileSetupScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
          path: '/create-room',
          builder: (context, state) =>
              CreateRoomScreen(classic: state.extra as bool? ?? false)),
      GoRoute(
          path: '/join-room',
          builder: (context, state) => const JoinRoomScreen()),
      GoRoute(
          path: '/invite-friends',
          builder: (context, state) => const InviteFriendsScreen()),
      GoRoute(
          path: '/tutorial',
          builder: (context, state) => const TutorialScreen()),
      GoRoute(
          path: '/choose-game',
          builder: (context, state) => ChooseGameScreen(
              initialMode: state.extra as String? ?? 'quick')),
      GoRoute(
        path: '/game',
        builder: (context, state) {
          final extra = state.extra;
          final args = extra is GameArgs
              ? extra
              : extra is String
                  ? GameArgs(mode: extra)
                  : const GameArgs();
          return GameScreen(args: args);
        },
      ),
      GoRoute(
          path: '/lobby/:code',
          builder: (context, state) =>
              LobbyScreen(code: state.pathParameters['code']!)),
      GoRoute(
          path: '/countdown/:code',
          builder: (context, state) =>
              CountdownScreen(code: state.pathParameters['code']!)),
      GoRoute(
          path: '/match/:code',
          builder: (context, state) =>
              LiveGameScreen(code: state.pathParameters['code']!)),
      GoRoute(
          path: '/events',
          builder: (context, state) => EventsScreen(
              initialTab: state.extra as int? ?? 0)),
      GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen()),
      GoRoute(
          path: '/notification-settings',
          builder: (context, state) => const NotificationSettingsScreen()),
      GoRoute(
          path: '/collection',
          builder: (context, state) => StoreScreen(
                initialTab: state.uri.queryParameters['tab'],
              )),
      GoRoute(
          path: '/collection/card-backs',
          redirect: (_, __) => '/collection?tab=card-backs'),
      GoRoute(
          path: '/collection/special-cards',
          redirect: (_, __) => '/collection?tab=special-cards'),
      GoRoute(
          path: '/collection/avatars',
          redirect: (_, __) => '/collection?tab=avatars'),
      GoRoute(
          path: '/collection/themes',
          redirect: (_, __) => '/collection?tab=themes'),
      GoRoute(
          path: '/collection/effects',
          redirect: (_, __) => '/collection?tab=effects'),
      GoRoute(
          path: '/collection/stickers',
          redirect: (_, __) => '/collection?tab=stickers'),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    authChanges.dispose();
  });
  return router;
});
