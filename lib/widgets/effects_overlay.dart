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
    // We use Keys to ensure the widgets maintain state unless the type changes
    return Stack(
      children: [
        if (showMotes)
          MotesEffect(
            key: const ValueKey('Motes'),
            color: effectColor,
            numberOfMotes: motesDensity.toInt(),
          ),
        if (showRain)
          RainEffect(
            key: const ValueKey('Rain'),
            color: Colors.white,
            numberOfDrops: rainIntensity.toInt(),
          ),
        if (showFireflies)
          FirefliesEffect(
            key: const ValueKey('Fireflies'),
            numberOfFireflies: firefliesCount.toInt(),
          ),
      ],
    );
  }
}

// =======================================================================
// Dust Motes Effect
// =======================================================================
class MotesEffect extends StatefulWidget {
  final int numberOfMotes;
  final Color color;

  const MotesEffect({
    super.key,
    this.numberOfMotes = 50,
    required this.color,
  });

  @override
  State<MotesEffect> createState() => _MotesEffectState();
}

class _MotesEffectState extends State<MotesEffect> {
  final Random random = Random();
  late List<_MoteItem> _motes;

  @override
  void initState() {
    super.initState();
    _generateMotes();
  }

  @override
  void didUpdateWidget(MotesEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only regenerate if the density actually changed
    if (oldWidget.numberOfMotes != widget.numberOfMotes) {
      _generateMotes();
    }
  }

  void _generateMotes() {
    _motes = List.generate(widget.numberOfMotes, (index) {
      final baseSize = random.nextDouble() * 40.0 + 20.0;
      final opacity = random.nextDouble() * 0.15 + 0.05;
      final duration = Duration(milliseconds: random.nextInt(20000) + 30000);

      final tween = MovieTween()
        ..scene(duration: duration)
            .tween('x', Tween(begin: random.nextDouble(), end: random.nextDouble()), curve: Curves.easeInOutSine)
            .tween('y', Tween(begin: random.nextDouble(), end: random.nextDouble()), curve: Curves.easeInOutSine)
            .tween('scale', Tween(begin: 0.6, end: 1.4), curve: Curves.easeInOut)
            .tween('opacityFactor', TweenSequence([
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
              TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
            ]));

      return _MoteItem(
        tween: tween,
        duration: duration,
        baseSize: baseSize,
        baseOpacity: opacity,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _motes.map((mote) {
        return Positioned.fill(
          child: LoopAnimationBuilder<Movie>(
            tween: mote.tween,
            duration: mote.duration,
            builder: (context, value, child) {
              return CustomPaint(
                painter: MotePainter(
                  x: value.get('x'),
                  y: value.get('y'),
                  size: mote.baseSize * value.get('scale'),
                  color: widget.color,
                  opacity: mote.baseOpacity * value.get('opacityFactor'),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

// Data class to cache mote properties
class _MoteItem {
  final MovieTween tween;
  final Duration duration;
  final double baseSize;
  final double baseOpacity;

  _MoteItem({
    required this.tween,
    required this.duration,
    required this.baseSize,
    required this.baseOpacity,
  });
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
      ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.8);

    canvas.drawCircle(
      Offset(x * canvasSize.width, y * canvasSize.height),
      size,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant MotePainter oldDelegate) {
    return x != oldDelegate.x || y != oldDelegate.y || opacity != oldDelegate.opacity;
  }
}

// =======================================================================
// Rain Effect
// =======================================================================
class RainEffect extends StatefulWidget {
  final int numberOfDrops;
  final Color color;

  const RainEffect({
    super.key,
    this.numberOfDrops = 40,
    required this.color,
  });

  @override
  State<RainEffect> createState() => _RainEffectState();
}

class _RainEffectState extends State<RainEffect> {
  late List<_RainDrop> _drops;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _generateDrops();
  }

  @override
  void didUpdateWidget(RainEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.numberOfDrops != widget.numberOfDrops) {
      _generateDrops();
    }
  }

  void _generateDrops() {
    _drops = List.generate(widget.numberOfDrops, (index) {
      return _RainDrop(
        x: random.nextDouble(),
        yStart: random.nextDouble(),
        speed: 1 + random.nextDouble() * 1.5,
        length: 0.05 + random.nextDouble() * 0.35,
        opacity: 0.01 + random.nextDouble() * 0.03,
        strokeWidth: 0.5 + random.nextDouble() * 1.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoopAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1000.0),
      duration: const Duration(minutes: 10),
      builder: (context, value, child) {
        return CustomPaint(
          painter: RainPainter(
            drops: _drops,
            animationValue: value,
            color: widget.color,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _RainDrop {
  final double x;
  final double yStart;
  final double speed;
  final double length;
  final double opacity;
  final double strokeWidth;

  _RainDrop({
    required this.x,
    required this.yStart,
    required this.speed,
    required this.length,
    required this.opacity,
    required this.strokeWidth,
  });
}

class RainPainter extends CustomPainter {
  final List<_RainDrop> drops;
  final double animationValue;
  final Color color;

  RainPainter({
    required this.drops,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double slantX = 0.15; 

    for (var drop in drops) {
      final paint = Paint()
        ..color = color.withOpacity(drop.opacity.clamp(0.0, 1.0))
        ..strokeWidth = drop.strokeWidth
        ..strokeCap = StrokeCap.round;

      final double progress = (drop.yStart + animationValue * drop.speed * 0.8) % 1.0;
      
      final double topY = progress * size.height;
      final double bottomY = topY + (drop.length * size.height);
      final double xOffset = drop.length * slantX * size.width;
      
      canvas.drawLine(
        Offset(drop.x * size.width, topY),
        Offset(drop.x * size.width - xOffset, bottomY),
        paint,
      );

      // Wrap-around logic
      if (progress + drop.length > 1.0) {
         final double wrapTopY = (progress - 1.0) * size.height;
         final double wrapBottomY = wrapTopY + (drop.length * size.height);
         
         canvas.drawLine(
          Offset(drop.x * size.width, wrapTopY),
          Offset(drop.x * size.width - xOffset, wrapBottomY),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant RainPainter oldDelegate) => true;
}

// =======================================================================
// Fireflies Effect
// =======================================================================
class FirefliesEffect extends StatefulWidget {
  final int numberOfFireflies;

  const FirefliesEffect({
    super.key,
    this.numberOfFireflies = 30,
  });

  @override
  State<FirefliesEffect> createState() => _FirefliesEffectState();
}

class _FirefliesEffectState extends State<FirefliesEffect> {
  final Random random = Random();
  late List<_FireflyItem> _fireflies;

  @override
  void initState() {
    super.initState();
    _generateFireflies();
  }

  @override
  void didUpdateWidget(FirefliesEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.numberOfFireflies != widget.numberOfFireflies) {
      _generateFireflies();
    }
  }

  void _generateFireflies() {
    _fireflies = List.generate(widget.numberOfFireflies, (index) {
      final duration = Duration(milliseconds: random.nextInt(25000) + 20000);
      final double pulsePhase = random.nextDouble();
      final bool isGreen = random.nextDouble() > 0.7;
      final Color flyColor = isGreen ? Colors.lightGreenAccent : Colors.yellowAccent;
      final double fireflySize = random.nextDouble() * 40.0 + 10.0;

      final pathTween = MovieTween()
        ..scene(duration: duration)
            .tween('x', Tween(begin: random.nextDouble(), end: random.nextDouble()), curve: Curves.easeInOutSine)
            .tween('y', Tween(begin: random.nextDouble(), end: random.nextDouble()), curve: Curves.easeInOutSine)
            .tween('opacityFactor', TweenSequence([
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
              TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
            ]));

      final int halfCycleDuration = random.nextInt(2000) + 2000;
      final pulseTween = Tween<double>(begin: 0.4, end: 1.0);

      return _FireflyItem(
        pathTween: pathTween,
        pulseTween: pulseTween,
        duration: duration,
        pulsePhase: pulsePhase,
        color: flyColor,
        size: fireflySize,
        halfCycleDuration: Duration(milliseconds: halfCycleDuration),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _fireflies.map((firefly) {
        return Positioned.fill(
          child: LoopAnimationBuilder<Movie>(
            tween: firefly.pathTween,
            duration: firefly.duration,
            builder: (context, pathValue, child) {
              return CustomAnimationBuilder<double>(
                tween: firefly.pulseTween,
                duration: firefly.halfCycleDuration,
                control: Control.mirror,
                curve: Curves.easeInOut,
                startPosition: firefly.pulsePhase,
                builder: (context, opacityValue, child) {
                  return CustomPaint(
                    painter: FireflyPainter(
                      x: pathValue.get('x'),
                      y: pathValue.get('y'),
                      size: firefly.size,
                      opacity: opacityValue * pathValue.get('opacityFactor'),
                      color: firefly.color,
                    ),
                  );
                },
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

// Data class for firefly
class _FireflyItem {
  final MovieTween pathTween;
  final Tween<double> pulseTween;
  final Duration duration;
  final double pulsePhase;
  final Color color;
  final double size;
  final Duration halfCycleDuration;

  _FireflyItem({
    required this.pathTween,
    required this.pulseTween,
    required this.duration,
    required this.pulsePhase,
    required this.color,
    required this.size,
    required this.halfCycleDuration,
  });
}

class FireflyPainter extends CustomPainter {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final Color color;

  FireflyPainter({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity((opacity * 0.4).clamp(0.0, 1.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, this.size * 0.6);

    canvas.drawCircle(
      Offset(x * size.width, y * size.height),
      this.size,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant FireflyPainter oldDelegate) {
    return x != oldDelegate.x || y != oldDelegate.y || opacity != oldDelegate.opacity;
  }
}