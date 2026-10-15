import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/models.dart';
import '../../ui/avatars.dart';
import '../../ui/theme.dart';
import '../game/game_controller.dart';
import '../game/game_screen.dart';
import '../stats/stats_screen.dart';

class WinScreen extends ConsumerWidget {
  const WinScreen({
    super.key,
    required this.winnerName,
    required this.winnerColor,
    this.winnerAvatar = '',
    this.players = const [],
  });

  final String winnerName;
  final PlayerColor winnerColor;
  final String winnerAvatar;

  /// Игроки партии со статистикой — для экрана статистики.
  final List<Player> players;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: Icon(Icons.emoji_events, size: 110, color: winnerColor.color),
                ),
                const SizedBox(height: 12),
                Text(
                  'Победа!',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                PlayerAvatar(color: winnerColor, avatar: winnerAvatar, size: 96),
                const SizedBox(height: 12),
                Text(
                  winnerName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: winnerColor.dark),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 40),
                if (players.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StatsScreen(players: players, winner: winnerColor),
                      ),
                    ),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Статистика'),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: () {
                    ref.read(gameControllerProvider.notifier).restart();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => const GameScreen()),
                    );
                  },
                  child: const Text('Играть снова'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('В меню'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
