import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';

/// A unified panel for managing the main system prompt.
///
/// Provides a title field, the prompt content, a library for hotswapping presets,
/// and quick-save capabilities.
class SystemPromptPanel extends StatefulWidget {
  const SystemPromptPanel({super.key});

  @override
  State<SystemPromptPanel> createState() => _SystemPromptPanelState();
}

class _SystemPromptPanelState extends State<SystemPromptPanel> {
  late TextEditingController _titleController;
  late TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _titleController = TextEditingController();
    _promptController = TextEditingController(text: chatProvider.systemInstruction);
    
    // Try to match current prompt with a title from the library
    _matchTitleFromLibrary(chatProvider);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _matchTitleFromLibrary(ChatProvider provider) {
    final currentText = provider.systemInstruction.trim();
    if (currentText.isEmpty) return;

    final match = provider.savedSystemPrompts.firstWhere(
      (p) => p.content.trim() == currentText,
      orElse: () => const SystemPromptData(title: '', content: ''),
    );

    if (match.title.isNotEmpty) {
      _titleController.text = match.title;
    }
  }

  void _syncControllers(ChatProvider chatProvider) {
    if (_promptController.text != chatProvider.systemInstruction) {
      _promptController.text = chatProvider.systemInstruction;
      _matchTitleFromLibrary(chatProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    _syncControllers(chatProvider);

    final fs = scaleProvider.systemFontSize;
    final accent = themeProvider.textColor;
    final useBloom = vfxProvider.enableBloom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header with Library Dropdown ---
        Row(
          children: [
            Expanded(
              child: Text(
                "Prompt Library",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fs * 0.9,
                  color: themeProvider.subtitleColor,
                ),
              ),
            ),
            if (chatProvider.savedSystemPrompts.isNotEmpty)
              DropdownButton<SystemPromptData>(
                underline: const SizedBox(),
                icon: Icon(Icons.library_books, color: accent, size: 20),
                dropdownColor: themeProvider.dropdownColor,
                items: chatProvider.savedSystemPrompts.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(
                      p.title,
                      style: TextStyle(color: themeProvider.textColor, fontSize: fs * 0.85),
                    ),
                  );
                }).toList(),
                onChanged: (p) {
                  if (p != null) {
                    chatProvider.setSystemInstruction(p.content);
                    _titleController.text = p.title;
                    _promptController.text = p.content;
                    chatProvider.saveSettings(showConfirmation: false);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 8),

        // --- Title Field ---
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: "Preset Title",
            hintText: "Enter a title for this prompt...",
            labelStyle: TextStyle(fontSize: fs * 0.8),
            hintStyle: TextStyle(fontSize: fs * 0.8),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
            isDense: true,
          ),
          style: TextStyle(fontSize: fs * 0.9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // --- Main Prompt Field ---
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            TextField(
              controller: _promptController,
              maxLines: 12,
              minLines: 5,
              onChanged: (val) {
                chatProvider.setSystemInstruction(val.trim());
                chatProvider.saveSettings(showConfirmation: false);
              },
              decoration: InputDecoration(
                hintText: "Enter system instructions, persona, or rules...",
                hintStyle: TextStyle(fontSize: fs * 0.8),
                border: OutlineInputBorder(
                  borderSide: useBloom ? BorderSide(color: themeProvider.bloomGlowColor) : const BorderSide(),
                ),
                enabledBorder: useBloom
                    ? OutlineInputBorder(
                        borderSide: BorderSide(color: themeProvider.bloomGlowColor.withValues(alpha: 0.5)),
                      )
                    : const OutlineInputBorder(),
                filled: true,
                fillColor: themeProvider.containerFillColor,
              ),
              style: TextStyle(fontSize: fs * 0.9),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: () {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a title to save")),
                    );
                    return;
                  }
                  chatProvider.saveCurrentSystemPrompt(title);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Prompt '$title' saved!")),
                  );
                },
                icon: Icon(Icons.save, color: Colors.blueAccent, size: 24 * scaleProvider.iconScale),
                tooltip: "Save to Library",
              ),
            ),
          ],
        ),
        
        if (chatProvider.savedSystemPrompts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            "Library Management",
            style: TextStyle(fontSize: fs * 0.8, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: chatProvider.savedSystemPrompts.map((p) {
              final isCurrent = _titleController.text == p.title;
              return ActionChip(
                label: Text(p.title, style: TextStyle(fontSize: fs * 0.7)),
                onPressed: () {
                  chatProvider.setSystemInstruction(p.content);
                  _titleController.text = p.title;
                  _promptController.text = p.content;
                },
                backgroundColor: isCurrent ? Colors.blueAccent.withValues(alpha: 0.2) : null,
                avatar: isCurrent ? const Icon(Icons.check, size: 12) : null,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
