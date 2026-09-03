import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One entry in the JOIN ROOM "recent rooms" list.
class RecentRoom {
  const RecentRoom({
    required this.code,
    required this.name,
    required this.host,
    required this.players,
    required this.maxPlayers,
  });

  final String code;
  final String name;
  final String host;
  final int players;
  final int maxPlayers;

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'host': host,
        'players': players,
        'maxPlayers': maxPlayers,
      };

  factory RecentRoom.fromJson(Map<String, dynamic> j) => RecentRoom(
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? 'Room',
        host: j['host'] as String? ?? '',
        players: (j['players'] as num?)?.toInt() ?? 1,
        maxPlayers: (j['maxPlayers'] as num?)?.toInt() ?? 4,
      );
}

/// Locally persisted list of the rooms the player recently created or joined
/// (newest first, max 6). The backend has no "recent rooms" endpoint, so the
/// Join screen keeps them on-device.
class RecentRoomsStore extends Notifier<List<RecentRoom>> {
  static const _key = 'recent_rooms_v1';

  @override
  List<RecentRoom> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => RecentRoom.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      state = list;
    } on FormatException {
      // Corrupted cache — start fresh.
    }
  }

  Future<void> remember(RecentRoom room) async {
    final next = [
      room,
      ...state.where((r) => r.code != room.code),
    ].take(6).toList();
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(next.map((r) => r.toJson()).toList()));
  }
}

final recentRoomsProvider =
    NotifierProvider<RecentRoomsStore, List<RecentRoom>>(RecentRoomsStore.new);
