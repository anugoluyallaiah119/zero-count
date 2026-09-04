import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

/// A shop catalog item returned by GET /api/shop.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.priceCoins,
    required this.owned,
  });

  final String id;
  final String kind;
  final String name;
  final int priceCoins;
  final bool owned;

  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
        id: j['id'] as String,
        kind: j['kind'] as String,
        name: j['name'] as String,
        priceCoins: (j['priceCoins'] as num).toInt(),
        owned: j['owned'] as bool? ?? false,
      );

  /// Approximate INR price label (900 coins ≈ ₹9, etc.).
  String get priceLabel {
    if (priceCoins == 0) return 'Free';
    final rupees = (priceCoins / 100).round();
    return '₹$rupees';
  }
}

class ShopException implements Exception {
  const ShopException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShopRepository {
  ShopRepository(this._dio);
  final Dio _dio;

  Future<List<ShopItem>> catalog() async {
    try {
      final res = await _dio.get<List>('/api/shop');
      return (res.data ?? [])
          .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ShopException(
          e.response?.data?['error'] as String? ?? 'Failed to load catalog');
    }
  }

  Future<int> buy(String itemId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
          '/api/shop/buy', data: {'itemId': itemId});
      return (res.data?['balance'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      final err = e.response?.data?['error'] as String?;
      throw ShopException(err == 'not_enough_coins'
          ? 'Not enough coins'
          : err ?? 'Purchase failed');
    }
  }

  Future<void> equip(String itemId) async {
    try {
      await _dio.post<void>('/api/shop/equip', data: {'itemId': itemId});
    } on DioException catch (e) {
      throw ShopException(
          e.response?.data?['error'] as String? ?? 'Equip failed');
    }
  }

  Future<List<String>> mine() async {
    try {
      final res = await _dio.get<List>('/api/shop/mine');
      return (res.data ?? []).map((e) => e.toString()).toList();
    } on DioException {
      return const [];
    }
  }
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ShopRepository(dio);
});

/// Live catalog with owned flags — refreshed after every purchase.
final shopCatalogProvider =
    AsyncNotifierProvider<ShopCatalogNotifier, List<ShopItem>>(
        ShopCatalogNotifier.new);

class ShopCatalogNotifier extends AsyncNotifier<List<ShopItem>> {
  @override
  Future<List<ShopItem>> build() =>
      ref.watch(shopRepositoryProvider).catalog();

  Future<void> buy(String itemId) async {
    await ref.read(shopRepositoryProvider).buy(itemId);
    ref.invalidateSelf();
  }

  Future<void> equip(String itemId) async {
    await ref.read(shopRepositoryProvider).equip(itemId);
    ref.invalidateSelf();
  }
}
