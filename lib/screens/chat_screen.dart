import 'package:flutter/material.dart';
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
  String? _previousSessionId;
  int _settingsDrawerVersion = 0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onZoomChange);

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
    final animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: Matrix4.identity(),
        ).animate(
          CurvedAnimation(
            parent: AnimationController(
              vsync: this,
              duration: AnimationDefaults.zoomResetDuration,
            )..forward(),
            curve: Curves.easeOut,
          ),
        );

    animation.addListener(() {
      _transformationController.value = animation.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    if (chatProvider.currentSessionId != _previousSessionId) {
      _previousSessionId = chatProvider.currentSessionId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

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
            systemFontSize: Provider.of<ScaleProvider>(context).systemFontSize,
          ),
          body: Stack(
            children: [
              ChatMessagesList(
                scrollController: _scrollController,
                transformationController: _transformationController,
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
                top: _isZoomed ? 16.0 : -60.0,
                right: 16,
                child: SafeArea(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
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
                    child: FloatingActionButton.small(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      onPressed: _resetZoom,
                      child: Icon(
                        Icons.zoom_out_map,
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
