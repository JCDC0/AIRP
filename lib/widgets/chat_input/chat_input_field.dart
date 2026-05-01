import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/lorebook_models.dart';
import 'orbit_animations.dart';

class ChatInputField extends StatelessWidget {
  final TextEditingController textController;
  final bool hasPendingImages;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final LorebookEntry? recognizedLorePreview;
  final AnimationController orbitController;
  final List<OrbitLine> orbitLines;

  const ChatInputField({
    super.key,
    required this.textController,
    required this.hasPendingImages,
    required this.isLoading,
    required this.onSend,
    required this.onCancel,
    required this.recognizedLorePreview,
    required this.orbitController,
    required this.orbitLines,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  // Handle Ctrl+Enter or Cmd+Enter to send message
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    final isCtrlOrCmd =
                        HardwareKeyboard.instance.isLogicalKeyPressed(
                          LogicalKeyboardKey.controlLeft,
                        ) ||
                        HardwareKeyboard.instance.isLogicalKeyPressed(
                          LogicalKeyboardKey.controlRight,
                        ) ||
                        HardwareKeyboard.instance.isLogicalKeyPressed(
                          LogicalKeyboardKey.metaLeft,
                        ) ||
                        HardwareKeyboard.instance.isLogicalKeyPressed(
                          LogicalKeyboardKey.metaRight,
                        );
                    if (isCtrlOrCmd && !isLoading) {
                      onSend();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: AnimatedBuilder(
                  animation: orbitController,
                  builder: (context, child) {
                    return CustomPaint(
                      foregroundPainter:
                          isLoading && themeProvider.enableLoadingAnimation
                              ? LineOrbitPainter(
                                  progress: orbitController.value,
                                  lines: orbitLines,
                                  color: themeProvider.textColor,
                                  bloomColor: themeProvider.bloomGlowColor,
                                  enableBloom: themeProvider.enableBloom,
                                  borderRadius: 24.0,
                                )
                              : null,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: themeProvider.inputFillColor,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: TextField(
                    controller: textController,
                    minLines: 1,
                    maxLines: scaleProvider.inputAreaScale.toInt(),
                    style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: scaleProvider.chatFontSize,
                    ),
                    decoration: InputDecoration(
                      hintText: hasPendingImages
                          ? 'Add a caption...'
                          : (chatProvider.enableGrounding
                                ? 'Search web...'
                                : 'Message...'),
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: scaleProvider.chatFontSize,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isLoading
                              ? Colors.transparent
                              : Colors.grey[900]!,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isLoading
                              ? Colors.transparent
                              : Colors.grey[900]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isLoading
                              ? Colors.transparent
                              : themeProvider.textColor.withValues(
                                  alpha: 0.5,
                                ),
                          width: 1,
                        ),
                      ),
                      filled: true,
                      fillColor: themeProvider.inputFillColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40 * scaleProvider.iconScale,
              height: 40 * scaleProvider.iconScale,
              decoration: BoxDecoration(
                color: themeProvider.inputFillColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLoading
                      ? themeProvider.textColor.withValues(alpha: 0.3)
                      : (chatProvider.enableGrounding
                            ? Colors.green
                            : themeProvider.textColor),
                  width: 0.5 * scaleProvider.iconScale,
                ),
              ),
              child: IconButton(
                onPressed: isLoading ? onCancel : onSend,
                icon: Icon(
                  isLoading ? Icons.stop_circle_outlined : Icons.send,
                  color: isLoading
                      ? themeProvider.textColor.withValues(alpha: 0.5)
                      : themeProvider.textColor,
                  size: 20 * scaleProvider.iconScale,
                ),
                iconSize: 20 * scaleProvider.iconScale,
                constraints: BoxConstraints(
                  minWidth: 40 * scaleProvider.iconScale,
                  minHeight: 40 * scaleProvider.iconScale,
                  maxWidth: 40 * scaleProvider.iconScale,
                  maxHeight: 40 * scaleProvider.iconScale,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        if (recognizedLorePreview != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: chatProvider.loreRecognizerGlowColor.withValues(
                  alpha: 0.16,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: chatProvider.loreRecognizerGlowColor
                      .withValues(alpha: 0.75),
                ),
                boxShadow: themeProvider.enableBloom
                    ? [
                        BoxShadow(
                          color: chatProvider.loreRecognizerGlowColor
                              .withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                recognizedLorePreview!.comment.trim().isEmpty
                    ? 'Recognized lore entry #${recognizedLorePreview!.id}'
                    : recognizedLorePreview!.comment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: chatProvider.loreRecognizerGlowColor,
                  fontWeight: FontWeight.w700,
                  fontSize: scaleProvider.systemFontSize * 0.78,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}