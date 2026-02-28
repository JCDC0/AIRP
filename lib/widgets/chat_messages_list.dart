import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
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
      backgroundColor: themeProvider.surfaceColor,
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
                            BoxShadow(
                    color: themeProvider.faintestColor,
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
                      color: themeProvider.textColor,
                      themeProvider: themeProvider,
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
                      themeProvider: themeProvider,
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
                        themeProvider: themeProvider,
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
                      themeProvider: themeProvider,
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
    required ThemeProvider themeProvider,
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
            color: themeProvider.subtitleColor,
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
        backgroundColor: themeProvider.dropdownColor,
        title: Text(
          "Edit Message",
          style: TextStyle(color: themeProvider.textColor),
        ),
        content: TextField(
          controller: editController,
          maxLines: null,
          style: TextStyle(color: themeProvider.subtitleColor),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: themeProvider.containerFillColor,
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
              style: TextStyle(color: themeProvider.textColor),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMessage(BuildContext context, int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Message?",
          style: TextStyle(color: themeProvider.textColor),
        ),
        content: Text(
          "This cannot be undone.",
          style: TextStyle(color: themeProvider.subtitleColor),
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Regenerate?", style: TextStyle(color: themeProvider.textColor)),
        content: Text(
          "This will keep this message as a version and generate a new response. Previous responses will be accessible via the version counter.",
          style: TextStyle(color: themeProvider.subtitleColor),
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
            child: Text(
              "Regenerate",
              style: TextStyle(color: themeProvider.onAccentColor),
            ),
          ),
        ],
      ),
    );
  }

  void _handleForkConversation(BuildContext context, int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Create new conversation from this message
    final newSessionId = chatProvider.createConversationFromMessage(index);
    
    if (newSessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to fork conversation"),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }
    
    // Get the newly created session
    final newSession = chatProvider.savedSessions.firstWhere(
      (s) => s.id == newSessionId,
      orElse: () => ChatSessionData(
        id: newSessionId,
        title: "Forked Conversation",
        messages: [],
        modelName: chatProvider.selectedModel,
        tokenCount: 0,
        systemInstruction: "",
      ),
    );
    
    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Conversation forked successfully!"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2000),
        action: SnackBarAction(
          label: "View",
          onPressed: () {
            // Switch to the new conversation
            chatProvider.loadSession(newSession);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final messages = chatProvider.messages;
    final bool showTypingIndicator = _showTypingIndicator(
      chatProvider,
      themeProvider,
    );
    final bool showVirtualAiTypingBubble =
        showTypingIndicator && (messages.isEmpty || messages.last.isUser);

    return InteractiveViewer(
      transformationController: transformationController,
      scaleEnabled: isZoomEnabled,
      panEnabled: isZoomEnabled,
      minScale: 1.0,
      maxScale: 5.0,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image(
              image: themeProvider.currentImageProvider,
              fit: BoxFit.cover,
            ),
          ),
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
              effectColor: themeProvider.bloomGlowColor,
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
                    itemCount:
                        messages.length + (showVirtualAiTypingBubble ? 1 : 0),
                    padding: const EdgeInsets.only(bottom: 120),
                    itemBuilder: (context, index) {
                      if (showVirtualAiTypingBubble && index == messages.length) {
                        return MessageBubble(
                          msg: ChatMessage(
                            text: '',
                            isUser: false,
                            modelName: chatProvider.selectedModel,
                          ),
                          themeProvider: themeProvider,
                          showTypingIndicator: true,
                        );
                      }

                      final message = messages[index];
                      final bool isLastMessage = index == messages.length - 1;
                      return MessageBubble(
                        msg: message,
                        themeProvider: themeProvider,
                        showTypingIndicator:
                            showTypingIndicator && isLastMessage && !message.isUser,
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
                        onRegenerate: !message.isUser
                            ? () => _confirmRegenerate(context, index)
                            : null,
                        onDelete: () => _confirmDeleteMessage(context, index),
                        onNextVersion: message.regenerationVersions.length > 1 && !message.isUser
                            ? () => chatProvider.nextMessageVersion(index)
                            : null,
                        onPreviousVersion: message.regenerationVersions.length > 1 && !message.isUser
                            ? () => chatProvider.previousMessageVersion(index)
                            : null,
                        onFork: !message.isUser
                            ? () => _handleForkConversation(context, index)
                            : null,
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
    
    final messages = chatProvider.messages;
    if (messages.isEmpty) return true;
    
    final last = messages.last;
    
    // If last message is from user, API hasn't created AI message yet
    if (last.isUser) return true;
    
    // If AI message exists but is empty or only whitespace, show typing indicator
    // Hide as soon as any non-whitespace text arrives
    return last.text.trim().isEmpty;
  }
}
