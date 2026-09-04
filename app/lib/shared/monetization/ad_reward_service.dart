import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../app/config.dart';

/// Ad unit IDs — use test IDs by default; real IDs are set via env at build.
/// Replace with your AdMob IDs before release:
///   --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-xxx~xxx
///   --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-xxx~xxx
const _testAndroid = 'ca-app-pub-3940256099942544/5224354917';
const _testIos = 'ca-app-pub-3940256099942544/1712485313';

const _adUnitId = kReleaseMode
    ? String.fromEnvironment(
        Platform.isAndroid
            ? 'ADMOB_REWARDED_ANDROID'
            : 'ADMOB_REWARDED_IOS',
        defaultValue: '')
    : (kIsWeb ? '' : '');

String get _effectiveAdUnit =>
    _adUnitId.isNotEmpty
        ? _adUnitId
        : Platform.isAndroid
            ? _testAndroid
            : _testIos;

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
  RewardedAd? _preloaded;

  Future<void> init() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    _preload();
  }

  void _preload() {
    if (kIsWeb) return;
    RewardedAd.load(
      adUnitId: _effectiveAdUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _preloaded = ad,
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded ad load failed: $err');
          _preloaded = null;
        },
      ),
    );
  }

  /// Fetches today's ad status from the server.
  Future<AdStatus> status() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/wallet/ad-status');
    final d = res.data!;
    return AdStatus(
      adsWatchedToday: (d['adsWatchedToday'] as num).toInt(),
      dailyCap: (d['dailyCap'] as num).toInt(),
      coinsPerAd: (d['coinsPerAd'] as num).toInt(),
    );
  }

  /// Shows a rewarded ad. On completion, claims coins from the server.
  /// Returns the new wallet coin balance, or null if the ad was not shown.
  Future<({int coins, int balance})?> watchAndEarn() async {
    if (kIsWeb) {
      // Web fallback — no ad SDK, simulate for dev purposes.
      return _claimOnServer();
    }
    final ad = _preloaded;
    if (ad == null) {
      // No preloaded ad; try to load synchronously (will likely fail).
      _preload();
      return null;
    }
    _preloaded = null; // consume
    final result = await _showAd(ad);
    _preload(); // start preloading the next one
    if (!result) return null;
    return _claimOnServer();
  }

  /// Returns true if the user earned the reward.
  Future<bool> _showAd(RewardedAd ad) async {
    final completer = Future<bool>.value(false);
    bool earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) => a.dispose(),
      onAdFailedToShowFullScreenContent: (a, _) => a.dispose(),
    );
    late final Future<bool> done;
    final notifier = ValueNotifier<bool?>(null);
    ad.show(onUserEarnedReward: (_, __) {
      earned = true;
      notifier.value = true;
    });
    // Wait for dismiss (earned or skipped).
    await Future.delayed(const Duration(seconds: 1));
    for (var i = 0; i < 60 && notifier.value == null; i++) {
      await Future.delayed(const Duration(seconds: 1));
    }
    return earned;
  }

  Future<({int coins, int balance})?> _claimOnServer() async {
    final nonce =
        DateTime.now().millisecondsSinceEpoch.toRadixString(16) +
            '-' +
            identityHashCode(this).toRadixString(16);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/wallet/ad-reward',
        data: {'nonce': nonce},
      );
      final d = res.data!;
      if (d['granted'] == true) {
        return (
          coins: (d['coins'] as num).toInt(),
          balance: (d['balance'] as num).toInt()
        );
      }
    } catch (e) {
      debugPrint('Ad claim failed: $e');
    }
    return null;
  }

  void dispose() => _preloaded?.dispose();
}

final adRewardServiceProvider = Provider<AdRewardService>((ref) {
  final svc = AdRewardService(ref.watch(dioProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

final adStatusProvider = FutureProvider<AdStatus>((ref) {
  return ref.watch(adRewardServiceProvider).status();
});
