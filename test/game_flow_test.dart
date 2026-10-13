import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trouble_game/core/constants.dart';
import 'package:trouble_game/core/game/engine.dart';
import 'package:trouble_game/core/game/models.dart';
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
    ]);
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
    ], direction: MoveDirection.counterclockwise);
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
    ]);
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
}
