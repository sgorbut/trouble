import 'models.dart';

/// Простой бот. Приоритет: сбить соперника → зайти в финиш → встать на бонусную
/// клетку → выйти из дома → сходить самой дальней фишкой на кольце.
class Bot {
  const Bot._();

  static Move? chooseMove(List<Move> moves) {
    if (moves.isEmpty) return null;

    Move? farthest(Iterable<Move> list) => list.isEmpty
        ? null
        : list.reduce((a, b) => b.from > a.from ? b : a);

    return farthest(moves.where((m) => m.isCapture)) ??
        farthest(moves.where((m) => m.entersFinish)) ??
        farthest(moves.where((m) => m.bonus)) ??
        farthest(moves.where((m) => m.leavesHome)) ??
        farthest(moves)!;
  }
}
