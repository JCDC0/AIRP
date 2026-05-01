import 'package:flutter/material.dart';

/// A custom painter to draw a bubble with a glowing border effect.
class BorderGlowPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final Color glowColor;
  final double radius;
  final double strokeWidth;
  final double glowStrokeWidth;

  BorderGlowPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.glowColor,
    this.radius = 12.0,
    this.strokeWidth = 1.0,
    this.glowStrokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowStrokeWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect.inflate(-strokeWidth / 2), borderPaint);
  }

  @override
  bool shouldRepaint(covariant BorderGlowPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.glowColor != glowColor;
  }
}
