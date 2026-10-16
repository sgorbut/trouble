import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/engine.dart';
import '../../core/game/models.dart';
import '../../ui/avatars.dart';
import '../../ui/theme.dart';
import '../game/game_controller.dart';
import '../game/game_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

/// Настройки одного игрока на экране подготовки партии.
class _Slot {
  _Slot(this.color, this.type)
    : name = TextEditingController(text: avatarName(defaultAvatarFor(color))),
      avatar = defaultAvatarFor(color);

  PlayerColor color;
  PlayerType type;
  final TextEditingController name;
  String avatar;
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _count = 2;

  /// Четыре слота; цвета в них всегда образуют перестановку всех цветов,
  /// поэтому у видимых игроков цвета никогда не совпадают.
  /// Порядок по умолчанию: при двух игроках — красный и жёлтый (напротив друг друга).
  final List<_Slot> _slots = [
    _Slot(PlayerColor.red, PlayerType.human),
    _Slot(PlayerColor.yellow, PlayerType.bot),
    _Slot(PlayerColor.blue, PlayerType.bot),
    _Slot(PlayerColor.green, PlayerType.bot),
  ];

  @override
  void dispose() {
    for (final slot in _slots) {
      slot.name.dispose();
    }
    super.dispose();
  }

  /// Меняет цвет игрока; если цвет занят другим слотом — слоты меняются цветами.
  /// Имя и аватар, оставленные по умолчанию, следуют за цветом.
  void _setColor(_Slot slot, PlayerColor color) {
    if (slot.color == color) return;
    final other = _slots.firstWhere((s) => s.color == color);
    setState(() {
      final old = slot.color;
      _recolor(other, old);
      _recolor(slot, color);
    });
  }

  void _recolor(_Slot slot, PlayerColor color) {
    final name = slot.name.text.trim();
    if (name == slot.color.displayName) slot.name.text = color.displayName;
    if (slot.avatar == defaultAvatarFor(slot.color)) _setAvatar(slot, defaultAvatarFor(color));
    slot.color = color;
  }

  /// Меняет аватар; имя, совпадающее с именем прежнего аватара (или пустое),
  /// меняется на имя нового.
  void _setAvatar(_Slot slot, String avatar) {
    final name = slot.name.text.trim();
    if (name.isEmpty || name == avatarName(slot.avatar)) slot.name.text = avatarName(avatar);
    slot.avatar = avatar;
  }

  void _start() {
    final configs = [
      for (final slot in _slots.take(_count))
        PlayerConfig(
          color: slot.color,
          type: slot.type,
          name: slot.name.text.trim().isEmpty ? slot.color.displayName : slot.name.text.trim(),
          avatar: slot.avatar,
        ),
    ];
    ref.read(gameControllerProvider.notifier).start(configs);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => const GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая игра')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Число игроков и кнопка «Начать» — в одной строке.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Число игроков', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 2, label: Text('2')),
                              ButtonSegment(value: 3, label: Text('3')),
                              ButtonSegment(value: 4, label: Text('4')),
                            ],
                            selected: {_count},
                            onSelectionChanged: (s) => setState(() => _count = s.first),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: _start,
                      label: const Text('Начать'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _count; i++) _playerCard(i, _slots[i]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar(_Slot slot) async {
    final c = slot.color;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Аватар: ${c.displayName.toLowerCase()}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              // Сетка 4 ряда × 5 аватаров; размер подстраивается под ширину экрана.
              LayoutBuilder(
                builder: (context, box) {
                  const perRow = 5;
                  const gap = 10.0;
                  final size = min(52.0, (box.maxWidth - gap * (perRow - 1)) / perRow - 10);
                  Widget item(String a) => InkResponse(
                    onTap: () => Navigator.pop(context, a),
                    radius: size / 2 + 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: slot.avatar == a ? c.dark : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: PlayerAvatar(color: c, avatar: a, size: size),
                    ),
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var r = 0; r < presetAvatars.length; r += perRow)
                        Padding(
                          padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = r; i < min(r + perRow, presetAvatars.length); i++) ...[
                                if (i > r) const SizedBox(width: gap),
                                item(presetAvatars[i]),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _setAvatar(slot, picked));
  }

  Widget _quickNames(_Slot slot) {
    final c = slot.color;
    final controller = slot.name;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          // Имя по аватару, имя-цвет (только для своего цвета), затем общие имена.
          for (final name in {
            avatarName(slot.avatar),
            c.displayName,
            ...quickNames,
          }.where((n) => n.isNotEmpty))
            ChoiceChip(
              label: Text(name),
              visualDensity: VisualDensity.compact,
              selected: value.text.trim() == name,
              onSelected: (_) {
                controller.text = name;
                controller.selection = TextSelection.collapsed(offset: name.length);
              },
            ),
        ],
      ),
    );
  }

  /// Выбор цвета: четыре кружка; занятый другим игроком цвет помечен его номером.
  /// Человек или бот — две строки «иконка + галочка», галочка у выбранного.
  Widget _typePicker(_Slot slot) {
    final c = slot.color;
    Widget row(PlayerType type, IconData icon, String tooltip) {
      final selected = slot.type == type;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => setState(() => slot.type = type),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: selected ? c.dark : Colors.black38),
                const SizedBox(width: 4),
                SizedBox(
                  width: 20,
                  child: selected ? Icon(Icons.check, size: 20, color: c.dark) : null,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(PlayerType.human, Icons.person, 'Человек'),
        const SizedBox(height: 4),
        row(PlayerType.bot, Icons.smart_toy_outlined, 'Бот'),
      ],
    );
  }

  /// Выбор цвета квадратом 2×2 — как дома на поле: красный и синий сверху,
  /// зелёный и жёлтый снизу.
  Widget _colorPicker(_Slot slot) {
    Widget row(PlayerColor left, PlayerColor right) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [_colorDot(slot, left), const SizedBox(width: 6), _colorDot(slot, right)],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(PlayerColor.red, PlayerColor.blue),
        const SizedBox(height: 6),
        row(PlayerColor.green, PlayerColor.yellow),
      ],
    );
  }

  Widget _colorDot(_Slot slot, PlayerColor color) {
    final selected = slot.color == color;
    final owner = _slots.indexWhere((s) => s.color == color);
    final takenByOther = !selected && owner < _count;
    return Tooltip(
      message: takenByOther
          ? '${color.displayName} — у игрока ${owner + 1}, поменяться'
          : color.displayName,
      child: InkResponse(
        onTap: () => _setColor(slot, color),
        radius: 24,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.color.withValues(alpha: takenByOther ? 0.35 : 1),
            border: Border.all(color: selected ? color.dark : Colors.transparent, width: 3),
            boxShadow: [
              if (selected) BoxShadow(color: color.color.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
          child: selected
              ? Icon(Icons.check, size: 18, color: color.onColor)
              : takenByOther
              ? Text(
                  '${owner + 1}',
                  style: TextStyle(color: color.dark, fontWeight: FontWeight.bold),
                )
              : null,
        ),
      ),
    );
  }

  Widget _playerCard(int index, _Slot slot) {
    final c = slot.color;
    return Card(
      key: ValueKey(slot),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Аватар, имя и выбор цвета — в одном ряду.
            Row(
              children: [
                Tooltip(
                  message: 'Выбрать аватар',
                  child: InkResponse(
                    onTap: () => _pickAvatar(slot),
                    radius: 32,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PlayerAvatar(color: c, avatar: slot.avatar, size: 56),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: c.dark,
                            child: const Icon(Icons.edit, size: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: slot.name,
                    maxLength: 16,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Имя игрока ${index + 1}',
                      labelStyle: TextStyle(color: c.dark),
                      floatingLabelStyle: TextStyle(color: c.dark, fontWeight: FontWeight.bold),
                      hintText: 'Введите своё или выберите ниже',
                      counterText: '',
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Очистить',
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: slot.name.clear,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                _colorPicker(slot),
              ],
            ),
            const SizedBox(height: 10),
            // Быстрые имена и в правом нижнем углу — человек/бот.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _quickNames(slot)),
                const SizedBox(width: 16),
                _typePicker(slot),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
