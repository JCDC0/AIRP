import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Wraps the chat surface in a CRT post-process.
///
/// Rasterises the whole subtree (background, particles and text) every frame
/// and runs it through `shaders/crt.frag`, so glyphs pick up the same smear,
/// bloom and scanlines as everything else.
///
/// Deliberately does NOT use [SnapshotWidget]. That widget caches its raster
/// and its painter's `notifyListeners` repaints "re-using the same raster", so
/// live content freezes at whatever it looked like when the snapshot was
/// taken. Children behind a [RepaintBoundary] (the message list and the
/// effects overlay both are) never mark the snapshot dirty, so it is never
/// regenerated. Re-rasterising per frame is the cost of a live post-process.
///
/// Falls back to painting the child untouched whenever [enabled] is false or
/// the platform could not compile the shader.
class CrtScreen extends StatefulWidget {
  /// The surface to treat.
  final Widget child;

  /// Whether to apply the CRT post-process.
  final bool enabled;

  /// Master strength in `[0, 1]` for the analog artifacts.
  final double intensity;

  /// Visibility of the horizontal scanlines in `[0, 1]`, independent of
  /// [intensity] so the raster structure can be dialled out on its own.
  final double scanlines;

  /// Whether to apply the barrel (fisheye) warp.
  final bool fisheye;

  const CrtScreen({
    super.key,
    required this.child,
    required this.enabled,
    required this.intensity,
    required this.scanlines,
    required this.fisheye,
  });

  @override
  State<CrtScreen> createState() => _CrtScreenState();
}

class _CrtScreenState extends State<CrtScreen>
    with SingleTickerProviderStateMixin {
  static ui.FragmentProgram? _program;
  static bool _programFailed = false;

  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  final _CrtClock _clock = _CrtClock();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _clock.seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    });
    _loadProgram();
  }

  @override
  void didUpdateWidget(CrtScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
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
    setState(() => _shader = _program!.fragmentShader());
    _syncTicker();
  }

  /// The clock drives the scanline roll and the grain, and also forces the
  /// per-frame re-rasterise that keeps the content live.
  void _syncTicker() {
    final active = widget.enabled && _shader != null && !_programFailed;
    if (active && !_ticker.isActive) {
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (!widget.enabled || shader == null || _programFailed) {
      return widget.child;
    }

    return _CrtEffect(
      shader: shader,
      clock: _clock,
      intensity: widget.intensity,
      scanlines: widget.scanlines,
      fisheye: widget.fisheye,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      child: widget.child,
    );
  }
}

/// Frame clock for the roll, the grain, and the per-frame re-rasterise.
class _CrtClock extends ChangeNotifier {
  double _seconds = 0;

  double get seconds => _seconds;

  set seconds(double value) {
    if (_seconds == value) return;
    _seconds = value;
    notifyListeners();
  }
}

class _CrtEffect extends SingleChildRenderObjectWidget {
  final ui.FragmentShader shader;
  final _CrtClock clock;
  final double intensity;
  final double scanlines;
  final bool fisheye;
  final double devicePixelRatio;

  const _CrtEffect({
    required this.shader,
    required this.clock,
    required this.intensity,
    required this.scanlines,
    required this.fisheye,
    required this.devicePixelRatio,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCrtEffect(
      shader: shader,
      clock: clock,
      intensity: intensity,
      scanlines: scanlines,
      fisheye: fisheye,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderCrtEffect renderObject) {
    renderObject
      ..shader = shader
      ..clock = clock
      ..intensity = intensity
      ..scanlines = scanlines
      ..fisheye = fisheye
      ..devicePixelRatio = devicePixelRatio;
  }
}

/// Rasterises its child every paint and draws the result through the shader.
class _RenderCrtEffect extends RenderProxyBox {
  _RenderCrtEffect({
    required ui.FragmentShader shader,
    required _CrtClock clock,
    required double intensity,
    required double scanlines,
    required bool fisheye,
    required double devicePixelRatio,
  }) : _shader = shader,
       _clock = clock,
       _intensity = intensity,
       _scanlines = scanlines,
       _fisheye = fisheye,
       _devicePixelRatio = devicePixelRatio;

  ui.FragmentShader _shader;
  set shader(ui.FragmentShader value) {
    if (_shader == value) return;
    _shader = value;
    markNeedsPaint();
  }

  _CrtClock _clock;
  set clock(_CrtClock value) {
    if (_clock == value) return;
    if (attached) _clock.removeListener(markNeedsPaint);
    _clock = value;
    if (attached) _clock.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _intensity;
  set intensity(double value) {
    if (_intensity == value) return;
    _intensity = value;
    markNeedsPaint();
  }

  double _scanlines;
  set scanlines(double value) {
    if (_scanlines == value) return;
    _scanlines = value;
    markNeedsPaint();
  }

  bool _fisheye;
  set fisheye(bool value) {
    if (_fisheye == value) return;
    _fisheye = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _clock.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _clock.removeListener(markNeedsPaint);
    super.detach();
  }

  /// Paints the child into a detached layer and rasterises it.
  ///
  /// Mirrors the framework's own `_paintAndDetachToImage`, including the
  /// protected-member ignore, which is how `SnapshotWidget` does this.
  ui.Image? _rasterizeChild() {
    final OffsetLayer offsetLayer = OffsetLayer();
    final PaintingContext context = PaintingContext(
      offsetLayer,
      Offset.zero & size,
    );
    super.paint(context, Offset.zero);
    // ignore: invalid_use_of_protected_member
    context.stopRecordingIfNeeded();

    // A platform view anywhere in the subtree cannot be rasterised.
    if (!offsetLayer.supportsRasterization()) {
      offsetLayer.dispose();
      return null;
    }

    final ui.Image image = offsetLayer.toImageSync(
      Offset.zero & size,
      pixelRatio: _devicePixelRatio,
    );
    offsetLayer.dispose();
    return image;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty) return;

    final ui.Image? image = _rasterizeChild();
    if (image == null) {
      // Could not rasterise this frame; show the child untreated.
      super.paint(context, offset);
      return;
    }

    _shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, _intensity.clamp(0.0, 1.0))
      ..setFloat(3, _scanlines.clamp(0.0, 1.0))
      ..setFloat(4, _fisheye ? 1.0 : 0.0)
      ..setFloat(5, _clock.seconds)
      ..setImageSampler(0, image);

    final Canvas canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawRect(Offset.zero & size, Paint()..shader = _shader);
    canvas.restore();

    image.dispose();
  }
}
