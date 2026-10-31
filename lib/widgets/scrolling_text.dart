import 'package:flutter/material.dart';

/// One line of text that scrolls itself sideways when it does not fit.
///
/// A conversation title and a chronicle entry are both long and both matter:
/// truncating them to an ellipsis makes two generations of the same story
/// indistinguishable, which is the thing this replaces.
///
/// It renders a plain [Text] whenever the string fits, or when the incoming
/// constraints are unbounded and there is nothing to measure against, so a list
/// of short titles schedules no animation at all.
///
/// Note for tests: an overflowing string animates forever, so `pumpAndSettle`
/// on a widget containing one will run to its timeout. Pump a fixed number of
/// frames instead.
class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Logical pixels per second. Deliberately slow enough to read.
  final double speed;

  const ScrollingText(this.text, {super.key, this.style, this.speed = 22});

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// Holds the text still at each end before reversing, so the start and the
  /// end of the title are both readable rather than swinging past.
  late final Animation<double> _travel = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.18, 0.82),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation(double overflow) {
    if (!mounted) return;
    if (overflow <= 0) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 0;
      return;
    }
    final seconds = (overflow / widget.speed).clamp(3.0, 30.0);
    final wanted = Duration(milliseconds: (seconds * 1000).round());
    if (_controller.isAnimating && _controller.duration == wanted) return;
    _controller.duration = wanted;
    _controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite) {
          return Text(widget.text, maxLines: 1, softWrap: false, style: style);
        }

        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final overflow = painter.width - constraints.maxWidth;

        // Starting a controller during build would mark the tree dirty while
        // it is being built.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _syncAnimation(overflow),
        );

        if (overflow <= 0) {
          return Text(widget.text, maxLines: 1, softWrap: false, style: style);
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _travel,
            builder: (context, child) => Transform.translate(
              offset: Offset(-overflow * _travel.value, 0),
              child: child,
            ),
            child: SizedBox(
              width: painter.width,
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                style: style,
              ),
            ),
          ),
        );
      },
    );
  }
}
