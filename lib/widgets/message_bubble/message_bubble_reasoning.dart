import 'dart:math' show Random;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Thinking-bubble orbit helpers
// ---------------------------------------------------------------------------

/// Immutable config for a single orbiting line on the thinking bubble.
class _ThinkOrbitLine {
  final int speed; // Whole-number speed multiplier (1–3)
  final double offset; // Starting phase [0, 1)
  final double length; // Arc fraction of total path [0.10, 0.35)
  const _ThinkOrbitLine({
    required this.speed,
    required this.offset,
    required this.length,
  });
}

/// Generates [count] randomised orbit lines with whole-number speeds.
List<_ThinkOrbitLine> _generateThinkOrbitLines(
  Random rng, {
  int count = 2,
  int maxSpeed = 2,
}) {
  final int c = count.clamp(2, 5);
  final List<int> speeds = List.generate(c, (i) => (i % maxSpeed) + 1);
  speeds.shuffle(rng);
  return List.generate(c, (i) {
    final double offset = (i / c) + rng.nextDouble() * 0.1;
    final double length = 0.12 + rng.nextDouble() * 0.18;
    return _ThinkOrbitLine(
      speed: speeds[i],
      offset: offset % 1.0,
      length: length,
    );
  });
}

/// Draws randomised animated lines orbiting the thinking bubble header.
class _ThinkingOrbitPainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<_ThinkOrbitLine> lines;

  _ThinkingOrbitPainter({
    required this.progress,
    required this.color,
    required this.lines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    final Path path = Path()..addRRect(rrect);

    final List<ui.PathMetric> metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final ui.PathMetric metric = metrics.first;
    final double pathLength = metric.length;

    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
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
      canvas.drawPath(extract, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThinkingOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- REASONING HELPERS ---

class MessageBubbleReasoning extends StatefulWidget {
  final String reasoning;
  final Color textColor;
  final bool useBloom;
  final bool isDone;
  final bool enableLoadingAnimation;

  const MessageBubbleReasoning({
    super.key,
    required this.reasoning,
    required this.textColor,
    required this.useBloom,
    required this.isDone,
    required this.enableLoadingAnimation,
  });

  @override
  State<MessageBubbleReasoning> createState() => _MessageBubbleReasoningState();
}

class _MessageBubbleReasoningState extends State<MessageBubbleReasoning>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _orbitController;
  List<_ThinkOrbitLine> _orbitLines = [];

  @override
  void initState() {
    super.initState();
    _isExpanded = !widget.isDone;
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    final rng = Random();
    _orbitLines = _generateThinkOrbitLines(rng, count: rng.nextInt(3) + 2);
    if (!widget.isDone && widget.enableLoadingAnimation) {
      _orbitController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MessageBubbleReasoning oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableLoadingAnimation != widget.enableLoadingAnimation) {
      if (widget.enableLoadingAnimation && !widget.isDone && _isExpanded) {
        // Re-randomise lines each time animation is enabled
        final rng = Random();
        setState(() {
          _orbitLines = _generateThinkOrbitLines(
            rng,
            count: rng.nextInt(3) + 2,
          );
        });
        _orbitController.repeat();
      } else {
        _orbitController.stop();
      }
    }
    if (!oldWidget.isDone && widget.isDone) {
      _orbitController.stop();
      setState(() {
        _isExpanded = false;
      });
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reasoning.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: _orbitController,
              builder: (context, child) {
                return CustomPaint(
                  foregroundPainter:
                      !widget.isDone &&
                              _isExpanded &&
                              widget.enableLoadingAnimation
                          ? _ThinkingOrbitPainter(
                              progress: _orbitController.value,
                              color: widget.textColor.withValues(alpha: 0.6),
                              lines: _orbitLines,
                            )
                          : null,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.textColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: widget.textColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExpanded
                          ? Icons.visibility_off_outlined
                          : Icons.psychology_outlined,
                      size: 14,
                      color: widget.textColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isExpanded
                          ? "Hide Thought Process"
                          : "Show Thought Process",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),

          if (_isExpanded)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.textColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: widget.textColor.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                widget.reasoning,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: widget.textColor.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}