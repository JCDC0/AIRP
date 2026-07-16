import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/search_provider.dart' show ChatSearchProvider;
import 'message_bubble.dart';
import 'effects_overlay.dart';

/// A widget that displays a list of chat messages with interactive capabilities.
///
/// This widget handles rendering the message bubbles, background effects,
/// and the long-press menu for message actions like copy, edit, and delete.
class ChatMessagesList extends StatefulWidget {
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

  @override
  State<ChatMessagesList> createState() => ChatMessagesListState();
}

class ChatMessagesListState extends State<ChatMessagesList> {
  /// Per-message keys used to scroll a specific message into view (find bar).
  final Map<int, GlobalKey> _messageKeys = {};

  GlobalKey _keyFor(int index) => _messageKeys.putIfAbsent(
    index,
    () => GlobalKey(debugLabel: 'msg-$index'),
  );

  /// Scrolls the message at [index] into view. Used by the in-chat find bar
  /// to follow the current match.
  void scrollToMessage(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _messageKeys[index]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.4,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showEditDialog(BuildContext context, int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.isLoading) {
      return;
    }
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final message = chatProvider.messages[index];
    final readOnlyReasoning = chatProvider.getReadOnlyReasoningForEdit(message);
    final TextEditingController editController = TextEditingController(
      text: chatProvider.getEditableMessageText(message),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text(
          "Edit Message",
          style: TextStyle(color: themeProvider.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (readOnlyReasoning.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: themeProvider.containerFillColor,
                    border: Border.all(color: themeProvider.borderColor),
                  ),
                  child: Text(
                    'Reasoning is read-only.',
                    style: TextStyle(
                      color: themeProvider.subtitleColor,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ),
              TextField(
                controller: editController,
                maxLines: null,
                style: TextStyle(color: themeProvider.subtitleColor),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: themeProvider.containerFillColor,
                  labelText: 'Visible response',
                ),
              ),
            ],
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
    if (chatProvider.isLoading) {
      return;
    }
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
    if (chatProvider.isLoading) {
      return;
    }
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Regenerate?",
          style: TextStyle(color: themeProvider.textColor),
        ),
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

  void _handleBranchConversation(BuildContext context, int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // Create a new branch from the selected message
    final newSessionId = chatProvider.createBranchFromMessage(index);

    if (newSessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to branch conversation"),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    // Find and switch to the newly created session
    final newSession = chatProvider.savedSessions.firstWhere(
      (s) => s.id == newSessionId,
      orElse: () => ChatSessionData(
        id: newSessionId,
        title: "Branched Conversation",
        messages: [],
        modelName: chatProvider.selectedModel,
        tokenCount: 0,
        systemInstruction: "",
      ),
    );

    // Auto-switch into the branched conversation
    chatProvider.loadSession(newSession);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Switched to branched conversation"),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final searchProvider = Provider.of<ChatSearchProvider>(context);
    final messages = chatProvider.messages;
    final showTypingIndicator = _showTypingIndicator(chatProvider, vfxProvider);
    final bool showVirtualAiTypingBubble =
        showTypingIndicator && (messages.isEmpty || messages.last.isUser);

    final int? currentMatchMessageIndex =
        searchProvider.currentMatchMessageIndex;
    final Set<int> matchMessageIndices = searchProvider.matchMessageIndices;
    final String searchQuery = searchProvider.query;

    return InteractiveViewer(
      transformationController: widget.transformationController,
      scaleEnabled: widget.isZoomEnabled,
      panEnabled: widget.isZoomEnabled,
      minScale: 1.0,
      maxScale: 5.0,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image(
              image: vfxProvider.currentImageProvider,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(
                (vfxProvider.backgroundOpacity * 255).round(),
              ),
            ),
          ),

          Positioned.fill(
            child: EffectsOverlay(
              showMotes: vfxProvider.enableMotes,
              showRain: vfxProvider.enableRain,
              showFireflies: vfxProvider.enableFireflies,
              effectColor: themeProvider.bloomGlowColor,
              motesDensity: vfxProvider.motesDensity.toDouble(),
              rainIntensity: vfxProvider.rainIntensity.toDouble(),
              firefliesCount: vfxProvider.firefliesCount.toDouble(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: widget.scrollController,
                    itemCount:
                        messages.length + (showVirtualAiTypingBubble ? 1 : 0),
                    padding: const EdgeInsets.only(bottom: 120),
                    itemBuilder: (context, index) {
                      if (showVirtualAiTypingBubble &&
                          index == messages.length) {
                        return MessageBubble(
                          msg: ChatMessage(
                            text: '',
                            isUser: false,
                            modelName: chatProvider.selectedModel,
                          ),
                          showTypingIndicator: true,
                          searchQuery: searchQuery,
                          isCurrentSearchMessage: false,
                        );
                      }

                      final message = messages[index];
                      final bool isLastMessage = index == messages.length - 1;
                      return MessageBubble(
                        key: _keyFor(index),
                        msg: message,
                        isSearchCurrent: currentMatchMessageIndex == index,
                        isSearchMatch: matchMessageIndices.contains(index),
                        searchQuery: searchQuery,
                        isCurrentSearchMessage:
                            currentMatchMessageIndex == index,
                        showTypingIndicator:
                            showTypingIndicator &&
                            isLastMessage &&
                            !message.isUser,
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
                        onEdit: chatProvider.isLoading
                            ? null
                            : () => _showEditDialog(context, index),
                        onRegenerate: (!isLastMessage || chatProvider.isLoading)
                            ? null
                            : () => _confirmRegenerate(context, index),
                        onDelete: chatProvider.isLoading
                            ? null
                            : () => _confirmDeleteMessage(context, index),
                        onNextVersion:
                            message.regenerationVersions.length > 1 &&
                                !message.isUser &&
                                !chatProvider.isLoading
                            ? () => chatProvider.nextMessageVersion(index)
                            : null,
                        onPreviousVersion:
                            message.regenerationVersions.length > 1 &&
                                !message.isUser &&
                                !chatProvider.isLoading
                            ? () => chatProvider.previousMessageVersion(index)
                            : null,
                        onBranch: !message.isUser
                            ? () => _handleBranchConversation(context, index)
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
  bool _showTypingIndicator(
    ChatProvider chatProvider,
    VfxProvider vfxProvider,
  ) {
    if (!chatProvider.isLoading || vfxProvider.enableLoadingAnimation) {
      return false;
    }

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
