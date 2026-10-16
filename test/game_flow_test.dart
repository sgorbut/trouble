import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trouble_game/core/constants.dart';
import 'package:trouble_game/core/game/engine.dart';
import 'package:trouble_game/core/game/models.dart';
import 'package:trouble_game/core/game/board_geometry.dart';
import 'package:trouble_game/features/game/board_view.dart';
import 'package:trouble_game/features/game/game_controller.dart';
import 'package:trouble_game/features/game/game_screen.dart';
import 'package:trouble_game/features/win/win_screen.dart';
import 'package:trouble_game/ui/theme.dart';

void main() {
  testWidgets('партия двух ботов доходит до экрана победы', (tester) async {
    SharedPreferences.setMockInitialValues({'soundEnabled': false});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [randomProvider.overrideWithValue(Random(7))],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const Scaffold()),
    ));

    container.read(gameControllerProvider.notifier).start(const [
      PlayerConfig(color: PlayerColor.red, type: PlayerType.bot, name: 'Бот 1'),
      PlayerConfig(color: PlayerColor.yellow, type: PlayerType.bot, name: 'Бот 2'),
    ], lottery: false);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => const GameScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget);

    for (var i = 0; i < 20000 && find.byType(WinScreen).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(find.byType(WinScreen), findsOneWidget);
    expect(find.text('Победа!'), findsOneWidget);
    expect(container.read(gameControllerProvider)!.game.winner, isNotNull);
  });

  testWidgets('кубик сбрасывается перед следующим броском', (tester) async {
    SharedPreferences.setMockInitialValues({'soundEnabled': false});
    final container = ProviderContainer(
      overrides: [randomProvider.overrideWithValue(Random(1))],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold()),
    ));

    final ctrl = container.read(gameControllerProvider.notifier);
    ctrl.start(const [
      PlayerConfig(color: PlayerColor.red, type: PlayerType.human, name: 'Я'),
      PlayerConfig(color: PlayerColor.yellow, type: PlayerType.human, name: 'Друг'),
    ], direction: MoveDirection.counterclockwise, lottery: false);
    expect(container.read(gameControllerProvider)!.shownDice, isNull);

    ctrl.roll();
    await tester.pump(const Duration(milliseconds: 900));
    final rolled = container.read(gameControllerProvider)!;
    expect(rolled.shownDice, isNotNull);
    expect(rolled.game.phase, GamePhase.waitingForMove);

    // Ход любой фишкой: выбор + подтверждение.
    final piece = rolled.legalMoves.first.piece;
    ctrl.tapPiece(piece);
    ctrl.tapPiece(piece);
    await tester.pump(const Duration(seconds: 3));

    final after = container.read(gameControllerProvider)!;
    expect(after.game.phase, GamePhase.waitingForRoll);
    expect(after.shownDice, isNull);
    ctrl.stop();
  });

  testWidgets('отмена последнего хода: фишка возвращается, бросок тот же, только один раз', (tester) async {
    SharedPreferences.setMockInitialValues({'soundEnabled': false, 'vibrationEnabled': false});
    final container = ProviderContainer(
      overrides: [randomProvider.overrideWithValue(Random(5))],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold()),
    ));

    final ctrl = container.read(gameControllerProvider.notifier);
    ctrl.start(const [
      PlayerConfig(color: PlayerColor.red, type: PlayerType.human, name: 'Сергей', avatar: '🦊'),
      PlayerConfig(color: PlayerColor.yellow, type: PlayerType.bot, name: 'Бот'),
    ], lottery: false);
    expect(container.read(gameControllerProvider)!.canUndo, isFalse);
    expect(container.read(gameControllerProvider)!.game.players.first.avatar, '🦊');

    ctrl.roll();
    await tester.pump(const Duration(seconds: 1));
    final before = container.read(gameControllerProvider)!;
    final dice = before.shownDice;
    final piece = before.legalMoves.first.piece;
    ctrl.tapPiece(piece);
    ctrl.tapPiece(piece);
    // Ход человека и ответ бота.
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(gameControllerProvider)!.game.pieceOf(piece).progress, isNot(homeProgress));

    // Ждём, пока бот не будет в анимации, и отменяем.
    for (var i = 0; i < 50 && !container.read(gameControllerProvider)!.canUndo; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    ctrl.undo();
    final after = container.read(gameControllerProvider)!;
    expect(after.game.currentPlayer.color, PlayerColor.red);
    expect(after.game.phase, GamePhase.waitingForMove);
    expect(after.shownDice, dice);
    expect(after.game.pieceOf(piece).progress, homeProgress);
    expect(after.legalMoves, isNotEmpty);
    expect(after.canUndo, isFalse, reason: 'отменить можно только один ход');

    // Бот после отмены не ходит сам: ход за человеком.
    await tester.pump(const Duration(seconds: 3));
    expect(container.read(gameControllerProvider)!.game.phase, GamePhase.waitingForMove);
    ctrl.stop();
  });

  testWidgets('жребий: все бросают, первым ходит выбросивший больше, ничья — переброс', (tester) async {
    SharedPreferences.setMockInitialValues({'soundEnabled': false, 'vibrationEnabled': false});
    // Броски: красный 4, жёлтый 4 (ничья) → переброс: красный 2, жёлтый 5 → первым ходит жёлтый.
    final container = ProviderContainer(
      overrides: [randomProvider.overrideWithValue(_ScriptedRandom([3, 3, 1, 4]))],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold()),
    ));

    final ctrl = container.read(gameControllerProvider.notifier);
    ctrl.start(const [
      PlayerConfig(color: PlayerColor.red, type: PlayerType.human, name: 'Аня'),
      PlayerConfig(color: PlayerColor.yellow, type: PlayerType.human, name: 'Боря'),
    ], direction: MoveDirection.counterclockwise, lottery: true);
    GameViewState view() => container.read(gameControllerProvider)!;
    expect(view().lottery, isNotNull);

    Future<void> rollOnce() async {
      ctrl.roll();
      await tester.pump(diceRollDuration + const Duration(milliseconds: 50));
      await tester.pump(lotteryPause + const Duration(milliseconds: 50));
    }

    await rollOnce(); // красный 4
    expect(view().game.currentPlayer.color, PlayerColor.yellow);
    await rollOnce(); // жёлтый 4 — ничья
    expect(view().lottery!.contenders, [PlayerColor.red, PlayerColor.yellow]);
    expect(view().lottery!.rolls, isEmpty);
    expect(view().notice, contains('Ничья'));
    await rollOnce(); // красный 2
    await rollOnce(); // жёлтый 5 — победа в жребии

    expect(view().lottery, isNull);
    expect(view().game.currentPlayer.color, PlayerColor.yellow);
    expect(view().game.phase, GamePhase.waitingForRoll);
    expect(view().notice, 'Первым ходит Боря');
    ctrl.stop();
  });

  testWidgets('тап по клетке пути не делает ход, а снимает выбор фишки', (tester) async {
    SharedPreferences.setMockInitialValues({'soundEnabled': false, 'vibrationEnabled': false});
    final container = ProviderContainer(
      overrides: [randomProvider.overrideWithValue(Random(5))],
    );
    addTearDown(container.dispose);
    const side = 450.0;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: Align(alignment: Alignment.topLeft, child: BoardView(side: side))),
      ),
    ));

    final ctrl = container.read(gameControllerProvider.notifier);
    ctrl.start(const [
      PlayerConfig(color: PlayerColor.red, type: PlayerType.human, name: 'Красный'),
      PlayerConfig(color: PlayerColor.yellow, type: PlayerType.bot, name: 'Бот'),
    ], lottery: false);
    ctrl.roll();
    await tester.pump(const Duration(seconds: 1));
    final view = container.read(gameControllerProvider)!;
    expect(view.legalMoves.length, greaterThan(1), reason: 'нужен выбор из нескольких фишек');
    final move = view.legalMoves.first;
    ctrl.tapPiece(move.piece);
    await tester.pump();
    expect(container.read(gameControllerProvider)!.selected, move.piece);

    // Клетка пути до назначения (или, если ход на 1, любая другая пустая клетка кольца).
    final dir = view.game.direction;
    final cell = side / gridSize;
    final target = move.to > 0
        ? BoardGeometry.cellFor(move.piece.owner, 0, 0, dir)
        : BoardGeometry.ringCell(10);
    await tester.tapAt(Offset((target.col + 0.5) * cell, (target.row + 0.5) * cell));
    await tester.pump();

    final after = container.read(gameControllerProvider)!;
    expect(after.game.pieceOf(move.piece).progress, homeProgress, reason: 'ход не сделан');
    expect(after.selected, isNull, reason: 'выбор снят');
    ctrl.stop();
  });
}

/// Random с заранее заданной последовательностью nextInt (для бросков: значение + 1).
class _ScriptedRandom implements Random {
  _ScriptedRandom(this._values);
  final List<int> _values;
  int _i = 0;

  @override
  int nextInt(int max) => _values[_i++ % _values.length] % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}
