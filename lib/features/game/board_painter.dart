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
      if (isBonus) _drawEmoji(canvas, '🎁', r.center, cell * 0.4);
    }

    // Финишные клетки.
    for (final c in PlayerColor.values) {
      final cells = BoardGeometry.finishCells(c, direction);
      for (var i = 0; i < cells.length; i++) {
        final rr = RRect.fromRectAndRadius(
          rectOf(cells[i], cell * 0.06),
          Radius.circular(cell * 0.18),
        );
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
      final r = rectOf(BoardGeometry.startCell(c), cell * 0.06);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.18));
      canvas.drawRRect(rr, Paint()..color = c.color.withValues(alpha: 0.4));
      canvas.drawRRect(rr, border);
    }

    final player = activePlayer;

    // Путь выбранной фишки до места хода — неяркая заливка цветом игрока.
    final pathColor = destinationColor ?? player;
    if (pathColor != null) {
      for (final g in movePath) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rectOf(g, cell * 0.06), Radius.circular(cell * 0.18)),
          Paint()..color = pathColor.color.withValues(alpha: 0.22),
        );
      }
    }

    // Путь текущего игрока: грани клеток цветом игрока — поверх клеток, под фишками.
    if (player != null) _drawActivePathEdges(canvas, player, cell, rectOf);

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

  /// Ход игрока: путь его фишек от старта до конца финиша выделен гранями самих клеток.
  /// У каждой клетки пути цветом игрока перекрашены только грани, не обращённые к соседним
  /// клеткам пути: у первой и последней — три, у остальных — по две (на поворотах — угол).
  /// Толщина — как у обычной рамки клетки, цвет приглушённый.
  void _drawActivePathEdges(
    Canvas canvas,
    PlayerColor c,
    double cell,
    Rect Function(GridPos, [double]) rectOf,
  ) {
    final path = [
      for (var p = 0; p <= finishEndProgress; p++) BoardGeometry.cellFor(c, 0, p, direction),
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, cell * 0.03)
      ..color = c.color.withValues(alpha: 0.6);
    for (var i = 0; i < path.length; i++) {
      final g = path[i];
      final neighbours = [if (i > 0) path[i - 1], if (i + 1 < path.length) path[i + 1]];
      bool open(int dr, int dc) =>
          neighbours.any((n) => n.row - g.row == dr && n.col - g.col == dc);
      // Клетка делится диагоналями на четыре треугольника — по одному на грань; рамка
      // клетки рисуется только внутри треугольников закрытых граней, так что скругления
      // углов делятся между гранями пополам.
      final box = rectOf(g);
      final m = box.center;
      final clip = Path();
      void side(Offset a, Offset b) => clip.addPolygon([m, a, b], true);
      if (!open(-1, 0)) side(box.topLeft, box.topRight);
      if (!open(1, 0)) side(box.bottomLeft, box.bottomRight);
      if (!open(0, -1)) side(box.topLeft, box.bottomLeft);
      if (!open(0, 1)) side(box.topRight, box.bottomRight);
      canvas.save();
      canvas.clipPath(clip);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectOf(g, cell * 0.06), Radius.circular(cell * 0.18)),
        paint,
      );
      canvas.restore();
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
