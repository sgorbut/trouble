import 'package:flutter/material.dart';

import '../../core/game/models.dart';
import '../../ui/theme.dart';
import '../rules/rules_screen.dart';
import '../settings/settings_screen.dart';
import '../setup/setup_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in PlayerColor.values)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: CircleAvatar(radius: 14, backgroundColor: c.color),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'TROUBLE',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                ),
                const SizedBox(height: 4),
                Text('Настольная игра для 2–4 игроков', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 48),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _open(context, const SetupScreen()),
                  label: const Text('Новая игра'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.menu_book),
                  onPressed: () => _open(context, const RulesScreen()),
                  label: const Text('Правила'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _open(context, const SettingsScreen()),
                  label: const Text('Настройки'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
