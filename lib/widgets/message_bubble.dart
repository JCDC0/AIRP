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

  const MessageBubble({
    super.key,
    required this.msg,
    required this.themeProvider,
    this.onLongPress,
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

    final codeStyle = TextStyle(
      color: textColor,
      backgroundColor: Colors.black26,
      shadows: useBloom ? [Shadow(color: textColor.withOpacity(0.9), blurRadius: 4)] : [],
      fontFamily: 'monospace',
    );

    // Define the content once to avoid repetition
    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Important for CustomPaint to get the correct size
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
        // --------------------------------------
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
                if (msg.text.isNotEmpty)
          MarkdownBody(
            data: msg.text,
            builders: {
              'pre': CodeElementBuilder(context, codeStyle),
            },
            styleSheet: MarkdownStyleSheet(
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
      ],
    );

        // Use the CustomPaint for the glowing border, or a simple Container if bloom is off
    final bubbleWidget = useBloom
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

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: bubbleWidget,
      ),
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

    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      language = lg.substring(9);
    }

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
/// This provides more control than a simple boxShadow, allowing the glow
/// to emanate directly from the border line.
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
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0); // Increased blur for "dreamy" look

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

    // Draw the glow first, so it's behind everything
    canvas.drawRRect(rrect, glowPaint);

    // Draw the background fill on top of the glow
    canvas.drawRRect(rrect, bgPaint);

    // Draw the crisp border on top of the background
    canvas.drawRRect(rrect.inflate(-strokeWidth / 2), borderPaint);
  }

  @override
  bool shouldRepaint(covariant BorderGlowPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.borderColor != borderColor ||
           oldDelegate.glowColor != glowColor;
  }
}

