import 'package:flutter/material.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import 'message_bubble_markdown.dart';

/// Collapsible disclosure for a conversation's chronicle block.
///
/// A chronicle accumulates across compactions, so by the third or fourth
/// generation it is long enough to push the live roleplay off screen if it
/// renders inline. It starts collapsed and shows its size, so the block reads
/// as a reference document the user opens rather than a message in the chat.
///
/// Deliberately separate from [MessageBubbleReasoning]: that widget is on the
/// render path for every AI message and its API is reasoning-shaped
/// (`isDone`, loading animation, monospace body).
class MessageBubbleChronicle extends StatefulWidget {
  /// The chronicle body, already stripped of its heading.
  final String body;

  final ThemeProvider themeProvider;
  final ScaleProvider scaleProvider;
  final Color textColor;
  final bool useBloom;
  final String? searchQuery;
  final bool isCurrentSearchMessage;

  const MessageBubbleChronicle({
    super.key,
    required this.body,
    required this.themeProvider,
    required this.scaleProvider,
    required this.textColor,
    required this.useBloom,
    this.searchQuery,
    this.isCurrentSearchMessage = false,
  });

  @override
  State<MessageBubbleChronicle> createState() => _MessageBubbleChronicleState();
}

class _MessageBubbleChronicleState extends State<MessageBubbleChronicle> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Open automatically when a search is running, so a match inside the
    // chronicle is not hidden behind a collapsed header.
    _expanded = (widget.searchQuery ?? '').isNotEmpty;
  }

  @override
  void didUpdateWidget(MessageBubbleChronicle oldWidget) {
    super.didUpdateWidget(oldWidget);
    final query = widget.searchQuery ?? '';
    if (query.isNotEmpty && query != (oldWidget.searchQuery ?? '')) {
      _expanded = true;
    }
  }

  int get _wordCount {
    final trimmed = widget.body.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeProvider;
    final scale = widget.scaleProvider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories,
                  size: scale.chatFontSize,
                  color: widget.textColor,
                  shadows: widget.useBloom
                      ? [Shadow(color: theme.bloomGlowColor, blurRadius: 8)]
                      : [],
                ),
                const SizedBox(width: 6),
                Text(
                  "Chronicle",
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scale.chatFontSize - 1,
                    shadows: widget.useBloom
                        ? [Shadow(color: theme.bloomGlowColor, blurRadius: 8)]
                        : [],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _expanded ? "hide" : "$_wordCount words",
                  style: TextStyle(
                    color: theme.subtitleColor,
                    fontSize: scale.chatFontSize - 3,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: scale.chatFontSize,
                  color: theme.subtitleColor,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          MessageBubbleMarkdown(
            text: widget.body,
            themeProvider: theme,
            scaleProvider: scale,
            textColor: widget.textColor,
            useBloom: widget.useBloom,
            searchQuery: widget.searchQuery,
            isCurrentSearchMessage: widget.isCurrentSearchMessage,
          ),
      ],
    );
  }
}
