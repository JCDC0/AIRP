import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import '../../providers/theme_provider.dart';
import '../../services/file_io_helper.dart';

class MessageBubbleAttachments extends StatelessWidget {
  final List<String> imagePaths;
  final ThemeProvider themeProvider;

  const MessageBubbleAttachments({
    super.key,
    required this.imagePaths,
    required this.themeProvider,
  });

  void _showImageZoom(
    BuildContext context,
    ImageProvider imageProvider, {
    Uint8List? rawBytes,
  }) {
    showDialog(
      context: context,
      barrierColor: const Color.fromARGB(255, 0, 0, 0),
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image(image: imageProvider, fit: BoxFit.contain),
            ),
          ),
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
          if (rawBytes != null)
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
                    onPressed: () async {
                      if (kIsWeb) {
                        try {
                          await FileIOHelper.saveFile(
                            bytes: rawBytes,
                            fileName:
                                'airp_image_${DateTime.now().millisecondsSinceEpoch}.png',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Image saved'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          }
                        }
                      } else {
                        try {
                          final savedPath = await FileIOHelper.saveToDownloads(
                            bytes: rawBytes,
                            filename:
                                'airp_image_${DateTime.now().millisecondsSinceEpoch}.png',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Saved to $savedPath'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
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
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: imagePaths.map((path) {
          final String ext = path.split('.').last.toLowerCase();
          final bool isImage = [
            'jpg',
            'jpeg',
            'png',
            'webp',
            'heic',
            'heif',
          ].contains(ext);

          if (isImage) {
            final imageProvider = FileIOHelper.imageProviderFromPath(path);
            return GestureDetector(
              onTap: imageProvider != null
                  ? () => _showImageZoom(context, imageProvider)
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 150,
                  height: 150,
                  color: themeProvider.containerFillColor,
                  child: FileIOHelper.imageWidgetFromPath(
                    path,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 150,
              height: 150,
              color: themeProvider.containerFillColor,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    ext == 'pdf'
                        ? Icons.picture_as_pdf
                        : ['doc', 'docx'].contains(ext)
                        ? Icons.description
                        : Icons.insert_drive_file,
                    size: 50,
                    color: themeProvider.hintColor,
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Text(
                      path.split('/').last,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: themeProvider.subtitleColor,
                      ),
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
