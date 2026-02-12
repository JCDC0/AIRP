import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import 'message_bubble.dart';
import 'effects_overlay.dart';

/// A widget that displays a list of chat messages with interactive capabilities.
///
/// This widget handles rendering the message bubbles, background effects,
/// and the long-press menu for message actions like copy, edit, and delete.
class ChatMessagesList extends StatelessWidget {
  /// Controller for managing the scroll position of the message list.
  final ScrollController scrollController;

  /// Controller for handling zoom and pan transformations.
  final TransformationController transformationController;

  /// Whether zoom/pan is enabled on the InteractiveViewer.
  final bool isZoomEnabled;

  const ChatMessagesList({
    super.key,
    required this.scrollController,
    required this.transformationController,
    this.isZoomEnabled = true,
  });

  /// Displays a bottom sheet with options for a specific message.
  void _showMessageOptions(BuildContext context, int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final msg = chatProvider.messages[index];
    final bool isLastMessage = index == chatProvider.messages.length - 1;
    final bool useBloom = themeProvider.enableBloom;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bottom sheet handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: useBloom
                        ? [
                            const BoxShadow(
                              color: Colors.white24,
                              blurRadius: 6,
                            ),
                          ]
                        : [],
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMenuIcon(
                      icon: Icons.copy,
                      label: "Copy",
                      color: themeProvider.appThemeColor,
                      useBloom: useBloom,
                      onTap: () {
                        Navigator.pop(context);
                        Clipboard.setData(ClipboardData(text: msg.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Copied!"),
                            duration: Duration(milliseconds: 800),
                          ),
                        );
                      },
                    ),

                    _buildMenuIcon(
                      icon: Icons.edit,
                      label: "Edit",
                      color: Colors.orangeAccent,
                      useBloom: useBloom,
                      onTap: () {
                        Navigator.pop(context);
                        _showEditDialog(context, index);
                      },
                    ),

                    Opacity(
                      opacity: isLastMessage ? 1.0 : 0.3,
                      child: _buildMenuIcon(
                        icon: Icons.refresh,
                        label: "Retry",
                        color: Colors.greenAccent,
                        useBloom: useBloom,
                        onTap: isLastMessage
                            ? () {
                                Navigator.pop(context);
                                _confirmRegenerate(context, index);
                              }
                            : null,
                      ),
                    ),

                    _buildMenuIcon(
                      icon: Icons.delete,
                      label: "Delete",
                      color: Colors.redAccent,
                      useBloom: useBloom,
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDeleteMessage(context, index);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuIcon({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool useBloom = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
          ),
          icon: Icon(
            icon,
            color: color,
            size: 36,
            shadows: useBloom ? [Shadow(color: color, blurRadius: 10)] : [],
          ),
          onPressed: onTap,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            shadows: useBloom ? [Shadow(color: color, blurRadius: 8)] : [],
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final TextEditingController editController = TextEditingController(
      text: chatProvider.messages[index].text,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          "Edit Message",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: editController,
          maxLines: null,
          style: const TextStyle(color: Colors.white70),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.black26,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              chatProvider.editMessage(index, editController.text);
              Navigator.pop(context);
            },
            child: Text(
              "Save",
              style: TextStyle(color: themeProvider.appThemeColor),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMessage(BuildContext context, int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Delete Message?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              chatProvider.deleteMessage(index);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Message deleted"),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(milliseconds: 1000),
                ),
              );
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _confirmRegenerate(BuildContext context, int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Regenerate?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will delete this message and all subsequent history, then retry the generation.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.greenAccent),
            onPressed: () {
              Navigator.pop(context);
              chatProvider.regenerateResponse(index);
            },
            child: const Text(
              "Regenerate",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final messages = chatProvider.messages;

    return InteractiveViewer(
      transformationController: transformationController,
      scaleEnabled: isZoomEnabled,
      panEnabled: isZoomEnabled,
      minScale: 1.0,
      maxScale: 5.0,
      child: Stack(
        children: [
          if (themeProvider.backgroundImagePath != null)
            Positioned.fill(
              child: Image(
                image: themeProvider.currentImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          if (themeProvider.backgroundImagePath != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(
                  (themeProvider.backgroundOpacity * 255).round(),
                ),
              ),
            ),

          Positioned.fill(
            child: EffectsOverlay(
              showMotes: themeProvider.enableMotes,
              showRain: themeProvider.enableRain,
              showFireflies: themeProvider.enableFireflies,
              effectColor: themeProvider.appThemeColor,
              motesDensity: themeProvider.motesDensity.toDouble(),
              rainIntensity: themeProvider.rainIntensity.toDouble(),
              firefliesCount: themeProvider.firefliesCount.toDouble(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: messages.length + (_showTypingIndicator(chatProvider, themeProvider) ? 1 : 0),
                    padding: const EdgeInsets.only(bottom: 120),
                    itemBuilder: (context, index) {
                      // Show typing indicator as the last item
                      if (_showTypingIndicator(chatProvider, themeProvider) && index == messages.length) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: themeProvider.aiBubbleColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                  bottomRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(4),
                                ),
                                boxShadow: themeProvider.enableBloom
                                    ? [
                                        BoxShadow(
                                          color: themeProvider.appThemeColor.withOpacity(0.2),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: const _TypingDots(),
                            ),
                          ),
                        );
                      }

                      return MessageBubble(
                        msg: messages[index],
                        themeProvider: themeProvider,
                        onLongPress: () => _showMessageOptions(context, index),
                        onCopy: () {
                          Clipboard.setData(
                            ClipboardData(text: messages[index].text),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Copied!"),
                              duration: Duration(milliseconds: 600),
                            ),
                          );
                        },
                        onEdit: () => _showEditDialog(context, index),
                        onRegenerate: () => _confirmRegenerate(context, index),
                        onDelete: () => _confirmDeleteMessage(context, index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns true when typing indicator should be shown:
  /// Loading is active, animations are disabled, and no AI response text yet.
  bool _showTypingIndicator(ChatProvider chatProvider, ThemeProvider themeProvider) {
    if (!chatProvider.isLoading || themeProvider.enableLoadingAnimation) return false;
    // Show the dots when waiting for response (last message is empty AI message or user message)
    final messages = chatProvider.messages;
    if (messages.isEmpty) return true;
    final last = messages.last;
    // If last message is still the user's, API hasn't created AI message yet
    if (last.isUser) return true;
    // If AI message exists but is empty, still waiting for tokens
    return last.text.isEmpty;
  }
}

/// Animated three bouncing dots typing indicator.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by 0.2
            final double delay = i * 0.2;
            final double t = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            // Bounce: 0→1→0 over the cycle
            final double bounce = (t < 0.5) ? (t * 2) : (2 - t * 2);
            final double offset = -4.0 * bounce;

            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
