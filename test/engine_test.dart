import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trouble_game/core/constants.dart';
import 'package:trouble_game/core/game/bot.dart';
import 'package:trouble_game/core/game/engine.dart';
import 'package:trouble_game/core/game/models.dart';

const cw = MoveDirection.clockwise;
const ccw = MoveDirection.counterclockwise;

/// Последняя клетка кольца на пути фишки и границы финиша.
const lastRing = ringPathLength - 1;
const f0 = finishStartProgress;
const fEnd = finishEndProgress;

/// Партия на двоих (красный и жёлтый) с заданными позициями фишек.
/// По умолчанию — по часовой стрелке.
GameState makeState({
  List<int> red = const [-1, -1, -1],
  List<int> yellow = const [-1, -1, -1],
  int current = 0,
  MoveDirection direction = cw,
}) {
  Player p(PlayerColor c, List<int> pos) => Player(
    color: c,
    type: PlayerType.human,
    name: c.displayName,
    pieces: [
      for (var i = 0; i < pos.length; i++)
        Piece(owner: c, id: i, progress: pos[i]),
    ],
  );
  return GameState(
    players: [p(PlayerColor.red, red), p(PlayerColor.yellow, yellow)],
    currentPlayerIndex: current,
    direction: direction,
  );
}

/// progress фишки цвета [c], при котором она стоит на абсолютной клетке [index].
int progressAt(PlayerColor c, int index, [MoveDirection d = cw]) =>
    ((index - c.startIndex) * d.sign) % ringLength;

/// Абсолютная клетка красной фишки с данным progress.
int redCell(int progress, [MoveDirection d = cw]) =>
    ringIndexFor(PlayerColor.red, progress, d);

Move moveFor(List<Move> moves, int pieceId) =>
    moves.firstWhere((m) => m.piece.id == pieceId);

void main() {
  const yellow = PlayerColor.yellow;

  group('rollDice', () {
    test('возвращает значения 1..6', () {
      final r = Random(1);
      final values = {for (var i = 0; i < 500; i++) GameEngine.rollDice(r)};
      expect(values, {1, 2, 3, 4, 5, 6});
    });
  });

  group('выход из дома', () {
    for (var dice = 1; dice <= 6; dice++) {
      test(
        'при броске $dice фишка выходит и проходит $dice шаг(ов): progress ${dice - 1}',
        () {
          final s = makeState();
          final moves = GameEngine.getLegalMoves(s, dice);
          expect(moves, hasLength(piecesPerPlayer));
          expect(moves.every((m) => m.leavesHome && m.to == dice - 1), isTrue);
        },
      );
    }

    test(
      'при 1 фишка встаёт на старт; старт занят своей — на следующую клетку',
      () {
        final s = makeState(red: [0, -1, -1]);
        expect(moveFor(GameEngine.getLegalMoves(s, 1), 1).to, 1);
      },
    );

    test(
      'целевая клетка выхода и следующие заняты своими — цепочка сдвигов',
      () {
        final s = makeState(red: [2, 3, -1]);
        expect(moveFor(GameEngine.getLegalMoves(s, 3), 2).to, 4);
      },
    );

    test('перепрыгивание через фишку на старте при выходе её не сбивает', () {
      final s = makeState(yellow: [progressAt(yellow, redCell(0)), -1, -1]);
      final m = moveFor(GameEngine.getLegalMoves(s, 4), 0);
      expect(m.to, 3);
      expect(m.isCapture, isFalse);
    });

    test(
      'выход на старт (бросок 1), занятый чужой фишкой, — она сбрасывается',
      () {
        final s = makeState(yellow: [progressAt(yellow, redCell(0)), -1, -1]);
        final m = moveFor(GameEngine.getLegalMoves(s, 1), 0);
        expect(m.to, 0);
        expect(m.captured, const PieceRef(PlayerColor.yellow, 0));
        final next = GameEngine.applyMove(GameEngine.applyRoll(s, 1), m);
        expect(
          next.playerOf(PlayerColor.yellow).pieces[0].progress,
          homeProgress,
        );
        expect(next.playerOf(PlayerColor.red).pieces[0].progress, 0);
      },
    );

    test('выход с приземлением на чужую фишку сбрасывает её', () {
      final s = makeState(yellow: [progressAt(yellow, redCell(4)), -1, -1]);
      final m = moveFor(GameEngine.getLegalMoves(s, 5), 0);
      expect(m.to, 4);
      expect(m.captured, const PieceRef(PlayerColor.yellow, 0));
    });
  });

  group('движение по кольцу', () {
    test('сброс чужой фишки при приземлении', () {
      final s = makeState(
        red: [5, -1, -1],
        yellow: [progressAt(yellow, redCell(8)), -1, -1],
      );
      final m = moveFor(GameEngine.getLegalMoves(s, 3), 0);
      expect(m.to, 8);
      expect(m.isCapture, isTrue);
      final next = GameEngine.applyMove(GameEngine.applyRoll(s, 3), m);
      expect(next.playerOf(PlayerColor.yellow).pieces[0].isHome, isTrue);
    });

    test('перепрыгивание через фишки не мешает ходу и не сбивает их', () {
      final s = makeState(
        red: [5, 7, -1],
        yellow: [progressAt(yellow, redCell(6)), -1, -1],
      );
      final m = moveFor(GameEngine.getLegalMoves(s, 4), 0);
      expect(m.to, 9);
      expect(m.isCapture, isFalse);
    });

    test('своя фишка на целевой клетке — переход на следующую', () {
      final s = makeState(red: [5, 8, -1]);
      expect(moveFor(GameEngine.getLegalMoves(s, 3), 0).to, 9);
    });

    test('цепочка из нескольких своих фишек подряд', () {
      final s = makeState(red: [5, 8, 9]);
      expect(moveFor(GameEngine.getLegalMoves(s, 3), 0).to, 10);
    });

    test(
      'сдвиг за своей фишкой через переход последнего индекса кольца к 0',
      () {
        // Жёлтый: progress 15 — индекс 31, progress 16 — индекс 0.
        final s = makeState(yellow: [13, 15, -1], current: 1);
        expect(ringIndexFor(yellow, 15, cw), ringLength - 1);
        expect(moveFor(GameEngine.getLegalMoves(s, 2), 0).to, 16);
      },
    );
  });

  group('финиш', () {
    test('точный бросок — заход в финиш, самая дальняя лунка', () {
      final s = makeState(red: [lastRing - 2, -1, -1]);
      final m = moveFor(GameEngine.getLegalMoves(s, 3), 0);
      expect(m.entersFinish, isTrue);
      expect(m.to, fEnd);
    });

    test('избыточный бросок тоже заводит в финиш', () {
      final s = makeState(red: [lastRing - 1, -1, -1]);
      expect(moveFor(GameEngine.getLegalMoves(s, 6), 0).to, fEnd);
    });

    test('занимается самая дальняя свободная лунка', () {
      final s = makeState(red: [fEnd, fEnd - 1, lastRing - 3]);
      expect(moveFor(GameEngine.getLegalMoves(s, 6), 2).to, fEnd - 2);
    });

    test('почти полный круг: клетка перед стартом ещё на кольце', () {
      final s = makeState(red: [lastRing - 5, -1, -1]);
      final m = moveFor(GameEngine.getLegalMoves(s, 5), 0);
      expect(m.to, lastRing);
      expect(m.entersFinish, isFalse);
      // Последняя клетка кольца по часовой — прямо перед красным стартом (индекс 0).
      expect(redCell(m.to), ringLength - 1);
    });

    test('сдвиг за своей фишкой может завести в финиш', () {
      final s = makeState(red: [lastRing - 2, lastRing, -1]);
      final m = moveFor(GameEngine.getLegalMoves(s, 2), 0);
      expect(m.entersFinish, isTrue);
      expect(m.to, fEnd);
    });

    test('фишки в финише не ходят и неуязвимы', () {
      final s = makeState(red: [fEnd, fEnd - 1, -1]);
      final moves = GameEngine.getLegalMoves(s, 4);
      expect(moves, hasLength(1));
      expect(moves.single.piece.id, 2);
    });
  });

  group('очерёдность', () {
    test('после 6 — дополнительный бросок', () {
      final s = GameEngine.applyRoll(makeState(red: [5, -1, -1]), 6);
      expect(s.extraTurn, isTrue);
      final next = GameEngine.applyMove(
        s,
        moveFor(GameEngine.getLegalMoves(s, 6), 0),
      );
      expect(next.currentPlayer.color, PlayerColor.red);
      expect(next.phase, GamePhase.waitingForRoll);
      expect(next.extraTurn, isTrue);
    });

    test('обычный бросок — ход переходит дальше', () {
      final s = GameEngine.applyRoll(makeState(red: [5, -1, -1]), 3);
      final next = GameEngine.applyMove(
        s,
        moveFor(GameEngine.getLegalMoves(s, 3), 0),
      );
      expect(next.currentPlayer.color, PlayerColor.yellow);
      expect(next.diceValue, isNull);
    });

    test('нет ходов — пропуск хода', () {
      final s = GameEngine.applyRoll(makeState(red: [fEnd, fEnd - 1, f0]), 4);
      expect(GameEngine.getLegalMoves(s, 4), isEmpty);
      expect(GameEngine.passTurn(s).currentPlayer.color, PlayerColor.yellow);
    });

    test('нет ходов при 6 — дополнительный бросок всё равно даётся', () {
      final s = GameEngine.applyRoll(makeState(red: [fEnd, fEnd - 1, f0]), 6);
      expect(GameEngine.getLegalMoves(s, 6), isEmpty);
      final next = GameEngine.passTurn(s);
      expect(next.currentPlayer.color, PlayerColor.red);
      expect(next.extraTurn, isTrue);
    });

    test('ход всегда есть, пока у игрока есть фишка не в финише', () {
      final s = makeState(red: [fEnd, fEnd - 1, 10]);
      for (var d = 1; d <= 6; d++) {
        expect(GameEngine.getLegalMoves(s, d), isNotEmpty);
      }
    });
  });

  group('победа', () {
    test('последняя фишка в финише — победа', () {
      final s = GameEngine.applyRoll(
        makeState(red: [fEnd, fEnd - 1, lastRing - 1]),
        2,
      );
      final next = GameEngine.applyMove(
        s,
        moveFor(GameEngine.getLegalMoves(s, 2), 2),
      );
      expect(next.phase, GamePhase.finished);
      expect(next.winner, PlayerColor.red);
      expect(GameEngine.isFinished(next), isTrue);
    });

    test('до финиша всех фишек игра продолжается', () {
      final s = GameEngine.applyRoll(
        makeState(red: [fEnd, 20, lastRing - 1]),
        2,
      );
      final next = GameEngine.applyMove(
        s,
        moveFor(GameEngine.getLegalMoves(s, 2), 2),
      );
      expect(next.winner, isNull);
      expect(GameEngine.isFinished(next), isFalse);
    });
  });

  group('бот', () {
    test('приоритет: сброс соперника', () {
      final s = makeState(
        red: [5, 20, -1],
        yellow: [progressAt(yellow, redCell(8)), -1, -1],
      );
      expect(Bot.chooseMove(GameEngine.getLegalMoves(s, 3))!.isCapture, isTrue);
    });

    test('приоритет: финиш перед выходом из дома', () {
      final s = makeState(red: [5, lastRing - 2, -1]);
      expect(Bot.chooseMove(GameEngine.getLegalMoves(s, 3))!.piece.id, 1);
    });

    test('приоритет: выход из дома перед обычным ходом', () {
      final s = makeState(red: [5, -1, -1]);
      expect(
        Bot.chooseMove(GameEngine.getLegalMoves(s, 2))!.leavesHome,
        isTrue,
      );
    });

    test('иначе — самая дальняя фишка', () {
      final s = makeState(red: [5, 20, 12]);
      expect(Bot.chooseMove(GameEngine.getLegalMoves(s, 2))!.piece.id, 1);
    });
  });

  group('бонусные клетки', () {
    test('пятая клетка каждой стороны от угла по ходу движения', () {
      expect(bonusRingIndices(cw), {5, 13, 21, 29});
      expect(bonusRingIndices(ccw), {27, 3, 11, 19});
      for (final dir in MoveDirection.values) {
        for (final i in bonusRingIndices(dir)) {
          expect(i % (ringLength ~/ 4), isNot(0), reason: 'бонус не в углу');
        }
      }
    });

    for (final dir in MoveDirection.values) {
      test('остановка на бонусной клетке даёт ещё бросок (${dir.name})', () {
        final s = GameEngine.applyRoll(
          makeState(red: [2, -1, -1], direction: dir),
          3,
        );
        final m = moveFor(GameEngine.getLegalMoves(s, 3), 0);
        expect(m.to, bonusOffsetFromCorner);
        expect(m.bonus, isTrue);
        final next = GameEngine.applyMove(s, m);
        expect(next.currentPlayer.color, PlayerColor.red);
        expect(next.phase, GamePhase.waitingForRoll);
        expect(next.extraTurn, isTrue);
      });
    }

    test('проход через бонусную клетку без остановки бонуса не даёт', () {
      final s = GameEngine.applyRoll(makeState(red: [3, -1, -1]), 4);
      final m = moveFor(GameEngine.getLegalMoves(s, 4), 0);
      expect(m.bonus, isFalse);
      expect(
        GameEngine.applyMove(s, m).currentPlayer.color,
        PlayerColor.yellow,
      );
    });

    test('сброс чужой фишки на бонусной клетке — и сброс, и ещё бросок', () {
      final s = GameEngine.applyRoll(
        makeState(
          red: [2, -1, -1],
          yellow: [progressAt(yellow, redCell(5)), -1, -1],
        ),
        3,
      );
      final m = moveFor(GameEngine.getLegalMoves(s, 3), 0);
      expect(m.isCapture, isTrue);
      expect(m.bonus, isTrue);
      final next = GameEngine.applyMove(s, m);
      expect(next.playerOf(PlayerColor.yellow).pieces[0].isHome, isTrue);
      expect(next.currentPlayer.color, PlayerColor.red);
    });

    test('бот предпочитает бонусную клетку выходу из дома', () {
      final s = makeState(red: [2, -1, -1]);
      expect(Bot.chooseMove(GameEngine.getLegalMoves(s, 3))!.bonus, isTrue);
    });
  });

  group('бот со случайной стратегией', () {
    test('всегда выбирает допустимый ход и не всегда один и тот же', () {
      final s = makeState(
        red: [5, 20, -1],
        yellow: [progressAt(yellow, redCell(8)), -1, -1],
      );
      final moves = GameEngine.getLegalMoves(s, 3);
      final random = Random(7);
      final chosen = {
        for (var i = 0; i < 60; i++) Bot.chooseMove(moves, random: random)!,
      };
      expect(chosen.every(moves.contains), isTrue);
      expect(chosen.length, greaterThan(1));
    });
  });

  group('против часовой стрелки', () {
    test('фишка идёт к меньшим индексам кольца', () {
      final s = makeState(red: [0, -1, -1], direction: ccw);
      final m = moveFor(GameEngine.getLegalMoves(s, 3), 0);
      expect(m.to, 3);
      expect(redCell(m.to, ccw), ringLength - 3);
    });

    test('сброс чужой фишки сравнивается по абсолютному индексу', () {
      final target = redCell(3, ccw);
      final s = makeState(
        red: [0, -1, -1],
        yellow: [progressAt(yellow, target, ccw), -1, -1],
        direction: ccw,
      );
      expect(
        moveFor(GameEngine.getLegalMoves(s, 3), 0).captured,
        const PieceRef(PlayerColor.yellow, 0),
      );
    });

    test('выход на старт, занятый чужой фишкой', () {
      final s = makeState(
        yellow: [progressAt(yellow, redCell(0, ccw), ccw), -1, -1],
        direction: ccw,
      );
      expect(
        moveFor(GameEngine.getLegalMoves(s, 1), 0).captured,
        const PieceRef(PlayerColor.yellow, 0),
      );
    });

    test(
      'выход из дома против часовой: бросок 4 → три клетки после старта',
      () {
        final s = makeState(direction: ccw);
        final m = moveFor(GameEngine.getLegalMoves(s, 4), 0);
        expect(redCell(m.to, ccw), ringLength - 3);
      },
    );

    test('финиш работает так же', () {
      final s = makeState(red: [lastRing - 2, -1, -1], direction: ccw);
      expect(moveFor(GameEngine.getLegalMoves(s, 5), 0).to, fEnd);
    });

    test('очерёдность: красный → зелёный → жёлтый → синий', () {
      final s = GameEngine.newGame([
        for (final c in PlayerColor.values)
          PlayerConfig(color: c, type: PlayerType.human, name: c.displayName),
      ], direction: ccw);
      expect(s.players.map((p) => p.color), [
        PlayerColor.red,
        PlayerColor.green,
        PlayerColor.yellow,
        PlayerColor.blue,
      ]);
    });

    test('по часовой: красный → синий → жёлтый → зелёный', () {
      final s = GameEngine.newGame([
        for (final c in PlayerColor.values.reversed)
          PlayerConfig(color: c, type: PlayerType.human, name: c.displayName),
      ], direction: cw);
      expect(s.players.map((p) => p.color), PlayerColor.values);
    });
  });

  for (final dir in MoveDirection.values) {
    test('полная партия ботов завершается победой (${dir.name})', () {
      final random = Random(42);
      var s = GameEngine.newGame([
        for (final c in PlayerColor.values)
          PlayerConfig(color: c, type: PlayerType.bot, name: c.displayName),
      ], direction: dir);
      var turns = 0;
      while (!GameEngine.isFinished(s) && turns < 10000) {
        final dice = GameEngine.rollDice(random);
        s = GameEngine.applyRoll(s, dice);
        final moves = GameEngine.getLegalMoves(s, dice);
        s = moves.isEmpty
            ? GameEngine.passTurn(s)
            : GameEngine.applyMove(s, Bot.chooseMove(moves)!);
        // Инвариант: на одной клетке кольца не больше одной фишки.
        final ring = s.allPieces
            .map((p) => p.ringIndex(dir))
            .whereType<int>()
            .toList();
        expect(ring.toSet().length, ring.length);
        turns++;
      }
      expect(s.winner, isNotNull);
    });
  }
}
