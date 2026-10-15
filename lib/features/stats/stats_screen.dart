import 'package:flutter/material.dart';

import '../../core/game/models.dart';
import '../../ui/avatars.dart';
import '../../ui/theme.dart';

/// Статистика партии по каждому игроку. Наибольшее значение в каждой категории
/// выделено жирным (при равенстве — у всех лидеров; нули не выделяются).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.players, this.winner});

  final List<Player> players;
  final PlayerColor? winner;

  static final List<(String, int Function(PlayerStats))> _categories = [
    ('Ходов', (s) => s.moves),
    ('Бонусов', (s) => s.bonuses),
    ('Съедено', (s) => s.captures),
    ('Смертей', (s) => s.deaths),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = [
      for (final (_, value) in _categories)
        players.map((p) => value(p.stats)).fold(0, (a, b) => a > b ? a : b),
    ];

    TableRow header() => TableRow(
          children: [
            const SizedBox.shrink(),
            for (final (title, _) in _categories)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(color: Colors.black54),
                ),
              ),
          ],
        );

    TableRow row(Player p) => TableRow(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  PlayerAvatar(color: p.color, avatar: p.avatar, size: 36),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      p.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(color: p.color.dark),
                    ),
                  ),
                  if (p.color == winner) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.emoji_events, size: 18, color: p.color.color),
                  ],
                ],
              ),
            ),
            for (var i = 0; i < _categories.length; i++)
              Builder(builder: (context) {
                final value = _categories[i].$2(p.stats);
                final top = value > 0 && value == best[i];
                return Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: top ? FontWeight.w800 : FontWeight.w400,
                    color: top ? Colors.black : Colors.black54,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              }),
          ],
        );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Статистика партии'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {0: FlexColumnWidth(2.2)},
                    children: [header(), for (final p in players) row(p)],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Бонусы — выпавшие шестёрки и остановки на клетке 🎁. '
                    'Съедено — сбитые фишки соперников, смерти — свои сбитые фишки.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
