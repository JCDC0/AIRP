import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_messages_list.dart';
import '../widgets/chat_input_area.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TransformationController _transformationController = TransformationController();
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onZoomChange);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onZoomChange);
    _transformationController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    final animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      )..forward(),
      curve: Curves.easeOut,
    ));

    animation.addListener(() {
      _transformationController.value = animation.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      resizeToAvoidBottomInset: true, 
      drawer: const ConversationDrawer(),
      endDrawer: const SettingsDrawer(),
      appBar: const ChatAppBar(),
      body: Stack(
        children: [
          // 1. ZOOMABLE CONTENT (Chat History + Background)
          // Note: ChatMessagesList handles the InteractiveViewer internally now?
          // Wait, in my extraction I put InteractiveViewer inside ChatMessagesList.
          // But EffectsOverlay needs to be *inside* the zoomable area if we want effects to zoom?
          // In the original code:
          /*
          InteractiveViewer(
            child: Stack(
              children: [
                Image...,
                Container(color...),
                EffectsOverlay...,
                SafeArea(Column(ListView...))
              ]
            )
          )
          */
          // My ChatMessagesList extraction included InteractiveViewer and the Background/Effects?
          // Let's check ChatMessagesList content.
          // It has InteractiveViewer -> Stack -> [Image, Container, SafeArea(ListView)].
          // It missed EffectsOverlay! I need to add EffectsOverlay to ChatMessagesList or pass it in.
          // Or I can wrap ChatMessagesList with EffectsOverlay in ChatScreen?
          // No, EffectsOverlay was *under* the text but *over* the background.
          
          // I should probably update ChatMessagesList to include EffectsOverlay.
          // But EffectsOverlay depends on ThemeProvider, which ChatMessagesList has access to.
          // So I will update ChatMessagesList to include EffectsOverlay.
          
          ChatMessagesList(
            scrollController: _scrollController,
            transformationController: _transformationController,
          ),

          // 2. FIXED INPUT AREA (Stays at bottom, doesn't zoom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ChatInputArea(scrollController: _scrollController),
          ),

          // 3. ANIMATED ZOOM RESET BUTTON
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
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
                            color: themeProvider.appThemeColor.withOpacity(0.6),
                            blurRadius: 20,
                            spreadRadius: 0,
                          )
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
                              color: themeProvider.appThemeColor.withOpacity(0.7),
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
    );
  }
}
