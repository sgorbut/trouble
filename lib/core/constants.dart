/// Глобальные константы игры. Чистый Dart, без импортов Flutter.
library;

/// Количество клеток кольца: периметр поля 9×9.
const int ringLength = 32;

/// Сколько клеток кольца проходит одна фишка (progress 0..31): почти полный круг —
/// от своей стартовой клетки до клетки прямо перед ней, затем поворот в финиш.
const int ringPathLength = ringLength;

/// progress фишки, стоящей дома.
const int homeProgress = -1;

/// Бонусная клетка — пятая клетка каждой стороны по ходу движения, считая от угловой
/// (стартовой) клетки: остановка на ней даёт ещё один бросок.
const int bonusOffsetFromCorner = 5;

/// Первая (ближняя) финишная лунка.
const int finishStartProgress = ringPathLength; // 32

/// Последняя (дальняя) финишная лунка.
const int finishEndProgress = ringPathLength + piecesPerPlayer - 1; // 34

/// Фишек у каждого игрока.
const int piecesPerPlayer = 3;

/// Размер сетки поля.
const int gridSize = 9;

/// Тайминги анимаций.
const Duration diceRollDuration = Duration(milliseconds: 800);
const Duration stepDuration = Duration(milliseconds: 150);
const Duration captureDuration = Duration(milliseconds: 350);
const Duration noMovesPause = Duration(milliseconds: 900);
const Duration lotteryPause = Duration(milliseconds: 1100);
const int botDelayMinMs = 600;
const int botDelayMaxMs = 1000;
