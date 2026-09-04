import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'shared/analytics/analytics_service.dart';
import 'shared/monetization/ad_reward_service.dart';
import 'shared/monetization/iap_service.dart';
import 'shared/push/notification_settings_screen.dart';
import 'shared/push/push_notification_service.dart';

/// Background message handler — must be top-level (FCM requirement).
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage msg) async {
  // Firebase.initializeApp is called here automatically by firebase_messaging.
  debugPrint('FCM bg: ${msg.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
  } catch (_) {
    // Firebase is optional — the app runs fine without it (dev builds without
    // google-services.json / GoogleService-Info.plist).
  }
  runApp(const ProviderScope(child: ZeroCountApp()));
}

class ZeroCountApp extends ConsumerWidget {
  const ZeroCountApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(analyticsServiceProvider).track('app_start');
    // Register FCM token once the user is authenticated.
    // Best-effort: silently swallows errors if Firebase is not configured.
    final push = ref.watch(pushNotificationServiceProvider);
    Future.microtask(() async {
      try { await push.init(); } catch (_) {}
    });
    // Init AdMob + IAP — best-effort, no crash if SDK unavailable.
    final ads = ref.watch(adRewardServiceProvider);
    final iap = ref.watch(iapServiceProvider);
    Future.microtask(() async {
      try { await ads.init(); } catch (_) {}
      try { await iap.init(); } catch (_) {}
    });
    return ZcNotifBannerOverlay(
      child: MaterialApp.router(
      title: 'Zero Count',
      theme: ZeroCountTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      ),
    );
    );
  }
}
