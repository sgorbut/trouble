// Генератор иконки приложения. Запуск:
//   flutter test tool/icon/generate_icon_test.dart
//   dart run flutter_launcher_icons
// Рисует tool/icon/icon.png (1024×1024, без прозрачности — для iOS/Web/macOS)
// и tool/icon/icon_foreground.png (передний план адаптивной иконки Android).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _bgTop = Color(0xFF3F51B5);
const _bgBottom = Color(0xFF1A237E);

const _red = Color(0xFFE53935);
const _blue = Color(0xFF1E88E5);
const _yellow = Color(0xFFFBC02D);
const _green = Color(0xFF43A047);

void main() {
  testWidgets('generate app icon', (tester) async {
    await tester.runAsync(() async {
      await _save(_render(background: true, scale: 1), 'tool/icon/icon.png');
      // Безопасная зона адаптивной иконки — ~66% от размера.
      await _save(_render(background: false, scale: 0.62), 'tool/icon/icon_foreground.png');
    });
  });
}

ui.Picture _render({required bool background, required double scale}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _size, _size));

  if (background) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _size, _size),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bgTop, _bgBottom],
        ).createShader(const Rect.fromLTWH(0, 0, _size, _size)),
    );
  }

  canvas.translate(_size / 2, _size / 2);
  canvas.scale(scale);

  // Кольцо-«поле» за фишками.
  canvas.drawCircle(
    Offset.zero,
    330,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..color = Colors.white.withValues(alpha: 0.18),
  );

  // Четыре фишки по углам, как дома на поле.
  const d = 230.0;
  _token(canvas, const Offset(-d, -d), _red);
  _token(canvas, const Offset(d, -d), _blue);
  _token(canvas, const Offset(d, d), _yellow);
  _token(canvas, const Offset(-d, d), _green);

  // Кубик в центре, слегка повёрнут.
  canvas.save();
  canvas.rotate(-0.21);
  const half = 175.0;
  final die = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
    const Radius.circular(70),
  );
  canvas.drawRRect(
    die.shift(const Offset(0, 22)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
  );
  canvas.drawRRect(
    die,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFDCE0EA)],
      ).createShader(die.outerRect),
  );
  final pip = Paint()..color = const Color(0xFF263238);
  const o = 92.0;
  for (final p in const [Offset(-o, -o), Offset(o, -o), Offset.zero, Offset(-o, o), Offset(o, o)]) {
    canvas.drawCircle(p, 36, pip);
  }
  canvas.restore();

  return recorder.endRecording();
}

void _token(Canvas canvas, Offset c, Color color) {
  const r = 128.0;
  canvas.drawCircle(
    c + const Offset(0, 16),
    r,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
  final dark = HSLColor.fromColor(color).withLightness(0.3).toColor();
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.95,
        colors: [Color.lerp(color, Colors.white, 0.6)!, color, dark],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );
  canvas.drawCircle(
    c + Offset(-r * 0.35, -r * 0.4),
    r * 0.18,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
}

Future<void> _save(ui.Picture picture, String path) async {
  final image = await picture.toImage(_size.toInt(), _size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}
