import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

/// Player profile + stats — mirrors the E2.4 GET /api/players/me contract.
class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.phoneMasked,
    required this.name,
    required this.avatar,
    required this.coins,
    required this.gems,
    required this.matches,
    required this.wins,
    required this.zerosMade,
    required this.bestCount,
    required this.streakDays,
    required this.elo,
    required this.winStreak,
    required this.bestWinStreak,
  });

  final String id;
  final String phoneMasked;
  final String name;
  final String avatar;
  final int coins;
  final int gems;
  final int matches;
  final int wins;
  final int zerosMade;
  final int bestCount; // -1 = none yet
  final int streakDays;
  final int elo;
  /// R1.6 — current run of consecutive match wins (reset on any loss).
  final int winStreak;
  /// R1.6 — personal all-time peak.
  final int bestWinStreak;

  /// Display name — new users haven't picked one yet.
  String get displayName => name.isEmpty ? 'You' : name;

  /// Client-side progression display derived from real match counts:
  /// level up every 10 matches, XP bar shows progress into the level.
  int get level => 1 + matches ~/ 10;
  double get levelProgress => (matches % 10) / 10.0;

  factory PlayerProfile.fromJson(Map<String, dynamic> j) {
    final stats = (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    int asInt(Object? v, [int fallback = 0]) =>
        v is num ? v.toInt() : fallback;
    return PlayerProfile(
      id: j['id'] as String? ?? '',
      phoneMasked: j['phone'] as String? ?? '',
      name: j['name'] as String? ?? '',
      avatar: j['avatar'] as String? ?? '',
      coins: asInt(j['coins']),
      gems: asInt(j['gems']),
      matches: asInt(stats['matches']),
      wins: asInt(stats['wins']),
      zerosMade: asInt(stats['zerosMade']),
      bestCount: asInt(stats['bestCount'], -1),
      streakDays: asInt(stats['streakDays']),
      elo: asInt(stats['elo'], 1200),
      winStreak: asInt(stats['winStreak']),
      bestWinStreak: asInt(stats['bestWinStreak']),
    );
  }
}

class ProfileException implements Exception {
  const ProfileException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the E2.4 player endpoints (Bearer token attached by the dio
/// interceptor).
class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<PlayerProfile> me() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/players/me');
      return PlayerProfile.fromJson(res.data!);
    } on DioException catch (e) {
      throw ProfileException(_message(e));
    }
  }

  /// Partial update (E2.4 PATCH): name and/or avatar.
  Future<PlayerProfile> update({String? name, String? avatar}) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/players/me',
        data: {
          if (name != null) 'name': name,
          if (avatar != null) 'avatar': avatar,
        },
      );
      return PlayerProfile.fromJson(res.data!);
    } on DioException catch (e) {
      throw ProfileException(_message(e));
    }
  }

  static String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return 'Could not reach the server. Please try again.';
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);

/// Live profile for the home screen. Refreshed after login and after
/// profile edits (screens call `ref.invalidate(profileProvider)`).
final profileProvider = FutureProvider<PlayerProfile>(
  (ref) => ref.watch(profileRepositoryProvider).me(),
);
