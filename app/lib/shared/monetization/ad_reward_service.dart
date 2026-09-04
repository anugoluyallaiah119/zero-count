import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../../app/config.dart';

/// Unity Ads credentials — from Unity Dashboard → Monetization.
/// Game ID: 800367330
/// Placement: Rewarded_Android
const _kGameIdAndroid = '800367330';
const _kGameIdIos = '800367330'; // update if you make a separate iOS app
const _kPlacement = 'Rewarded_Android';

class AdStatus {
  const AdStatus({
    required this.adsWatchedToday,
    required this.dailyCap,
    required this.coinsPerAd,
  });
  final int adsWatchedToday;
  final int dailyCap;
  final int coinsPerAd;

  int get remaining => (dailyCap - adsWatchedToday).clamp(0, dailyCap);
  bool get canWatch => remaining > 0;
}

class AdRewardService {
  AdRewardService(this._dio);
  final Dio _dio;

  bool _sdkReady = false;
  bool _adReady = false;

  Future<void> init() async {
    if (kIsWeb || _sdkReady) return;
    _sdkReady = true;
    await UnityAds.init(
      gameId: defaultTargetPlatform == TargetPlatform.android
          ? _kGameIdAndroid
          : _kGameIdIos,
      testMode: kDebugMode, // shows test ads in debug builds
      onComplete: () => _loadAd(),
      onFailed: (err, msg) =>
          debugPrint('Unity Ads init failed: $err $msg'),
    );
  }

  void _loadAd() {
    UnityAds.load(
      placementId: _kPlacement,
      onComplete: (_) {
        _adReady = true;
        debugPrint('Unity Ads: ad ready');
      },
      onFailed: (_, err, msg) {
        _adReady = false;
        debugPrint('Unity Ads load failed: $err $msg');
      },
    );
  }

  /// Fetches today's ad quota from the server.
  Future<AdStatus> status() async {
    final res =
        await _dio.get<Map<String, dynamic>>('/api/wallet/ad-status');
    final d = res.data!;
    return AdStatus(
      adsWatchedToday: (d['adsWatchedToday'] as num).toInt(),
      dailyCap: (d['dailyCap'] as num).toInt(),
      coinsPerAd: (d['coinsPerAd'] as num).toInt(),
    );
  }

  /// Shows the Unity rewarded ad. On completion claims 50 coins from server.
  /// Returns (coins, balance) on success, null if skipped or unavailable.
  Future<({int coins, int balance})?> watchAndEarn() async {
    if (kIsWeb) return _claimOnServer(); // dev fallback
    if (!_adReady) {
      debugPrint('Unity Ads: no ad loaded yet');
      _loadAd();
      return null;
    }

    final c = _Once<bool>();
    UnityAds.showVideoAd(
      placementId: _kPlacement,
      onStart: (_) {},
      onClick: (_) {},
      onSkipped: (_) {
        c.complete(false);
        _adReady = false;
        _loadAd();
      },
      onComplete: (_) {
        c.complete(true);
        _adReady = false;
        _loadAd();
      },
      onFailed: (_, err, msg) {
        debugPrint('Unity Ads show failed: $err $msg');
        c.complete(false);
        _adReady = false;
        _loadAd();
      },
    );

    final earned = await c.future;
    if (!earned) return null;
    return _claimOnServer();
  }

  Future<({int coins, int balance})?> _claimOnServer() async {
    final nonce =
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}'
        '-${identityHashCode(this).toRadixString(16)}';
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/wallet/ad-reward',
        data: {'nonce': nonce},
      );
      final d = res.data!;
      if (d['granted'] == true) {
        return (
          coins: (d['coins'] as num).toInt(),
          balance: (d['balance'] as num).toInt(),
        );
      }
    } catch (e) {
      debugPrint('Ad claim error: $e');
    }
    return null;
  }
}

/// Single-use completer — ignores duplicate calls.
class _Once<T> {
  final _c = Completer<T>();
  Future<T> get future => _c.future;
  void complete(T v) { if (!_c.isCompleted) _c.complete(v); }
}

final adRewardServiceProvider = Provider<AdRewardService>(
  (ref) => AdRewardService(ref.watch(dioProvider)),
);

final adStatusProvider = FutureProvider<AdStatus>(
  (ref) => ref.watch(adRewardServiceProvider).status(),
);
