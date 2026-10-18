import 'package:flutter/material.dart';

import '../core/game/models.dart';
import 'theme.dart';

// Имена для быстрого выбора (quickNames) — в отдельном файле вне git.
export 'quick_names.dart';

/// Готовые аватары игроков (эмодзи — без файлов картинок).
const List<String> presetAvatars = [
  '🦊',
  '🐼',
  '🐯',
  '🦁',
  '🐸',
  '🐵',
  '🐨',
  '🐰',
  '🐻',
  '🐱',
  '🐶',
  '🦄',
  '🐧',
  '🐙',
  '🦉',
  '🐢',
  '🐝',
  '🦖',
  '🐳',
  '🤖',
];

/// Имя по картинке аватара — предлагается по умолчанию и среди быстрых имён.
const Map<String, String> avatarNames = {
  '🦊': 'Лиса',
  '🐼': 'Панда',
  '🐯': 'Тигр',
  '🦁': 'Лев',
  '🐸': 'Лягушка',
  '🐵': 'Обезьянка',
  '🐨': 'Коала',
  '🐰': 'Кролик',
  '🐻': 'Мишка',
  '🐱': 'Котик',
  '🐶': 'Пёс',
  '🦄': 'Единорог',
  '🐧': 'Пингвин',
  '🐙': 'Осьминог',
  '🦉': 'Сова',
  '🐢': 'Черепаха',
  '🐝': 'Пчёлка',
  '🦖': 'Динозавр',
  '🐳': 'Кит',
  '🤖': 'Робот',
};

/// Имя для аватара; для неизвестного — пустая строка.
String avatarName(String avatar) => avatarNames[avatar] ?? '';


/// Аватары по умолчанию на этот запуск: четыре разных, выбираются случайно один раз
/// при старте приложения.
final List<String> _launchAvatars = ([...presetAvatars]..shuffle()).take(4).toList();

/// Аватар по умолчанию для цвета (у каждого цвета свой, меняется от запуска к запуску).
String defaultAvatarFor(PlayerColor color) => _launchAvatars[color.index];

/// Круглый аватар в цвете игрока.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.color,
    required this.avatar,
    this.size = 40,
  });

  final PlayerColor color;
  final String avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(color.color, Colors.white, 0.75),
        border: Border.all(color: color.color, width: size * 0.07),
      ),
      child: avatar.isEmpty
          ? null
          : Text(avatar, style: TextStyle(fontSize: size * 0.55, height: 1.1)),
    );
  }
}
