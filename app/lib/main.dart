import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'shared/analytics/analytics_service.dart';

void main() {
  runApp(const ProviderScope(child: ZeroCountApp()));
}

class ZeroCountApp extends ConsumerWidget {
  const ZeroCountApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // E4.4: start the analytics buffer and record the first funnel event.
    ref.watch(analyticsServiceProvider).track('app_start');
    return MaterialApp.router(
      title: 'Zero Count',
      theme: ZeroCountTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
