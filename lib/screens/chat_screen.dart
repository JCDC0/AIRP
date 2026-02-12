import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/scale_provider.dart';
import '../utils/constants.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_messages_list.dart';
import '../widgets/chat_input_area.dart';

/// The main screen of the application that manages the chat interface.
///
/// This screen coordinates the message list, input area, and the
/// side drawers for conversations and settings.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TransformationController _transformationController =
      TransformationController();

  late AnimationController _drawerController;
  late AnimationController _endDrawerController;
  late Animation<Offset> _drawerSlideAnimation;
  late Animation<Offset> _endDrawerSlideAnimation;

  bool _isZoomed = false;
  bool _isZoomMode = false;
  late AnimationController _zoomBorderController;
  String? _previousSessionId;
  int _settingsDrawerVersion = 0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onZoomChange);

    _zoomBorderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScaleProvider>(
        context,
        listen: false,
      ).initializeDeviceType(context);
    });

    _drawerController = AnimationController(
      vsync: this,
      duration: AnimationDefaults.drawerDuration,
    );
    _endDrawerController = AnimationController(
      vsync: this,
      duration: AnimationDefaults.drawerDuration,
    );

    _drawerSlideAnimation =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _drawerController, curve: Curves.easeOut),
        );

    _endDrawerSlideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _endDrawerController, curve: Curves.easeOut),
        );
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onZoomChange);
    _transformationController.dispose();
    _scrollController.dispose();
    _zoomBorderController.dispose();
    _drawerController.dispose();
    _endDrawerController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    if (_drawerController.isDismissed) {
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }
  }

  void _toggleEndDrawer() {
    if (_endDrawerController.isDismissed) {
      setState(() {
        _settingsDrawerVersion++;
      });
      _endDrawerController.forward();
    } else {
      _endDrawerController.reverse();
    }
  }

  void _closeDrawers() {
    if (_drawerController.isCompleted ||
        _drawerController.isAnimating ||
        _drawerController.value > 0) {
      _drawerController.reverse();
    }
    if (_endDrawerController.isCompleted ||
        _endDrawerController.isAnimating ||
        _endDrawerController.value > 0) {
      _endDrawerController.reverse();
    }
  }

  void _handleDrawerDragUpdate(DragUpdateDetails details) {
    _drawerController.value +=
        details.primaryDelta! / AnimationDefaults.drawerDragDivisor;
  }

  void _handleDrawerDragEnd(DragEndDetails details) {
    if (_drawerController.value > 0.5 ||
        details.primaryVelocity! > AnimationDefaults.drawerVelocityThreshold) {
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }
  }

  void _handleEndDrawerDragUpdate(DragUpdateDetails details) {
    _endDrawerController.value -=
        details.primaryDelta! / AnimationDefaults.endDrawerDragDivisor;
  }

  void _handleEndDrawerDragEnd(DragEndDetails details) {
    if (_endDrawerController.value > 0.5 ||
        details.primaryVelocity! < -AnimationDefaults.drawerVelocityThreshold) {
      _endDrawerController.forward();
    } else {
      _endDrawerController.reverse();
    }
  }

  void _onZoomChange() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale > 1.01 && !_isZoomed) {
      setState(() => _isZoomed = true);
    } else if (scale <= 1.01 && _isZoomed) {
      setState(() => _isZoomed = false);
    }
  }

  void _resetZoom() {
    final controller = AnimationController(
      vsync: this,
      duration: AnimationDefaults.zoomResetDuration,
    );
    final animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: Matrix4.identity(),
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: Curves.easeOut,
          ),
        );

    animation.addListener(() {
      _transformationController.value = animation.value;
    });
    controller.forward().then((_) => controller.dispose());
  }

  void _toggleZoomMode() {
    setState(() {
      _isZoomMode = !_isZoomMode;
    });
    if (_isZoomMode) {
      _zoomBorderController.repeat();
    } else {
      _zoomBorderController.stop();
      _resetZoom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final bool isDesktop = scaleProvider.deviceType == DeviceType.desktop;

    if (chatProvider.currentSessionId != _previousSessionId) {
      _previousSessionId = chatProvider.currentSessionId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    // On desktop, zoom is controlled by _isZoomMode toggle.
    // On mobile, zoom is always enabled (default behavior).
    final bool zoomEnabled = isDesktop ? _isZoomMode : true;

    // Determine zoom button visibility
    final bool showZoomButton = isDesktop ? true : _isZoomed;
    final double fabSize = 40 * scaleProvider.iconScale;
    final double fabIconSize = 20 * scaleProvider.iconScale;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          resizeToAvoidBottomInset: true,
          drawer: null,
          endDrawer: null,
          appBar: ChatAppBar(
            onOpenDrawer: _toggleDrawer,
            onOpenEndDrawer: _toggleEndDrawer,
            systemFontSize: scaleProvider.systemFontSize,
          ),
          body: Stack(
            children: [
              ChatMessagesList(
                scrollController: _scrollController,
                transformationController: _transformationController,
                isZoomEnabled: zoomEnabled,
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ChatInputArea(scrollController: _scrollController),
              ),

              AnimatedPositioned(
                duration: AnimationDefaults.zoomButtonDuration,
                curve: Curves.easeOutCubic,
                top: showZoomButton ? 16.0 : -60.0,
                right: 16,
                child: SafeArea(
                  child: SizedBox(
                    width: fabSize,
                    height: fabSize,
                    child: AnimatedBuilder(
                      animation: _zoomBorderController,
                      builder: (context, child) {
                        return CustomPaint(
                          foregroundPainter: _isZoomMode && isDesktop && themeProvider.enableLoadingAnimation
                              ? _ZoomArcPainter(
                                  progress: _zoomBorderController.value,
                                  color: Colors.white,
                                  enableBloom: themeProvider.enableBloom,
                                  bloomColor: themeProvider.appThemeColor,
                                )
                              : null,
                          child: child,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: themeProvider.enableBloom
                              ? [
                                  BoxShadow(
                                    color: themeProvider.appThemeColor.withOpacity(
                                      0.6,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : [],
                        ),
                        child: SizedBox(
                          width: fabSize,
                          height: fabSize,
                          child: FloatingActionButton(
                            mini: true,
                            shape: const CircleBorder(),
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            onPressed: isDesktop ? _toggleZoomMode : _resetZoom,
                            child: Icon(
                              isDesktop
                                  ? (_isZoomMode ? Icons.zoom_out_map : Icons.zoom_in)
                                  : Icons.zoom_out_map,
                              size: fabIconSize,
                              shadows: themeProvider.enableBloom
                                  ? [
                                      Shadow(
                                        color: Colors.white.withOpacity(0.7),
                                        blurRadius: 4,
                                      ),
                                      Shadow(
                                        color: themeProvider.appThemeColor
                                            .withOpacity(0.7),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        AnimatedBuilder(
          animation: Listenable.merge([
            _drawerController,
            _endDrawerController,
          ]),
          builder: (context, child) {
            final double opacity =
                (_drawerController.value + _endDrawerController.value).clamp(
                  0.0,
                  1.0,
                ) *
                0.5;
            return opacity > 0
                ? GestureDetector(
                    onTap: _closeDrawers,
                    child: Container(color: Colors.black.withOpacity(opacity)),
                  )
                : const SizedBox.shrink();
          },
        ),

        SlideTransition(
          position: _drawerSlideAnimation,
          child: GestureDetector(
            onHorizontalDragUpdate: _handleDrawerDragUpdate,
            onHorizontalDragEnd: _handleDrawerDragEnd,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConversationDrawer(onClose: _closeDrawers),
            ),
          ),
        ),

        SlideTransition(
          position: _endDrawerSlideAnimation,
          child: GestureDetector(
            onHorizontalDragUpdate: _handleEndDrawerDragUpdate,
            onHorizontalDragEnd: _handleEndDrawerDragEnd,
            child: Align(
              alignment: Alignment.centerRight,
              child: SettingsDrawer(resetVersion: _settingsDrawerVersion),
            ),
          ),
        ),

        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 20,
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) _toggleDrawer();
            },
            behavior: HitTestBehavior.translucent,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 20,
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < 0) _toggleEndDrawer();
            },
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

/// Draws a single animated arc around the circular zoom button.
class _ZoomArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool enableBloom;
  final Color bloomColor;

  _ZoomArcPainter({
    required this.progress,
    required this.color,
    required this.enableBloom,
    required this.bloomColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 2.0;
    const double inset = strokeWidth / 2;
    final Rect arcRect = Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth);

    final Paint arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Single arc: 90 degrees, rotating
    final double startAngle = progress * 2 * math.pi;
    const double sweepAngle = math.pi / 2;

    if (enableBloom) {
      final Paint bloomPaint = Paint()
        ..color = bloomColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, bloomPaint);
    }

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _ZoomArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
