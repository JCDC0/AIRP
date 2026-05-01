import 'dart:math' as math;
import 'dart:math' show Random;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Orbit line data & generator
// ---------------------------------------------------------------------------

/// Immutable config for a single orbiting arc/line.
class OrbitLine {
  final int speed; // Whole-number speed multiplier (1, 2 or 3)
  final double offset; // Starting phase offset [0, 1)
  final double length; // Arc fraction of total path [0.1, 0.35)

  const OrbitLine({
    required this.speed,
    required this.offset,
    required this.length,
  });
}

/// Generates [lineCount] randomised orbit lines with whole-number speeds so
/// that every arc completes full cycles within one controller period,
/// eliminating stutter at the repeat boundary.
List<OrbitLine> generateOrbitLines(
  Random rng, {
  int lineCount = 3,
  int maxSpeed = 3,
}) {
  final int count = lineCount.clamp(2, 5);
  // Assign distinct speeds cycling through 1..maxSpeed
  final List<int> speeds = List.generate(count, (i) => (i % maxSpeed) + 1);
  // Shuffle so order isn't always ascending
  speeds.shuffle(rng);

  return List.generate(count, (i) {
    final double offset = (i / count) + rng.nextDouble() * 0.1;
    final double length = 0.10 + rng.nextDouble() * 0.20; // 10 %–30 %
    return OrbitLine(speed: speeds[i], offset: offset % 1.0, length: length);
  });
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Draws randomised animated lines orbiting the rounded-rectangle border of the
/// chat text field. This is used as a loading indicator when an AI response is
/// being generated.
class LineOrbitPainter extends CustomPainter {
  final double progress;
  final List<OrbitLine> lines;
  final Color color;
  final Color bloomColor;
  final bool enableBloom;
  final double borderRadius;

  LineOrbitPainter({
    required this.progress,
    required this.lines,
    required this.color,
    required this.bloomColor,
    required this.enableBloom,
    this.borderRadius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );
    final Path path = Path()..addRRect(rrect);

    final List<ui.PathMetric> metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final ui.PathMetric metric = metrics.first;
    final double pathLength = metric.length;

    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = ui.StrokeCap.round;

    final Paint bloomPaint = Paint()
      ..color = bloomColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..strokeCap = ui.StrokeCap.round;

    for (final line in lines) {
      final double p = (progress * line.speed + line.offset) % 1.0;

      final double startOffset = p * pathLength;
      final double segmentLength = line.length * pathLength;

      Path extract;
      if (startOffset + segmentLength <= pathLength) {
        extract = metric.extractPath(startOffset, startOffset + segmentLength);
      } else {
        extract = metric.extractPath(startOffset, pathLength);
        extract.addPath(
          metric.extractPath(0, (startOffset + segmentLength) % pathLength),
          Offset.zero,
        );
      }

      if (enableBloom) {
        canvas.drawPath(extract, bloomPaint);
      }
      canvas.drawPath(extract, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.enableBloom != enableBloom;
}

/// Draws randomised animated arcs around a circular icon button.
class IconArcPainter extends CustomPainter {
  final double progress;
  final List<OrbitLine> lines;
  final Color color;
  final double strokeWidth;
  final bool enableBloom;
  final Color bloomColor;

  IconArcPainter({
    required this.progress,
    required this.lines,
    required this.color,
    required this.strokeWidth,
    required this.enableBloom,
    required this.bloomColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = strokeWidth / 2;
    final Rect arcRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final Paint arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    Paint? bloomPaint;
    if (enableBloom) {
      bloomPaint = Paint()
        ..color = bloomColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..strokeCap = StrokeCap.round;
    }

    for (final line in lines) {
      // Full circle arc — sweep angle is a fraction of the circle
      final double startAngle =
          ((progress * line.speed + line.offset) % 1.0) * 2 * math.pi;
      // Each line covers ~90°; shorter lines for higher-speed arcs feel snappier
      final double sweepAngle = line.length * 2 * math.pi;

      if (bloomPaint != null) {
        canvas.drawArc(arcRect, startAngle, sweepAngle, false, bloomPaint);
      }
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant IconArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}