import 'dart:math';

import 'package:airp/providers/vfx_provider.dart';
import 'package:airp/widgets/effects_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoteField', () {
    final field = MoteField.pool(80, Random(7));

    test('generates the requested count', () {
      expect(field.motes, hasLength(80));
    });

    test('keeps positions normalised for a long run', () {
      // Motion is closed-form in t, so a far-future sample must still wrap
      // into the viewport rather than drifting off screen forever.
      for (final t in [0.0, 1.0, 60.0, 3600.0, 86400.0]) {
        for (final mote in field.motes) {
          expect(mote.xAt(t), inInclusiveRange(0.0, 1.0));
          expect(mote.yAt(t), inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('alpha stays within range', () {
      for (final t in [0.0, 2.5, 100.0, 5000.0]) {
        for (final mote in field.motes) {
          expect(mote.alphaAt(t), inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('nearer motes are larger and faster than far ones', () {
      const near = Mote(
        x0: 0,
        y0: 0,
        driftX: 0,
        driftY: 0,
        wanderAx: 0,
        wanderAy: 0,
        wanderFx: 0,
        wanderFy: 0,
        phaseX: 0,
        phaseY: 0,
        depth: 1.0,
        radius: 4,
        opacity: 0.5,
        twinkleF: 0,
        twinklePhase: 0,
      );
      const far = Mote(
        x0: 0,
        y0: 0,
        driftX: 0,
        driftY: 0,
        wanderAx: 0,
        wanderAy: 0,
        wanderFx: 0,
        wanderFy: 0,
        phaseX: 0,
        phaseY: 0,
        depth: 0.0,
        radius: 4,
        opacity: 0.5,
        twinkleF: 0,
        twinklePhase: 0,
      );

      expect(near.scaledRadius, greaterThan(far.scaledRadius));
      expect(near.parallax, greaterThan(far.parallax));
      expect(near.alphaAt(0), greaterThan(far.alphaAt(0)));
    });

    test('motes actually move over time', () {
      final mote = field.motes.first;
      expect(mote.yAt(0), isNot(closeTo(mote.yAt(30), 1e-6)));
    });
  });

  group('RainField', () {
    final field = RainField.pool(60, Random(11));

    test('streak length scales with fall speed', () {
      const slow = RainDrop(
        x: 0,
        yStart: 0,
        speed: 0.6,
        depth: 0,
        strokeWidth: 1,
        opacity: 0.2,
      );
      const fast = RainDrop(
        x: 0,
        yStart: 0,
        speed: 2.2,
        depth: 1,
        strokeWidth: 1,
        opacity: 0.2,
      );
      expect(fast.length, greaterThan(slow.length));
    });

    test('streak length is clamped to a sane band', () {
      const absurd = RainDrop(
        x: 0,
        yStart: 0,
        speed: 500,
        depth: 1,
        strokeWidth: 1,
        opacity: 0.2,
      );
      expect(absurd.length, lessThanOrEqualTo(0.20));

      const crawling = RainDrop(
        x: 0,
        yStart: 0,
        speed: 0.001,
        depth: 0,
        strokeWidth: 1,
        opacity: 0.2,
      );
      expect(crawling.length, greaterThanOrEqualTo(0.02));
    });

    test('drop positions wrap into the viewport', () {
      for (final t in [0.0, 5.0, 500.0, 50000.0]) {
        for (final drop in field.drops) {
          expect(drop.yAt(t), inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('wind slant is shared by the whole field and stays bounded', () {
      // The old implementation derived slant per drop from its own length, so
      // drops fell at differing angles. Slant is now a property of time only.
      for (final t in [0.0, 3.0, 17.5, 240.0]) {
        final slant = RainField.slantAt(t);
        expect(slant, inInclusiveRange(0.0, 0.35));
      }
    });

    test('wind varies over time rather than being constant', () {
      expect(RainField.slantAt(0), isNot(closeTo(RainField.slantAt(9), 1e-6)));
    });

    test('nearer drops fall faster than far drops on average', () {
      final near = field.drops.where((d) => d.depth > 0.7);
      final far = field.drops.where((d) => d.depth < 0.3);
      double mean(Iterable<RainDrop> ds) =>
          ds.map((d) => d.speed).reduce((a, b) => a + b) / ds.length;

      expect(mean(near), greaterThan(mean(far)));
    });
  });

  group('Firefly', () {
    Firefly makeFly({double period = 4.0, double phase = 0.0}) => Firefly(
      cx: 0.5,
      cy: 0.5,
      ax: 0.1,
      ay: 0.1,
      fx1: 0.2,
      fx2: 0.5,
      fy1: 0.15,
      fy2: 0.4,
      px1: 0,
      px2: 1,
      py1: 2,
      py2: 3,
      blinkPeriod: period,
      blinkPhase: phase,
      radius: 2,
      brightness: 1.0,
      color: Colors.yellow,
    );

    test('blink is dark for most of the cycle', () {
      final fly = makeFly(period: 4.0);
      // rise .06 + hold .07 + decay .22 = .35 lit, .65 dark.
      var dark = 0;
      const samples = 1000;
      for (var i = 0; i < samples; i++) {
        final t = (i / samples) * 4.0;
        if (fly.flashAt(t) == 0.0) dark++;
      }
      expect(dark / samples, greaterThan(0.5));
    });

    test('blink reaches full brightness at the hold', () {
      final fly = makeFly(period: 4.0);
      // Inside rise(0.06)..rise+hold(0.13) of the cycle.
      expect(fly.flashAt(4.0 * 0.10), 1.0);
    });

    test('decay is monotonically falling', () {
      final fly = makeFly(period: 4.0);
      final a = fly.flashAt(4.0 * 0.15);
      final b = fly.flashAt(4.0 * 0.25);
      final c = fly.flashAt(4.0 * 0.34);
      expect(a, greaterThan(b));
      expect(b, greaterThan(c));
    });

    test('flash envelope stays within range across the cycle', () {
      final fly = makeFly(period: 3.3, phase: 0.42);
      for (var i = 0; i < 500; i++) {
        expect(fly.flashAt(i * 0.11), inInclusiveRange(0.0, 1.0));
      }
    });

    test('phase offsets desynchronise the swarm', () {
      final a = makeFly(period: 4.0, phase: 0.0);
      final b = makeFly(period: 4.0, phase: 0.5);
      expect(a.flashAt(0.4), isNot(equals(b.flashAt(0.4))));
    });

    test('flight stays in the viewport over a long run', () {
      final swarm = FireflySwarm.pool(40, Random(3));
      for (final t in [0.0, 12.0, 600.0, 20000.0]) {
        for (final fly in swarm.flies) {
          expect(fly.xAt(t), inInclusiveRange(0.0, 1.0));
          expect(fly.yAt(t), inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('flight path is not a straight line', () {
      // The old implementation lerped x and y from A to B, so every fly
      // retraced one segment. Sampling three points must not be collinear.
      final fly = makeFly();
      final p0 = Offset(fly.xAt(0), fly.yAt(0));
      final p1 = Offset(fly.xAt(4), fly.yAt(4));
      final p2 = Offset(fly.xAt(8), fly.yAt(8));

      final cross =
          (p1.dx - p0.dx) * (p2.dy - p0.dy) - (p1.dy - p0.dy) * (p2.dx - p0.dx);
      expect(cross.abs(), greaterThan(1e-4));
    });

    test('swarm colours sit in the bioluminescent yellow-green band', () {
      final swarm = FireflySwarm.pool(50, Random(5));
      for (final fly in swarm.flies) {
        final hue = HSVColor.fromColor(fly.color).hue;
        expect(hue, inInclusiveRange(50.0, 80.0));
      }
    });
  });

  group('particleCountFromPercent', () {
    test('maps the percentage onto the pool size', () {
      expect(particleCountFromPercent(0, 200), 0);
      expect(particleCountFromPercent(50, 200), 100);
      expect(particleCountFromPercent(100, 200), 200);
    });

    test('clamps out-of-range input', () {
      expect(particleCountFromPercent(-25, 200), 0);
      expect(particleCountFromPercent(400, 200), 200);
      expect(particleCountFromPercent(double.nan, 200), 0);
    });

    test('is monotonic, so raising the slider never removes particles', () {
      var previous = -1;
      for (var pct = 0; pct <= 100; pct++) {
        final count = particleCountFromPercent(pct.toDouble(), kMaxMotes);
        expect(count, greaterThanOrEqualTo(previous));
        previous = count;
      }
    });
  });

  group('pool stability', () {
    // The visible field is a prefix of a fixed pool. Growing the count must
    // leave existing particles untouched, otherwise the slider reads as a
    // reseed rather than a count.
    test('a larger count is a superset of a smaller one', () {
      final pool = MoteField.pool(kMaxMotes, Random(0x5EED));
      final small = pool.motes.take(20).toList();
      final large = pool.motes.take(60).toList();

      expect(large.length, 60);
      for (var i = 0; i < small.length; i++) {
        expect(identical(large[i], small[i]), isTrue);
      }
    });

    test('the same seed reproduces the same pool across rebuilds', () {
      final a = MoteField.pool(40, Random(0x5EED));
      final b = MoteField.pool(40, Random(0x5EED));
      for (var i = 0; i < 40; i++) {
        expect(a.motes[i].x0, b.motes[i].x0);
        expect(a.motes[i].radius, b.motes[i].radius);
      }
    });
  });

  group('mote size distribution', () {
    final pool = MoteField.pool(kMaxMotes, Random(0x5EED));
    final radii = pool.motes.map((m) => m.radius).toList()..sort();

    test('includes minute specks', () {
      expect(radii.first, lessThan(1.5));
    });

    test('includes markedly larger specks', () {
      expect(radii.last, greaterThan(8.0));
    });

    test('is weighted toward the small end', () {
      // Cubic weighting: the median should sit well below the midpoint of the
      // range, so large specks stay occasional rather than typical.
      final median = radii[radii.length ~/ 2];
      final midpoint = (radii.first + radii.last) / 2;
      expect(median, lessThan(midpoint));
    });
  });

  group('VfxProvider.percentFromLegacy', () {
    test('rescales the old per-effect ranges onto 0-100', () {
      expect(VfxProvider.percentFromLegacy(75, 150), 50);
      expect(VfxProvider.percentFromLegacy(100, 200), 50);
      expect(VfxProvider.percentFromLegacy(50, 100), 50);
    });

    test('preserves the endpoints', () {
      expect(VfxProvider.percentFromLegacy(150, 150), 100);
      expect(VfxProvider.percentFromLegacy(0, 150), 0);
    });

    test('clamps a stored value above the legacy maximum', () {
      expect(VfxProvider.percentFromLegacy(999, 150), 100);
    });
  });
}
