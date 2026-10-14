import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/game/models.dart';

class Settings {
  const Settings({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.autoMoveSingle = true,
    this.lotteryStart = true,
    this.direction = MoveDirection.counterclockwise,
  });

  final bool soundEnabled;

  /// Вибрация при броске кубика.
  final bool vibrationEnabled;

  /// Если допустим ровно один ход — выполнять его автоматически.
  final bool autoMoveSingle;

  /// Кто ходит первым, решает жребий: все бросают кубик, у кого больше — тот первый.
  final bool lotteryStart;

  /// Направление хода фишек; применяется к новым партиям.
  final MoveDirection direction;

  Settings copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? autoMoveSingle,
    bool? lotteryStart,
    MoveDirection? direction,
  }) => Settings(
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    autoMoveSingle: autoMoveSingle ?? this.autoMoveSingle,
    lotteryStart: lotteryStart ?? this.lotteryStart,
    direction: direction ?? this.direction,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _soundKey = 'soundEnabled';
  static const _vibrationKey = 'vibrationEnabled';
  static const _autoMoveKey = 'autoMoveSingle';
  static const _lotteryKey = 'lotteryStart';
  static const _clockwiseKey = 'clockwise';

  @override
  Settings build() {
    _load();
    return const Settings();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = Settings(
        soundEnabled: prefs.getBool(_soundKey) ?? true,
        vibrationEnabled: prefs.getBool(_vibrationKey) ?? true,
        autoMoveSingle: prefs.getBool(_autoMoveKey) ?? true,
        lotteryStart: prefs.getBool(_lotteryKey) ?? true,
        direction: (prefs.getBool(_clockwiseKey) ?? false)
            ? MoveDirection.clockwise
            : MoveDirection.counterclockwise,
      );
    } catch (_) {
      // Хранилище недоступно — остаются значения по умолчанию.
    }
  }

  Future<void> setSound(bool value) async {
    state = state.copyWith(soundEnabled: value);
    await _save(_soundKey, value);
  }

  Future<void> setVibration(bool value) async {
    state = state.copyWith(vibrationEnabled: value);
    await _save(_vibrationKey, value);
  }

  Future<void> setAutoMove(bool value) async {
    state = state.copyWith(autoMoveSingle: value);
    await _save(_autoMoveKey, value);
  }

  Future<void> setLottery(bool value) async {
    state = state.copyWith(lotteryStart: value);
    await _save(_lotteryKey, value);
  }

  Future<void> setDirection(MoveDirection value) async {
    state = state.copyWith(direction: value);
    await _save(_clockwiseKey, value == MoveDirection.clockwise);
  }

  Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
