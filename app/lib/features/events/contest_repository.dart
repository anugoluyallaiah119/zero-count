import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';
import '../auth/auth_controller.dart';

class Contest {
  const Contest({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.sponsor,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? sponsor;

  bool get isLive => endsAt.isAfter(DateTime.now().toUtc());

  Duration get timeLeft => endsAt.difference(DateTime.now().toUtc());

  factory Contest.fromJson(Map<String, dynamic> j) => Contest(
        id: j['id'] as String,
        title: j['title'] as String,
        startsAt:
            DateTime.tryParse(j['startsAt'] as String? ?? '') ??
                DateTime.now(),
        endsAt:
            DateTime.tryParse(j['endsAt'] as String? ?? '') ??
                DateTime.now(),
        sponsor: j['sponsor'] as String?,
      );
}

class ContestStanding {
  const ContestStanding({
    required this.userId,
    required this.score,
    required this.rank,
    this.name = '',
    this.avatar = '',
    this.isMe = false,
  });

  final String userId;
  final int score;
  final int rank;
  final String name;
  final String avatar;
  final bool isMe;

  factory ContestStanding.fromJson(Map<String, dynamic> j, String myId) =>
      ContestStanding(
        userId: j['userId'] as String? ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        isMe: (j['userId'] as String? ?? '') == myId,
      );
}

class ContestRepository {
  ContestRepository(this._dio);
  final Dio _dio;

  Future<List<Contest>> list() async {
    final res = await _dio.get<List>('/api/contests');
    return (res.data ?? [])
        .map((e) => Contest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> enter(String contestId) async {
    await _dio.post<void>('/api/contests/$contestId/enter');
  }

  Future<({List<ContestStanding> standings, int myRank})> standings(
      String contestId, String myId) async {
    final res = await _dio.get<Map<String, dynamic>>(
        '/api/contests/$contestId/standings');
    final data = res.data ?? {};
    final list = (data['standings'] as List? ?? [])
        .map((e) =>
            ContestStanding.fromJson(e as Map<String, dynamic>, myId))
        .toList();
    final myRank = (data['myRank'] as num?)?.toInt() ?? -1;
    return (standings: list, myRank: myRank);
  }
}

final contestRepositoryProvider = Provider<ContestRepository>(
  (ref) => ContestRepository(ref.watch(dioProvider)),
);

final activeContestsProvider = FutureProvider<List<Contest>>(
  (ref) => ref.watch(contestRepositoryProvider).list(),
);

// Standings per contest id — family keeps each contest's data separate.
final contestStandingsProvider =
    FutureProvider.family<({List<ContestStanding> standings, int myRank}),
        String>((ref, contestId) {
  final repo = ref.watch(contestRepositoryProvider);
  final myId = ref.watch(authControllerProvider).userId ?? '';
  return repo.standings(contestId, myId);
});
