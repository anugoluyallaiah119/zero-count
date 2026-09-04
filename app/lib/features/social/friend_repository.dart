import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

class FriendEntry {
  const FriendEntry({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.online,
  });

  final String userId;
  final String name;
  final String avatar;
  final bool online;

  factory FriendEntry.fromJson(Map<String, dynamic> j) => FriendEntry(
        userId: j['userId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        avatar: j['avatar'] as String? ?? '',
        online: j['online'] as bool? ?? false,
      );
}

class FriendLists {
  const FriendLists({
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });
  final List<FriendEntry> friends;
  final List<FriendEntry> incoming;
  final List<FriendEntry> outgoing;

  factory FriendLists.fromJson(Map<String, dynamic> j) => FriendLists(
        friends: _parseList(j['friends']),
        incoming: _parseList(j['incoming']),
        outgoing: _parseList(j['outgoing']),
      );

  static List<FriendEntry> _parseList(dynamic l) =>
      (l as List? ?? [])
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
}

class FriendException implements Exception {
  const FriendException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FriendRepository {
  FriendRepository(this._dio);
  final Dio _dio;

  Future<FriendLists> lists() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/api/friends');
      return FriendLists.fromJson(res.data!);
    } on DioException catch (e) {
      throw FriendException(_msg(e));
    }
  }

  Future<List<FriendEntry>> search(String q) async {
    try {
      final res = await _dio.get<List>('/api/friends/search',
          queryParameters: {'q': q});
      return (res.data ?? [])
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw FriendException(_msg(e));
    }
  }

  /// Returns 'requested', 'accepted', or 'already_friends'.
  Future<String> request(String userId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
          '/api/friends/request', data: {'userId': userId});
      return res.data?['result'] as String? ?? 'requested';
    } on DioException catch (e) {
      throw FriendException(_msg(e));
    }
  }

  Future<void> accept(String userId) async {
    try {
      await _dio.post<void>('/api/friends/accept', data: {'userId': userId});
    } on DioException catch (e) {
      throw FriendException(_msg(e));
    }
  }

  Future<void> remove(String userId) async {
    try {
      await _dio.post<void>('/api/friends/remove', data: {'userId': userId});
    } on DioException catch (e) {
      throw FriendException(_msg(e));
    }
  }

  static String _msg(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['error'] is String) return d['error'] as String;
    return 'Request failed. Please try again.';
  }
}

final friendRepositoryProvider = Provider<FriendRepository>(
  (ref) => FriendRepository(ref.watch(dioProvider)),
);

final friendListsProvider =
    FutureProvider<FriendLists>((ref) {
  return ref.watch(friendRepositoryProvider).lists();
});
