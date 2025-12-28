import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';
import 'dart:math';

// =======================================================================
// Main Effects Overlay Widget
// =======================================================================
class EffectsOverlay extends StatelessWidget {
  final bool showMotes;
  final bool showRain;
  final bool showFireflies;
  final Color effectColor;
  final double motesDensity;
  final double rainIntensity;
  final double firefliesCount;

  const EffectsOverlay({
    super.key,
    this.showMotes = false,
    this.showRain = false,
    this.showFireflies = false,
    required this.effectColor,
    this.motesDensity = 50.0,
    this.rainIntensity = 80.0,
    this.firefliesCount = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showMotes)
          MotesEffect(
            color: effectColor,
            numberOfMotes: motesDensity.toInt(),
          ),
        if (showRain)
          RainEffect(
            color: Colors.white,
            numberOfDrops: rainIntensity.toInt(),
          ),
        if (showFireflies)
          FirefliesEffect(
            numberOfFireflies: firefliesCount.toInt(),
          ),
      ],
    );
  }
}

// =======================================================================
// Dust Motes Effect
// =======================================================================
class MotesEffect extends StatelessWidget {
  final int numberOfMotes;
  final Color color;

  MotesEffect({
    super.key,
    this.numberOfMotes = 50,
    required this.color,
  });

  final Random random = Random();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(numberOfMotes, (index) {
        final baseSize = random.nextDouble() * 4.0 + 1.0;
        final opacity = random.nextDouble() * 0.4 + 0.3;
        final duration =
            Duration(milliseconds: random.nextInt(20000) + 30000);

        final tween = MovieTween()
          ..scene(duration: duration, curve: Curves.easeInOutSine)
              .tween('x', Tween(begin: random.nextDouble(), end: random.nextDouble()))
              .tween('y', Tween(begin: random.nextDouble(), end: random.nextDouble()))
          ..scene(duration: duration, curve: Curves.easeInOut)
              .tween('scale', Tween(begin: 0.6, end: 1.4));

        return Positioned.fill(
          child: LoopAnimationBuilder<Movie>(
            tween: tween,
            duration: duration,
            builder: (context, value, child) {
              return CustomPaint(
                painter: MotePainter(
                  x: value.get('x'),
                  y: value.get('y'),
                  size: baseSize * value.get('scale'),
                  color: color,
                  opacity: opacity,
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

class MotePainter extends CustomPainter {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double opacity;

  MotePainter({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..maskFilter =
          MaskFilter.blur(BlurStyle.normal, size * 1.1);

    canvas.drawCircle(
      Offset(x * canvasSize.width, y * canvasSize.height),
      size,
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

// =======================================================================
// Rain Effect
// =======================================================================
class RainEffect extends StatelessWidget {
  final int numberOfDrops;
  final Color color;

  RainEffect({
    super.key,
    this.numberOfDrops = 40,
    required this.color,
  });

  final Random random = Random();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(numberOfDrops, (index) {
        final speed = random.nextDouble() * 0.8;
        final duration =
            Duration(milliseconds: (2000 / speed).toInt());

        final tween = MovieTween()
          ..scene(duration: duration, curve: Curves.linear)
              .tween('y', Tween(begin: -0.2, end: 1.2));

        return Positioned.fill(
          child: LoopAnimationBuilder<Movie>(
            tween: tween,
            duration: duration,
            builder: (context, value, child) {
              return CustomPaint(
                painter: RainPainter(
                  x: random.nextDouble(),
                  y: value.get('y'),
                  length: 300 * speed,
                  speed: speed,
                  color: color,
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

class RainPainter extends CustomPainter {
  final double x;
  final double y;
  final double length;
  final double speed;
  final Color color;

  RainPainter({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.18)
      ..strokeWidth = speed * 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(x * size.width, y * size.height),
      Offset(x * size.width, y * size.height + length),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

// =======================================================================
// Fireflies Effect (DESYNCED PROPERLY)
// =======================================================================
class FirefliesEffect extends StatelessWidget {
  final int numberOfFireflies;

  const FirefliesEffect({
    super.key,
    this.numberOfFireflies = 30,
  });

  @override
  Widget build(BuildContext context) {
    final Random random = Random();

    return Stack(
      children: List.generate(numberOfFireflies, (index) {
        final duration =
            Duration(milliseconds: random.nextInt(8000) + 4000);

        final double pulsePhase = random.nextDouble();

        final bool isGreen = random.nextDouble() > 0.7;
        final Color flyColor =
            isGreen ? Colors.lightGreenAccent : Colors.yellowAccent;

        final pathTween = MovieTween()
          ..scene(duration: duration, curve: Curves.easeInOutSine)
              .tween('x', Tween(begin: random.nextDouble(), end: random.nextDouble()))
              .tween('y', Tween(begin: random.nextDouble(), end: random.nextDouble()));

        final pulseTween = MovieTween()
          ..scene(duration: const Duration(milliseconds: 1200), curve: Curves.easeOut)
              .tween('opacity', Tween(begin: 0.1, end: 0.9))
          ..scene(duration: const Duration(milliseconds: 2200), curve: Curves.easeIn)
              .tween('opacity', Tween(begin: 0.9, end: 0.1));

        return Positioned.fill(
          child: LoopAnimationBuilder<Movie>(
            tween: pathTween,
            duration: duration,
            builder: (context, pathValue, child) {
              return CustomAnimationBuilder<Movie>(
                tween: pulseTween,
                duration: pulseTween.duration,
                control: Control.loop,
                startPosition: pulsePhase,
                builder: (context, pulseValue, child) {
                  return CustomPaint(
                    painter: FireflyPainter(
                      x: pathValue.get('x'),
                      y: pathValue.get('y'),
                      opacity: pulseValue.get('opacity'),
                      color: flyColor,
                    ),
                  );
                },
              );
            },
          ),
        );
      }),
    );
  }
}

class FireflyPainter extends CustomPainter {
  final double x;
  final double y;
  final double opacity;
  final Color color;

  FireflyPainter({
    required this.x,
    required this.y,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawCircle(
      Offset(x * size.width, y * size.height),
      2.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

