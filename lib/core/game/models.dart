import '../constants.dart';

/// Цвета игроков в порядке обхода по часовой стрелке.
enum PlayerColor { red, blue, yellow, green }

extension PlayerColorX on PlayerColor {
  /// Индекс стартовой клетки на кольце.
  /// Индекс стартовой (угловой) клетки на кольце: 0, 8, 16, 24.
  int get startIndex => index * ringLength ~/ 4;

  String get displayName => switch (this) {
    PlayerColor.red => 'Красный',
    PlayerColor.blue => 'Синий',
    PlayerColor.yellow => 'Жёлтый',
    PlayerColor.green => 'Зелёный',
  };
}

enum PlayerType { human, bot }

/// Направление движения фишек по кольцу (и очерёдности ходов).
enum MoveDirection { clockwise, counterclockwise }

extension MoveDirectionX on MoveDirection {
  /// Шаг по индексам кольца (индексы 0..31 идут по часовой стрелке).
  int get sign => this == MoveDirection.clockwise ? 1 : -1;

  String get displayName =>
      this == MoveDirection.clockwise ? 'По часовой стрелке' : 'Против часовой стрелки';
}

/// Абсолютные индексы бонусных клеток кольца при данном направлении движения.
Set<int> bonusRingIndices(MoveDirection direction) => {
  for (final c in PlayerColor.values)
    (c.startIndex + direction.sign * bonusOffsetFromCorner) % ringLength,
};

/// Абсолютный индекс клетки кольца для фишки [owner] с данным progress (0..31).
int ringIndexFor(PlayerColor owner, int progress, MoveDirection direction) =>
    (owner.startIndex + direction.sign * progress) % ringLength;

enum GamePhase { waitingForRoll, waitingForMove, animating, finished }

/// Фишка. progress: -1 дом; 0..31 кольцо; 32..35 финишные лунки.
class Piece {
  const Piece({required this.owner, required this.id, this.progress = homeProgress, int? homeSlot})
    : homeSlot = homeSlot ?? id;

  final PlayerColor owner;
  final int id;
  final int progress;

  /// Лунка дома, в которой стоит фишка, пока она дома. В начале партии — по номеру
  /// фишки; сбитая фишка встаёт в самую дальнюю от центра свободную лунку.
  final int homeSlot;

  bool get isHome => progress == homeProgress;
  bool get isOnRing => progress >= 0 && progress < ringPathLength;
  bool get isFinished => progress >= finishStartProgress;

  /// Абсолютный индекс клетки кольца или null, если фишка не на кольце.
  int? ringIndex(MoveDirection direction) =>
      isOnRing ? ringIndexFor(owner, progress, direction) : null;

  Piece copyWith({int? progress, int? homeSlot}) => Piece(
    owner: owner,
    id: id,
    progress: progress ?? this.progress,
    homeSlot: homeSlot ?? this.homeSlot,
  );

  @override
  bool operator ==(Object other) =>
      other is Piece &&
      other.owner == owner &&
      other.id == id &&
      other.progress == progress &&
      other.homeSlot == homeSlot;

  @override
  int get hashCode => Object.hash(owner, id, progress, homeSlot);

  @override
  String toString() => 'Piece(${owner.name}#$id @ $progress)';
}

class Player {
  const Player({
    required this.color,
    required this.type,
    required this.name,
    required this.pieces,
    this.avatar = '',
    this.stats = const PlayerStats(),
  });

  factory Player.initial(PlayerColor color, PlayerType type, String name, {String avatar = ''}) =>
      Player(
        color: color,
        type: type,
        name: name,
        avatar: avatar,
        pieces: List.generate(piecesPerPlayer, (i) => Piece(owner: color, id: i)),
      );

  final PlayerColor color;
  final PlayerType type;
  final String name;
  final List<Piece> pieces;

  /// Аватар игрока (эмодзи); пустая строка — без аватара.
  final String avatar;

  /// Статистика за партию.
  final PlayerStats stats;

  bool get isBot => type == PlayerType.bot;
  bool get allFinished => pieces.every((p) => p.isFinished);

  Player copyWith({List<Piece>? pieces, PlayerStats? stats}) => Player(
    color: color,
    type: type,
    name: name,
    avatar: avatar,
    pieces: pieces ?? this.pieces,
    stats: stats ?? this.stats,
  );
}

/// Статистика игрока за партию. Хранится в [GameState], поэтому отмена хода
/// откатывает и её.
class PlayerStats {
  const PlayerStats({this.cells = 0, this.bonuses = 0, this.captures = 0, this.deaths = 0});

  /// Клеток пройдено фишками (выход из дома на старт — тоже шаг).
  final int cells;

  /// Дополнительных бросков: выпавших шестёрок и остановок на бонусной клетке.
  final int bonuses;

  /// Сбито фишек соперников.
  final int captures;

  /// Своих фишек сбито соперниками.
  final int deaths;

  PlayerStats copyWith({int? cells, int? bonuses, int? captures, int? deaths}) => PlayerStats(
    cells: cells ?? this.cells,
    bonuses: bonuses ?? this.bonuses,
    captures: captures ?? this.captures,
    deaths: deaths ?? this.deaths,
  );
}

/// Ссылка на фишку конкретного игрока.
class PieceRef {
  const PieceRef(this.owner, this.id);
  final PlayerColor owner;
  final int id;

  @override
  bool operator ==(Object other) => other is PieceRef && other.owner == owner && other.id == id;

  @override
  int get hashCode => Object.hash(owner, id);

  @override
  String toString() => '${owner.name}#$id';
}

/// Допустимый ход с заранее рассчитанным результатом.
class Move {
  const Move({
    required this.piece,
    required this.from,
    required this.to,
    this.captured,
    this.bonus = false,
  });

  final PieceRef piece;
  final int from;
  final int to;

  /// Сбитая фишка соперника (не больше одной: на клетке кольца стоит максимум одна фишка).
  final PieceRef? captured;

  /// Ход заканчивается на бонусной клетке — после него ещё один бросок.
  final bool bonus;

  bool get leavesHome => from == homeProgress;
  bool get entersFinish => to >= finishStartProgress;
  bool get isCapture => captured != null;

  @override
  String toString() => 'Move($piece: $from -> $to${captured != null ? ' x$captured' : ''})';
}

class GameState {
  const GameState({
    required this.players,
    this.direction = MoveDirection.counterclockwise,
    this.currentPlayerIndex = 0,
    this.diceValue,
    this.phase = GamePhase.waitingForRoll,
    this.extraTurn = false,
    this.winner,
  });

  final List<Player> players;
  final MoveDirection direction;
  final int currentPlayerIndex;
  final int? diceValue;
  final GamePhase phase;
  final bool extraTurn;
  final PlayerColor? winner;

  Player get currentPlayer => players[currentPlayerIndex];

  Player playerOf(PlayerColor color) => players.firstWhere((p) => p.color == color);

  Piece pieceOf(PieceRef ref) => playerOf(ref.owner).pieces[ref.id];

  Iterable<Piece> get allPieces => players.expand((p) => p.pieces);

  GameState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    int? Function()? diceValue,
    GamePhase? phase,
    bool? extraTurn,
    PlayerColor? Function()? winner,
  }) => GameState(
    players: players ?? this.players,
    direction: direction,
    currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
    diceValue: diceValue != null ? diceValue() : this.diceValue,
    phase: phase ?? this.phase,
    extraTurn: extraTurn ?? this.extraTurn,
    winner: winner != null ? winner() : this.winner,
  );
}
