import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

/// One lobby member.
class RoomMember {
  const RoomMember({
    required this.userId,
    required this.displayName,
    required this.ready,
  });

  factory RoomMember.fromJson(Map<String, Object?> j) => RoomMember(
        userId: j['userId'] as String,
        displayName: (j['name'] as String?) ?? 'Player',
        ready: j['ready'] as bool? ?? false,
      );

  final String userId;
  final String displayName;
  final bool ready;
}

/// Lobby snapshot from the room REST contract (E2.5).
class RoomLobby {
  const RoomLobby({
    required this.code,
    required this.hostId,
    required this.maxPlayers,
    required this.handSize,
    required this.target,
    required this.members,
  });

  factory RoomLobby.fromJson(Map<String, Object?> j) {
    final settings = (j['settings'] as Map?)?.cast<String, Object?>() ?? const {};
    final rawMembers = (j['members'] as List?) ?? const [];
    final members = rawMembers
        .map((m) => RoomMember.fromJson((m as Map).cast<String, Object?>()))
        .toList();
    // The contract marks the host inside the member list (host: true).
    final hostEntry = rawMembers
        .map((m) => (m as Map).cast<String, Object?>())
        .where((m) => m['host'] == true)
        .firstOrNull;
    return RoomLobby(
      code: j['code'] as String,
      hostId: (hostEntry?['userId'] as String?) ?? '',
      maxPlayers: (settings['maxPlayers'] as num?)?.toInt() ?? 4,
      handSize: (settings['handSize'] as num?)?.toInt() ?? 7,
      target: (settings['target'] as num?)?.toInt() ?? 100,
      members: members,
    );
  }

  final String code;
  final String hostId;
  final int maxPlayers;
  final int handSize;
  final int target;
  final List<RoomMember> members;

  bool get isFull => members.length >= maxPlayers;
  bool get startable => isFull && members.every((m) => m.ready);

  bool isHost(String userId) => hostId == userId;
}

class RoomException implements Exception {
  RoomException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Room REST client (M1.6) — create/join/ready/leave/get against E2.5.
class RoomRepository {
  RoomRepository(this._dio);

  final Dio _dio;

  Future<RoomLobby> create(
      {required int maxPlayers, required int handSize, required int target}) async {
    try {
      final r = await _dio.post<Map<String, Object?>>('/api/rooms',
          data: {'maxPlayers': maxPlayers, 'handSize': handSize, 'target': target});
      return RoomLobby.fromJson(r.data!);
    } on DioException catch (e) {
      throw RoomException(_msg(e));
    }
  }

  Future<RoomLobby> join(String code) async {
    try {
      final r = await _dio.post<Map<String, Object?>>(
          '/api/rooms/${code.toUpperCase()}/join', data: const {});
      return RoomLobby.fromJson(r.data!);
    } on DioException catch (e) {
      throw RoomException(_msg(e));
    }
  }

  Future<RoomLobby> setReady(String code, bool ready) async {
    try {
      final r = await _dio.post<Map<String, Object?>>(
          '/api/rooms/$code/ready', data: {'ready': ready});
      return RoomLobby.fromJson(r.data!);
    } on DioException catch (e) {
      throw RoomException(_msg(e));
    }
  }

  Future<void> leave(String code) async {
    try {
      await _dio.post<void>('/api/rooms/$code/leave', data: const {});
    } on DioException catch (e) {
      throw RoomException(_msg(e));
    }
  }

  Future<RoomLobby> get(String code) async {
    try {
      final r = await _dio.get<Map<String, Object?>>('/api/rooms/$code');
      return RoomLobby.fromJson(r.data!);
    } on DioException catch (e) {
      throw RoomException(_msg(e));
    }
  }

  static String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return 'Cannot reach the server. Is the backend running?';
  }
}

final roomRepositoryProvider =
    Provider<RoomRepository>((ref) => RoomRepository(ref.watch(dioProvider)));
