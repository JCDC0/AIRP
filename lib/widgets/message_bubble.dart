import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';
import '../providers/scale_provider.dart';
import '../services/reasoning_utils.dart';

import 'message_bubble/message_bubble_actions.dart';
import 'message_bubble/message_bubble_attachments.dart';
import 'message_bubble/message_bubble_markdown.dart';
import 'message_bubble/message_bubble_metadata.dart';
import 'message_bubble/message_bubble_painters.dart';
import 'message_bubble/message_bubble_reasoning.dart';

/// A widget that displays a single chat message bubble.
///
/// This widget handles rendering markdown text, images, and providing
/// interactive buttons for message actions.
class MessageBubble extends StatelessWidget {
  /// The chat message to display.
  final ChatMessage msg;

  /// The theme provider for styling.
  final ThemeProvider themeProvider;

  /// Callback when the bubble is long-pressed.
  final VoidCallback? onLongPress;

  /// Callback for copying message text.
  final VoidCallback? onCopy;

  /// Callback for editing the message.
  final VoidCallback? onEdit;

  /// Callback for regenerating an AI response.
  final VoidCallback? onRegenerate;

  /// Callback for deleting the message.
  final VoidCallback? onDelete;

  /// Callback for navigating to next version.
  final VoidCallback? onNextVersion;

  /// Callback for navigating to previous version.
  final VoidCallback? onPreviousVersion;

  /// Callback for branching conversation from this message.
  final VoidCallback? onBranch;

  /// Whether to show an inline typing indicator inside this bubble.
  final bool showTypingIndicator;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.themeProvider,
    this.onLongPress,
    this.onCopy,
    this.onEdit,
    this.onRegenerate,
    this.onDelete,
    this.onNextVersion,
    this.onPreviousVersion,
    this.onBranch,
    this.showTypingIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final bubbleColor = msg.isUser
        ? themeProvider.userBubbleColor
        : themeProvider.aiBubbleColor;
    final textColor = msg.isUser
        ? themeProvider.userTextColor
        : themeProvider.aiTextColor;
    final borderColor = msg.isUser
        ? themeProvider.userBubbleColor.withAlpha(128)
        : themeProvider.dividerColor;
    final useBloom = themeProvider.enableBloom;

    Widget bubble;
    if (msg.contentNotifier != null) {
      bubble = ValueListenableBuilder<String>(
        valueListenable: msg.contentNotifier!,
        builder: (context, value, child) {
          return _buildBubble(
            context,
            value,
            bubbleColor,
            borderColor,
            textColor,
            useBloom,
            scaleProvider,
            themeProvider.enableLoadingAnimation,
            showTypingIndicator,
          );
        },
      );
    } else {
      bubble = _buildBubble(
        context,
        msg.text,
        bubbleColor,
        borderColor,
        textColor,
        useBloom,
        scaleProvider,
        themeProvider.enableLoadingAnimation,
        showTypingIndicator,
      );
    }

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: msg.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(onLongPress: onLongPress, child: bubble),
          MessageBubbleActions(
            msg: msg,
            textColor: textColor,
            iconScale: scaleProvider.iconScale,
            onRegenerate: onRegenerate,
            onCopy: onCopy,
            onEdit: onEdit,
            onDelete: onDelete,
            onPreviousVersion: onPreviousVersion,
            onNextVersion: onNextVersion,
            onBranch: onBranch,
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    String text,
    Color bubbleColor,
    Color borderColor,
    Color textColor,
    bool useBloom,
    ScaleProvider scaleProvider,
    bool enableLoadingAnimation,
    bool showTypingIndicator,
  ) {
    final splitContent = ReasoningUtils.split(text);
    final reasoningText = splitContent.reasoning;
    final visibleText = splitContent.content;
    final isReasoningDone = splitContent.isDone;
    final bool hasReasoning = reasoningText.trim().isNotEmpty;
    final bool hasVisibleText = visibleText.trim().isNotEmpty;
    final bool hasAttachments = msg.imagePaths.isNotEmpty;
    final bool shouldShowTypingDots =
        showTypingIndicator &&
        !hasReasoning &&
        !hasVisibleText &&
        !hasAttachments;

    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MessageBubbleMetadata(
          msg: msg,
          themeProvider: themeProvider,
          scaleProvider: scaleProvider,
          textColor: textColor,
          useBloom: useBloom,
        ),
        if (reasoningText.isNotEmpty)
          MessageBubbleReasoning(
            reasoning: reasoningText,
            textColor: textColor,
            useBloom: useBloom,
            isDone: isReasoningDone,
            enableLoadingAnimation: enableLoadingAnimation,
          ),
        if (shouldShowTypingDots)
          Padding(
            padding: EdgeInsets.only(
              top: 5,
              bottom: 2.0 * scaleProvider.iconScale,
            ),
            child: InlineTypingDots(iconScale: scaleProvider.iconScale),
          ),
        if (hasAttachments)
          MessageBubbleAttachments(
            imagePaths: msg.imagePaths,
            themeProvider: themeProvider,
          ),
        if (hasVisibleText)
          MessageBubbleMarkdown(
            text: visibleText,
            themeProvider: themeProvider,
            scaleProvider: scaleProvider,
            textColor: textColor,
            useBloom: useBloom,
          ),
      ],
    );

    return useBloom
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: CustomPaint(
              painter: BorderGlowPainter(
                backgroundColor: bubbleColor,
                borderColor: borderColor,
                glowColor: (msg.isUser ? bubbleColor : themeProvider.textColor)
                    .withValues(alpha: 0.15),
                radius: 12.0,
                strokeWidth: 2.0,
                glowStrokeWidth: 10.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                child: contentColumn,
              ),
            ),
          )
        : Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: contentColumn,
          );
  }
}