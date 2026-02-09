import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import 'message_bubble.dart';
import 'effects_overlay.dart';

class ChatMessagesList extends StatelessWidget {
  final ScrollController scrollController;
  final TransformationController transformationController;

  const ChatMessagesList({
    super.key,
    required this.scrollController,
    required this.transformationController,
  });

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
                // Little handle bar
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

                // THE ICON ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. COPY
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

                    // 2. EDIT
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

                    // 3. REGENERATE
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

                    // 4. DELETE
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
                    itemCount: messages.length,
                    padding: const EdgeInsets.only(bottom: 120),
                    itemBuilder: (context, index) {
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
}
