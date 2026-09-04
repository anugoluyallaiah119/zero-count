import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import '../../app/config.dart';
import '../analytics/analytics_service.dart';

/// All product ids must be registered in Google Play Console
/// and App Store Connect before release.
///
/// Naming convention: zc_coins_AMOUNT  /  zc_gems_AMOUNT
class IapCatalog {
  static const coinProducts = [
    _IapProduct(id: 'zc_coins_1000',   coins: 1000,  priceDisplay: '₹9',   label: '1,000'),
    _IapProduct(id: 'zc_coins_5000',   coins: 5000,  priceDisplay: '₹39',  label: '5,000'),
    _IapProduct(id: 'zc_coins_10000',  coins: 10000, priceDisplay: '₹79',  label: '10,000'),
    _IapProduct(id: 'zc_coins_25000',  coins: 25000, priceDisplay: '₹189', label: '25,000'),
  ];

  static const gemProducts = [
    _IapProduct(id: 'zc_gems_60',   gems: 60,   priceDisplay: '₹9',   label: '60'),
    _IapProduct(id: 'zc_gems_250',  gems: 250,  priceDisplay: '₹39',  label: '250'),
    _IapProduct(id: 'zc_gems_520',  gems: 520,  priceDisplay: '₹79',  label: '520'),
    _IapProduct(id: 'zc_gems_1100', gems: 1100, priceDisplay: '₹149', label: '1,100'),
  ];

  static Set<String> get allIds => {
    for (final p in [...coinProducts, ...gemProducts]) p.id,
  };
}

class _IapProduct {
  const _IapProduct({
    required this.id,
    this.coins,
    this.gems,
    required this.priceDisplay,
    required this.label,
  });
  final String id;
  final int? coins;
  final int? gems;
  final String priceDisplay; // fallback if platform price not loaded
  final String label;
}

enum IapPurchaseState { idle, purchasing, success, error, unavailable }

class IapPurchaseResult {
  const IapPurchaseResult(this.state, {this.message, this.coins, this.gems});
  final IapPurchaseState state;
  final String? message;
  final int? coins;
  final int? gems;
}

/// Wraps in_app_purchase and the server claim endpoint.
class IapService {
  IapService(this._dio, this._analytics);
  final Dio _dio;
  final AnalyticsService _analytics;

  final _iap = InAppPurchase.instance;
  final _resultController =
      StreamController<IapPurchaseResult>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Map<String, ProductDetails> _products = {};

  Stream<IapPurchaseResult> get results => _resultController.stream;
  Map<String, ProductDetails> get products => Map.unmodifiable(_products);

  bool get isAvailable => !kIsWeb;

  Future<void> init() async {
    if (!isAvailable) return;
    final available = await _iap.isAvailable();
    if (!available) return;

    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (e) => _resultController
          .add(IapPurchaseResult(IapPurchaseState.error, message: e.toString())),
    );

    // Load product details from the platform.
    final resp = await _iap.queryProductDetails(IapCatalog.allIds);
    _products = {for (final p in resp.productDetails) p.id: p};
  }

  Future<void> buy(String productId) async {
    if (!isAvailable) {
      _resultController.add(const IapPurchaseResult(
          IapPurchaseState.unavailable,
          message: 'Store not available on this device.'));
      return;
    }
    final product = _products[productId];
    if (product == null) {
      _resultController.add(IapPurchaseResult(IapPurchaseState.unavailable,
          message: 'Product $productId not found in store.'));
      return;
    }
    _resultController
        .add(const IapPurchaseResult(IapPurchaseState.purchasing));
    final param = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: param);
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _claimOnServer(p);
      } else if (p.status == PurchaseStatus.error) {
        _resultController.add(IapPurchaseResult(IapPurchaseState.error,
            message: p.error?.message ?? 'Purchase failed'));
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  Future<void> _claimOnServer(PurchaseDetails p) async {
    final platform = Platform.isAndroid ? 'google' : 'apple';
    final token = Platform.isAndroid
        ? (p as GooglePlayPurchaseDetails).purchaseID ?? ''
        : (p as AppStorePurchaseDetails).purchaseID ?? '';
    final nonce = '${p.purchaseID}-${p.productID}';
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/wallet/iap-claim',
        data: {
          'platform': platform,
          'productId': p.productID,
          'purchaseToken': token,
          'nonce': nonce,
        },
      );
      final d = res.data!;
      if (d['granted'] == true) {
        _analytics.track('iap_purchase', {
          'productId': p.productID,
          'platform': platform,
        });
        _resultController.add(IapPurchaseResult(
          IapPurchaseState.success,
          coins: d['amount'] as int?,
          gems: d['gems'] as int?,
        ));
      }
    } catch (e) {
      _resultController.add(IapPurchaseResult(IapPurchaseState.error,
          message: 'Server claim failed: $e'));
    }
  }

  void dispose() {
    _sub?.cancel();
    _resultController.close();
  }
}

final iapServiceProvider = Provider<IapService>((ref) {
  final svc = IapService(
      ref.watch(dioProvider), ref.watch(analyticsServiceProvider));
  ref.onDispose(svc.dispose);
  return svc;
});
