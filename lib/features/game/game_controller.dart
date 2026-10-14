import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/game/board_geometry.dart';
import '../../core/game/bot.dart';
import '../../core/game/engine.dart';
import '../../core/game/models.dart';
import '../settings/settings_provider.dart';
import 'sound_service.dart';

/// Короткий визуальный эффект на клетке поля (сброс фишки, заход в финиш).
class BoardEffect {
  const BoardEffect({
    required this.id,
    required this.cell,
    required this.color,
    required this.kind,
  });
  final int id;
  final GridPos cell;
  final PlayerColor color;
  final BoardEffectKind kind;
}

enum BoardEffectKind { capture, finish }

/// Жребий перед партией: кто выбросит больше, ходит первым; при ничьей лидеры перебрасывают.
class Lottery {
  const Lottery(this.contenders, this.rolls);

  /// Кто сейчас участвует в жребии (в порядке ходов).
  final List<PlayerColor> contenders;

  /// Выпавшие значения в текущем круге жребия.
  final Map<PlayerColor, int> rolls;
}

/// Состояние экрана игры: логическое состояние партии плюс то, что нужно для анимаций.
class GameViewState {
  const GameViewState({
    required this.game,
    required this.configs,
    required this.direction,
    required this.display,
    this.shownDice,
    this.rolling = false,
    this.legalMoves = const [],
    this.selected,
    this.fastPieces = const {},
    this.effects = const [],
    this.notice,
    this.paused = false,
    this.undoSnapshot,
    this.lottery,
  });

  final GameState game;
  final List<PlayerConfig> configs;
  final MoveDirection direction;

  /// Отображаемый progress каждой фишки (во время анимации отличается от [game]).
  final Map<PieceRef, int> display;

  /// Значение на кубике: выпавшее в текущем броске; null — кубик ещё не брошен.
  final int? shownDice;
  final bool rolling;
  final List<Move> legalMoves;
  final PieceRef? selected;

  /// Фишки, которые сейчас быстро летят домой после сброса.
  final Set<PieceRef> fastPieces;
  final List<BoardEffect> effects;
  final String? notice;
  final bool paused;

  /// Состояние перед последним ходом человека (с тем же броском) — для отмены.
  /// Хранится только одно: отменить можно ровно один ход.
  final GameState? undoSnapshot;

  /// Идёт жребий за право первого хода (null — партия уже началась).
  final Lottery? lottery;

  bool get canUndo =>
      undoSnapshot != null &&
      !paused &&
      game.phase != GamePhase.animating &&
      game.phase != GamePhase.finished;

  Move? get selectedMove {
    final sel = selected;
    if (sel == null) return null;
    for (final m in legalMoves) {
      if (m.piece == sel) return m;
    }
    return null;
  }

  bool get canRoll =>
      game.phase == GamePhase.waitingForRoll &&
      !game.currentPlayer.isBot &&
      !paused;

  GameViewState copyWith({
    GameState? game,
    Map<PieceRef, int>? display,
    int? Function()? shownDice,
    bool? rolling,
    List<Move>? legalMoves,
    PieceRef? Function()? selected,
    Set<PieceRef>? fastPieces,
    List<BoardEffect>? effects,
    String? Function()? notice,
    bool? paused,
    GameState? Function()? undoSnapshot,
    Lottery? Function()? lottery,
  }) => GameViewState(
    game: game ?? this.game,
    configs: configs,
    direction: direction,
    display: display ?? this.display,
    shownDice: shownDice != null ? shownDice() : this.shownDice,
    rolling: rolling ?? this.rolling,
    legalMoves: legalMoves ?? this.legalMoves,
    selected: selected != null ? selected() : this.selected,
    fastPieces: fastPieces ?? this.fastPieces,
    effects: effects ?? this.effects,
    notice: notice != null ? notice() : this.notice,
    paused: paused ?? this.paused,
    undoSnapshot: undoSnapshot != null ? undoSnapshot() : this.undoSnapshot,
    lottery: lottery != null ? lottery() : this.lottery,
  );
}

final randomProvider = Provider<Random>((ref) => Random());

class GameController extends Notifier<GameViewState?> {
  /// Увеличивается при рестарте/выходе: незавершённые асинхронные цепочки прерываются.
  int _epoch = 0;
  int _effectSeq = 0;

  Random get _random => ref.read(randomProvider);
  SoundService get _sound => ref.read(soundServiceProvider);

  @override
  GameViewState? build() {
    ref.onDispose(() => _epoch++);
    return null;
  }

  GameViewState get _s => state!;

  /// Новая партия. Направление и жребий по умолчанию берутся из настроек.
  void start(
    List<PlayerConfig> configs, {
    MoveDirection? direction,
    bool? lottery,
  }) {
    _epoch++;
    final settings = ref.read(settingsProvider);
    final dir = direction ?? settings.direction;
    final game = GameEngine.newGame(configs, direction: dir);
    final useLottery = lottery ?? settings.lotteryStart;
    state = GameViewState(
      game: game,
      configs: configs,
      direction: dir,
      display: _displayFrom(game),
      lottery: useLottery
          ? Lottery([for (final p in game.players) p.color], const {})
          : null,
      notice: useLottery ? 'Жребий: кто выбросит больше, ходит первым' : null,
    );
    _scheduleBotTurn();
  }

  /// Перезапуск с теми же игроками и направлением.
  void restart() {
    final s = state;
    if (s != null) start(s.configs, direction: s.direction);
  }

  /// Прерывает все отложенные действия (при уходе с экрана игры).
  void stop() => _epoch++;

  void pause() {
    if (state != null) state = _s.copyWith(paused: true);
  }

  void resume() {
    if (state != null) state = _s.copyWith(paused: false);
  }

  Map<PieceRef, int> _displayFrom(GameState game) => {
    for (final p in game.allPieces) PieceRef(p.owner, p.id): p.progress,
  };

  /// Пауза с учётом паузы игры. Возвращает false, если цепочку надо прервать.
  Future<bool> _wait(Duration d, int epoch) async {
    await Future<void>.delayed(d);
    while (true) {
      if (epoch != _epoch || !ref.mounted || state == null) return false;
      if (!_s.paused) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Duration _botDelay() => Duration(
    milliseconds:
        botDelayMinMs + _random.nextInt(botDelayMaxMs - botDelayMinMs + 1),
  );

  void _scheduleBotTurn() async {
    final s = state;
    if (s == null ||
        s.game.phase != GamePhase.waitingForRoll ||
        !s.game.currentPlayer.isBot) {
      return;
    }
    final epoch = _epoch;
    if (!await _wait(_botDelay(), epoch)) return;
    await _roll(epoch);
  }

  /// Бросок кубика по нажатию игрока.
  Future<void> roll() async {
    final s = state;
    if (s == null || !s.canRoll) return;
    await _roll(_epoch);
  }

  Future<void> _roll(int epoch) async {
    if (_s.lottery != null) return _lotteryRoll(epoch);
    final before = _s.game;
    if (before.phase != GamePhase.waitingForRoll) return;
    state = _s.copyWith(
      rolling: true,
      game: before.copyWith(phase: GamePhase.animating),
      selected: () => null,
      notice: () => null,
    );
    _sound.play(GameSound.roll);
    if (!await _wait(diceRollDuration, epoch)) return;

    final dice = GameEngine.rollDice(_random);
    final rolled = GameEngine.applyRoll(before, dice);
    final moves = GameEngine.getLegalMoves(rolled, dice);

    if (moves.isEmpty) {
      state = _s.copyWith(
        rolling: false,
        shownDice: () => dice,
        game: rolled.copyWith(phase: GamePhase.animating),
        legalMoves: const [],
        notice: () => dice == 6
            ? 'Ходов нет, но за 6 — ещё бросок'
            : 'Ходов нет — ход переходит',
      );
      if (!await _wait(noMovesPause, epoch)) return;
      state = _s.copyWith(
        game: GameEngine.passTurn(rolled),
        shownDice: () => null,
        notice: () => null,
      );
      _scheduleBotTurn();
      return;
    }

    state = _s.copyWith(
      rolling: false,
      shownDice: () => dice,
      game: rolled,
      legalMoves: moves,
    );

    if (rolled.currentPlayer.isBot) {
      if (!await _wait(_botDelay(), epoch)) return;
      await _executeMove(Bot.chooseMove(moves, random: _random)!, epoch);
    } else if (moves.length == 1 && ref.read(settingsProvider).autoMoveSingle) {
      if (!await _wait(const Duration(milliseconds: 350), epoch)) return;
      await _executeMove(moves.single, epoch);
    }
  }

  /// Бросок жребия текущим участником. Когда все бросили: один лидер — он ходит первым,
  /// несколько с одинаковым максимумом — перебрасывают только они.
  Future<void> _lotteryRoll(int epoch) async {
    final before = _s.game;
    if (before.phase != GamePhase.waitingForRoll) return;
    final lot = _s.lottery!;
    final player = before.currentPlayer;
    state = _s.copyWith(
      rolling: true,
      game: before.copyWith(phase: GamePhase.animating),
      notice: () => null,
    );
    _sound.play(GameSound.roll);
    if (!await _wait(diceRollDuration, epoch)) return;

    final dice = GameEngine.rollDice(_random);
    final rolls = {...lot.rolls, player.color: dice};
    state = _s.copyWith(
      rolling: false,
      shownDice: () => dice,
      lottery: () => Lottery(lot.contenders, rolls),
      notice: () => '${player.name}: $dice',
    );
    if (!await _wait(lotteryPause, epoch)) return;

    int indexOf(PlayerColor c) =>
        before.players.indexWhere((p) => p.color == c);
    String nameOf(PlayerColor c) => before.players[indexOf(c)].name;
    GameState turnOf(PlayerColor c) => before.copyWith(
      currentPlayerIndex: indexOf(c),
      phase: GamePhase.waitingForRoll,
      diceValue: () => null,
    );

    final pending = lot.contenders.where((c) => !rolls.containsKey(c)).toList();
    if (pending.isNotEmpty) {
      state = _s.copyWith(
        game: turnOf(pending.first),
        shownDice: () => null,
        notice: () => null,
      );
    } else {
      final best = lot.contenders.map((c) => rolls[c]!).reduce(max);
      final leaders = lot.contenders.where((c) => rolls[c] == best).toList();
      if (leaders.length > 1) {
        state = _s.copyWith(
          game: turnOf(leaders.first),
          shownDice: () => null,
          lottery: () => Lottery(leaders, const {}),
          notice: () =>
              'Ничья ($best): ${leaders.map(nameOf).join(', ')} — перебрасывают',
        );
      } else {
        state = _s.copyWith(
          game: turnOf(leaders.single),
          shownDice: () => null,
          lottery: () => null,
          notice: () => 'Первым ходит ${nameOf(leaders.single)}',
        );
      }
    }
    _scheduleBotTurn();
  }

  /// Нажатие на фишку. Один допустимый ход — выполняется сразу; иначе первое нажатие
  /// выбирает фишку и показывает клетку назначения, повторное — ходит.
  void tapPiece(PieceRef piece) {
    final s = state;
    if (s == null ||
        s.paused ||
        s.game.phase != GamePhase.waitingForMove ||
        s.game.currentPlayer.isBot) {
      return;
    }
    Move? move;
    for (final m in s.legalMoves) {
      if (m.piece == piece) move = m;
    }
    if (move == null) {
      state = s.copyWith(selected: () => null);
      return;
    }
    if (s.legalMoves.length == 1 || s.selected == piece) {
      _executeMove(move, _epoch);
    } else {
      state = s.copyWith(selected: () => piece);
    }
  }

  /// Нажатие на подсвеченную клетку назначения.
  void confirmSelected() {
    final s = state;
    final move = s?.selectedMove;
    if (s == null ||
        move == null ||
        s.paused ||
        s.game.phase != GamePhase.waitingForMove)
      return;
    _executeMove(move, _epoch);
  }

  /// Отмена последнего хода человека: фишки возвращаются, бросок тот же,
  /// игрок выбирает ход заново. Ходы ботов после него тоже откатываются.
  void undo() {
    final s = state;
    if (s == null || !s.canUndo) return;
    _epoch++; // прерываем отложенные действия ботов
    final game = s.undoSnapshot!;
    state = GameViewState(
      game: game,
      configs: s.configs,
      direction: s.direction,
      display: _displayFrom(game),
      shownDice: game.diceValue,
      legalMoves: GameEngine.getLegalMoves(game, game.diceValue!),
    );
  }

  /// Пошаговые позиции фишки во время хода.
  static List<int> movePath(Move move) {
    final path = <int>[];
    final first = move.leavesHome ? 0 : move.from + 1;
    final ringEnd = move.entersFinish ? ringPathLength - 1 : move.to;
    for (var p = first; p <= ringEnd; p++) {
      path.add(p);
    }
    if (move.entersFinish) {
      for (var p = finishStartProgress; p <= move.to; p++) {
        path.add(p);
      }
    }
    return path;
  }

  Future<void> _executeMove(Move move, int epoch) async {
    final game = _s.game;
    state = _s.copyWith(
      game: game.copyWith(phase: GamePhase.animating),
      legalMoves: const [],
      selected: () => null,
      // Запоминаем позицию перед ходом человека для отмены; ход бота её не трогает.
      undoSnapshot: game.currentPlayer.isBot ? null : () => game,
    );

    for (final p in movePath(move)) {
      state = _s.copyWith(display: {..._s.display, move.piece: p});
      _sound.play(GameSound.move);
      if (!await _wait(stepDuration, epoch)) return;
    }

    final captured = move.captured;
    if (captured != null) {
      _addEffect(
        BoardGeometry.cellFor(
          move.piece.owner,
          move.piece.id,
          move.to,
          game.direction,
        ),
        captured.owner,
        BoardEffectKind.capture,
      );
      state = _s.copyWith(
        display: {..._s.display, captured: homeProgress},
        fastPieces: {captured},
      );
      _sound.play(GameSound.capture);
      if (!await _wait(captureDuration, epoch)) return;
    }

    if (move.entersFinish) {
      _addEffect(
        BoardGeometry.cellFor(
          move.piece.owner,
          move.piece.id,
          move.to,
          game.direction,
        ),
        move.piece.owner,
        BoardEffectKind.finish,
      );
    }

    final next = GameEngine.applyMove(game, move);
    state = _s.copyWith(
      notice: move.bonus && next.phase != GamePhase.finished
          ? () => 'Бонусная клетка — ещё бросок!'
          : null,
      game: next,
      display: _displayFrom(next),
      fastPieces: const {},
      // Перед следующим броском кубик сбрасывается.
      shownDice: next.phase == GamePhase.waitingForRoll ? () => null : null,
    );

    if (next.phase == GamePhase.finished) {
      _sound.play(GameSound.win);
      return;
    }
    _scheduleBotTurn();
  }

  void _addEffect(GridPos cell, PlayerColor color, BoardEffectKind kind) {
    final effect = BoardEffect(
      id: _effectSeq++,
      cell: cell,
      color: color,
      kind: kind,
    );
    state = _s.copyWith(effects: [..._s.effects, effect]);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!ref.mounted || state == null) return;
      state = _s.copyWith(
        effects: _s.effects.where((e) => e.id != effect.id).toList(),
      );
    });
  }
}

final gameControllerProvider = NotifierProvider<GameController, GameViewState?>(
  GameController.new,
);
