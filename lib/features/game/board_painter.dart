import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/game/board_geometry.dart';
import '../../core/game/models.dart';
import '../../ui/theme.dart';

/// Рисует статичное поле: кольцо, дома, финиши, стартовые и бонусные клетки.
/// Путь ходящего игрока, путь выбранной фишки и клетка назначения — по параметрам.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.pulse,
    required this.direction,
    this.activePlayer,
    this.movePath = const [],
    this.destination,
    this.destinationColor,
  }) : super(repaint: pulse);

  final Animation<double> pulse;

  /// От направления зависит, какой рукав креста — финиш какого цвета.
  final MoveDirection direction;

  /// Чей сейчас ход: его зона дома рисуется насыщеннее и с рамкой, а путь фишек
  /// от старта до финиша выделен гранями клеток.
  final PlayerColor? activePlayer;

  /// Клетки, по которым пройдёт выбранная фишка (до клетки назначения включительно).
  final List<GridPos> movePath;
  final GridPos? destination;
  final PlayerColor? destinationColor;

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height);
    final cell = side / gridSize;

    Rect rectOf(GridPos p, [double inset = 0]) => Rect.fromLTWH(
      p.col * cell + inset,
      p.row * cell + inset,
      cell - inset * 2,
      cell - inset * 2,
    );

    // Клетки внутри зон домов (лунки и финиш) стоят с бо́льшим отступом — целиком
    // внутри цветной области.
    final ring = {for (var i = 0; i < ringLength; i++) BoardGeometry.ringCell(i)};
    RRect cellShape(GridPos g) => RRect.fromRectAndRadius(
      rectOf(g, cell * (ring.contains(g) ? 0.06 : 0.14)),
      Radius.circular(cell * 0.18),
    );

    // Фон.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & Size(side, side), Radius.circular(cell * 0.3)),
      Paint()..color = AppTheme.boardBackground,
    );

    // Зоны домов.
    for (final c in PlayerColor.values) {
      final o = BoardGeometry.homeZoneOrigin(c);
      const z = BoardGeometry.homeZoneSize;
      final r = Rect.fromLTWH(o.col * cell, o.row * cell, cell * z, cell * z).inflate(cell * 0.02);
      final zone = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.4));
      final active = c == activePlayer;
      canvas.drawRRect(zone, Paint()..color = c.color.withValues(alpha: active ? 0.45 : 0.18));
    }

    // Клетки кольца; бонусные — как обычные, только с бледной иконкой.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, cell * 0.03)
      ..color = AppTheme.cellBorder;
    final bonus = bonusRingIndices(direction);
    for (var i = 0; i < ringLength; i++) {
      final g = BoardGeometry.ringCell(i);
      final rr = cellShape(g);
      canvas.drawRRect(rr, Paint()..color = Colors.white);
      canvas.drawRRect(rr, border);
      if (bonus.contains(i)) {
        _drawEmoji(canvas, '🎁', rr.center, cell * 0.4, opacity: 0.35);
      }
    }

    // Финишные клетки.
    for (final c in PlayerColor.values) {
      final cells = BoardGeometry.finishCells(c, direction);
      for (var i = 0; i < cells.length; i++) {
        final rr = cellShape(cells[i]);
        canvas.drawRRect(rr, Paint()..color = Color.lerp(c.light, c.color, i / 4)!);
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1, cell * 0.03)
            ..color = c.dark.withValues(alpha: 0.5),
        );
        _drawHole(
          canvas,
          rectOf(cells[i]).center,
          cell * 0.26,
          Colors.white.withValues(alpha: 0.5),
        );
      }
    }

    // Направление движения: стрелка на стартовой клетке (первой клетке пути).
    for (final c in PlayerColor.values) {
      Offset centerAt(int progress) =>
          rectOf(BoardGeometry.cellFor(c, 0, progress, direction)).center;
      final paint = Paint()..color = c.color.withValues(alpha: 0.75);
      _drawArrow(canvas, centerAt(0), centerAt(1) - centerAt(0), cell * 0.32, paint);
    }

    // Лунки домов.
    for (final c in PlayerColor.values) {
      for (final h in BoardGeometry.homeHoles(c, direction)) {
        _drawHole(canvas, rectOf(h).center, cell * 0.36, c.color.withValues(alpha: 0.25));
      }
    }

    final player = activePlayer;

    // Путь выбранной фишки до места хода — неяркая заливка цветом игрока.
    final pathColor = destinationColor ?? player;
    if (pathColor != null) {
      for (final g in movePath) {
        canvas.drawRRect(cellShape(g), Paint()..color = pathColor.color.withValues(alpha: 0.22));
      }
    }

    // Путь текущего игрока: обводка клеток и линия через них — поверх клеток, под фишками.
    if (player != null) _drawActivePath(canvas, player, cell, cellShape);

    // Клетка назначения выбранной фишки.
    final dest = destination;
    if (dest != null) {
      final r = rectOf(dest, cell * 0.08);
      final color = destinationColor?.dark ?? Colors.black;
      canvas.drawCircle(
        r.center,
        cell * 0.42,
        Paint()..color = color.withValues(alpha: 0.15 + 0.15 * pulse.value),
      );
      canvas.drawCircle(
        r.center,
        cell * 0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.07
          ..color = color,
      );
    }
  }

  /// Лунка-углубление: заливка плюс «внутренняя тень» радиальным градиентом.
  void _drawHole(Canvas canvas, Offset c, double radius, Color fill) {
    canvas.drawCircle(c, radius, Paint()..color = fill);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.25, 0.3),
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
  }

  /// Ход игрока: путь его фишек от старта до конца финиша. Каждая клетка пути обведена
  /// цветом игрока, а в промежутках между соседними клетками пути боковые грани
  /// продолжены линиями — получается коридор, внутри клеток линий нет. Толщина — как
  /// у обычной рамки клетки, цвет приглушённый.
  void _drawActivePath(
    Canvas canvas,
    PlayerColor c,
    double cell,
    RRect Function(GridPos) cellShape,
  ) {
    final cells = [
      for (var p = 0; p <= finishEndProgress; p++) BoardGeometry.cellFor(c, 0, p, direction),
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, cell * 0.03)
      ..strokeCap = StrokeCap.round
      ..color = c.color.withValues(alpha: 0.6);
    for (final g in cells) {
      canvas.drawRRect(cellShape(g), paint);
    }

    // Связки между соседними клетками: от конца прямого участка боковой грани одной
    // клетки до начала прямого участка у следующей (скругления углов не мешают).
    for (var i = 0; i + 1 < cells.length; i++) {
      final a = cellShape(cells[i]);
      final b = cellShape(cells[i + 1]);
      final dr = cells[i + 1].row - cells[i].row;
      final dc = cells[i + 1].col - cells[i].col;
      final ra = a.tlRadiusX;
      final rb = b.tlRadiusX;
      if (dc == 0) {
        // Соседи по вертикали: соединяются левые и правые грани.
        final ya = dr > 0 ? a.bottom - ra : a.top + ra;
        final yb = dr > 0 ? b.top + rb : b.bottom - rb;
        canvas.drawLine(Offset(a.left, ya), Offset(b.left, yb), paint);
        canvas.drawLine(Offset(a.right, ya), Offset(b.right, yb), paint);
      } else {
        // Соседи по горизонтали: соединяются верхние и нижние грани.
        final xa = dc > 0 ? a.right - ra : a.left + ra;
        final xb = dc > 0 ? b.left + rb : b.right - rb;
        canvas.drawLine(Offset(xa, a.top), Offset(xb, b.top), paint);
        canvas.drawLine(Offset(xa, a.bottom), Offset(xb, b.bottom), paint);
      }
    }
  }

  /// Эмодзи по центру точки [c].
  void _drawEmoji(Canvas canvas, String emoji, Offset c, double size, {double opacity = 1}) {
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: size, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final layer = c - Offset(tp.width / 2, tp.height / 2) & tp.size;
    if (opacity < 1) {
      canvas.saveLayer(layer, Paint()..color = Colors.white.withValues(alpha: opacity));
    }
    tp.paint(canvas, layer.topLeft);
    if (opacity < 1) canvas.restore();
  }

  /// Треугольная стрелка с центром в [c], смотрящая в направлении [dir].
  void _drawArrow(Canvas canvas, Offset c, Offset dir, double size, Paint paint) {
    final d = dir / dir.distance;
    final n = Offset(-d.dy, d.dx);
    final tip = c + d * size * 0.6;
    final back = c - d * size * 0.4;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + n.dx * size * 0.5, back.dy + n.dy * size * 0.5)
      ..lineTo(back.dx - n.dx * size * 0.5, back.dy - n.dy * size * 0.5)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.direction != direction ||
      old.activePlayer != activePlayer ||
      !_samePath(old.movePath, movePath) ||
      old.destination != destination ||
      old.destinationColor != destinationColor;

  static bool _samePath(List<GridPos> a, List<GridPos> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
