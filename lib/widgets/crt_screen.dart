import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Wraps the chat surface in a CRT post-process.
///
/// Unlike a background-only treatment, this rasterises the whole subtree
/// (background, particles and text) via [SnapshotWidget] and runs the result
/// through `shaders/crt.frag`, so glyphs pick up the same smear, bloom and
/// scanlines as everything else. That fuzz is the point of the effect;
/// curvature is capped low in the shader so it does not read as a fisheye.
///
/// Costs a full-surface rasterise per frame while the child animates, which is
/// inherent to any full-screen post-process. Falls back to painting the child
/// untouched whenever [enabled] is false, the shader has not loaded, or the
/// platform could not compile it.
class CrtScreen extends StatefulWidget {
  /// The surface to treat.
  final Widget child;

  /// Whether to apply the CRT post-process.
  final bool enabled;

  /// Master strength in `[0, 1]`, scaling every artifact together.
  final double intensity;

  const CrtScreen({
    super.key,
    required this.child,
    required this.enabled,
    required this.intensity,
  });

  @override
  State<CrtScreen> createState() => _CrtScreenState();
}

class _CrtScreenState extends State<CrtScreen>
    with SingleTickerProviderStateMixin {
  static ui.FragmentProgram? _program;
  static bool _programFailed = false;

  final SnapshotController _controller = SnapshotController();
  CrtSnapshotPainter? _painter;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _painter?.time =
          elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    });
    _loadProgram();
  }

  @override
  void didUpdateWidget(CrtScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intensity != widget.intensity) {
      _painter?.intensity = widget.intensity;
    }
    _sync();
  }

  Future<void> _loadProgram() async {
    if (_programFailed) return;
    if (_program == null) {
      try {
        _program = await ui.FragmentProgram.fromAsset('shaders/crt.frag');
      } catch (e) {
        // Software or older backends may reject the program. Degrade to an
        // untreated surface rather than a blank one.
        _programFailed = true;
        debugPrint('CRT shader unavailable, rendering untreated: $e');
        if (mounted) setState(() {});
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _painter = CrtSnapshotPainter(
        shader: _program!.fragmentShader(),
        intensity: widget.intensity,
      );
    });
    _sync();
  }

  /// Snapshotting and the roll ticker both run only while the effect is live.
  void _sync() {
    final active = widget.enabled && _painter != null && !_programFailed;
    _controller.allowSnapshotting = active;
    if (active && !_ticker.isActive) {
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    _painter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = _painter;
    if (!widget.enabled || painter == null || _programFailed) {
      return widget.child;
    }

    _controller.allowSnapshotting = true;
    return SnapshotWidget(
      controller: _controller,
      // The chat surface is pure Flutter, but stay permissive so a platform
      // view anywhere in the tree degrades instead of throwing.
      mode: SnapshotMode.permissive,
      painter: painter,
      child: widget.child,
    );
  }
}

/// Paints a rasterised snapshot of the chat surface through the CRT shader.
class CrtSnapshotPainter extends SnapshotPainter {
  final ui.FragmentShader shader;

  CrtSnapshotPainter({required this.shader, required double intensity})
      : _intensity = intensity;

  double _time = 0;
  double _intensity;

  /// Elapsed seconds, driving the scanline roll and the grain.
  set time(double value) {
    if (_time == value) return;
    _time = value;
    notifyListeners();
  }

  /// Master strength in `[0, 1]`.
  set intensity(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_intensity == clamped) return;
    _intensity = clamped;
    notifyListeners();
  }

  void _draw(Canvas canvas, Offset offset, Size size, ui.Image image) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, _intensity.clamp(0.0, 1.0))
      ..setFloat(3, _time)
      ..setImageSampler(0, image);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) {
    _draw(context.canvas, offset, size, image);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) {
    // Snapshotting is unavailable this frame. Paint the child untreated.
    painter(context, offset);
  }

  @override
  bool shouldRepaint(covariant CrtSnapshotPainter oldPainter) {
    return oldPainter.shader != shader ||
        oldPainter._intensity != _intensity ||
        oldPainter._time != _time;
  }

  @override
  void dispose() {
    shader.dispose();
    super.dispose();
  }
}
