import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';

/// Кубик. До броска показывает пустую грань с «?». Во время броска подпрыгивает
/// и вращается, а на грани крутится индикатор загрузки; после остановки показывает
/// только итоговое значение. При включённой вибрации бросок сопровождается тактильной отдачей.
class DiceWidget extends StatefulWidget {
  const DiceWidget({
    super.key,
    required this.value,
    required this.rolling,
    required this.enabled,
    required this.accent,
    required this.onTap,
    this.haptics = true,
    this.size = 72,
  });

  /// Выпавшее значение; null — кубик ещё не брошен.
  final int? value;
  final bool rolling;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  /// Вибрация при броске: толчок в начале, лёгкие на подскоках, сильнее при приземлении.
  final bool haptics;
  final double size;

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> with TickerProviderStateMixin {
  /// Подскоки и вращение во время броска.
  late final AnimationController _tumble = AnimationController(
    vsync: this,
    duration: diceRollDuration,
  );

  /// «Приземление» после броска: короткий пружинящий отскок.
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// Пульсация-приглашение, пока игрок может бросить.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  static const _hops = 3;

  /// Номер последнего касания «стола» во время броска (для вибрации на подскоках).
  int _lastBounce = 0;

  @override
  void initState() {
    super.initState();
    _tumble.addListener(_onTumbleTick);
    if (widget.rolling) _startTumble();
    _syncIdle();
  }

  /// Кубик касается стола в конце каждого подскока — короткий тактильный щелчок.
  void _onTumbleTick() {
    final bounce = (_tumble.value * _hops).floor();
    if (bounce > _lastBounce && bounce < _hops) {
      _lastBounce = bounce;
      _haptic(HapticFeedback.lightImpact);
    }
  }

  void _haptic(Future<void> Function() feedback) {
    if (widget.haptics) feedback();
  }

  void _startTumble() {
    _lastBounce = 0;
    _land.reset();
    _haptic(HapticFeedback.mediumImpact);
    _tumble.forward(from: 0);
  }

  void _syncIdle() {
    final shouldPulse = widget.enabled && !widget.rolling;
    if (shouldPulse && !_idle.isAnimating) {
      _idle.repeat(reverse: true);
    } else if (!shouldPulse && _idle.isAnimating) {
      _idle
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didUpdateWidget(DiceWidget old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !old.rolling) {
      _startTumble();
    } else if (!widget.rolling && old.rolling) {
      _tumble.stop();
      if (widget.value != null) {
        _haptic(HapticFeedback.heavyImpact);
        _land.forward(from: 0);
      }
    }
    _syncIdle();
  }

  @override
  void dispose() {
    _tumble.dispose();
    _land.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final blank = widget.value == null && !widget.rolling;

    return Semantics(
      button: true,
      label: blank ? 'Бросить кубик' : 'Кубик: ${widget.value ?? ''}',
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: MouseRegion(
          cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: SizedBox(
            width: s * 1.25,
            height: s * 1.5,
            child: AnimatedBuilder(
              animation: Listenable.merge([_tumble, _land, _idle]),
              builder: (context, child) {
                final rolling = widget.rolling && _tumble.isAnimating;
                final t = _tumble.value;
                final damp = 1 - t;

                // Высота подскока: три затухающих отскока.
                final hop = rolling
                    ? (sin(t * pi * _hops)).abs() * s * 0.28 * damp
                    : 0.0;
                // Приземление: сжатие и пружинящий возврат.
                final landT = _land.isAnimating ? _land.value : 1.0;
                final squash = 1 + 0.18 * sin(landT * pi) * (1 - landT);
                final idleScale =
                    1 + 0.05 * Curves.easeInOut.transform(_idle.value);

                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.0018) // перспектива
                  ..translateByDouble(0.0, -hop, 0.0, 1.0);
                if (rolling) {
                  // Вращение в плоскости экрана с замедлением к концу броска.
                  transform.rotateZ(Curves.easeOut.transform(t) * pi * 3);
                }
                transform.scaleByDouble(
                  idleScale * squash,
                  idleScale / squash,
                  1.0,
                  1.0,
                );

                final shadowScale = 1 - hop / (s * 0.6);
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Тень под кубиком: уменьшается, когда кубик в воздухе.
                    Positioned(
                      bottom: s * 0.02,
                      child: Container(
                        width: s * 0.9 * shadowScale,
                        height: s * 0.14 * shadowScale,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(s, s * 0.14),
                          ),
                          color: Colors.black.withValues(
                            alpha: 0.18 * shadowScale,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: s * 0.1,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: transform,
                        child: child,
                      ),
                    ),
                  ],
                );
              },
              child: _DiceFace(
                size: s,
                face: blank || widget.rolling ? 0 : widget.value!,
                accent: widget.accent,
                enabled: widget.enabled,
                rolling: widget.rolling,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  const _DiceFace({
    required this.size,
    required this.face,
    required this.accent,
    required this.enabled,
    required this.rolling,
  });

  final double size;
  final int face;
  final Color accent;
  final bool enabled;
  final bool rolling;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFE7E9EE)],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: accent, width: enabled || rolling ? 4 : 2),
        boxShadow: [
          if (enabled)
            BoxShadow(
              color: accent.withValues(alpha: 0.55),
              blurRadius: 14,
              spreadRadius: 2,
            ),
        ],
      ),
      child: rolling
          ? Padding(
              padding: EdgeInsets.all(size * 0.24),
              child: CircularProgressIndicator(
                strokeWidth: max(2.5, size * 0.07),
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.15),
              ),
            )
          : CustomPaint(painter: _PipsPainter(face)),
    );
  }
}

class _PipsPainter extends CustomPainter {
  _PipsPainter(this.value);

  /// 0 — пустая грань (кубик ещё не брошен).
  final int value;

  static const _layout = <int, List<Offset>>{
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.27, 0.27), Offset(0.73, 0.73)],
    3: [Offset(0.27, 0.27), Offset(0.5, 0.5), Offset(0.73, 0.73)],
    4: [
      Offset(0.27, 0.27),
      Offset(0.73, 0.27),
      Offset(0.27, 0.73),
      Offset(0.73, 0.73),
    ],
    5: [
      Offset(0.27, 0.27),
      Offset(0.73, 0.27),
      Offset(0.5, 0.5),
      Offset(0.27, 0.73),
      Offset(0.73, 0.73),
    ],
    6: [
      Offset(0.27, 0.25),
      Offset(0.73, 0.25),
      Offset(0.27, 0.5),
      Offset(0.73, 0.5),
      Offset(0.27, 0.75),
      Offset(0.73, 0.75),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (value == 0) {
      final tp = TextPainter(
        // Кубик ещё не брошен.
        text: TextSpan(
          text: '🎲',
          style: TextStyle(fontSize: size.width * 0.55, height: 1.0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        size.center(Offset.zero) - Offset(tp.width / 2, tp.height / 2),
      );
      return;
    }
    final paint = Paint()..color = const Color(0xFF263238);
    for (final p in _layout[value]!) {
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        size.width * 0.085,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PipsPainter old) => old.value != value;
}
