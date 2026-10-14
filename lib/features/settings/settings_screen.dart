import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/models.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up),
                title: const Text('Звук'),
                value: settings.soundEnabled,
                onChanged: notifier.setSound,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration),
                title: const Text('Вибрация'),
                subtitle: const Text('При броске кубика'),
                value: settings.vibrationEnabled,
                onChanged: notifier.setVibration,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fast_forward),
                title: const Text('Автоход'),
                subtitle: const Text('Если допустим только один ход, выполнять его автоматически'),
                value: settings.autoMoveSingle,
                onChanged: notifier.setAutoMove,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.rotate_left),
                title: const Text('Направление хода фишек'),
                subtitle: const Text('Применяется к новой партии. Очерёдность игроков — в ту же сторону.'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SegmentedButton<MoveDirection>(
                  segments: const [
                    ButtonSegment(
                      value: MoveDirection.counterclockwise,
                      icon: Icon(Icons.rotate_left),
                      label: Text('Против часовой'),
                    ),
                    ButtonSegment(
                      value: MoveDirection.clockwise,
                      icon: Icon(Icons.rotate_right),
                      label: Text('По часовой'),
                    ),
                  ],
                  selected: {settings.direction},
                  onSelectionChanged: (s) => notifier.setDirection(s.first),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
