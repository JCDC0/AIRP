import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';

class UpdateSettingsPanel extends StatelessWidget {
  const UpdateSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final updateProvider = Provider.of<UpdateProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    if (!updateProvider.updateAvailable &&
        !updateProvider.isDownloading &&
        !updateProvider.isChecking &&
        updateProvider.error == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (updateProvider.isChecking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Checking for updates...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: scaleProvider.systemFontSize - 2,
                    ),
                  ),
                ],
              ),
            ),
          if (updateProvider.error != null && !updateProvider.updateAvailable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      updateProvider.error!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: scaleProvider.systemFontSize - 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (updateProvider.updateAvailable && !updateProvider.isDownloading) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.system_update,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'v${updateProvider.latestVersion} available',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: scaleProvider.systemFontSize,
                        ),
                      ),
                    ],
                  ),
                  if (updateProvider.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: Markdown(
                        data: updateProvider.releaseNotes,
                        shrinkWrap: true,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: scaleProvider.systemFontSize - 2,
                          ),
                          h1: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: scaleProvider.systemFontSize + 2,
                            fontWeight: FontWeight.bold,
                          ),
                          h2: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: scaleProvider.systemFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          h3: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: scaleProvider.systemFontSize - 1,
                            fontWeight: FontWeight.bold,
                          ),
                          listBullet: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: scaleProvider.systemFontSize - 2,
                          ),
                          code: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: scaleProvider.systemFontSize - 3,
                            backgroundColor: Colors.black26,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Update Now'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.greenAccent,
                            side: const BorderSide(color: Colors.greenAccent),
                          ),
                          onPressed: () => updateProvider.downloadAndInstall(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => updateProvider.dismiss(),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            color: themeProvider.textColor.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => updateProvider.skipVersion(),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: themeProvider.textColor.withValues(
                              alpha: 0.4,
                            ),
                            fontSize: scaleProvider.systemFontSize - 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (updateProvider.isDownloading) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Downloading v${updateProvider.latestVersion}...',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: scaleProvider.systemFontSize - 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: updateProvider.downloadProgress,
                            backgroundColor: themeProvider.textColor.withValues(
                              alpha: 0.1,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.greenAccent,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(updateProvider.downloadProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: themeProvider.textColor,
                          fontSize: scaleProvider.systemFontSize - 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
