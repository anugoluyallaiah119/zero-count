import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

/// Possible notification kinds — mirrors the server Notification.Kind enum.
enum ZcNotifKind {
  friendRequest,
  challengeNudge,
  streakAtRisk,
  contestStarting,
  rewardGranted,
  rematchNudge,
  matchResult,
}

extension ZcNotifKindX on ZcNotifKind {
  String get serverName => switch (this) {
        ZcNotifKind.friendRequest => 'FRIEND_REQUEST',
        ZcNotifKind.challengeNudge => 'CHALLENGE_NUDGE',
        ZcNotifKind.streakAtRisk => 'STREAK_AT_RISK',
        ZcNotifKind.contestStarting => 'CONTEST_STARTING',
        ZcNotifKind.rewardGranted => 'REWARD_GRANTED',
        ZcNotifKind.rematchNudge => 'REMATCH_NUDGE',
        ZcNotifKind.matchResult => 'MATCH_RESULT',
      };

  String get displayName => switch (this) {
        ZcNotifKind.friendRequest => 'Friend requests',
        ZcNotifKind.challengeNudge => 'Daily challenge reminders',
        ZcNotifKind.streakAtRisk => 'Streak-at-risk alerts',
        ZcNotifKind.contestStarting => 'Contest starting alerts',
        ZcNotifKind.rewardGranted => 'Reward notifications',
        ZcNotifKind.rematchNudge => 'Rematch nudges',
        ZcNotifKind.matchResult => 'Match result summaries',
      };
}

/// An in-app notification banner model (foreground messages).
class ZcNotifBanner {
  const ZcNotifBanner({
    required this.title,
    required this.body,
    this.payload = const {},
  });
  final String title;
  final String body;
  final Map<String, String> payload;
}

/// Flutter-side push notification service.
///
/// Responsibilities:
///  1. Request FCM permission on first call.
///  2. Register the FCM token with the backend (/api/notifications/device).
///  3. Listen for foreground messages → emit ZcNotifBanner.
///  4. Refresh the token when FCM rotates it.
class PushNotificationService {
  PushNotificationService(this._dio);

  final Dio _dio;
  final _bannerController = StreamController<ZcNotifBanner>.broadcast();

  Stream<ZcNotifBanner> get banners => _bannerController.stream;

  /// Call once at startup (after Firebase.initializeApp).
  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS / macOS).
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Register current token.
    final token = await messaging.getToken();
    if (token != null) await _register(token);

    // Re-register when FCM rotates the token.
    messaging.onTokenRefresh.listen(_register);

    // Foreground message → in-app banner.
    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      if (notif == null) return;
      _bannerController.add(ZcNotifBanner(
        title: notif.title ?? '',
        body: notif.body ?? '',
        payload: msg.data.map((k, v) => MapEntry(k, v.toString())),
      ));
    });

    // Background/terminated tap → log for now; deep-link can go here.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('FCM tap: ${msg.data}');
    });
  }

  Future<void> _register(String token) async {
    try {
      await _dio.post<void>(
        '/api/notifications/device',
        data: {'token': token},
      );
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> muteKind(ZcNotifKind kind) async {
    await _dio.post<void>('/api/notifications/mute',
        data: {'kind': kind.serverName});
  }

  Future<void> unmuteKind(ZcNotifKind kind) async {
    await _dio.post<void>('/api/notifications/unmute',
        data: {'kind': kind.serverName});
  }

  Future<Set<ZcNotifKind>> mutes() async {
    final res = await _dio.get<List>('/api/notifications/mutes');
    final names = (res.data ?? []).map((e) => e.toString()).toSet();
    return ZcNotifKind.values
        .where((k) => names.contains(k.serverName))
        .toSet();
  }

  void dispose() => _bannerController.close();
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final svc = PushNotificationService(ref.watch(dioProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

/// Mute state — fetched once on settings screen open.
final notifMutesProvider = FutureProvider<Set<ZcNotifKind>>(
  (ref) => ref.watch(pushNotificationServiceProvider).mutes(),
);
