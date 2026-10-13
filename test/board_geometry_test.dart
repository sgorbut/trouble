import 'package:flutter_test/flutter_test.dart';
import 'package:trouble_game/core/constants.dart';
import 'package:trouble_game/core/game/board_geometry.dart';
import 'package:trouble_game/core/game/models.dart';

int manhattan(GridPos a, GridPos b) => (a.row - b.row).abs() + (a.col - b.col).abs();

const last = gridSize - 1;
const corners = [GridPos(0, 0), GridPos(0, last), GridPos(last, last), GridPos(last, 0)];

void main() {
  final ring = [for (var i = 0; i < ringLength; i++) BoardGeometry.ringCell(i)];

  test('поле 9×9, в кольце 32 уникальные клетки по периметру', () {
    expect(gridSize, 9);
    expect(ringLength, 32);
    expect(ring.toSet(), hasLength(32));
    for (final c in ring) {
      expect(c.row == 0 || c.row == last || c.col == 0 || c.col == last, isTrue, reason: '$c');
    }
  });

  test('соседние индексы стоят рядом (включая 31 → 0)', () {
    for (var i = 0; i < ringLength; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ringLength];
      expect(manhattan(a, b), 1, reason: '$i: $a → $b');
    }
  });

  test('стартовые клетки 0, 8, 16, 24 — углы поля', () {
    expect([for (final c in PlayerColor.values) c.startIndex], [0, 8, 16, 24]);
    for (final c in PlayerColor.values) {
      expect(BoardGeometry.startCell(c), corners[c.index]);
    }
  });

  for (final dir in MoveDirection.values) {
    group(dir.name, () {
      test('путь фишки идёт по соседним клеткам от старта до дальней лунки', () {
        for (final c in PlayerColor.values) {
          final path = [
            for (var p = 0; p <= finishEndProgress; p++) BoardGeometry.cellFor(c, 0, p, dir),
          ];
          expect(path.first, BoardGeometry.startCell(c));
          for (var i = 0; i + 1 < path.length; i++) {
            expect(manhattan(path[i], path[i + 1]), 1, reason: '${c.name} $i: ${path[i]} → ${path[i + 1]}');
          }
        }
      });

      test('последняя клетка кольца на пути — соседняя со стартом (почти полный круг)', () {
        for (final c in PlayerColor.values) {
          final lastCell = BoardGeometry.cellFor(c, 0, ringPathLength - 1, dir);
          expect(manhattan(lastCell, BoardGeometry.startCell(c)), 1, reason: c.name);
        }
      });

      test('дома, финиши и кольцо не пересекаются', () {
        final all = <GridPos>[
          ...ring,
          for (final c in PlayerColor.values) ...BoardGeometry.homeHoles(c, dir),
          for (final c in PlayerColor.values) ...BoardGeometry.finishCells(c, dir),
        ];
        expect(all.toSet().length, all.length);
      });
    });
  }

  test('против часовой: красный идёт вниз по левому краю, финиш — вниз по краю дома', () {
    const dir = MoveDirection.counterclockwise;
    expect(BoardGeometry.cellFor(PlayerColor.red, 0, 1, dir), const GridPos(1, 0));
    expect(BoardGeometry.cellFor(PlayerColor.red, 0, ringPathLength - 1, dir), const GridPos(0, 1));
    expect(BoardGeometry.finishCells(PlayerColor.red, dir).first, const GridPos(1, 1));
  });

  test('по часовой: красный идёт вправо по верху, финиш — вправо по краю дома', () {
    const dir = MoveDirection.clockwise;
    expect(BoardGeometry.cellFor(PlayerColor.red, 0, 1, dir), const GridPos(0, 1));
    expect(BoardGeometry.cellFor(PlayerColor.red, 0, ringPathLength - 1, dir), const GridPos(1, 0));
    expect(BoardGeometry.finishCells(PlayerColor.red, dir).first, const GridPos(1, 1));
  });

  test('лунки и финишная дорожка помещаются в цветной квадрат дома', () {
    const z = BoardGeometry.homeZoneSize;
    bool inZone(GridPos o, GridPos g) =>
        g.row >= o.row && g.row < o.row + z && g.col >= o.col && g.col < o.col + z;
    for (final dir in MoveDirection.values) {
      for (final c in PlayerColor.values) {
        final o = BoardGeometry.homeZoneOrigin(c);
        expect(BoardGeometry.homeHoles(c, dir), hasLength(piecesPerPlayer));
        expect(BoardGeometry.finishCells(c, dir), hasLength(piecesPerPlayer));
        for (final g in [...BoardGeometry.homeHoles(c, dir), ...BoardGeometry.finishCells(c, dir)]) {
          expect(inZone(o, g), isTrue, reason: '${c.name} ${dir.name} $g');
        }
      }
    }
  });
}
