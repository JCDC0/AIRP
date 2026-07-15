import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/scale_provider.dart';
import '../utils/constants.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_messages_list.dart';
import '../widgets/chat_input_area.dart';
import '../providers/search_provider.dart';
import '../widgets/chat_search_bar.dart';
import '../widgets/summarize_drawer.dart';
import 'package:flutter/services.dart';

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
  late AnimationController _searchBarController;
  late AnimationController _summaryDrawerController;
  late Animation<Offset> _drawerSlideAnimation;
  late Animation<Offset> _endDrawerSlideAnimation;
  late Animation<Offset> _searchBarSlideAnimation;
  late Animation<Offset> _summarySlideAnimation;

  bool _isZoomed = false;
  bool _isZoomMode = false;
  late AnimationController _zoomBorderController;
  String? _previousSessionId;
  int _settingsDrawerVersion = 0;

  ChatSearchProvider? _searchProvider;
  final TextEditingController _searchFieldController = TextEditingController();
  final FocusNode _searchFieldFocus = FocusNode();
  final GlobalKey<State> _messagesListKey = GlobalKey<State>();

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

    _searchProvider = ChatSearchProvider();
    _searchFieldController.addListener(_onSearchFieldChanged);
    _searchFieldFocus.addListener(_onSearchFocusChanged);
    _searchProvider!.addListener(_onSearchCurrentMatchChanged);

    _searchBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _searchBarSlideAnimation =
        Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _searchBarController, curve: Curves.easeOut),
        );

    _summaryDrawerController = AnimationController(
      vsync: this,
      duration: AnimationDefaults.drawerDuration,
    );
    _summarySlideAnimation =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _summaryDrawerController,
            curve: Curves.easeOut,
          ),
        );

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
    _summaryDrawerController.dispose();
    _searchFieldController.removeListener(_onSearchFieldChanged);
    _searchFieldController.dispose();
    _searchFieldFocus.removeListener(_onSearchFocusChanged);
    _searchFieldFocus.dispose();
    _searchProvider?.removeListener(_onSearchCurrentMatchChanged);
    _searchProvider?.dispose();
    _searchBarController.dispose();
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

  void _toggleSummaryDrawer() {
    if (_summaryDrawerController.isDismissed) {
      _summaryDrawerController.forward();
    } else {
      _summaryDrawerController.reverse();
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
    if (_summaryDrawerController.isCompleted ||
        _summaryDrawerController.isAnimating ||
        _summaryDrawerController.value > 0) {
      _summaryDrawerController.reverse();
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

  void _openSearch() {
    if (_searchProvider == null) return;
    _searchProvider!.open();
    _searchBarController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFieldFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchProvider?.close();
    _searchFieldController.clear();
    _searchFieldFocus.unfocus();
    _searchBarController.reverse();
  }

  /// Recompute matches when the message list changes while the find bar is
  /// open (e.g. new messages arrive during/after a search).
  void _onSearchChanged() {
    if (_searchProvider == null || !_searchProvider!.isOpen) return;
    final chat = Provider.of<ChatProvider>(context, listen: false);
    _searchProvider!.recompute(chat.messages);
    if (_searchProvider!.hasMatches) {
      _scrollToCurrentMatch();
    }
  }

  void _onSearchFieldChanged() {
    if (_searchProvider == null) return;
    final chat = Provider.of<ChatProvider>(context, listen: false);
    _searchProvider!.setQuery(_searchFieldController.text, chat.messages);
    if (_searchProvider!.hasMatches) {
      _scrollToCurrentMatch();
    }
  }

  void _onSearchFocusChanged() {
    if (!_searchFieldFocus.hasFocus && _searchFieldController.text.isEmpty) {
      _searchProvider?.close();
    }
  }

  void _scrollToCurrentMatch() {
    final idx = _searchProvider?.currentMatchMessageIndex;
    if (idx == null) return;
    final state = _messagesListKey.currentState as ChatMessagesListState?;
    state?.scrollToMessage(idx);
  }

  /// Callback for SearchProvider when current-match index changes (next/prev).
  void _onSearchCurrentMatchChanged() {
    _scrollToCurrentMatch();
  }

  /// Handler bound to the next-match intent (Ctrl/Cmd+G).
  void _searchNext() {
    if (_searchProvider == null || !_searchProvider!.hasMatches) return;
    _searchProvider!.next();
  }

  /// Handler bound to the previous-match intent (Shift+Ctrl/Cmd+G).
  void _searchPrevious() {
    if (_searchProvider == null || !_searchProvider!.hasMatches) return;
    _searchProvider!.previous();
  }

  void _resetZoom() {
    final controller = AnimationController(
      vsync: this,
      duration: AnimationDefaults.zoomResetDuration,
    );
    final animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    animation.addListener(() {
      _transformationController.value = animation.value;
    });
    controller.forward().then((_) => controller.dispose());
  }

  void _toggleZoomMode(bool enableLoadingAnimation) {
    setState(() {
      _isZoomMode = !_isZoomMode;
    });
    if (_isZoomMode) {
      if (enableLoadingAnimation) {
        _zoomBorderController.repeat();
      } else {
        _zoomBorderController.stop();
      }
    } else {
      _zoomBorderController.stop();
      _resetZoom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final bool isDesktop = scaleProvider.deviceType == DeviceType.desktop;

    if (!vfxProvider.enableLoadingAnimation &&
        _zoomBorderController.isAnimating) {
      _zoomBorderController.stop();
    }

    if (chatProvider.currentSessionId != _previousSessionId) {
      _previousSessionId = chatProvider.currentSessionId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    // Recompute find-bar matches + follow current match when messages change.
    if (_searchProvider != null && _searchProvider!.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onSearchChanged());
    }

    // On desktop, zoom is controlled by _isZoomMode toggle.
    // On mobile, zoom is always enabled (default behavior).
    final bool zoomEnabled = isDesktop ? _isZoomMode : true;

    // Determine zoom button visibility
    final bool showZoomButton = isDesktop ? true : _isZoomed;
    final double fabSize = 40 * scaleProvider.iconScale;
    final double fabIconSize = 20 * scaleProvider.iconScale;

    return ChangeNotifierProvider<ChatSearchProvider>.value(
      value: _searchProvider!,
      child: Builder(
        builder: (context) {
          return Shortcuts(
            shortcuts: <ShortcutActivator, Intent>{
              const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                  _OpenSearchIntent(),
              const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                  _OpenSearchIntent(),
              const SingleActivator(LogicalKeyboardKey.keyG, control: true):
                  _SearchNextIntent(),
              const SingleActivator(LogicalKeyboardKey.keyG, meta: true):
                  _SearchNextIntent(),
              const SingleActivator(
                LogicalKeyboardKey.keyG,
                control: true,
                shift: true,
              ): _SearchPrevIntent(),
              const SingleActivator(
                LogicalKeyboardKey.keyG,
                meta: true,
                shift: true,
              ): _SearchPrevIntent(),
              const SingleActivator(
                LogicalKeyboardKey.keyG,
                control: true,
                alt: true,
              ): _SearchPrevIntent(),
              const SingleActivator(
                LogicalKeyboardKey.keyG,
                meta: true,
                alt: true,
              ): _SearchPrevIntent(),
              const SingleActivator(LogicalKeyboardKey.escape):
                  _CloseSearchIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
                  onInvoke: (_) => _openSearch(),
                ),
                _SearchNextIntent: CallbackAction<_SearchNextIntent>(
                  onInvoke: (_) => _searchNext(),
                ),
                _SearchPrevIntent: CallbackAction<_SearchPrevIntent>(
                  onInvoke: (_) => _searchPrevious(),
                ),
                _CloseSearchIntent: CallbackAction<_CloseSearchIntent>(
                  onInvoke: (_) => _closeSearch(),
                ),
              },
              child: Focus(
                autofocus: true,
                child: Stack(
                  children: [
                    Scaffold(
                      backgroundColor: themeProvider.scaffoldBackgroundColor,
                      resizeToAvoidBottomInset: true,
                      drawer: null,
                      endDrawer: null,
                      appBar: ChatAppBar(
                        onOpenDrawer: _toggleDrawer,
                        onOpenEndDrawer: _toggleEndDrawer,
                        onOpenSearch: _openSearch,
                        onOpenSummary: _toggleSummaryDrawer,
                        systemFontSize: scaleProvider.systemFontSize,
                      ),
                      body: Stack(
                        children: [
                          ChatMessagesList(
                            key: _messagesListKey,
                            scrollController: _scrollController,
                            transformationController: _transformationController,
                            isZoomEnabled: zoomEnabled,
                          ),

                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ChatInputArea(
                              scrollController: _scrollController,
                            ),
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
                                      foregroundPainter:
                                          _isZoomMode &&
                                              isDesktop &&
                                              vfxProvider.enableLoadingAnimation
                                          ? _ZoomArcPainter(
                                              progress:
                                                  _zoomBorderController.value,
                                              color: themeProvider.textColor,
                                              enableBloom:
                                                  vfxProvider.enableBloom,
                                              bloomColor:
                                                  themeProvider.bloomGlowColor,
                                            )
                                          : null,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: themeProvider.inputFillColor,
                                      border: Border.all(
                                        color: themeProvider.textColor,
                                        width: 0.5,
                                      ),
                                      boxShadow: vfxProvider.enableBloom
                                          ? [
                                              BoxShadow(
                                                color: themeProvider
                                                    .bloomGlowColor
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 20,
                                                spreadRadius: 0,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: isDesktop
                                            ? () => _toggleZoomMode(
                                                vfxProvider
                                                    .enableLoadingAnimation,
                                              )
                                            : _resetZoom,
                                        customBorder: const CircleBorder(),
                                        child: Center(
                                          child: Icon(
                                            isDesktop
                                                ? (_isZoomMode
                                                      ? Icons.zoom_out_map
                                                      : Icons.zoom_in)
                                                : Icons.zoom_out_map,
                                            size: fabIconSize,
                                            color: themeProvider.textColor,
                                            shadows: vfxProvider.enableBloom
                                                ? [
                                                    Shadow(
                                                      color: themeProvider
                                                          .textColor
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                      blurRadius: 4,
                                                    ),
                                                    Shadow(
                                                      color: themeProvider
                                                          .bloomGlowColor
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
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
                          ),

                          // In-chat find bar (ctrl+F).
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _searchProvider!,
                              _searchBarController,
                            ]),
                            builder: (context, _) {
                              if (_searchProvider == null ||
                                  (!_searchProvider!.isOpen &&
                                      _searchBarController.isDismissed)) {
                                return const SizedBox.shrink();
                              }
                              return Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: SlideTransition(
                                  position: _searchBarSlideAnimation,
                                  child: ChatSearchBar(
                                    controller: _searchFieldController,
                                    focusNode: _searchFieldFocus,
                                    onClose: _closeSearch,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _drawerController,
                        _endDrawerController,
                        _summaryDrawerController,
                      ]),
                      builder: (context, child) {
                        final double opacity =
                            (_drawerController.value +
                                    _endDrawerController.value +
                                    _summaryDrawerController.value)
                                .clamp(0.0, 1.0) *
                            0.5;
                        return opacity > 0
                            ? GestureDetector(
                                onTap: _closeDrawers,
                                child: Container(
                                  color: Colors.black.withValues(
                                    alpha: opacity,
                                  ),
                                ), // Overlay always dark
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
                          child: SettingsDrawer(
                            resetVersion: _settingsDrawerVersion,
                          ),
                        ),
                      ),
                    ),

                    SlideTransition(
                      position: _summarySlideAnimation,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SummarizeDrawer(onClose: _closeDrawers),
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
                ),
              ),
            ),
          );
        },
      ),
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

/// Intent bound to opening the in-chat find bar (Ctrl/Cmd+F).
class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

/// Intent bound to jumping to the next find match (Ctrl/Cmd+G).
class _SearchNextIntent extends Intent {
  const _SearchNextIntent();
}

/// Intent bound to jumping to the previous find match
/// (Shift+Ctrl/Cmd+G or Alt+Ctrl/Cmd+G).
class _SearchPrevIntent extends Intent {
  const _SearchPrevIntent();
}

/// Intent bound to closing the find bar (Esc).
class _CloseSearchIntent extends Intent {
  const _CloseSearchIntent();
}
