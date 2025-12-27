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
  final bool showGlitch;
  final Color effectColor;
  final double motesDensity;
  final double rainIntensity;
  final double firefliesCount;
  final double glitchIntensity;

  const EffectsOverlay({
    super.key,
    this.showMotes = false,
    this.showRain = false,
    this.showFireflies = false,
    this.showGlitch = false,
    required this.effectColor,
    this.motesDensity = 50.0,
    this.rainIntensity = 80.0,
    this.firefliesCount = 30.0,
    this.glitchIntensity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showMotes) MotesEffect(color: effectColor, numberOfMotes: motesDensity.toInt()),
        if (showRain) RainEffect(color: Colors.white, numberOfDrops: rainIntensity.toInt()),
        if (showFireflies) FirefliesEffect(numberOfFireflies: firefliesCount.toInt()),
        if (showGlitch) GlitchEffect(intensity: glitchIntensity),
      ],
    );
  }
}
// =======================================================================
class MotesEffect extends StatelessWidget {
  final int numberOfMotes;
  final Color color;

  MotesEffect({super.key, this.numberOfMotes = 50, required this.color});

  final Random random = Random();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(numberOfMotes, (index) {
        final size = random.nextDouble() * 2.5 + 0.5;
        final duration = Duration(milliseconds: random.nextInt(15000) + 30000);
        
        final tween = MovieTween()
          ..scene(duration: duration, curve: Curves.easeInOutSine)
              .tween('x', Tween(begin: random.nextDouble(), end: random.nextDouble()))
              .tween('y', Tween(begin: random.nextDouble(), end: random.nextDouble()));

        return Positioned.fill(
          child: LoopAnimationBuilder<Movie>(
            tween: tween,
            duration: duration,
            builder: (context, value, child) {
              return CustomPaint(
                painter: MotePainter(
                  x: value.get('x'),
                  y: value.get('y'),
                  size: size,
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

class MotePainter extends CustomPainter {
  final double x;
  final double y;
  final double size;
  final Color color;

  MotePainter({required this.x, required this.y, required this.size, required this.color});

  final Random random = Random();

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity = (random.nextDouble() * 0.5 + 0.4).clamp(0.0, 1.0);
    
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, this.size * 1.5);
    canvas.drawCircle(Offset(x * size.width, y * size.height), this.size, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// =======================================================================
// Rain Effect
// =======================================================================
class RainEffect extends StatelessWidget {
  final int numberOfDrops;
  final Color color;

  // Reduced count slightly to be less chaotic
  RainEffect({super.key, this.numberOfDrops = 80, required this.color});

  final Random random = Random();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(numberOfDrops, (index) {
        final duration = Duration(milliseconds: random.nextInt(1500) + 1500);

        final tween = MovieTween()
          ..scene(
            duration: duration,
            curve: Curves.linear,
          ).tween('y', Tween(begin: -0.2, end: 1.2));

        return Positioned.fill(
          child: LoopAnimationBuilder<Movie>(
            tween: tween,
            duration: duration,
            builder: (context, value, child) {
              return CustomPaint(
                painter: RainPainter(
                  x: random.nextDouble(),
                  y: value.get('y'),
                  // UPDATED: Much longer lines
                  length: random.nextDouble() * 150,
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
  final Color color;

  RainPainter({required this.x, required this.y, required this.length, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // UPDATED: Lower opacity for "gentler" look
      ..color = color.withOpacity(0.25) 
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(
      Offset(x * size.width, y * size.height),
      Offset(x * size.width, y * size.height + length),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// =======================================================================
// Fireflies Effect
// =======================================================================
class FirefliesEffect extends StatelessWidget {
  final int numberOfFireflies;

  const FirefliesEffect({super.key, this.numberOfFireflies = 30});

  @override
  Widget build(BuildContext context) {
    final Random random = Random();
    
    return Stack(
      children: List.generate(numberOfFireflies, (index) {
        final duration = Duration(milliseconds: random.nextInt(8000) + 4000);

        // UPDATED: Color logic - Yellows and Greens
        final bool isGreen = random.nextDouble() > 0.7; // 30% chance of green
        final Color flyColor = isGreen ? Colors.lightGreenAccent : Colors.yellowAccent;

        final tween = MovieTween()
          ..scene(duration: duration, curve: Curves.easeInOutSine)
              .tween('x', Tween(begin: random.nextDouble(), end: random.nextDouble()))
              .tween('y', Tween(begin: random.nextDouble(), end: random.nextDouble()));
        
        final pulseTween = MovieTween()
          ..scene(duration: const Duration(seconds: 2), curve: Curves.easeInOut)
              .tween('opacity', Tween(begin: 0.2, end: 0.8))
          ..scene(duration: const Duration(seconds: 2), curve: Curves.easeInOut)
              .tween('opacity', Tween(begin: 0.8, end: 0.2));

        return Positioned.fill(
          child: LoopAnimationBuilder<Movie>(
            tween: tween,
            duration: duration,
            builder: (context, pathValue, child) {
              return LoopAnimationBuilder<Movie>(
                tween: pulseTween,
                duration: pulseTween.duration,
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

  FireflyPainter({required this.x, required this.y, required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    // Slight glow core
    canvas.drawCircle(Offset(x * size.width, y * size.height), 2.5, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// =======================================================================
// Glitch Effect
// =======================================================================
class GlitchEffect extends StatefulWidget {
  final double intensity;
  const GlitchEffect({super.key, this.intensity = 0.5});

  @override
  State<GlitchEffect> createState() => _GlitchEffectState();
}

class _GlitchEffectState extends State<GlitchEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Random random = Random();
  
  final List<_GlitchArtifact> _artifacts = [];
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() {
        final spawnChance = widget.intensity * 0.25;
        if (random.nextDouble() < spawnChance) {
           _addArtifact();
        }
        _cleanupArtifacts();
      })
      ..repeat();
  }
  
  void _addArtifact() {
     if (!mounted) return;
     setState(() {
       _artifacts.add(_GlitchArtifact(
         top: random.nextDouble(),
         height: random.nextDouble() * 0.0005 + 0.0002, 
         offset: random.nextDouble() * 5 - 2.5,
         isChromatic: random.nextDouble() > 0.3, 
       ));
     });
  }
  
  void _cleanupArtifacts() {
     if (!mounted) return;
     setState(() {
        _artifacts.removeWhere((a) => a.isExpired);
     });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Optional: Random scanline pulse
        if (_artifacts.length > 5) 
           Positioned.fill(
             child: Opacity(
               opacity: 0.03,
               child: Container(color: Colors.white),
             ),
           ),
        
        ..._artifacts.map((artifact) {
           return Positioned(
             top: artifact.top * MediaQuery.of(context).size.height,
             height: artifact.height * MediaQuery.of(context).size.height,
             left: 0, right: 0,
             child: _GlitchBar(artifact: artifact),
           );
        }),
      ],
    );
  }
}

class _GlitchArtifact {
   final double top;
   final double height;
   final double offset;
   final bool isChromatic;
   final DateTime createdAt = DateTime.now();
   final int lifeSpan = Random().nextInt(150) + 50; 
   
   bool get isExpired => DateTime.now().difference(createdAt).inMilliseconds > lifeSpan;
   
   _GlitchArtifact({required this.top, required this.height, required this.offset, required this.isChromatic});

}

class _GlitchBar extends StatelessWidget {
   final _GlitchArtifact artifact;
   
   const _GlitchBar({required this.artifact});
   
   @override
   Widget build(BuildContext context) {
      if (artifact.isChromatic) {
         return Stack(
            children: [
               Transform.translate(
                  offset: Offset(artifact.offset, 0),
                  child: Container(
                    color: Colors.red.withOpacity(0.8),
                  ),
               ),
               Transform.translate(
                  offset: Offset(-artifact.offset * 1.5, 0),
                  child: Container(
                    color: Colors.cyan.withOpacity(0.8),
                  ),
               ),
            ],
         );
      } else {
         return Container(color: Colors.white.withOpacity(0.5));
      }
   }
}