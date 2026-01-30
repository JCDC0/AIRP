import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart'; 

class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final ThemeProvider themeProvider;
  final VoidCallback? onLongPress;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.themeProvider,
    this.onLongPress,
    this.onCopy,
    this.onEdit,
    this.onRegenerate,
    this.onDelete,
  });

    void _showImageZoom(BuildContext context, ImageProvider provider) {
    showDialog(
      context: context,
      barrierColor: const Color.fromARGB(255, 0, 0, 0),
      builder: (context) => Stack(
        children: [
          // 1. Zoomable Image
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image(image: provider, fit: BoxFit.contain),
            ),
          ),
          // 2. Close Button (Top Right)
          Positioned(
            top: 40,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // 3. Download Button (Bottom Center)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Placeholder for actual download logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Image saved to Gallery (Simulated)")),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text("Download"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

    @override
    Widget build(BuildContext context) {
      final bubbleColor = msg.isUser ? themeProvider.userBubbleColor : themeProvider.aiBubbleColor;
      final textColor = msg.isUser ? themeProvider.userTextColor : themeProvider.aiTextColor;
      final borderColor = msg.isUser ? themeProvider.userBubbleColor.withAlpha(128) : Colors.white10;
      final useBloom = themeProvider.enableBloom;
  
      Widget bubble;
      if (msg.contentNotifier != null) {
        bubble = ValueListenableBuilder<String>(
          valueListenable: msg.contentNotifier!,
          builder: (context, value, child) {
            return _buildBubble(context, value, bubbleColor, borderColor, textColor, useBloom);
          },
        );
      } else {
        bubble = _buildBubble(context, msg.text, bubbleColor, borderColor, textColor, useBloom);
      }
  
      return Align(
        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: onLongPress,
              child: bubble,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. REGENERATE (Leftmost for AI)
                 if (onRegenerate != null)
                   _buildIconBtn(Icons.refresh, "Regenerate", onRegenerate!, textColor, 25),

                 // 2. COPY
                 if (onCopy != null)
                   _buildIconBtn(Icons.copy_rounded, "Copy", onCopy!, textColor, 25),

                 // 3. EDIT (User Only usually)
                 if (onEdit != null)
                   _buildIconBtn(Icons.edit_outlined, "Edit", onEdit!, textColor, 25),
                 // 4. DELETE
                 if (onDelete != null)
                   _buildIconBtn(Icons.delete_outline, "Delete", onDelete!, textColor, 25),
              ],
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildIconBtn(IconData icon, String tooltip, VoidCallback onTap, Color color, double size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon, size: size, color: color.withOpacity(0.5)),
        onPressed: onTap,
        tooltip: tooltip,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          hoverColor: color.withOpacity(0.1),
        ),
      ),
    );
  }

    Widget _buildBubble(BuildContext context, String text, Color bubbleColor, Color borderColor, Color textColor, bool useBloom) {
      final codeStyle = TextStyle(
        color: textColor,
        backgroundColor: Colors.black26,
        shadows: useBloom ? [Shadow(color: textColor.withOpacity(0.9), blurRadius: 4)] : [],
        fontFamily: 'monospace',
      );
  
      // --- PARSE REASONING ---
      final splitContent = _extractReasoning(text);
      final reasoningText = splitContent['reasoning'] as String;
      final visibleText = splitContent['content'] as String;
      final isReasoningDone = splitContent['isDone'] as bool;
  
      // Define the content once to avoid repetition
      final contentColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- MODEL NAME DISPLAY ADDED HERE ---
          if (!msg.isUser && msg.modelName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: useBloom ? [const BoxShadow(color: Color.fromARGB(26, 255, 255, 255), blurRadius: 4)] : [],
                ),
                child: Text(
                  cleanModelName(msg.modelName!),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    shadows: useBloom ? [Shadow(color: textColor.withOpacity(0.9), blurRadius: 4)] : [],
                  ),
                ),
              ),
            ),
  
          // --- REASONING DROPDOWN ---
          if (reasoningText.isNotEmpty)
            ReasoningView(
              reasoning: reasoningText,
              textColor: textColor,
              useBloom: useBloom,
              isDone: isReasoningDone,
            ),
  
          if (msg.imagePaths.isNotEmpty)
            _buildAttachmentGrid(context, msg.imagePaths),
          if (msg.aiImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GestureDetector(
                onTap: () => _showImageZoom(context, MemoryImage(base64Decode(msg.aiImage!))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(base64Decode(msg.aiImage!), width: 250, fit: BoxFit.contain),
                ),
              ),
            ),
          if (visibleText.isNotEmpty)
            MarkdownBody(
              data: visibleText,
              builders: {
                'code': CodeElementBuilder(context, codeStyle),
              },
              styleSheet: MarkdownStyleSheet(
                codeblockPadding: EdgeInsets.zero,
                codeblockDecoration: const BoxDecoration(color: Colors.transparent),
                p: TextStyle(
                  color: textColor,
                  shadows: useBloom ? [Shadow(color: textColor.withOpacity(0.9), blurRadius: 15)] : [],
                ),
                a: TextStyle(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                  shadows: useBloom ? [const Shadow(color: Colors.blueAccent, blurRadius: 8)] : [],
                ),
                code: codeStyle,
                h1: TextStyle(color: textColor, fontWeight: FontWeight.bold, shadows: useBloom ? [Shadow(color: textColor, blurRadius: 10)] : []),
                h2: TextStyle(color: textColor, fontWeight: FontWeight.bold, shadows: useBloom ? [Shadow(color: textColor, blurRadius: 10)] : []),
                h3: TextStyle(color: textColor, fontWeight: FontWeight.bold, shadows: useBloom ? [Shadow(color: textColor, blurRadius: 10)] : []),
              ),
            ),
  
          // --- USAGE STATS DISPLAY ---
          if (msg.usage != null && !msg.isUser)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: useBloom ? [const BoxShadow(color: Color.fromARGB(26, 255, 255, 255), blurRadius: 4)] : [],
                ),
                child: Text(
                  "Usage: ${msg.usage!['prompt_tokens'] ?? 0} in + ${msg.usage!['completion_tokens'] ?? 0} out = ${msg.usage!['total_tokens'] ?? 0} total",
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    shadows: useBloom ? [Shadow(color: textColor.withOpacity(0.9), blurRadius: 4)] : [],
                  ),
                ),
              ),
            ),
        ],
      );
  
      // Use the CustomPaint for the glowing border, or a simple Container if bloom is off
      return useBloom
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: CustomPaint(
                painter: BorderGlowPainter(
                  backgroundColor: bubbleColor,
                  borderColor: borderColor,
                  glowColor: (msg.isUser ? bubbleColor : Colors.white).withOpacity(0.15),
                  radius: 12.0,
                  strokeWidth: 2.0,
                  glowStrokeWidth: 10.0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                  child: contentColumn,
                ),
              ),
            )
          : Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: contentColumn,
            );
    }
  
    Widget _buildAttachmentGrid(BuildContext context, List<String> paths) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: paths.map((path) {
          final String ext = path.split('.').last.toLowerCase();
          final bool isImage = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'].contains(ext);

          if (isImage) {
            return GestureDetector(
              onTap: () => _showImageZoom(context, FileImage(File(path))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 150, height: 150,
                  color: Colors.black26,
                  child: Image.file(File(path), fit: BoxFit.cover),
                ),
              ),
            );
          }

          // Return Non-Image File Icon
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 150, height: 150,
              color: Colors.black26,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    ext == 'pdf' ? Icons.picture_as_pdf 
                    : ['doc', 'docx'].contains(ext) ? Icons.description
                    : Icons.insert_drive_file,
                    size: 50, 
                    color: Colors.white54
                  ),
                  Positioned(
                    bottom: 8, left: 8, right: 8,
                    child: Text(
                      path.split('/').last,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
    }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final TextStyle textStyle;

  CodeElementBuilder(this.context, this.textStyle);

    @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';

    // 1. Detect Language safely
    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      if (lg.startsWith('language-')) {
        language = lg.substring(9);
      } else {
        language = lg;
      }
    }

    // 2. Decide if this is a Block Code or Inline Code
    // If it has a language class or contains newlines, treat as block.
    final bool isBlock = language.isNotEmpty || element.textContent.contains('\n');

    if (!isBlock) {
      // INLINE CODE STYLE
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          element.textContent,
          style: textStyle.copyWith(fontSize: (textStyle.fontSize ?? 14) * 0.9),
        ),
      );
    }

    // BLOCK CODE STYLE
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Code Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (language.isNotEmpty)
                  Text(
                    language.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  )
                else
                   const SizedBox.shrink(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: element.textContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.copy, color: Colors.white70, size: 14),
                      SizedBox(width: 6),
                      Text("Copy Code", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Code Body
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text(
              element.textContent.trimRight(),
              style: textStyle.copyWith(backgroundColor: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom painter to draw a bubble with a glowing border effect.
class BorderGlowPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final Color glowColor;
  final double radius;
  final double strokeWidth;
  final double glowStrokeWidth;

  BorderGlowPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.glowColor,
    this.radius = 12.0,
    this.strokeWidth = 1.0,
    this.glowStrokeWidth = 3.0,
  });

    @override
  void paint(Canvas canvas, Size size) {
    // Paint for the glowing effect
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowStrokeWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

    // Paint for the solid background fill
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    // Paint for the crisp, visible border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect.inflate(-strokeWidth / 2), borderPaint);
  }

    @override
  bool shouldRepaint(covariant BorderGlowPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.borderColor != borderColor ||
           oldDelegate.glowColor != glowColor;
  }
}

// --- REASONING HELPERS ---

Map<String, dynamic> _extractReasoning(String text) {
  // Matches <think> content </think> (handling unclosed tag for streaming)
  final RegExp thinkRegex = RegExp(r'<think>(.*?)(?:</think>|$)', dotAll: true);
  final match = thinkRegex.firstMatch(text);
  
  if (match != null) {
    final reasoning = match.group(1)?.trim() ?? '';
    // Check if the closing tag exists in the full match
    final bool hasClosing = match.group(0)!.contains('</think>');
    
    // Remove the think block from the main text
    final content = text.replaceFirst(match.group(0)!, '').trim();
    return {
      'reasoning': reasoning, 
      'content': content,
      'isDone': hasClosing
    };
  }
  
  // If no reasoning found, effectively "done" with reasoning (none exists)
  return {'reasoning': '', 'content': text, 'isDone': true};
}

class ReasoningView extends StatefulWidget {
  final String reasoning;
  final Color textColor;
  final bool useBloom;
  final bool isDone;

  const ReasoningView({
    super.key,
    required this.reasoning,
    required this.textColor,
    required this.useBloom,
    required this.isDone,
  });

  @override
  State<ReasoningView> createState() => _ReasoningViewState();
}

class _ReasoningViewState extends State<ReasoningView> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // If it's NOT done (streaming), expand it automatically.
    // If it IS done (loaded from history), start collapsed.
    _isExpanded = !widget.isDone;
  }

  @override
  void didUpdateWidget(covariant ReasoningView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If it transitions from NOT done to DONE, collapse it.
    if (!oldWidget.isDone && widget.isDone) {
      setState(() {
        _isExpanded = false;
      });
    }
  }

    @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                 color: Colors.black12,
                 borderRadius: BorderRadius.circular(4),
                 border: Border.all(color: widget.textColor.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(
                     _isExpanded ? Icons.visibility_off_outlined : Icons.psychology_outlined,
                     size: 14, 
                     color: widget.textColor.withOpacity(0.6)
                   ),
                   const SizedBox(width: 6),
                   Text(
                     _isExpanded ? "Hide Thought Process" : "Show Thought Process",
                     style: TextStyle(
                       fontSize: 11,
                       fontWeight: FontWeight.bold,
                       color: widget.textColor.withOpacity(0.6),
                     ),
                   ),
                   const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          
          // Content
          if (_isExpanded)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(color: widget.textColor.withOpacity(0.3), width: 3)
                ),
              ),
              child: Text(
                widget.reasoning,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: widget.textColor.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


