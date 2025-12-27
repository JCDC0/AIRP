import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';
import 'dart:convert';
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

    // BLOOM LOGIC
    List<BoxShadow> boxShadows = [];
    if (themeProvider.enableBloom) {
      boxShadows = [
        BoxShadow(
          color: bubbleColor.withOpacity(0.5),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ];
    }

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: boxShadows, // Apply Glow
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      boxShadow: themeProvider.enableBloom ? [BoxShadow(color: Colors.white10, blurRadius: 4)] : [],
                    ),
                    child: Text(
                      cleanModelName(msg.modelName!),
                      style: TextStyle(
                        fontSize: 10, 
                        color: textColor.withOpacity(0.7), 
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        shadows: themeProvider.enableBloom ? [Shadow(color: textColor.withOpacity(0.5), blurRadius: 4)] : [],
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
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: textColor,
                      shadows: themeProvider.enableBloom ? [Shadow(color: textColor.withOpacity(0.6), blurRadius: 8)] : [],
                    ),
                    a: TextStyle(
                      color: Colors.blueAccent, 
                      decoration: TextDecoration.underline,
                      shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.blueAccent, blurRadius: 8)] : [],
                    ),
                    code: TextStyle(
                      color: textColor, 
                      backgroundColor: Colors.black26,
                      shadows: themeProvider.enableBloom ? [Shadow(color: textColor.withOpacity(0.4), blurRadius: 4)] : [],
                    ),
                    h1: TextStyle(color: textColor, fontWeight: FontWeight.bold, shadows: themeProvider.enableBloom ? [Shadow(color: textColor, blurRadius: 10)] : []),
                    h2: TextStyle(color: textColor, fontWeight: FontWeight.bold, shadows: themeProvider.enableBloom ? [Shadow(color: textColor, blurRadius: 10)] : []),
                    h3: TextStyle(color: textColor, fontWeight: FontWeight.bold, shadows: themeProvider.enableBloom ? [Shadow(color: textColor, blurRadius: 10)] : []),
                  ),
                ),
            ],
          ),
        ),
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
