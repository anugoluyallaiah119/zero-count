import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

/// One queued analytics event.
class AnalyticsEvent {
  AnalyticsEvent(this.name, {this.props = const {}, DateTime? ts})
      : ts = ts ?? DateTime.now().toUtc();

  final String name;
  final Map<String, Object> props;
  final DateTime ts;

  Map<String, Object> toJson() => {
        'name': name,
        'ts': ts.toIso8601String(),
        'props': props,
      };
}

/// Client-side analytics pipeline (E4.4).
///
/// Events are buffered in memory and flushed to POST /api/events in batches
/// (max 100 per request, matching the server limit). Flushes happen when the
/// buffer hits [flushAt] events, on a 30s timer, or on demand via [flush].
/// Failed flushes keep the buffer so events are retried — analytics must
/// never crash or block gameplay, so every error is swallowed here.
class AnalyticsService {
  AnalyticsService(this._dio);

  static const int flushAt = 10;
  static const int maxBatch = 100;

  final Dio _dio;
  final List<AnalyticsEvent> _buffer = [];
  Timer? _timer;

  int get pending => _buffer.length;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  void track(String name, [Map<String, Object> props = const {}]) {
    _buffer.add(AnalyticsEvent(name, props: props));
    if (_buffer.length >= flushAt) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final batch = _buffer.take(maxBatch).toList();
    try {
      await _dio.post<Map<String, Object>>(
        '/api/events',
        data: {'events': batch.map((e) => e.toJson()).toList()},
      );
      // Remove only what the server accepted.
      _buffer.removeRange(0, batch.length);
    } on DioException {
      // Keep the buffer; retried on the next timer tick.
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final svc = AnalyticsService(ref.watch(dioProvider))..start();
  ref.onDispose(svc.dispose);
  return svc;
});
