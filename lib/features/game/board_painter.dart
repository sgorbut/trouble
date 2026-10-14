import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/game/board_geometry.dart';
import '../../core/game/models.dart';
import '../../ui/theme.dart';

/// Рисует статичное поле: кольцо, дома, финиши, стартовые клетки.
/// Пульсация стартовой клетки и подсветка клетки назначения — по параметрам.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.pulse,
    required this.direction,
    this.pulsingStart,
    this.activePlayer,
    this.destination,
    this.destinationColor,
  }) : super(repaint: pulse);

  final Animation<double> pulse;

  /// От направления зависит, какой рукав креста — финиш какого цвета.
  final MoveDirection direction;

  /// Цвет, чья стартовая клетка сейчас пульсирует (можно вывести фишку).
  final PlayerColor? pulsingStart;

  /// Чей сейчас ход: его зона дома рисуется насыщеннее и с рамкой.
  final PlayerColor? activePlayer;
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

    // Фон.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & Size(side, side), Radius.circular(cell * 0.3)),
      Paint()..color = AppTheme.boardBackground,
    );

    // Зоны домов.
    for (final c in PlayerColor.values) {
      final o = BoardGeometry.homeZoneOrigin(c);
      const z = BoardGeometry.homeZoneSize;
      final r = Rect.fromLTWH(o.col * cell, o.row * cell, cell * z, cell * z).deflate(cell * 0.12);
      final zone = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.4));
      final active = c == activePlayer;
      canvas.drawRRect(zone, Paint()..color = c.color.withValues(alpha: active ? 0.45 : 0.18));
      if (active) {
        canvas.drawRRect(
          zone,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08
            ..color = c.color,
        );
      }
    }

    // Площадка под кубик в центре поля.
    final mid = Offset(side / 2, side / 2);
    canvas.drawCircle(mid, cell * 0.95, Paint()..color = Colors.white.withValues(alpha: 0.75));
    const quarterOrder = [PlayerColor.blue, PlayerColor.yellow, PlayerColor.green, PlayerColor.red];
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: mid, radius: cell * 0.95),
        -pi / 2 + i * pi / 2 + 0.08,
        pi / 2 - 0.16,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.1
          ..strokeCap = StrokeCap.round
          ..color = quarterOrder[i].color.withValues(alpha: 0.8),
      );
    }

    // Клетки кольца.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, cell * 0.03)
      ..color = AppTheme.cellBorder;
    final bonus = bonusRingIndices(direction);
    for (var i = 0; i < ringLength; i++) {
      final r = rectOf(BoardGeometry.ringCell(i), cell * 0.06);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.18));
      final isBonus = bonus.contains(i);
      canvas.drawRRect(rr, Paint()..color = isBonus ? _bonusFill : Colors.white);
      canvas.drawRRect(
        rr,
        isBonus
            ? (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.05
              ..color = _bonusBorder)
            : border,
      );
      if (isBonus) _drawMiniDie(canvas, r.center, cell * 0.42);
    }


    // Финишные клетки.
    for (final c in PlayerColor.values) {
      final cells = BoardGeometry.finishCells(c, direction);
      for (var i = 0; i < cells.length; i++) {
        final rr = RRect.fromRectAndRadius(rectOf(cells[i], cell * 0.06), Radius.circular(cell * 0.18));
        canvas.drawRRect(rr, Paint()..color = Color.lerp(c.light, c.color, i / 4)!);
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1, cell * 0.03)
            ..color = c.dark.withValues(alpha: 0.5),
        );
        _drawHole(canvas, rectOf(cells[i]).center, cell * 0.26, Colors.white.withValues(alpha: 0.5));
      }
    }

    // Финишная дорожка текущего игрока обведена по контуру.
    final player = activePlayer;
    if (player != null) _drawActiveFinishOutline(canvas, player, cell, rectOf);

    // Направление движения: стрелка на первой клетке после старта.
    for (final c in PlayerColor.values) {
      Offset centerAt(int progress) =>
          rectOf(BoardGeometry.cellFor(c, 0, progress, direction)).center;
      final paint = Paint()..color = c.color.withValues(alpha: 0.75);
      _drawArrow(canvas, centerAt(1), centerAt(2) - centerAt(1), cell * 0.32, paint);
    }

    // Лунки домов.
    for (final c in PlayerColor.values) {
      for (final h in BoardGeometry.homeHoles(c, direction)) {
        _drawHole(canvas, rectOf(h).center, cell * 0.36, c.color.withValues(alpha: 0.25));
      }
    }

    // Стартовые клетки (лунки выхода из дома).
    for (final c in PlayerColor.values) {
      final r = rectOf(BoardGeometry.startCell(c), cell * 0.05);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.2));
      if (pulsingStart == c) {
        final t = pulse.value;
        canvas.drawRRect(
          rr.inflate(cell * 0.04 + cell * 0.1 * t),
          Paint()..color = c.color.withValues(alpha: 0.45 * (1 - t)),
        );
      }
      canvas.drawRRect(rr, Paint()..color = c.color);
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.09
          ..color = c.dark,
      );
      _drawStar(canvas, r.center, cell * 0.3, c.onColor.withValues(alpha: 0.9));
    }

    // Клетка назначения выбранной фишки.
    final dest = destination;
    if (dest != null) {
      final r = rectOf(dest, cell * 0.08);
      final color = destinationColor?.dark ?? Colors.black;
      canvas.drawCircle(r.center, cell * 0.42, Paint()..color = color.withValues(alpha: 0.15 + 0.15 * pulse.value));
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

  static const _bonusFill = Color(0xFFFFE082);
  static const _bonusBorder = Color(0xFFFFA000);

  /// Ход игрока: обводка контура его финишной дорожки.
  void _drawActiveFinishOutline(
    Canvas canvas,
    PlayerColor c,
    double cell,
    Rect Function(GridPos, [double]) rectOf,
  ) {
    final lane = BoardGeometry.finishCells(c, direction);
    var bounds = rectOf(lane.first);
    for (final g in lane.skip(1)) {
      bounds = bounds.expandToInclude(rectOf(g));
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(cell * 0.02), Radius.circular(cell * 0.24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.09
        ..color = c.dark,
    );
  }

  /// Маленький кубик-значок на бонусной клетке.
  void _drawMiniDie(Canvas canvas, Offset c, double size) {
    final r = Rect.fromCenter(center: c, width: size, height: size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(size * 0.22)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(size * 0.22)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.07
        ..color = _bonusBorder,
    );
    final pip = Paint()..color = const Color(0xFF5D4037);
    for (final o in const [Offset(-0.25, -0.25), Offset(0.25, -0.25), Offset(0, 0), Offset(-0.25, 0.25), Offset(0.25, 0.25)]) {
      canvas.drawCircle(c + o * size, size * 0.08, pip);
    }
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

  void _drawStar(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final p = Offset(c.dx + radius * cos(a), c.dy + radius * sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.direction != direction ||
      old.pulsingStart != pulsingStart ||
      old.activePlayer != activePlayer ||
      old.destination != destination ||
      old.destinationColor != destinationColor;
}
