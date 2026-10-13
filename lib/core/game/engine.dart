import 'dart:math';

import '../constants.dart';
import 'models.dart';

/// Описание игрока для старта партии.
class PlayerConfig {
  const PlayerConfig({
    required this.color,
    required this.type,
    required this.name,
    this.avatar = '',
  });
  final PlayerColor color;
  final PlayerType type;
  final String name;
  final String avatar;
}

/// Игровой движок: чистые функции над [GameState].
class GameEngine {
  const GameEngine._();

  /// Цвета, участвующие в партии на [count] игроков.
  static List<PlayerColor> colorsForCount(int count) => switch (count) {
        2 => const [PlayerColor.red, PlayerColor.yellow],
        3 => const [PlayerColor.red, PlayerColor.blue, PlayerColor.yellow],
        _ => PlayerColor.values,
      };

  /// Очерёдность ходов совпадает с направлением движения: по часовой —
  /// красный, синий, жёлтый, зелёный; против — красный, зелёный, жёлтый, синий.
  static int turnOrderKey(PlayerColor color, MoveDirection direction) =>
      direction == MoveDirection.clockwise ? color.index : (4 - color.index) % 4;

  static GameState newGame(
    List<PlayerConfig> configs, {
    MoveDirection direction = MoveDirection.counterclockwise,
  }) {
    assert(configs.length >= 2 && configs.length <= 4);
    final sorted = [...configs]
      ..sort((a, b) =>
          turnOrderKey(a.color, direction).compareTo(turnOrderKey(b.color, direction)));
    return GameState(
      players: [for (final c in sorted) Player.initial(c.color, c.type, c.name, avatar: c.avatar)],
      direction: direction,
    );
  }

  static int rollDice(Random random) => random.nextInt(6) + 1;

  /// Все допустимые ходы текущего игрока при броске [dice].
  static List<Move> getLegalMoves(GameState state, int dice) {
    final player = state.currentPlayer;
    final moves = <Move>[];
    for (final piece in player.pieces) {
      if (piece.isFinished) continue;
      moves.add(_computeMove(state, player, piece, dice));
    }
    return moves;
  }

  static Move _computeMove(GameState state, Player player, Piece piece, int dice) {
    // Выход из дома при любом броске; шаг из дома на стартовую клетку — первый
    // из выпавших: при 1 фишка встаёт на старт (progress 0), при 6 — на progress 5.
    var target = piece.isHome ? dice - 1 : piece.progress + dice;

    // Своя фишка на целевой клетке: сдвигаемся на следующую, пока клетка занята своими.
    bool ownAt(int progress) =>
        player.pieces.any((p) => p.id != piece.id && p.progress == progress);
    while (target < finishStartProgress && ownAt(target)) {
      target++;
    }

    final ref = PieceRef(piece.owner, piece.id);
    if (target >= finishStartProgress) {
      // Финиш: точное число не нужно, занимаем самую дальнюю свободную лунку.
      var slot = finishEndProgress;
      while (slot > finishStartProgress && ownAt(slot)) {
        slot--;
      }
      return Move(piece: ref, from: piece.progress, to: slot);
    }

    final absIndex = ringIndexFor(player.color, target, state.direction);
    PieceRef? captured;
    for (final other in state.allPieces) {
      if (other.owner != player.color && other.ringIndex(state.direction) == absIndex) {
        captured = PieceRef(other.owner, other.id);
        break;
      }
    }
    return Move(
      piece: ref,
      from: piece.progress,
      to: target,
      captured: captured,
      bonus: bonusRingIndices(state.direction).contains(absIndex),
    );
  }

  /// Фиксирует бросок кубика.
  static GameState applyRoll(GameState state, int dice) => state.copyWith(
        diceValue: () => dice,
        extraTurn: dice == 6,
        phase: GamePhase.waitingForMove,
      );

  /// Выполняет ход и передаёт очередь (или даёт дополнительный бросок после 6).
  static GameState applyMove(GameState state, Move move) {
    final players = [
      for (final player in state.players)
        player.copyWith(pieces: [
          for (final p in player.pieces)
            if (p.owner == move.piece.owner && p.id == move.piece.id)
              p.copyWith(progress: move.to)
            else if (move.captured != null &&
                p.owner == move.captured!.owner &&
                p.id == move.captured!.id)
              p.copyWith(progress: homeProgress)
            else
              p,
        ]),
    ];
    final moved = state.copyWith(players: players);
    final mover = moved.currentPlayer;
    if (mover.allFinished) {
      return moved.copyWith(phase: GamePhase.finished, winner: () => mover.color);
    }
    return _advanceTurn(moved, bonus: move.bonus);
  }

  /// Пропуск хода, когда допустимых ходов нет (после 6 бросок всё равно повторяется).
  static GameState passTurn(GameState state) => _advanceTurn(state);

  /// Дополнительный бросок — после 6 или после остановки на бонусной клетке.
  static GameState _advanceTurn(GameState state, {bool bonus = false}) {
    final again = state.diceValue == 6 || bonus;
    return state.copyWith(
      currentPlayerIndex:
          again ? state.currentPlayerIndex : (state.currentPlayerIndex + 1) % state.players.length,
      diceValue: () => null,
      phase: GamePhase.waitingForRoll,
      extraTurn: again,
    );
  }

  static bool isFinished(GameState state) =>
      state.winner != null || state.players.any((p) => p.allFinished);
}
