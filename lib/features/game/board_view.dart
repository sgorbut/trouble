import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/game/board_geometry.dart';
import '../../core/game/models.dart';
import '../../ui/theme.dart';
import '../settings/settings_provider.dart';
import 'board_painter.dart';
import 'dice_widget.dart';
import 'game_controller.dart';

/// Поле: нарисованная подложка ([BoardPainter]) и слой фишек поверх неё.
class BoardView extends ConsumerStatefulWidget {
  const BoardView({super.key, required this.side});

  final double side;

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(gameControllerProvider);
    if (view == null) return SizedBox.square(dimension: widget.side);
    final controller = ref.read(gameControllerProvider.notifier);

    final side = widget.side;
    final cell = side / gridSize;
    final game = view.game;
    final current = game.currentPlayer.color;
    final humanTurn = !game.currentPlayer.isBot;

    final movable = {for (final m in view.legalMoves) m.piece};
    final selectedMove = view.selectedMove;
    final destCell = selectedMove == null
        ? null
        : BoardGeometry.cellFor(
            selectedMove.piece.owner,
            selectedMove.piece.id,
            selectedMove.to,
            game.direction,
          );
    // Клетки, которые пройдёт выбранная фишка: из дома — со стартовой клетки.
    final movePath = selectedMove == null
        ? const <GridPos>[]
        : [
            for (var p = max(selectedMove.from + 1, 0); p <= selectedMove.to; p++)
              BoardGeometry.cellFor(
                selectedMove.piece.owner,
                selectedMove.piece.id,
                p,
                game.direction,
              ),
          ];

    // Фишки: движущиеся/выбранные рисуются поверх остальных.
    final refs = [for (final p in game.allPieces) PieceRef(p.owner, p.id)]
      ..sort((a, b) {
        int rank(PieceRef r) => (movable.contains(r) ? 1 : 0) + (view.selected == r ? 2 : 0);
        return rank(a).compareTo(rank(b));
      });

    return SizedBox.square(
      dimension: side,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: destCell == null ? null : () => controller.confirmSelected(),
              child: CustomPaint(
                painter: BoardPainter(
                  pulse: _pulse,
                  direction: game.direction,
                  activePlayer: game.phase == GamePhase.finished ? null : current,
                  movePath: movePath,
                  destination: destCell,
                  destinationColor: current,
                ),
              ),
            ),
          ),
          for (final e in view.effects)
            Positioned(
              key: ValueKey('effect-${e.id}'),
              left: e.cell.col * cell - cell,
              top: e.cell.row * cell - cell,
              width: cell * 3,
              height: cell * 3,
              child: IgnorePointer(child: _Burst(effect: e)),
            ),
          _centerDice(view, side, cell, controller),
          for (final r in refs)
            _positionedPiece(
              r,
              view,
              cell,
              movable: humanTurn && movable.contains(r),
              highlighted: movable.contains(r),
              onTap: () => controller.tapPiece(r),
            ),
          if (destCell != null)
            Positioned(
              left: destCell.col * cell,
              top: destCell.row * cell,
              width: cell,
              height: cell,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.confirmSelected,
              ),
            ),
        ],
      ),
    );
  }

  /// Кубик в центре поля (на круглой площадке, которую рисует [BoardPainter]).
  Widget _centerDice(GameViewState view, double side, double cell, GameController controller) {
    final size = cell * 1.15;
    // DiceWidget занимает 1.25×1.5 размера грани: сверху запас под подскок, снизу тень;
    // центр грани — на 0.6 размера от нижнего края.
    return Positioned(
      left: side / 2 - size * 0.625,
      top: side / 2 - size * 0.9,
      child: DiceWidget(
        value: view.shownDice,
        rolling: view.rolling,
        enabled: view.canRoll,
        accent: view.game.currentPlayer.color.color,
        haptics: ref.watch(settingsProvider.select((s) => s.vibrationEnabled)),
        size: size,
        onTap: controller.roll,
      ),
    );
  }

  Widget _positionedPiece(
    PieceRef r,
    GameViewState view,
    double cell, {
    required bool movable,
    required bool highlighted,
    required VoidCallback onTap,
  }) {
    final progress = view.display[r] ?? homeProgress;
    final pos = BoardGeometry.cellFor(r.owner, r.id, progress, view.game.direction);
    final size = cell * 0.78;
    final fast = view.fastPieces.contains(r);
    return AnimatedPositioned(
      key: ValueKey('piece-${r.owner.name}-${r.id}'),
      duration: fast ? captureDuration : stepDuration * 0.85,
      curve: fast ? Curves.easeInBack : Curves.easeOut,
      left: pos.col * cell + (cell - size) / 2,
      top: pos.row * cell + (cell - size) / 2,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) {
            final dy = highlighted ? -sin(_bounce.value * pi) * cell * 0.1 : 0.0;
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
          child: _Token(
            color: r.owner,
            highlighted: highlighted,
            selected: view.selected == r,
            interactive: movable,
            flying: fast,
          ),
        ),
      ),
    );
  }
}

class _Token extends StatelessWidget {
  const _Token({
    required this.color,
    required this.highlighted,
    required this.selected,
    required this.interactive,
    required this.flying,
  });

  final PlayerColor color;
  final bool highlighted;
  final bool selected;
  final bool interactive;
  final bool flying;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedScale(
        scale: flying ? 0.7 : (selected ? 1.12 : 1.0),
        duration: const Duration(milliseconds: 180),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.4),
              radius: 0.95,
              colors: [Color.lerp(color.color, Colors.white, 0.65)!, color.color, color.dark],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: selected ? Colors.white : color.dark,
              width: selected ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
              if (highlighted)
                BoxShadow(
                  color: color.color.withValues(alpha: 0.85),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              if (flying) const BoxShadow(color: Colors.white, blurRadius: 12, spreadRadius: 3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Расходящееся кольцо: сброс фишки или заход в финиш.
class _Burst extends StatelessWidget {
  const _Burst({required this.effect});

  final BoardEffect effect;

  @override
  Widget build(BuildContext context) {
    final isFinish = effect.kind == BoardEffectKind.finish;
    final color = isFinish ? const Color(0xFFFFD54F) : effect.color.color;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, t, _) => CustomPaint(
        painter: _BurstPainter(t: t, color: color, sparkles: isFinish),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.t, required this.color, required this.sparkles});

  final double t;
  final Color color;
  final bool sparkles;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = maxR * 0.12 * (1 - t)
      ..color = color.withValues(alpha: 1 - t);
    canvas.drawCircle(c, maxR * (0.25 + 0.75 * t), paint);
    final rays = sparkles ? 8 : 6;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * pi / rays;
      final p = c + Offset(cos(a), sin(a)) * maxR * (0.3 + 0.6 * t);
      canvas.drawCircle(p, maxR * 0.07 * (1 - t), Paint()..color = color.withValues(alpha: 1 - t));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
