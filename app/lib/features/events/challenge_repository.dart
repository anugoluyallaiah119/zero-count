import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

class DailyChallenge {
  const DailyChallenge({
    required this.type,
    required this.title,
    required this.description,
    required this.cadence,
    required this.target,
    required this.rewardCoins,
    required this.rewardGems,
    required this.progress,
    required this.claimed,
    required this.canClaim,
    this.rewardCosmeticId,
    this.sponsorName,
  });

  final String type;
  final String title;
  final String description;
  final String cadence;
  final int target;
  final int rewardCoins;
  final int rewardGems;
  final int progress;
  final bool claimed;
  final bool canClaim;
  final String? rewardCosmeticId;
  final String? sponsorName;

  // back-compat used by the card widget
  int get reward => rewardCoins;

  factory DailyChallenge.fromJson(Map<String, dynamic> j) => DailyChallenge(
        type:             j['type'] as String,
        title:            (j['title'] as String?)?.toUpperCase() ?? _autoTitle(j['type'] as String),
        description:      (j['description'] as String?)?.isNotEmpty == true
                              ? j['description'] as String
                              : _autoDesc(j['type'] as String, (j['target'] as num).toInt()),
        cadence:          j['cadence'] as String? ?? 'daily',
        target:           (j['target'] as num).toInt(),
        rewardCoins:      (j['rewardCoins'] as num?)?.toInt() ?? (j['reward'] as num).toInt(),
        rewardGems:       (j['rewardGems'] as num?)?.toInt() ?? 0,
        progress:         (j['progress'] as num).toInt(),
        claimed:          j['claimed'] as bool? ?? false,
        canClaim:         j['canClaim'] as bool? ?? false,
        rewardCosmeticId: j['rewardCosmeticId'] as String?,
        sponsorName:      j['sponsorName'] as String?,
      );

  String get icon => switch (type) {
        'play_matches' => 'assets/art/ev_card_fan.png',
        'win_matches'  => 'assets/art/ev_flame_zero.png',
        'call_show'    => 'assets/art/ev_crystal_zero.png',
        _              => 'assets/art/ev_card_fan.png',
      };

  static String _autoTitle(String type) => switch (type) {
        'play_matches' => 'DAILY PLAY',
        'win_matches'  => 'ZERO STREAK',
        'call_show'    => 'CALL SHOW',
        _              => type.toUpperCase().replaceAll('_', ' '),
      };

  static String _autoDesc(String type, int target) => switch (type) {
        'play_matches' => 'Play $target matches today',
        'win_matches'  => 'Win $target match${target > 1 ? "es" : ""} today',
        'call_show'    => 'Call Show $target time${target > 1 ? "s" : ""} today',
        _              => 'Complete $target times',
      };
}

class ChallengeRepository {
  const ChallengeRepository(this._dio);
  final Dio _dio;

  Future<DailyChallenge> today() async {
    final res =
        await _dio.get<Map<String, dynamic>>('/api/challenges/today');
    return DailyChallenge.fromJson(res.data!);
  }

  Future<DailyChallenge> claim() async {
    final res =
        await _dio.post<Map<String, dynamic>>('/api/challenges/claim');
    return DailyChallenge.fromJson(res.data!);
  }
}

final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepository(ref.watch(dioProvider)),
);

final dailyChallengeProvider = FutureProvider<DailyChallenge>((ref) {
  return ref.watch(challengeRepositoryProvider).today();
});
