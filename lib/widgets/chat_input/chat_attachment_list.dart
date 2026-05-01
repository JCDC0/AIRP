import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/file_io_helper.dart';

class ChatAttachmentList extends StatelessWidget {
  final List<String> pendingImages;
  final Map<String, Uint8List> pendingImageBytes;
  final void Function(int index) onRemove;

  const ChatAttachmentList({
    super.key,
    required this.pendingImages,
    required this.pendingImageBytes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingImages.isEmpty) return const SizedBox.shrink();

    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pendingImages.length,
            itemBuilder: (context, index) {
              final path = pendingImages[index];
              final ext = path.split('.').last.toLowerCase();
              final isImage = [
                'jpg',
                'jpeg',
                'png',
                'webp',
                'heic',
              ].contains(ext);
              final Uint8List? webBytes = pendingImageBytes[path];

              Widget buildImageWidget({
                BoxFit fit = BoxFit.cover,
                double? width,
                double? height,
              }) {
                if (webBytes != null) {
                  return Image.memory(
                    webBytes,
                    fit: fit,
                    width: width,
                    height: height,
                  );
                }
                return FileIOHelper.imageWidgetFromPath(
                  path,
                  fit: fit,
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: isImage
                          ? () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: EdgeInsets.zero,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      InteractiveViewer(
                                        maxScale: 5.0,
                                        child: buildImageWidget(),
                                      ),
                                      Positioned(
                                        top: 40,
                                        right: 20,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isImage
                            ? buildImageWidget(
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                color: themeProvider.borderColor,
                                alignment: Alignment.center,
                                child: Icon(
                                  ext == 'pdf'
                                      ? Icons.picture_as_pdf
                                      : Icons.insert_drive_file,
                                  color: themeProvider.subtitleColor,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: InkWell(
                        onTap: () => onRemove(index),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(
                            Icons.close,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}