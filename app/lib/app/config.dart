import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';

/// Build flavors (E3.1): dev points at a local backend, prod at the real API.
/// Select with: flutter run --dart-define=FLAVOR=dev|prod
enum Flavor { dev, prod }

class AppConfig {
  const AppConfig({required this.flavor, required this.apiBaseUrl});

  final Flavor flavor;
  final String apiBaseUrl;

  static AppConfig fromEnvironment() {
    const name = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    switch (name) {
      case 'prod':
        return const AppConfig(
          flavor: Flavor.prod,
          apiBaseUrl: 'https://api.zerocount.app',
        );
      case 'dev':
      default:
        return const AppConfig(
          flavor: Flavor.dev,
          apiBaseUrl: String.fromEnvironment('API_BASE',
              defaultValue: 'http://localhost:8080'),
        );
    }
  }
}

final appConfigProvider =
    Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

/// Shared HTTP client for all backend calls. Attaches the live Bearer
/// token (if any) to every request; auth endpoints are exempt.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokens = ref.watch(tokenStoreProvider);
  final dio = Dio(BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    if (!options.path.startsWith('/api/auth/') && tokens.accessToken != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }));
  return dio;
});
