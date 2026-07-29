import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Renders the chat background image, optionally through a CRT fragment shader.
///
/// Only the background is distorted. Chat text is deliberately left outside
/// this widget: barrel distortion bows glyph baselines and softens stems,
/// which costs readability for a effect meant to sit in the background.
///
/// Falls back to a plain [BoxFit.cover] image whenever [enabled] is false, the
/// shader has not finished loading, or the platform failed to compile it, so
/// an unsupported backend degrades to today's appearance rather than a blank
/// screen.
class CrtBackground extends StatefulWidget {
  /// The background image to render.
  final ImageProvider image;

  /// Whether to apply the CRT treatment.
  final bool enabled;

  /// Master strength in `[0, 1]`, scaling every artifact together.
  final double intensity;

  const CrtBackground({
    super.key,
    required this.image,
    required this.enabled,
    required this.intensity,
  });

  @override
  State<CrtBackground> createState() => _CrtBackgroundState();
}

class _CrtBackgroundState extends State<CrtBackground>
    with SingleTickerProviderStateMixin {
  static ui.FragmentProgram? _program;
  static bool _programFailed = false;

  ui.FragmentShader? _shader;

  ui.Image? _resolved;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  late final Ticker _ticker;
  final CrtClock _clock = CrtClock();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _clock.seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    });
    _loadProgram();
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(CrtBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _resolveImage();
    }
    _syncTicker();
  }

  /// The scanline roll only needs a ticker while the effect is on screen.
  void _syncTicker() {
    final wants = widget.enabled && !_programFailed;
    if (wants && !_ticker.isActive) {
      _ticker.start();
    } else if (!wants && _ticker.isActive) {
      _ticker.stop();
    }
  }

  Future<void> _loadProgram() async {
    if (_programFailed) return;
    if (_program == null) {
      try {
        _program = await ui.FragmentProgram.fromAsset('shaders/crt.frag');
      } catch (e) {
        // Older or software backends may reject the program. Fall back rather
        // than leaving the background blank.
        _programFailed = true;
        debugPrint('CRT shader unavailable, falling back to plain image: $e');
        if (mounted) setState(() {});
        return;
      }
    }
    if (!mounted) return;
    setState(() => _shader = _program!.fragmentShader());
  }

  void _resolveImage() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;

    if (_listener != null) _stream?.removeListener(_listener!);

    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) {
          info.image.dispose();
          return;
        }
        setState(() {
          _resolved?.dispose();
          _resolved = info.image;
        });
      },
      onError: (error, stack) {
        debugPrint('CRT background image failed to resolve: $error');
      },
    );

    _stream = stream..addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _ticker.dispose();
    _clock.dispose();
    _shader?.dispose();
    _resolved?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final image = _resolved;

    if (!widget.enabled || shader == null || image == null || _programFailed) {
      return Image(image: widget.image, fit: BoxFit.cover);
    }

    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        willChange: true,
        painter: CrtPainter(
          repaint: _clock,
          clock: _clock,
          shader: shader,
          image: image,
          intensity: widget.intensity,
        ),
      ),
    );
  }
}

/// Frame clock for the scanline roll.
class CrtClock extends ChangeNotifier {
  double _seconds = 0;

  double get seconds => _seconds;

  set seconds(double value) {
    if (_seconds == value) return;
    _seconds = value;
    notifyListeners();
  }
}

/// Paints [image] through the CRT [shader].
class CrtPainter extends CustomPainter {
  final CrtClock clock;
  final ui.FragmentShader shader;
  final ui.Image image;
  final double intensity;

  CrtPainter({
    required Listenable repaint,
    required this.clock,
    required this.shader,
    required this.image,
    required this.intensity,
  }) : super(repaint: repaint);

  /// Screen UV to texture UV for [BoxFit.cover], as `(scale, offset)` pairs.
  ///
  /// The shader samples the texture directly, so the fit that [BoxFit.cover]
  /// would normally apply has to be expressed as a UV transform. The larger
  /// axis is cropped symmetrically about the centre.
  static ({double scaleX, double scaleY, double offsetX, double offsetY})
  coverMapping(Size layer, Size texture) {
    if (layer.isEmpty || texture.isEmpty) {
      return (scaleX: 1, scaleY: 1, offsetX: 0, offsetY: 0);
    }

    final layerAspect = layer.width / layer.height;
    final textureAspect = texture.width / texture.height;

    if (textureAspect > layerAspect) {
      // Texture is wider: crop its sides.
      final scaleX = layerAspect / textureAspect;
      return (
        scaleX: scaleX,
        scaleY: 1.0,
        offsetX: (1.0 - scaleX) / 2.0,
        offsetY: 0.0,
      );
    }
    // Texture is taller: crop top and bottom.
    final scaleY = textureAspect / layerAspect;
    return (
      scaleX: 1.0,
      scaleY: scaleY,
      offsetX: 0.0,
      offsetY: (1.0 - scaleY) / 2.0,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final map = coverMapping(
      size,
      Size(image.width.toDouble(), image.height.toDouble()),
    );

    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, map.scaleX)
      ..setFloat(3, map.scaleY)
      ..setFloat(4, map.offsetX)
      ..setFloat(5, map.offsetY)
      ..setFloat(6, intensity.clamp(0.0, 1.0))
      ..setFloat(7, clock.seconds)
      ..setImageSampler(0, image);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant CrtPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.intensity != intensity ||
        oldDelegate.shader != shader;
  }
}
