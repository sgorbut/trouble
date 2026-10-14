import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';

enum GameSound { roll, move, capture, win }

/// Проигрывает звуки из assets/sounds. Если файлов нет или аудио недоступно,
/// молча ничего не делает — игра работает и без звука.
class SoundService {
  SoundService(this._enabled);

  final bool Function() _enabled;
  final Map<GameSound, AudioPlayer> _players = {};
  final Map<GameSound, bool> _available = {};

  String _asset(GameSound s) => 'sounds/${s.name}.wav';

  Future<void> play(GameSound sound) async {
    if (!_enabled()) return;
    try {
      final available = _available[sound] ??= await _exists('assets/${_asset(sound)}');
      if (!available) return;
      final player = _players[sound] ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await player.stop();
      await player.play(AssetSource(_asset(sound)));
    } catch (_) {
      _available[sound] = false;
    }
  }

  Future<bool> _exists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
  }
}

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService(() => ref.read(settingsProvider).soundEnabled);
  ref.onDispose(service.dispose);
  return service;
});
