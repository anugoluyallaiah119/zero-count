import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.rarity,
    required this.rewardCoins,
    required this.earned,
    this.earnedAt,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final String rarity;
  final int rewardCoins;
  final bool earned;
  final String? earnedAt;

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        icon: j['icon'] as String,
        rarity: j['rarity'] as String,
        rewardCoins: (j['rewardCoins'] as num).toInt(),
        earned: j['earned'] as bool? ?? false,
        earnedAt: j['earnedAt'] as String?,
      );

  static Color rarityColor(String rarity) => switch (rarity) {
        'legendary' => const Color(0xFFFFD700),
        'epic'      => const Color(0xFFBF40BF),
        'rare'      => const Color(0xFF4169E1),
        _           => const Color(0xFF6B7280),
      };
}

class AchievementRepository {
  const AchievementRepository(this._dio);
  final Dio _dio;

  Future<List<Achievement>> list() async {
    final res = await _dio.get<List<dynamic>>('/api/achievements');
    return res.data!.map((e) => Achievement.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepository(ref.watch(dioProvider)),
);

final achievementsProvider = FutureProvider<List<Achievement>>((ref) {
  return ref.watch(achievementRepositoryProvider).list();
});
