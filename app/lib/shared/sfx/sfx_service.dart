import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SFX + haptics (G1.8) — ports V1's WebAudio tone moments to bundled WAV
/// assets, paired with platform haptics. A single low-latency player pool
/// keeps overlap cheap; muting persists across launches.
class SfxService {
  static const _muteKey = 'zc.sfxMuted';

  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;

  bool get muted => _muted;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_muteKey) ?? false;
    await _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, value);
  }

  Future<void> _play(String name) async {
    if (_muted) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sfx/$name.wav'));
    } catch (_) {
      // Audio must never break gameplay (web autoplay policies etc.).
    }
  }

  // ---- game moments (V1 parity) ----

  Future<void> draw() async {
    unawaited_(HapticFeedback.lightImpact());
    await _play('draw');
  }

  Future<void> discard() async {
    unawaited_(HapticFeedback.mediumImpact());
    await _play('discard');
  }

  Future<void> show() async {
    unawaited_(HapticFeedback.heavyImpact());
    await _play('show');
  }

  Future<void> zero() async {
    unawaited_(HapticFeedback.vibrate());
    await _play('zero');
  }

  Future<void> win() async => _play('win');
  Future<void> lose() async => _play('lose');

  Future<void> yourTurn() async {
    unawaited_(HapticFeedback.selectionClick());
    await _play('turn');
  }

  Future<void> error() async => _play('error');
}

void unawaited_(Future<void> f) {}

final sfxServiceProvider = Provider<SfxService>((ref) => SfxService());

/// UI-visible mute state (kept in sync with [SfxService.setMuted]).
final sfxMutedProvider = StateProvider<bool>((ref) => false);
