import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';
import '../auth/auth_controller.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.score,
    required this.rank,
    this.wins,
    this.matches,
    this.isMe = false,
  });

  final String userId;
  final String name;
  final String avatar;
  final int score;
  final int rank;
  final int? wins;
  final int? matches;
  final bool isMe;

  factory LeaderboardEntry.fromJson(
      Map<String, dynamic> j, int rank, String myId) {
    return LeaderboardEntry(
      userId: j['userId'] as String? ?? '',
      name: j['name'] as String? ?? 'Unknown',
      avatar: j['avatar'] as String? ?? '',
      score: (j['score'] as num?)?.toInt() ?? 0,
      rank: rank,
      wins: (j['wins'] as num?)?.toInt(),
      matches: (j['matches'] as num?)?.toInt(),
      isMe: (j['userId'] as String? ?? '') == myId,
    );
  }
}

class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.gameId,
    required this.endedAt,
    required this.finalScore,
    required this.placement,
    required this.seats,
  });

  final String gameId;
  final DateTime endedAt;
  final int finalScore;
  final int placement;
  final int seats;
  bool get isWin => placement == 1;

  factory MatchHistoryEntry.fromJson(Map<String, dynamic> j) =>
      MatchHistoryEntry(
        gameId: j['gameId'] as String? ?? '',
        endedAt: DateTime.tryParse(j['endedAt'] as String? ?? '') ??
            DateTime.now(),
        finalScore: (j['finalScore'] as num?)?.toInt() ?? 0,
        placement: (j['placement'] as num?)?.toInt() ?? 0,
        seats: (j['seats'] as num?)?.toInt() ?? 2,
      );
}

class LeaderboardRepository {
  LeaderboardRepository(this._dio);
  final Dio _dio;

  Future<List<LeaderboardEntry>> weekly(String myId) async {
    final res = await _dio.get<List>('/api/leaderboards/weekly');
    return (res.data ?? [])
        .asMap()
        .entries
        .map((e) => LeaderboardEntry.fromJson(
            e.value as Map<String, dynamic>, e.key + 1, myId))
        .toList();
  }

  Future<List<LeaderboardEntry>> alltime(String myId) async {
    final res = await _dio.get<List>('/api/leaderboards/alltime');
    return (res.data ?? [])
        .asMap()
        .entries
        .map((e) => LeaderboardEntry.fromJson(
            e.value as Map<String, dynamic>, e.key + 1, myId))
        .toList();
  }

  Future<List<MatchHistoryEntry>> history() async {
    final res = await _dio.get<List>('/api/leaderboards/history');
    return (res.data ?? [])
        .map((e) =>
            MatchHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => LeaderboardRepository(ref.watch(dioProvider)),
);

final weeklyLeaderboardProvider =
    FutureProvider<List<LeaderboardEntry>>((ref) {
  final repo = ref.watch(leaderboardRepositoryProvider);
  final myId = ref.watch(authControllerProvider).userId ?? '';
  return repo.weekly(myId);
});

final alltimeLeaderboardProvider =
    FutureProvider<List<LeaderboardEntry>>((ref) {
  final repo = ref.watch(leaderboardRepositoryProvider);
  final myId = ref.watch(authControllerProvider).userId ?? '';
  return repo.alltime(myId);
});

final matchHistoryProvider =
    FutureProvider<List<MatchHistoryEntry>>((ref) {
  final repo = ref.watch(leaderboardRepositoryProvider);
  return repo.history();
});
