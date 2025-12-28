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
        // Size between 20.0 and 60.0
        final baseSize = random.nextDouble() * 40.0 + 20.0;
        // Lower opacity (0.05 to 0.15) so it doesn't block text
        final opacity = random.nextDouble() * 0.15 + 0.05;
        final duration =
            Duration(milliseconds: random.nextInt(20000) + 30000);

        // Put all animations in one scene to ensure they run together and added fade in/out
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
                  // Multiply base opacity by the fade factor to prevent popping
                  opacity: opacity * value.get('opacityFactor'),
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
      ..color = color.withOpacity(opacity)
      ..maskFilter =
          MaskFilter.blur(BlurStyle.normal, size * 0.8);

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

  @override
  Widget build(BuildContext context) {
    final random = Random();
    
        // Generate drops with random properties
    final drops = List.generate(numberOfDrops, (index) {
      return _RainDrop(
        x: random.nextDouble(),
        yStart: random.nextDouble(),
        speed: 1 + random.nextDouble() * 1.5,
        length: 0.05 + random.nextDouble() * 0.35,
        opacity: 0.01 + random.nextDouble() * 0.03,
        strokeWidth: 0.5 + random.nextDouble() * 1.5,
      );
    });

    return LoopAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1000.0),
      duration: const Duration(minutes: 10),
      builder: (context, value, child) {
        return CustomPaint(
          painter: RainPainter(
            drops: drops,
            animationValue: value,
            color: color,
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
    // MODIFIED: Slant factor (how much X changes relative to Y)
    // Positive = slant right, Negative = slant left.
    const double slantX = 0.15; 

    for (var drop in drops) {
      // Create a unique paint for each drop to support variable opacity/width
      final paint = Paint()
        ..color = color.withOpacity(drop.opacity)
        ..strokeWidth = drop.strokeWidth
        ..strokeCap = StrokeCap.round;

      // MODIFIED: Faster global speed multiplier (0.3 -> 0.8)
      final double progress = (drop.yStart + animationValue * drop.speed * 0.8) % 1.0;
      
      final double topY = progress * size.height;
      final double bottomY = topY + (drop.length * size.height);

      // Calculate slanted X coordinates
      // We shift the bottom X to create the slant
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
        // MODIFIED: Slower fireflies (10s-20s) as requested ("not as slow as dustmotes")
        final duration =
            Duration(milliseconds: random.nextInt(25000) + 20000);

        final double pulsePhase = random.nextDouble();

        final bool isGreen = random.nextDouble() > 0.7;
        final Color flyColor =
            isGreen ? Colors.lightGreenAccent : Colors.yellowAccent;
        
                // MODIFIED: Variable size for fireflies (20.0 to 60.0)
        final double fireflySize = random.nextDouble() * 40.0 + 10.0;

        // COMBINED: Movement and Lifecycle Opacity to prevent popping
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

        return Positioned.fill(
          child: LoopAnimationBuilder<Movie>(
            tween: pathTween,
            duration: duration,
            builder: (context, pathValue, child) {
              return CustomAnimationBuilder<double>(
                tween: pulseTween,
                duration: Duration(milliseconds: halfCycleDuration),
                control: Control.mirror,
                curve: Curves.easeInOut,
                startPosition: pulsePhase,
                builder: (context, opacityValue, child) {
                                    return CustomPaint(
                    painter: FireflyPainter(
                      x: pathValue.get('x'),
                      y: pathValue.get('y'),
                      size: fireflySize, 
                      // Combine pulse opacity with lifecycle opacity
                      opacity: opacityValue * pathValue.get('opacityFactor'),
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
  final double size; // Added size
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
  void paint(Canvas canvas, Size size) { // Note: 'size' param here is canvas size
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.4) // Reduced base opacity for softness
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, this.size * 0.6); // Blur based on firefly size

    canvas.drawCircle(
      Offset(x * size.width, y * size.height),
      this.size, // Use the class property size
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

