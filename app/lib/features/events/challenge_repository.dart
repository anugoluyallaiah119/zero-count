import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

class DailyChallenge {
  const DailyChallenge({
    required this.type,
    required this.target,
    required this.reward,
    required this.progress,
    required this.claimed,
    required this.canClaim,
  });

  final String type;
  final int target;
  final int reward;
  final int progress;
  final bool claimed;
  final bool canClaim;

  factory DailyChallenge.fromJson(Map<String, dynamic> j) => DailyChallenge(
        type: j['type'] as String,
        target: (j['target'] as num).toInt(),
        reward: (j['reward'] as num).toInt(),
        progress: (j['progress'] as num).toInt(),
        claimed: j['claimed'] as bool? ?? false,
        canClaim: j['canClaim'] as bool? ?? false,
      );

  String get title => switch (type) {
        'play_matches' => 'DAILY PLAY',
        'win_matches'  => 'ZERO STREAK',
        'call_show'    => 'CALL SHOW',
        _              => type.toUpperCase(),
      };

  String get description => switch (type) {
        'play_matches' => 'Play $target matches today',
        'win_matches'  => 'Win $target match${target > 1 ? "es" : ""} today',
        'call_show'    => 'Call Show $target time${target > 1 ? "s" : ""} today',
        _              => 'Complete $target times',
      };

  String get icon => switch (type) {
        'play_matches' => 'assets/art/ev_card_fan.png',
        'win_matches'  => 'assets/art/ev_flame_zero.png',
        'call_show'    => 'assets/art/ev_crystal_zero.png',
        _              => 'assets/art/ev_card_fan.png',
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
