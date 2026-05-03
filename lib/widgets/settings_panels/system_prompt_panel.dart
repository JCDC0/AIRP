import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';

/// A unified panel for managing the main system prompt.
///
/// Layout (top to bottom):
///   1. Preset Title field
///   2. Prompt textarea — bordered, no overlaid controls
///   3. Save button row — placed below the textarea
///   4. Library Management — chips with load + delete per entry
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

    // Try to pre-fill the title by matching against saved prompts.
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

  void _saveToLibrary(ChatProvider chatProvider) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title before saving.')),
      );
      return;
    }
    chatProvider.saveCurrentSystemPrompt(title);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("'$title' saved to library.")),
    );
    setState(() {}); // refresh chips
  }

  void _loadPrompt(ChatProvider chatProvider, SystemPromptData p) {
    chatProvider.setSystemInstruction(p.content);
    _titleController.text = p.title;
    _promptController.text = p.content;
    chatProvider.saveSettings(showConfirmation: false);
    setState(() {});
  }

  void _deletePrompt(ChatProvider chatProvider, SystemPromptData p) {
    showDialog(
      context: context,
      builder: (ctx) {
        final tp = Provider.of<ThemeProvider>(ctx, listen: false);
        final sp = Provider.of<ScaleProvider>(ctx, listen: false);
        final fs = sp.systemFontSize;
        return AlertDialog(
          backgroundColor: tp.dropdownColor,
          title: Text(
            'Delete prompt?',
            style: TextStyle(color: Colors.redAccent, fontSize: fs),
          ),
          content: Text(
            "'${p.title}' will be removed from the library.",
            style: TextStyle(color: tp.subtitleColor, fontSize: fs * 0.85),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(fontSize: fs * 0.85)),
            ),
            TextButton(
              onPressed: () {
                chatProvider.deletePromptFromLibrary(p.title);
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("'${p.title}' deleted.")),
                );
              },
              child: Text(
                'DELETE',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: fs * 0.85,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    _syncControllers(chatProvider);

    final fs = scaleProvider.systemFontSize;
    final useBloom = vfxProvider.enableBloom;
    final glowColor = themeProvider.bloomGlowColor;
    final borderColor = useBloom
        ? glowColor.withValues(alpha: 0.55)
        : themeProvider.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Preset Title ────────────────────────────────────────────────
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Preset Title',
            hintText: 'Name this prompt…',
            labelStyle: TextStyle(fontSize: fs * 0.8),
            hintStyle: TextStyle(fontSize: fs * 0.8, color: themeProvider.hintColor),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: useBloom ? glowColor : themeProvider.textColor,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
            isDense: true,
          ),
          style: TextStyle(fontSize: fs * 0.9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // ── 2. Prompt Textarea — clearly bordered ──────────────────────────
        TextField(
          controller: _promptController,
          maxLines: 12,
          minLines: 5,
          onChanged: (val) {
            chatProvider.setSystemInstruction(val.trim());
            chatProvider.saveSettings(showConfirmation: false);
          },
          decoration: InputDecoration(
            hintText: 'Enter system instructions, persona, or rules…',
            hintStyle: TextStyle(fontSize: fs * 0.8, color: themeProvider.hintColor),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: useBloom ? glowColor : themeProvider.textColor,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: themeProvider.containerFillColor,
          ),
          style: TextStyle(fontSize: fs * 0.9),
        ),
        const SizedBox(height: 8),

        // ── 3. Save Button — below the textarea ────────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => _saveToLibrary(chatProvider),
            icon: Icon(Icons.save_outlined, size: fs * 1.1),
            label: Text('Save to Library', style: TextStyle(fontSize: fs * 0.85)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              side: const BorderSide(color: Colors.blueAccent),
              padding: EdgeInsets.symmetric(horizontal: fs, vertical: fs * 0.4),
            ),
          ),
        ),

        // ── 4. Library Management ──────────────────────────────────────────
        if (chatProvider.savedSystemPrompts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(color: themeProvider.borderColor),
          const SizedBox(height: 4),
          Text(
            'Library Management',
            style: TextStyle(
              fontSize: fs * 0.8,
              color: themeProvider.subtitleColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chatProvider.savedSystemPrompts.map((p) {
              final isActive = _titleController.text == p.title &&
                  _promptController.text.trim() == p.content.trim();
              return Container(
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.blueAccent.withValues(alpha: 0.15)
                      : themeProvider.containerFillDarkColor,
                  border: Border.all(
                    color: isActive
                        ? Colors.blueAccent.withValues(alpha: 0.6)
                        : themeProvider.borderColor,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Load tap area
                    InkWell(
                      onTap: () => _loadPrompt(chatProvider, p),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(fs * 0.7, fs * 0.3, fs * 0.3, fs * 0.3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActive)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.check_circle,
                                  size: fs * 0.85,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            Text(
                              p.title,
                              style: TextStyle(
                                fontSize: fs * 0.78,
                                color: isActive
                                    ? Colors.blueAccent
                                    : themeProvider.textColor,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Delete button
                    InkWell(
                      onTap: () => _deletePrompt(chatProvider, p),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(fs * 0.1, fs * 0.3, fs * 0.5, fs * 0.3),
                        child: Icon(
                          Icons.close,
                          size: fs * 0.8,
                          color: themeProvider.faintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 8),
      ],
    );
  }
}
