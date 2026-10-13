import 'package:flutter/material.dart';

import '../core/game/models.dart';

extension PlayerColorUi on PlayerColor {
  Color get color => switch (this) {
        PlayerColor.red => const Color(0xFFE53935),
        PlayerColor.blue => const Color(0xFF1E88E5),
        PlayerColor.yellow => const Color(0xFFFBC02D),
        PlayerColor.green => const Color(0xFF43A047),
      };

  Color get dark => HSLColor.fromColor(color).withLightness(0.32).toColor();

  Color get light => Color.lerp(color, Colors.white, 0.45)!;

  /// Цвет текста поверх цвета игрока.
  Color get onColor => this == PlayerColor.yellow ? Colors.black87 : Colors.white;
}

class AppTheme {
  static const boardBackground = Color(0xFFF6F1E4);
  static const cellBorder = Color(0xFFC9C6BF);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF5C6BC0));
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(220, 52),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(220, 52),
          textStyle: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
