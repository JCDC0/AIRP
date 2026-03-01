import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import '../../services/library_service.dart';

/// A panel that lets users export all app state to a `.airp` file
/// and import a previously exported library.
///
/// Settings are **overwritten** on import; system prompts and
/// conversations are **concatenated** (merged without duplicates).
class LibraryPanel extends StatefulWidget {
  const LibraryPanel({super.key});

  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<LibraryPanel> {
  bool _exportConversations = true;
  bool _exportSystemPrompt = true;
  bool _exportAdvancedSystemPrompt = true;
  bool _exportGenerationParams = true;
  bool _exportLayoutScaling = true;
  bool _exportVisualsAtmosphere = true;
  bool _exportCharacterCard = true;
  bool _exportSillyTavernState = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final fontSize = scaleProvider.systemFontSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          "Export and import your app configuration as a "
          "portable .airp file.",
          style: TextStyle(
            fontSize: fontSize * 0.8,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),

        // ── Export Button ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.greenAccent,
              side: const BorderSide(color: Colors.greenAccent),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              textStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: Icon(Icons.upload_file, size: fontSize * 1.4),
            label: const Text("Export Library"),
            onPressed: () => _handleExport(context),
          ),
        ),
        const SizedBox(height: 8),

        // ── Selective export switches ──
        _buildSwitch(
          "Conversations",
          _exportConversations,
          (v) => setState(() => _exportConversations = v),
          themeProvider,
          fontSize,
        ),
        _buildSwitch(
          "System Prompt",
          _exportSystemPrompt,
          (v) => setState(() => _exportSystemPrompt = v),
          themeProvider,
          fontSize,
        ),
        _buildSwitch(
          "Advanced System Prompt",
          _exportAdvancedSystemPrompt,
          (v) => setState(() => _exportAdvancedSystemPrompt = v),
          themeProvider,
          fontSize,
        ),
        _buildSwitch(
          "Generation Parameters",
          _exportGenerationParams,
          (v) => setState(() => _exportGenerationParams = v),
          themeProvider,
          fontSize,
        ),
        _buildSwitch(
          "Layout Scaling",
          _exportLayoutScaling,
          (v) => setState(() => _exportLayoutScaling = v),
          themeProvider,
          fontSize,
        ),
        _buildSwitch(
          "Visuals & Atmosphere",
          _exportVisualsAtmosphere,
          (v) => setState(() => _exportVisualsAtmosphere = v),
          themeProvider,
          fontSize,
        ),
        _buildSwitch(
          "Character Card",
          _exportCharacterCard,
          (v) => setState(() => _exportCharacterCard = v),
          themeProvider,
          fontSize,
        ),
        _buildSwitch(
          "Lorebook / Regex / Formatting",
          _exportSillyTavernState,
          (v) => setState(() => _exportSillyTavernState = v),
          themeProvider,
          fontSize,
        ),

        const Divider(height: 24),

        // ── Import Button ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: themeProvider.textColor,
              side: BorderSide(color: themeProvider.textColor),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              textStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: Icon(Icons.download, size: fontSize * 1.4),
            label: const Text("Import Library"),
            onPressed: () => _handleImport(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "⚠ Import overwrites settings but merges prompts & chats.",
          style: TextStyle(
            fontSize: fontSize * 0.7,
            color: Colors.orangeAccent.withOpacity(0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ─── Helper: Switch Row ─────────────────────────────────────────────────

  Widget _buildSwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    ThemeProvider themeProvider,
    double fontSize,
  ) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        label,
        style: TextStyle(fontSize: fontSize * 0.85, color: themeProvider.subtitleColor),
      ),
      value: value,
      activeThumbColor: themeProvider.textColor,
      onChanged: onChanged,
    );
  }

  // ─── Export ─────────────────────────────────────────────────────────────

  Future<void> _handleExport(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);

    try {
      final options = ExportOptions(
        conversations: _exportConversations,
        systemPrompt: _exportSystemPrompt,
        advancedSystemPrompt: _exportAdvancedSystemPrompt,
        generationParams: _exportGenerationParams,
        layoutScaling: _exportLayoutScaling,
        visualsAtmosphere: _exportVisualsAtmosphere,
        characterCard: _exportCharacterCard,
        sillyTavernState: _exportSillyTavernState,
      );

      final jsonString = await LibraryService.exportLibraryAsync(
        chatProvider: chatProvider,
        themeProvider: themeProvider,
        scaleProvider: scaleProvider,
        options: options,
      );

      final bytes = utf8.encode(jsonString);

      // saveFile with bytes works on all platforms (Android, iOS, desktop)
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save AIRP Library',
        fileName: 'airp_library.airp',
        type: FileType.any,
        bytes: Uint8List.fromList(bytes),
      );

      if (outputPath == null) return; // User cancelled

      // On desktop, FilePicker may not write bytes automatically
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Library exported successfully!"),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ─── Import ─────────────────────────────────────────────────────────────

  Future<void> _handleImport(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select AIRP Library File',
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final file = File(filePath);
    if (!await file.exists()) return;

    final fileContent = await file.readAsString();

    // Parse the file to generate preview
    if (!context.mounted) return;
    final preview = _generatePreview(fileContent);

    if (preview == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid .airp file format"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Show preview dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildPreviewDialog(ctx, preview),
    );

    if (confirmed != true) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);

    final importResult = await LibraryService.importLibrary(
      fileContent: fileContent,
      chatProvider: chatProvider,
      themeProvider: themeProvider,
      scaleProvider: scaleProvider,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(importResult.message),
          backgroundColor:
              importResult.success ? Colors.greenAccent : Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ─── Preview Generation ─────────────────────────────────────────────────

  _LibraryPreview? _generatePreview(String fileContent) {
    try {
      final data = jsonDecode(fileContent) as Map<String, dynamic>;

      if (!data.containsKey('airp_library_version')) {
        return null;
      }

      // Extract conversation info
      int conversationCount = 0;
      List<String> conversationTitles = [];

      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings != null && settings['sessions'] != null) {
        final sessions = settings['sessions'] as List<dynamic>;
        conversationCount = sessions.length;
        conversationTitles = sessions
            .take(3)
            .map((s) => (s as Map<String, dynamic>)['title'] as String? ?? 'Untitled')
            .toList();
      }

      // Extract system prompts count
      int systemPromptsCount = 0;
      if (settings != null && settings['systemPrompts'] != null) {
        systemPromptsCount = (settings['systemPrompts'] as List).length;
      }

      // Determine what sections are present
      final sections = <String>[];
      if (settings != null) {
        if (settings['generation'] != null) sections.add('Generation Parameters');
        if (settings['systemInstruction'] != null || settings['advancedSystemInstruction'] != null) {
          sections.add('System Prompts');
        }
        if (settings['provider'] != null || settings['models'] != null) {
          sections.add('Model Configuration');
        }
      }
      if (data['theme'] != null) sections.add('Visuals & Atmosphere');
      if (data['scale'] != null) sections.add('Layout & Scaling');

      return _LibraryPreview(
        appVersion: data['app_version'] as String? ?? 'unknown',
        conversationCount: conversationCount,
        conversationTitles: conversationTitles,
        systemPromptsCount: systemPromptsCount,
        sections: sections,
      );
    } catch (e) {
      return null;
    }
  }

  Widget _buildPreviewDialog(BuildContext ctx, _LibraryPreview preview) {
    final themeProvider = Provider.of<ThemeProvider>(ctx);
    final scaleProvider = Provider.of<ScaleProvider>(ctx);
    final fontSize = scaleProvider.systemFontSize;

    return AlertDialog(
      backgroundColor: themeProvider.dropdownColor,
      title: Row(
        children: [
          Icon(Icons.preview, color: themeProvider.textColor, size: fontSize * 1.5),
          const SizedBox(width: 8),
          Text(
            "Import Preview",
            style: TextStyle(color: themeProvider.textColor, fontSize: fontSize + 2),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Version info
            Text(
              "From version: ${preview.appVersion}",
              style: TextStyle(
                color: Colors.grey,
                fontSize: fontSize * 0.85,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            // Conversations
            if (preview.conversationCount > 0) ...[
              _buildSectionHeader("Conversations", fontSize, themeProvider),
              Text(
                "• ${preview.conversationCount} conversation${preview.conversationCount == 1 ? '' : 's'}",
                style: TextStyle(color: themeProvider.subtitleColor, fontSize: fontSize * 0.9),
              ),
              if (preview.conversationTitles.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...preview.conversationTitles.map((title) => Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      child: Text(
                        "→ $title",
                        style: TextStyle(
                          color: themeProvider.hintColor,
                          fontSize: fontSize * 0.85,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                if (preview.conversationCount > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text(
                      "...and ${preview.conversationCount - 3} more",
                      style: TextStyle(
                        color: themeProvider.dimTextColor,
                        fontSize: fontSize * 0.85,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
            ],

            // System Prompts
            if (preview.systemPromptsCount > 0) ...[
              Text(
                "• ${preview.systemPromptsCount} saved system prompt${preview.systemPromptsCount == 1 ? '' : 's'}",
                style: TextStyle(color: themeProvider.subtitleColor, fontSize: fontSize * 0.9),
              ),
              const SizedBox(height: 12),
            ],

            // Settings sections
            if (preview.sections.isNotEmpty) ...[
              _buildSectionHeader("Settings to Update", fontSize, themeProvider),
              ...preview.sections.map((section) => Padding(
                    padding: const EdgeInsets.only(left: 0, top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.greenAccent, size: fontSize),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            section,
                            style: TextStyle(
                              color: themeProvider.subtitleColor,
                              fontSize: fontSize * 0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // Warning message
            Divider(color: themeProvider.faintestColor),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.orangeAccent, size: fontSize),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Settings will be overwritten. Conversations and system prompts will be merged (duplicates skipped). API keys are never imported.",
                    style: TextStyle(
                      color: Colors.orangeAccent.withOpacity(0.9),
                      fontSize: fontSize * 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text("Cancel", style: TextStyle(fontSize: fontSize)),
          onPressed: () => Navigator.pop(ctx, false),
        ),
        TextButton(
          child: Text(
            "Import",
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, double fontSize, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: themeProvider.textColor,
          fontSize: fontSize * 0.95,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Preview Data Class ─────────────────────────────────────────────────

class _LibraryPreview {
  final String appVersion;
  final int conversationCount;
  final List<String> conversationTitles;
  final int systemPromptsCount;
  final List<String> sections;

  _LibraryPreview({
    required this.appVersion,
    required this.conversationCount,
    required this.conversationTitles,
    required this.systemPromptsCount,
    required this.sections,
  });

}
