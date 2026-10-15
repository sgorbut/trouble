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
          name: slot.name.text.trim().isEmpty
              ? slot.color.displayName
              : slot.name.text.trim(),
          avatar: slot.avatar,
        ),
    ];
    ref.read(gameControllerProvider.notifier).start(configs);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая игра')),
      body: Stack(
        children: [
          // Схема поля фоном: углы экрана подсвечены цветами домов, как на игровом поле.
          Positioned.fill(
            child: IgnorePointer(
              // Перерисовка и при вводе имени (контроллеры не вызывают setState).
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  for (final slot in _slots) slot.name,
                ]),
                builder: (context, _) => CustomPaint(
                  painter: _CornerGlowPainter({
                    for (final slot in _slots.take(_count))
                      slot.color: (
                        avatar: slot.avatar,
                        name: slot.name.text.trim().isEmpty
                            ? slot.color.displayName
                            : slot.name.text.trim(),
                      ),
                  }),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Число игроков',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                        ButtonSegment(value: 4, label: Text('4')),
                      ],
                      selected: {_count},
                      onSelectionChanged: (s) =>
                          setState(() => _count = s.first),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < _count; i++) _playerCard(i, _slots[i]),
                    const SizedBox(height: 16),
                    Center(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: _start,
                        label: const Text('Начать'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          for (final name in {avatarName(slot.avatar), c.displayName, ...quickNames}.where((n) => n.isNotEmpty))
            ChoiceChip(
              label: Text(name),
              visualDensity: VisualDensity.compact,
              selected: value.text.trim() == name,
              onSelected: (_) {
                controller.text = name;
                controller.selection = TextSelection.collapsed(
                  offset: name.length,
                );
              },
            ),
        ],
      ),
    );
  }

  /// Выбор цвета: четыре кружка; занятый другим игроком цвет помечен его номером.
  Widget _colorPicker(_Slot slot) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in PlayerColor.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _colorDot(slot, color),
          ),
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
            border: Border.all(
              color: selected ? color.dark : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: color.color.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
            ],
          ),
          child: selected
              ? Icon(Icons.check, size: 18, color: color.onColor)
              : takenByOther
              ? Text(
                  '${owner + 1}',
                  style: TextStyle(
                    color: color.dark,
                    fontWeight: FontWeight.bold,
                  ),
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
            Text(
              'Игрок ${index + 1}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: c.dark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
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
                            child: const Icon(
                              Icons.edit,
                              size: 13,
                              color: Colors.white,
                            ),
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
                      labelText: 'Имя',
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
              ],
            ),
            const SizedBox(height: 10),
            _quickNames(slot),
            const SizedBox(height: 12),
            // Человек/бот и цвет — в одной строке; на узком экране цвета переносятся.
            Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<PlayerType>(
                  segments: const [
                    ButtonSegment(
                      value: PlayerType.human,
                      icon: Icon(Icons.person),
                      label: Text('Человек'),
                    ),
                    ButtonSegment(
                      value: PlayerType.bot,
                      icon: Icon(Icons.smart_toy_outlined),
                      label: Text('Бот'),
                    ),
                  ],
                  selected: {slot.type},
                  onSelectionChanged: (s) =>
                      setState(() => slot.type = s.first),
                ),
                _colorPicker(slot),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Фон экрана настройки: в каждом углу — свечение цвета дома, как на поле
/// (красный — левый верхний, синий — правый верхний, жёлтый — правый нижний,
/// зелёный — левый нижний). Выбранные цвета ярче и с аватаром игрока.
class _CornerGlowPainter extends CustomPainter {
  _CornerGlowPainter(this.active);

  /// Цвета участников партии → их аватары и имена.
  final Map<PlayerColor, ({String avatar, String name})> active;

  static Alignment _corner(PlayerColor c) => switch (c) {
    PlayerColor.red => Alignment.topLeft,
    PlayerColor.blue => Alignment.topRight,
    PlayerColor.yellow => Alignment.bottomRight,
    PlayerColor.green => Alignment.bottomLeft,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final radius = min(size.width, size.height) * 0.6;
    for (final c in PlayerColor.values) {
      final player = active[c];
      final center = _corner(c).alongSize(size);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              c.color.withValues(alpha: player != null ? 0.7 : 0.32),
              c.color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
      if (player != null) _paintPlayer(canvas, size, c, player.avatar, player.name);
    }
  }

  /// Аватар и под ним имя игрока у его угла.
  void _paintPlayer(Canvas canvas, Size size, PlayerColor c, String avatar, String name) {
    const margin = 14.0;
    const maxWidth = 120.0;
    final a = _corner(c);
    final left = a.x < 0;
    final top = a.y < 0;

    final avatarTp = TextPainter(
      text: TextSpan(text: avatar, style: const TextStyle(fontSize: 34)),
      textDirection: TextDirection.ltr,
    )..layout();
    final nameTp = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: c.dark,
          shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: left ? TextAlign.left : TextAlign.right,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final blockHeight = avatarTp.height + 2 + nameTp.height;
    final y = top ? margin : size.height - blockHeight - 24;
    double xFor(double w) => left ? margin : size.width - w - margin;

    if (avatar.isNotEmpty) avatarTp.paint(canvas, Offset(xFor(avatarTp.width), y));
    nameTp.paint(canvas, Offset(xFor(nameTp.width), y + avatarTp.height + 2));
  }

  @override
  bool shouldRepaint(_CornerGlowPainter old) =>
      old.active.length != active.length ||
      old.active.entries.any((e) => active[e.key] != e.value);
}
