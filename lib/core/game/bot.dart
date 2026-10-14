import 'dart:math';

import 'models.dart';

/// Способы выбрать ход.
enum BotStrategy {
  /// Сбить фишку соперника.
  capture,

  /// Завести фишку в финиш.
  finish,

  /// Встать на бонусную клетку.
  bonus,

  /// Вывести фишку из дома.
  leaveHome,

  /// Сходить самой дальней фишкой.
  farthest,

  /// Сходить самой отстающей фишкой на кольце.
  nearest,

  /// Любой допустимый ход.
  any,
}

/// Бот.
///
/// Без [Random] — строгий порядок приоритетов: сбить соперника → финиш → бонусная
/// клетка → выход из дома → самая дальняя фишка.
/// С [Random] — на каждом ходу стратегии перемешиваются, и бот берёт первую, для которой
/// есть подходящий ход: то сбивает, то выводит фишку, то тянет отстающую — играть с ним
/// не так предсказуемо.
class Bot {
  const Bot._();

  static const _priority = [
    BotStrategy.capture,
    BotStrategy.finish,
    BotStrategy.bonus,
    BotStrategy.leaveHome,
    BotStrategy.farthest,
  ];

  static Move? chooseMove(List<Move> moves, {Random? random}) {
    if (moves.isEmpty) return null;
    final order = random == null ? _priority : ([...BotStrategy.values]..shuffle(random));
    for (final strategy in order) {
      final move = _pick(strategy, moves, random);
      if (move != null) return move;
    }
    return moves.first;
  }

  static Move? _pick(BotStrategy strategy, List<Move> moves, Random? random) {
    Move? farthest(Iterable<Move> list) =>
        list.isEmpty ? null : list.reduce((a, b) => b.from > a.from ? b : a);

    return switch (strategy) {
      BotStrategy.capture => farthest(moves.where((m) => m.isCapture)),
      BotStrategy.finish => farthest(moves.where((m) => m.entersFinish)),
      BotStrategy.bonus => farthest(moves.where((m) => m.bonus)),
      BotStrategy.leaveHome => farthest(moves.where((m) => m.leavesHome)),
      BotStrategy.farthest => farthest(moves),
      BotStrategy.nearest => () {
          final onRing = moves.where((m) => !m.leavesHome).toList();
          return onRing.isEmpty ? null : onRing.reduce((a, b) => b.from < a.from ? b : a);
        }(),
      BotStrategy.any => moves[(random ?? Random()).nextInt(moves.length)],
    };
  }
}
