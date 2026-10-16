import '../constants.dart';
import 'models.dart';

/// Клетка сетки 9×9: row сверху вниз, col слева направо.
class GridPos {
  const GridPos(this.row, this.col);
  final int row;
  final int col;

  @override
  bool operator ==(Object other) => other is GridPos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}

/// Геометрия поля: перевод индексов кольца, домов и финишей в клетки сетки.
class BoardGeometry {
  const BoardGeometry._();

  /// Клетка сетки для индекса кольца 0..31 (по часовой стрелке от левого верхнего угла).
  /// Кольцо — периметр поля 9×9; углы 0, 8, 16, 24 — стартовые клетки.
  static GridPos ringCell(int index) {
    assert(index >= 0 && index < ringLength);
    if (index < 8) return GridPos(0, index);
    if (index < 16) return GridPos(index - 8, 8);
    if (index < 24) return GridPos(8, 24 - index);
    return GridPos(32 - index, 0);
  }

  /// Сторона квадратной зоны дома в клетках.
  static const int homeZoneSize = 3;

  /// Номера лунок дома от самой дальней от центра поля к ближней.
  static List<int> homeSlotsFarFirst(PlayerColor color, MoveDirection direction) {
    final holes = homeHoles(color, direction);
    const c = (gridSize - 1) / 2;
    double dist(GridPos g) => (g.row - c) * (g.row - c) + (g.col - c) * (g.col - c);
    return [for (var i = 0; i < holes.length; i++) i]
      ..sort((a, b) => dist(holes[b]).compareTo(dist(holes[a])));
  }

  /// Лунки дома (по номеру лунки): три в ряд вдоль внутреннего края зоны дома,
  /// параллельно финишной дорожке — всё помещается в цветной квадрат 3×3.
  static List<GridPos> homeHoles(PlayerColor color, MoveDirection direction) =>
      direction == MoveDirection.counterclockwise
      ? switch (color) {
          PlayerColor.red => const [GridPos(1, 3), GridPos(2, 3), GridPos(3, 3)],
          PlayerColor.blue => const [GridPos(3, 7), GridPos(3, 6), GridPos(3, 5)],
          PlayerColor.yellow => const [GridPos(7, 5), GridPos(6, 5), GridPos(5, 5)],
          PlayerColor.green => const [GridPos(5, 1), GridPos(5, 2), GridPos(5, 3)],
        }
      : switch (color) {
          PlayerColor.red => const [GridPos(3, 1), GridPos(3, 2), GridPos(3, 3)],
          PlayerColor.blue => const [GridPos(1, 5), GridPos(2, 5), GridPos(3, 5)],
          PlayerColor.yellow => const [GridPos(5, 7), GridPos(5, 6), GridPos(5, 5)],
          PlayerColor.green => const [GridPos(7, 3), GridPos(6, 3), GridPos(5, 3)],
        };

  /// Зона дома: левый верхний угол квадрата [homeZoneSize]×[homeZoneSize].
  static GridPos homeZoneOrigin(PlayerColor color) => switch (color) {
    PlayerColor.red => const GridPos(1, 1),
    PlayerColor.blue => const GridPos(1, 5),
    PlayerColor.yellow => const GridPos(5, 5),
    PlayerColor.green => const GridPos(5, 1),
  };

  /// Финишные клетки, progress 32 → 34 (от ближней к дальней).
  ///
  /// Финишная дорожка начинается у клетки кольца прямо перед стартом своего цвета
  /// (фишка делает почти полный круг) и идёт вдоль края зоны дома, внутри неё.
  static List<GridPos> finishCells(PlayerColor color, MoveDirection direction) =>
      direction == MoveDirection.counterclockwise
      ? switch (color) {
          PlayerColor.red => const [GridPos(1, 1), GridPos(2, 1), GridPos(3, 1)],
          PlayerColor.blue => const [GridPos(1, 7), GridPos(1, 6), GridPos(1, 5)],
          PlayerColor.yellow => const [GridPos(7, 7), GridPos(6, 7), GridPos(5, 7)],
          PlayerColor.green => const [GridPos(7, 1), GridPos(7, 2), GridPos(7, 3)],
        }
      : switch (color) {
          PlayerColor.red => const [GridPos(1, 1), GridPos(1, 2), GridPos(1, 3)],
          PlayerColor.blue => const [GridPos(1, 7), GridPos(2, 7), GridPos(3, 7)],
          PlayerColor.yellow => const [GridPos(7, 7), GridPos(7, 6), GridPos(7, 5)],
          PlayerColor.green => const [GridPos(7, 1), GridPos(6, 1), GridPos(5, 1)],
        };

  static GridPos startCell(PlayerColor color) => ringCell(color.startIndex);

  /// Клетка, на которой стоит фишка с данным progress.
  /// Дома [homeSlot] — номер лунки ([Piece.homeSlot]); на поле не важен.
  static GridPos cellFor(PlayerColor owner, int homeSlot, int progress, MoveDirection direction) {
    if (progress == homeProgress) return homeHoles(owner, direction)[homeSlot];
    if (progress < ringPathLength) {
      return ringCell(ringIndexFor(owner, progress, direction));
    }
    return finishCells(owner, direction)[progress - finishStartProgress];
  }
}
