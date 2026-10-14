import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/models.dart';
import '../../ui/avatars.dart';
import '../../ui/theme.dart';
import '../win/win_screen.dart';
import 'board_view.dart';
import 'game_controller.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final GameController _controller;
  bool _navigatedToWin = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(gameControllerProvider.notifier);
  }

  @override
  void dispose() {
    // Уход с экрана прерывает отложенные ходы ботов.
    _controller.stop();
    super.dispose();
  }

  void _openPauseMenu() async {
    _controller.pause();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Пауза'),
        content: const Text('Игра приостановлена.'),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'menu'),
            child: const Text('В меню'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'restart'),
            child: const Text('Перезапустить'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(context, 'resume'),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'menu':
        Navigator.of(context).popUntil((r) => r.isFirst);
      case 'restart':
        _controller.restart();
      default:
        _controller.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider.select((s) => s?.game.winner), (
      prev,
      winner,
    ) {
      if (winner == null || _navigatedToWin) return;
      _navigatedToWin = true;
      final game = ref.read(gameControllerProvider)!.game;
      final player = game.playerOf(winner);
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => WinScreen(
              winnerName: player.name,
              winnerColor: winner,
              winnerAvatar: player.avatar,
            ),
          ),
        );
      });
    });

    final view = ref.watch(gameControllerProvider);
    if (view == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _openPauseMenu();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trouble'),
          leading: IconButton(
            tooltip: 'Пауза / меню',
            icon: const Icon(Icons.pause_circle_outline),
            onPressed: _openPauseMenu,
          ),
          actions: [
            IconButton(
              tooltip: 'Отменить последний ход',
              icon: const Icon(Icons.undo),
              onPressed: view.canUndo ? _controller.undo : null,
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final landscape = c.maxWidth > c.maxHeight;
              const pad = 12.0;
              if (landscape) {
                final panelWidth = min(280.0, c.maxWidth * 0.35);
                final side =
                    min(c.maxHeight, c.maxWidth - panelWidth) - pad * 2;
                return Row(
                  children: [
                    Expanded(
                      child: Center(child: BoardView(side: side)),
                    ),
                    // Панель игрока и счёта отделена от поля полосой.
                    Container(
                      width: panelWidth,
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.black12, width: 2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(pad),
                        child: _ControlPanel(view: view, vertical: true),
                      ),
                    ),
                  ],
                );
              }
              const panelHeight = 124.0;
              final side = min(c.maxWidth, c.maxHeight - panelHeight) - pad * 2;
              return Column(
                children: [
                  Expanded(
                    child: Center(child: BoardView(side: side)),
                  ),
                  // Панель игрока и счёта отделена от поля полосой.
                  Container(
                    height: panelHeight,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.black12, width: 2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(pad),
                      child: _ControlPanel(view: view, vertical: false),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Индикатор текущего игрока, подсказка, кубик и счёт финишировавших фишек.
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.view, required this.vertical});

  final GameViewState view;
  final bool vertical;

  String _hint() {
    final game = view.game;
    final player = game.currentPlayer;
    if (view.notice != null) return view.notice!;
    if (game.phase == GamePhase.finished) return 'Победа!';
    if (view.rolling) return 'Бросок…';
    if (view.lottery != null) {
      return player.isBot ? 'Бот бросает жребий…' : 'Жребий: бросьте кубик';
    }
    if (player.isBot) {
      return game.phase == GamePhase.waitingForMove ||
              game.phase == GamePhase.animating
          ? 'Бот ходит…'
          : 'Бот думает…';
    }
    switch (game.phase) {
      case GamePhase.waitingForRoll:
        return game.extraTurn ? 'Выпала 6! Бросьте ещё раз' : 'Бросьте кубик';
      case GamePhase.waitingForMove:
        return view.selected != null
            ? 'Нажмите фишку ещё раз или клетку назначения'
            : 'Выберите фишку';
      default:
        return 'Ход…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = view.game;
    final player = game.currentPlayer;
    final color = player.color;

    final indicator = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: color.color.withValues(alpha: 0.4), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          PlayerAvatar(color: color, avatar: player.avatar, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color.onColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (player.isBot) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.smart_toy_outlined,
                        color: color.onColor,
                        size: 18,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _hint(),
                  style: TextStyle(color: color.onColor, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final scores = _Scores(view: view, columns: vertical ? 1 : 2);

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [indicator, const Spacer(), scores],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: indicator),
        const SizedBox(width: 12),
        scores,
      ],
    );
  }
}

/// Сколько фишек каждый игрок уже довёл до финиша. Текущий игрок выделен рамкой.
class _Scores extends StatelessWidget {
  const _Scores({required this.view, required this.columns});

  final GameViewState view;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final current = view.game.currentPlayer.color;
    final players = view.game.players;
    final tiles = [
      for (final p in players)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: p.color == current ? p.color.dark : Colors.black12,
              width: p.color == current ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerAvatar(color: p.color, avatar: p.avatar, size: 24),
              const SizedBox(width: 6),
              if (columns == 1) ...[
                Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
              ],
              Text(
                // Во время жребия — выпавшее значение, иначе — сколько фишек в финише.
                view.lottery != null
                    ? (view.lottery!.rolls[p.color] != null
                          ? '🎲 ${view.lottery!.rolls[p.color]}'
                          : view.lottery!.contenders.contains(p.color)
                          ? '🎲 …'
                          : '—')
                    : '${p.pieces.where((x) => x.isFinished).length}/${p.pieces.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
    ];

    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in tiles)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: t),
        ],
      );
    }
    // Сетка 2×2 на месте прежнего кубика.
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            tiles[i],
            if (i + 1 < tiles.length) ...[
              const SizedBox(width: 6),
              tiles[i + 1],
            ],
          ],
        ),
      );
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 6));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: rows,
    );
  }
}
