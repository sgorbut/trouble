import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/game/board_geometry.dart';
import '../../core/game/models.dart';
import '../../ui/theme.dart';

/// Рисует статичное поле: кольцо, дома, финиши, стартовые и бонусные клетки.
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
      RRect.fromRectAndRadius(
        Offset.zero & Size(side, side),
        Radius.circular(cell * 0.3),
      ),
      Paint()..color = AppTheme.boardBackground,
    );

    // Зоны домов.
    for (final c in PlayerColor.values) {
      final o = BoardGeometry.homeZoneOrigin(c);
      const z = BoardGeometry.homeZoneSize;
      final r = Rect.fromLTWH(
        o.col * cell,
        o.row * cell,
        cell * z,
        cell * z,
      ).deflate(cell * 0.12);
      final zone = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.4));
      final active = c == activePlayer;
      canvas.drawRRect(
        zone,
        Paint()..color = c.color.withValues(alpha: active ? 0.45 : 0.18),
      );
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
      canvas.drawRRect(
        rr,
        Paint()..color = isBonus ? _bonusFill : Colors.white,
      );
      canvas.drawRRect(
        rr,
        isBonus
            ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = cell * 0.05
                ..color = _bonusBorder)
            : border,
      );
      if (isBonus) _drawEmoji(canvas, '🎁', r.center, cell * 0.5);
    }

    // Финишные клетки.
    for (final c in PlayerColor.values) {
      final cells = BoardGeometry.finishCells(c, direction);
      for (var i = 0; i < cells.length; i++) {
        final rr = RRect.fromRectAndRadius(
          rectOf(cells[i], cell * 0.06),
          Radius.circular(cell * 0.18),
        );
        canvas.drawRRect(
          rr,
          Paint()..color = Color.lerp(c.light, c.color, i / 4)!,
        );
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

    // Направление движения: стрелка на первой клетке после старта.
    for (final c in PlayerColor.values) {
      Offset centerAt(int progress) =>
          rectOf(BoardGeometry.cellFor(c, 0, progress, direction)).center;
      final paint = Paint()..color = c.color.withValues(alpha: 0.75);
      _drawArrow(
        canvas,
        centerAt(1),
        centerAt(2) - centerAt(1),
        cell * 0.32,
        paint,
      );
    }

    // Лунки домов.
    for (final c in PlayerColor.values) {
      for (final h in BoardGeometry.homeHoles(c, direction)) {
        _drawHole(
          canvas,
          rectOf(h).center,
          cell * 0.36,
          c.color.withValues(alpha: 0.25),
        );
      }
    }

    // Стартовые клетки (лунки выхода из дома).
    for (final c in PlayerColor.values) {
      final r = rectOf(BoardGeometry.startCell(c), cell * 0.06);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.18));
      if (pulsingStart == c) {
        final t = pulse.value;
        canvas.drawRRect(
          rr.inflate(cell * 0.04 + cell * 0.1 * t),
          Paint()..color = c.color.withValues(alpha: 0.45 * (1 - t)),
        );
      }
      canvas.drawRRect(rr, Paint()..color = c.color.withValues(alpha: 0.4));
      canvas.drawRRect(rr, border);
    }

    // Путь текущего игрока обведён по контуру — поверх клеток, под фишками.
    final player = activePlayer;
    if (player != null) _drawActivePathOutline(canvas, player, cell);

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

  static const _bonusFill = Color(0xFFFFE082);
  static const _bonusBorder = Color(0xFFFFA000);

  /// Ход игрока: путь его фишек от старта до конца финиша обведён снаружи по контуру,
  /// как коридор. У каждой клетки пути рисуются только те стороны, которые не граничат
  /// с соседними клетками пути: у старта — три стороны, дальше — по две, на углах кольца
  /// и на повороте в финиш обводится угол, у последней клетки финиша — снова три.
  void _drawActivePathOutline(Canvas canvas, PlayerColor c, double cell) {
    final path = [
      for (var p = 0; p <= finishEndProgress; p++)
        BoardGeometry.cellFor(c, 0, p, direction),
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.07
      ..strokeCap = StrokeCap.round
      ..color = c.dark;
    bool adjacent(GridPos a, GridPos b, int dr, int dc) =>
        b.row - a.row == dr && b.col - a.col == dc;
    for (var i = 0; i < path.length; i++) {
      final g = path[i];
      final neighbours = [
        if (i > 0) path[i - 1],
        if (i + 1 < path.length) path[i + 1],
      ];
      bool open(int dr, int dc) =>
          neighbours.any((n) => adjacent(g, n, dr, dc));
      final r = Rect.fromLTWH(
        g.col * cell,
        g.row * cell,
        cell,
        cell,
      ).deflate(cell * 0.02);
      if (!open(-1, 0)) canvas.drawLine(r.topLeft, r.topRight, paint);
      if (!open(1, 0)) canvas.drawLine(r.bottomLeft, r.bottomRight, paint);
      if (!open(0, -1)) canvas.drawLine(r.topLeft, r.bottomLeft, paint);
      if (!open(0, 1)) canvas.drawLine(r.topRight, r.bottomRight, paint);
    }
  }

  /// Эмодзи по центру точки [c].
  void _drawEmoji(Canvas canvas, String emoji, Offset c, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: size, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  /// Треугольная стрелка с центром в [c], смотрящая в направлении [dir].
  void _drawArrow(
    Canvas canvas,
    Offset c,
    Offset dir,
    double size,
    Paint paint,
  ) {
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
      old.pulsingStart != pulsingStart ||
      old.activePlayer != activePlayer ||
      old.destination != destination ||
      old.destinationColor != destinationColor;
}
