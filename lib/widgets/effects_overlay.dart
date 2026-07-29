import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Size in pixels of one cell in the particle sprite atlas.
const double _kSpriteCell = 64.0;

/// Atlas cell index for the soft, diffuse dust sprite.
const int _kSpriteDust = 0;

/// Atlas cell index for the firefly sprite (tight core, wide halo).
const int _kSpriteFirefly = 1;

/// Pool sizes. Each slider is a percentage of these, so 100% is this many
/// particles and every intermediate value is a prefix of the same pool.
const int kMaxMotes = 220;
const int kMaxRainDrops = 260;
const int kMaxFireflies = 140;

/// Fixed seeds. Pools are generated once and never regenerated, so moving a
/// slider adds or removes particles from the tail instead of reshuffling the
/// whole field, which previously read as a reseed rather than a count.
const int _kMoteSeed = 0x5EED;
const int _kRainSeed = 0x2A19;
const int _kFireflySeed = 0xF17E;

/// Converts a slider percentage in `[0, 100]` to a particle count out of [max].
///
/// Because pools are fixed and drawn as a prefix, this is a true count: 50%
/// draws the same first half of the pool every time rather than resampling it.
int particleCountFromPercent(double percent, int max) {
  if (!percent.isFinite || percent <= 0) return 0;
  return ((percent / 100.0) * max).round().clamp(0, max);
}

/// A widget that overlays atmospheric effects: dust motes, rain, and fireflies.
///
/// All enabled effects share a single [Ticker] and a single [CustomPaint]
/// layer. Glowing particles are drawn with one [Canvas.drawAtlas] call against
/// a pre-rendered sprite sheet, so particle count costs arithmetic rather than
/// draw calls or compositor layers.
class EffectsOverlay extends StatefulWidget {
  /// Whether to show the floating dust motes effect.
  final bool showMotes;

  /// Whether to show the falling rain effect.
  final bool showRain;

  /// Whether to show the blinking fireflies effect.
  final bool showFireflies;

  /// The primary color used for the motes.
  final Color effectColor;

  /// Mote density as a percentage of [kMaxMotes].
  final double motesDensity;

  /// Rain intensity as a percentage of [kMaxRainDrops].
  final double rainIntensity;

  /// Firefly count as a percentage of [kMaxFireflies].
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
  State<EffectsOverlay> createState() => _EffectsOverlayState();
}

class _EffectsOverlayState extends State<EffectsOverlay>
    with SingleTickerProviderStateMixin {
  /// Repaint signal for the painter. Advancing this does not rebuild widgets.
  final EffectClock _clock = EffectClock();

  late final Ticker _ticker;

  /// Pools are built once at full size and never regenerated. The sliders only
  /// move how many of each are drawn.
  late final MoteField _motePool;
  late final RainField _rainPool;
  late final FireflySwarm _fireflyPool;

  ui.Image? _atlas;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _motePool = MoteField.pool(kMaxMotes, Random(_kMoteSeed));
    _rainPool = RainField.pool(kMaxRainDrops, Random(_kRainSeed));
    _fireflyPool = FireflySwarm.pool(kMaxFireflies, Random(_kFireflySeed));
    _syncTicker();
    _buildAtlas();
  }

  @override
  void didUpdateWidget(EffectsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  bool get _anyEnabled =>
      widget.showMotes || widget.showRain || widget.showFireflies;

  /// Keeps the ticker running only while something is actually drawn, so a
  /// fully disabled overlay costs nothing per frame.
  void _syncTicker() {
    if (_anyEnabled && !_ticker.isActive) {
      _ticker.start();
    } else if (!_anyEnabled && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    _clock.seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  /// Renders the two particle sprites into a single atlas image.
  ///
  /// Drawn once at startup rather than blurring every particle every frame:
  /// a `MaskFilter.blur` per particle is a full gaussian pass per draw.
  Future<void> _buildAtlas() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double r = _kSpriteCell / 2;

    // Cell 0: dust. A wide, even falloff reading as an out-of-focus speck.
    canvas.drawCircle(
      const Offset(r, r),
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(r, r),
          r,
          [
            Colors.white,
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
          [0.0, 0.35, 1.0],
        ),
    );

    // Cell 1: firefly. A small saturated core inside a broad soft halo, which
    // is what gives it a body instead of reading as another blurred blob.
    canvas.drawCircle(
      const Offset(_kSpriteCell + r, r),
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(_kSpriteCell + r, r),
          r,
          [
            Colors.white,
            Colors.white,
            Colors.white.withValues(alpha: 0.38),
            Colors.white.withValues(alpha: 0.0),
          ],
          [0.0, 0.11, 0.30, 1.0],
        ),
    );

    final image = await recorder.endRecording().toImage(
      (_kSpriteCell * 2).round(),
      _kSpriteCell.round(),
    );

    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _atlas = image);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _atlas?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _atlas;
    if (!_anyEnabled || atlas == null) return const SizedBox.shrink();

    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        isComplex: true,
        willChange: true,
        painter: EnvironmentPainter(
          repaint: _clock,
          clock: _clock,
          atlas: atlas,
          motes: _motePool,
          rain: _rainPool,
          fireflies: _fireflyPool,
          moteCount: widget.showMotes
              ? particleCountFromPercent(widget.motesDensity, kMaxMotes)
              : 0,
          rainCount: widget.showRain
              ? particleCountFromPercent(widget.rainIntensity, kMaxRainDrops)
              : 0,
          fireflyCount: widget.showFireflies
              ? particleCountFromPercent(widget.firefliesCount, kMaxFireflies)
              : 0,
          moteColor: widget.effectColor,
        ),
      ),
    );
  }
}

/// Frame clock. Notifies listeners with the elapsed time in seconds.
///
/// Passed to [CustomPainter.repaint] so ticks repaint the canvas without
/// rebuilding any widgets.
class EffectClock extends ChangeNotifier {
  double _seconds = 0;

  double get seconds => _seconds;

  set seconds(double value) {
    if (_seconds == value) return;
    _seconds = value;
    notifyListeners();
  }
}

// ── Dust motes ──────────────────────────────────────────────────────────────

/// A single dust speck.
///
/// Motion is closed-form in `t` rather than integrated frame to frame, so the
/// field is resolution independent, resumes correctly after the ticker is
/// stopped, and is testable without a render loop.
@immutable
class Mote {
  /// Starting position, in normalised screen space.
  final double x0, y0;

  /// Constant drift, in screen widths (or heights) per second.
  final double driftX, driftY;

  /// Amplitude and angular frequency of the two-term wander, per axis.
  final double wanderAx, wanderAy, wanderFx, wanderFy;

  /// Phase offsets keeping specks out of lockstep.
  final double phaseX, phaseY;

  /// Depth in `[0, 1]`. 0 is far (small, dim, slow), 1 is near.
  final double depth;

  /// Base radius in logical pixels before depth scaling.
  final double radius;

  /// Base opacity before depth scaling and twinkle.
  final double opacity;

  /// Angular frequency and phase of the brightness twinkle.
  final double twinkleF, twinklePhase;

  const Mote({
    required this.x0,
    required this.y0,
    required this.driftX,
    required this.driftY,
    required this.wanderAx,
    required this.wanderAy,
    required this.wanderFx,
    required this.wanderFy,
    required this.phaseX,
    required this.phaseY,
    required this.depth,
    required this.radius,
    required this.opacity,
    required this.twinkleF,
    required this.twinklePhase,
  });

  /// Parallax factor: nearer motes travel faster and are larger.
  double get parallax => 0.3 + depth * 0.7;

  /// Normalised x at time [t], wrapped into `[0, 1)`.
  double xAt(double t) => _wrap01(
    x0 +
        driftX * t * parallax +
        wanderAx * sin(wanderFx * t + phaseX) +
        wanderAx * 0.45 * sin(wanderFx * 2.37 * t + phaseY),
  );

  /// Normalised y at time [t], wrapped into `[0, 1)`.
  double yAt(double t) => _wrap01(
    y0 +
        driftY * t * parallax +
        wanderAy * sin(wanderFy * t + phaseY) +
        wanderAy * 0.45 * sin(wanderFy * 1.73 * t + phaseX),
  );

  /// Alpha at time [t], including depth attenuation and twinkle.
  double alphaAt(double t) {
    final twinkle = 0.72 + 0.28 * sin(twinkleF * t + twinklePhase);
    return (opacity * (0.35 + depth * 0.65) * twinkle).clamp(0.0, 1.0);
  }

  /// Rendered radius in logical pixels.
  double get scaledRadius => radius * (0.4 + depth * 0.6);
}

/// A generated field of dust motes.
class MoteField {
  final List<Mote> motes;

  const MoteField(this.motes);

  /// Builds the full pool. Generated once with a fixed seed; the visible
  /// count is a prefix of this list, so raising the slider reveals more motes
  /// without disturbing the ones already on screen.
  factory MoteField.pool(int count, Random random) {
    return MoteField(
      List.generate(count, (_) {
        final depth = random.nextDouble();

        // Cubic weighting gives a long tail: mostly minute specks with a few
        // markedly larger, out-of-focus ones, rather than a uniform mid band.
        final sizeRoll = random.nextDouble();
        final radius = 0.45 + sizeRoll * sizeRoll * sizeRoll * 13.5;

        // Bigger specks read as nearer the lens and hang dimmer, so they do
        // not turn into bright blobs.
        final opacity =
            0.09 + random.nextDouble() * 0.24 * (1.0 - sizeRoll * 0.55);

        return Mote(
          x0: random.nextDouble(),
          y0: random.nextDouble(),
          // Dust settles: a slight, mostly downward drift with a lateral bias.
          driftX: (random.nextDouble() - 0.5) * 0.012,
          driftY: 0.004 + random.nextDouble() * 0.011,
          wanderAx: 0.015 + random.nextDouble() * 0.045,
          wanderAy: 0.010 + random.nextDouble() * 0.030,
          wanderFx: 0.05 + random.nextDouble() * 0.16,
          wanderFy: 0.04 + random.nextDouble() * 0.13,
          phaseX: random.nextDouble() * 2 * pi,
          phaseY: random.nextDouble() * 2 * pi,
          depth: depth,
          radius: radius,
          opacity: opacity,
          twinkleF: 0.25 + random.nextDouble() * 0.85,
          twinklePhase: random.nextDouble() * 2 * pi,
        );
      }),
    );
  }
}

// ── Rain ────────────────────────────────────────────────────────────────────

/// A single raindrop streak.
@immutable
class RainDrop {
  /// Horizontal position in normalised screen space.
  final double x;

  /// Vertical phase offset in `[0, 1)`.
  final double yStart;

  /// Fall speed in screen heights per second.
  final double speed;

  /// Depth in `[0, 1]`. 0 is far, 1 is near.
  final double depth;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  /// Base opacity.
  final double opacity;

  const RainDrop({
    required this.x,
    required this.yStart,
    required this.speed,
    required this.depth,
    required this.strokeWidth,
    required this.opacity,
  });

  /// Head position at time [t], wrapped so drops re-enter above the viewport.
  double yAt(double t) => _wrap01(yStart + speed * t);

  /// Streak length in normalised screen heights.
  ///
  /// Proportional to fall speed, which is what motion blur actually does: a
  /// faster drop smears further within one frame.
  double get length => (speed * 0.055).clamp(0.02, 0.20);
}

/// A generated field of raindrops.
class RainField {
  final List<RainDrop> drops;

  const RainField(this.drops);

  factory RainField.pool(int count, Random random) {
    return RainField(
      List.generate(count, (_) {
        final depth = random.nextDouble();
        return RainDrop(
          x: random.nextDouble(),
          yStart: random.nextDouble(),
          // Near drops fall faster, reinforcing the parallax.
          speed: 0.55 + depth * 1.5 + random.nextDouble() * 0.35,
          depth: depth,
          strokeWidth: 0.5 + depth * 1.5,
          opacity: 0.07 + depth * 0.20 + random.nextDouble() * 0.06,
        );
      }),
    );
  }

  /// Shared wind slant at time [t], as a horizontal offset per unit of fall.
  ///
  /// One value for the whole field: real rain shares a wind vector. The old
  /// implementation derived slant from each drop's own length, so drops
  /// crossed each other at different angles.
  static double slantAt(double t) =>
      0.16 + 0.10 * sin(t * 0.19) + 0.04 * sin(t * 0.47 + 1.3);
}

// ── Fireflies ───────────────────────────────────────────────────────────────

/// A single firefly.
///
/// Distinct from [Mote] in both flight and light. It wanders on a sum of
/// incommensurate sines rather than drifting along a straight line, and it
/// blinks in discrete flashes separated by darkness rather than pulsing
/// continuously.
@immutable
class Firefly {
  /// Centre of the wander region, in normalised screen space.
  final double cx, cy;

  /// Wander amplitudes per axis.
  final double ax, ay;

  /// The two angular frequencies per axis that compose the flight path.
  final double fx1, fx2, fy1, fy2;

  /// Phase offsets for each of the four flight terms.
  final double px1, px2, py1, py2;

  /// Duration of one blink cycle in seconds, and where in it this fly starts.
  final double blinkPeriod, blinkPhase;

  /// Core radius in logical pixels. The halo is drawn several times larger.
  final double radius;

  /// Peak brightness of a flash.
  final double brightness;

  /// Body colour. Real fireflies emit a narrow yellow-green band.
  final Color color;

  const Firefly({
    required this.cx,
    required this.cy,
    required this.ax,
    required this.ay,
    required this.fx1,
    required this.fx2,
    required this.fy1,
    required this.fy2,
    required this.px1,
    required this.px2,
    required this.py1,
    required this.py2,
    required this.blinkPeriod,
    required this.blinkPhase,
    required this.radius,
    required this.brightness,
    required this.color,
  });

  /// Normalised x at time [t].
  double xAt(double t) =>
      _wrap01(cx + ax * sin(fx1 * t + px1) + ax * 0.42 * sin(fx2 * t + px2));

  /// Normalised y at time [t].
  ///
  /// Carries a slight upward bias, which is how fireflies read at dusk.
  double yAt(double t) => _wrap01(
    cy + ay * sin(fy1 * t + py1) + ay * 0.42 * sin(fy2 * t + py2) - t * 0.0022,
  );

  /// Blink envelope in `[0, 1]` at time [t].
  ///
  /// Fast rise, brief hold, slower decay, then a long dark interval. The dark
  /// phase is the majority of the cycle and is what makes it read as a
  /// firefly rather than a throbbing lamp.
  double flashAt(double t) {
    final u = _wrap01(t / blinkPeriod + blinkPhase);
    const rise = 0.06;
    const hold = 0.07;
    const decay = 0.22;

    if (u < rise) {
      final k = u / rise;
      return k * k * (3 - 2 * k);
    }
    if (u < rise + hold) return 1.0;
    if (u < rise + hold + decay) {
      final k = 1.0 - (u - rise - hold) / decay;
      return k * k;
    }
    return 0.0;
  }

  /// Final alpha at time [t].
  double alphaAt(double t) => (flashAt(t) * brightness).clamp(0.0, 1.0);
}

/// A generated swarm of fireflies.
class FireflySwarm {
  final List<Firefly> flies;

  const FireflySwarm(this.flies);

  factory FireflySwarm.pool(int count, Random random) {
    return FireflySwarm(
      List.generate(count, (_) {
        // Yellow-green through warm amber, the real bioluminescent range.
        final hue = 52.0 + random.nextDouble() * 26.0;
        return Firefly(
          cx: random.nextDouble(),
          cy: random.nextDouble(),
          ax: 0.04 + random.nextDouble() * 0.16,
          ay: 0.03 + random.nextDouble() * 0.12,
          fx1: 0.07 + random.nextDouble() * 0.20,
          fx2: 0.23 + random.nextDouble() * 0.44,
          fy1: 0.06 + random.nextDouble() * 0.18,
          fy2: 0.19 + random.nextDouble() * 0.39,
          px1: random.nextDouble() * 2 * pi,
          px2: random.nextDouble() * 2 * pi,
          py1: random.nextDouble() * 2 * pi,
          py2: random.nextDouble() * 2 * pi,
          blinkPeriod: 2.4 + random.nextDouble() * 3.6,
          blinkPhase: random.nextDouble(),
          radius: 1.1 + random.nextDouble() * 1.5,
          brightness: 0.55 + random.nextDouble() * 0.45,
          color: HSVColor.fromAHSV(1.0, hue, 0.80, 1.0).toColor(),
        );
      }),
    );
  }
}

// ── Painting ────────────────────────────────────────────────────────────────

/// Draws every enabled effect into one layer.
class EnvironmentPainter extends CustomPainter {
  final EffectClock clock;
  final ui.Image atlas;
  final MoteField motes;
  final RainField rain;
  final FireflySwarm fireflies;

  /// How many of each pool to draw. Zero disables that effect.
  final int moteCount;
  final int rainCount;
  final int fireflyCount;

  final Color moteColor;

  EnvironmentPainter({
    required Listenable repaint,
    required this.clock,
    required this.atlas,
    required this.motes,
    required this.rain,
    required this.fireflies,
    required this.moteCount,
    required this.rainCount,
    required this.fireflyCount,
    required this.moteColor,
  }) : super(repaint: repaint);

  static final Rect _dustRect = Rect.fromLTWH(
    _kSpriteDust * _kSpriteCell,
    0,
    _kSpriteCell,
    _kSpriteCell,
  );

  static final Rect _fireflyRect = Rect.fromLTWH(
    _kSpriteFirefly * _kSpriteCell,
    0,
    _kSpriteCell,
    _kSpriteCell,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = clock.seconds;

    // Rain sits behind the glows so lit particles read as nearer the viewer.
    if (rainCount > 0) _paintRain(canvas, size, t);

    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    final colors = <Color>[];

    if (moteCount > 0) {
      _collectMotes(size, t, transforms, rects, colors);
    }
    if (fireflyCount > 0) {
      _collectFireflies(size, t, transforms, rects, colors);
    }

    if (transforms.isEmpty) return;

    // One draw call for every glowing particle on screen.
    canvas.drawAtlas(
      atlas,
      transforms,
      rects,
      colors,
      BlendMode.modulate,
      null,
      Paint()..blendMode = BlendMode.plus,
    );
  }

  void _collectMotes(
    Size size,
    double t,
    List<RSTransform> transforms,
    List<Rect> rects,
    List<Color> colors,
  ) {
    for (final mote in motes.motes.take(moteCount)) {
      final alpha = mote.alphaAt(t);
      if (alpha <= 0.004) continue;

      // The sprite's visible glow is smaller than its cell, so scale against
      // the drawn radius rather than the full cell.
      final scale = (mote.scaledRadius * 2.6) / _kSpriteCell;
      transforms.add(
        RSTransform.fromComponents(
          rotation: 0,
          scale: scale,
          anchorX: _kSpriteCell / 2,
          anchorY: _kSpriteCell / 2,
          translateX: mote.xAt(t) * size.width,
          translateY: mote.yAt(t) * size.height,
        ),
      );
      rects.add(_dustRect);
      colors.add(moteColor.withValues(alpha: alpha));
    }
  }

  void _collectFireflies(
    Size size,
    double t,
    List<RSTransform> transforms,
    List<Rect> rects,
    List<Color> colors,
  ) {
    for (final fly in fireflies.flies.take(fireflyCount)) {
      final alpha = fly.alphaAt(t);
      // Dark phase: skip entirely rather than drawing a transparent quad.
      if (alpha <= 0.004) continue;

      final scale = (fly.radius * 7.0) / _kSpriteCell;
      transforms.add(
        RSTransform.fromComponents(
          rotation: 0,
          scale: scale,
          anchorX: _kSpriteCell / 2,
          anchorY: _kSpriteCell / 2,
          translateX: fly.xAt(t) * size.width,
          translateY: fly.yAt(t) * size.height,
        ),
      );
      rects.add(_fireflyRect);
      colors.add(fly.color.withValues(alpha: alpha));
    }
  }

  void _paintRain(Canvas canvas, Size size, double t) {
    final slant = RainField.slantAt(t);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final drop in rain.drops.take(rainCount)) {
      final headY = drop.yAt(t);
      final len = drop.length;

      paint
        ..color = Colors.white.withValues(alpha: drop.opacity.clamp(0.0, 1.0))
        ..strokeWidth = drop.strokeWidth;

      _drawStreak(canvas, size, drop.x, headY, len, slant, paint);

      // Redraw across the seam so a streak entering from the top is not
      // clipped mid-stroke.
      if (headY - len < 0) {
        _drawStreak(canvas, size, drop.x, headY + 1.0, len, slant, paint);
      }
    }
  }

  /// Draws one streak trailing upwind from its head, along the fall vector.
  void _drawStreak(
    Canvas canvas,
    Size size,
    double x,
    double headY,
    double len,
    double slant,
    Paint paint,
  ) {
    final headX = x * size.width;
    canvas.drawLine(
      Offset(headX, headY * size.height),
      Offset(headX + slant * len * size.width, (headY - len) * size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant EnvironmentPainter oldDelegate) {
    return oldDelegate.moteCount != moteCount ||
        oldDelegate.rainCount != rainCount ||
        oldDelegate.fireflyCount != fireflyCount ||
        oldDelegate.moteColor != moteColor ||
        oldDelegate.atlas != atlas;
  }
}

/// Wraps [v] into `[0, 1)`, handling negatives.
double _wrap01(double v) {
  final r = v % 1.0;
  return r < 0 ? r + 1.0 : r;
}
