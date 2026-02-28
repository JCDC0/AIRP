import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';

/// A panel for editing the main system prompt and managing the prompt library.
///
/// Character cards, custom rules/presets, regex scripts, and formatting are
/// now in their own dedicated panels (see character_card_panel.dart,
/// preset_panel.dart, regex_panel.dart, formatting_panel.dart).
class SystemPromptPanel extends StatefulWidget {
  /// Controller for the main system instruction text.
  final TextEditingController mainPromptController;

  /// Controller for advanced behavioral instructions (managed by PresetPanel).
  final TextEditingController advancedPromptController;

  /// Controller for the title of the current prompt preset.
  final TextEditingController promptTitleController;

  /// Callback triggered when any prompt content changes.
  final VoidCallback onPromptChanged;

  const SystemPromptPanel({
    super.key,
    required this.mainPromptController,
    required this.advancedPromptController,
    required this.promptTitleController,
    required this.onPromptChanged,
  });

  @override
  State<SystemPromptPanel> createState() => _SystemPromptPanelState();
}

class _SystemPromptPanelState extends State<SystemPromptPanel> {
  // ---------------------------------------------------------------------------
  // Library management
  // ---------------------------------------------------------------------------

  void _handleSavePreset() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.setSystemInstruction(widget.mainPromptController.text);
    chatProvider.savePromptToLibrary(
      widget.promptTitleController.text,
      widget.mainPromptController.text,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Saved '${widget.promptTitleController.text}' to Library!",
            ),
          ),
        );
      }
    });
  }

  void _confirmDeletePromptFromLibrary(String title) {
    if (title.isEmpty) return;

    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text("Delete '$title'?",
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: scaleProvider.systemFontSize)),
        content: Text(
            "Are you sure you want to remove this preset from your library?",
            style: TextStyle(
                color: themeProvider.subtitleColor,
                fontSize: scaleProvider.systemFontSize * 0.8)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final chatProvider =
                  Provider.of<ChatProvider>(context, listen: false);
              chatProvider.deletePromptFromLibrary(title);
              widget.promptTitleController.clear();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Deleted from Library")),
              );
            },
            child: const Text("Delete",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Clipboard helpers
  // ---------------------------------------------------------------------------

  void _copyToClipboard() {
    final text = widget.mainPromptController.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Copied main prompt to Clipboard!"),
          duration: Duration(milliseconds: 600),
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        widget.mainPromptController.text = data!.text!;
      });
      widget.onPromptChanged();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Opacity(
      opacity: chatProvider.enableSystemPrompt ? 1.0 : 0.5,
      child: AbsorbPointer(
        absorbing: !chatProvider.enableSystemPrompt,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Library / Preset Dropdown ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: themeProvider.containerFillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: themeProvider.enableBloom
                        ? themeProvider.bloomGlowColor.withOpacity(0.5)
                        : themeProvider.borderColor,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: Text(
                      "Load Main Prompt...",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: scaleProvider.systemFontSize * 0.8,
                      ),
                    ),
                    dropdownColor: themeProvider.dropdownColor,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: themeProvider.textColor,
                    ),
                    value: null,
                    items: [
                      DropdownMenuItem<String>(
                        value: "CREATE_NEW",
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add,
                              color: Colors.greenAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Create New",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: scaleProvider.systemFontSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...chatProvider.savedSystemPrompts.map((prompt) {
                        return DropdownMenuItem<String>(
                          value: prompt.title,
                          child: Text(
                            prompt.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: scaleProvider.systemFontSize,
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue == "CREATE_NEW") {
                        widget.promptTitleController.clear();
                        widget.mainPromptController.clear();
                        widget.onPromptChanged();
                      } else if (newValue != null) {
                        final prompt = chatProvider.savedSystemPrompts
                            .firstWhere((p) => p.title == newValue);
                        widget.mainPromptController.text = prompt.content;
                        widget.promptTitleController.text = prompt.title;
                        widget.onPromptChanged();
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Delete from Library
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text("Clear from Library",
                      style: TextStyle(fontSize: 12)),
                  onPressed: () => _confirmDeletePromptFromLibrary(
                    widget.promptTitleController.text,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Prompt Title
              TextField(
                controller: widget.promptTitleController,
                decoration: InputDecoration(
                  labelText: "Prompt Title",
                  labelStyle: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: scaleProvider.systemFontSize * 0.8,
                  ),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: themeProvider.containerFillDarkColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              // Main Prompt Input
              TextField(
                controller: widget.mainPromptController,
                onChanged: (_) => widget.onPromptChanged(),
                maxLines: 8,
                minLines: 3,
                decoration: InputDecoration(
                  labelText: "Main System Prompt (Base Rules)",
                  hintText: "Enter the core roleplay rules here...",
                  hintStyle: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.8,
                  ),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: themeProvider.containerFillColor,
                ),
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize,
                ),
              ),

              const SizedBox(height: 8),

              // Copy / Paste / Save
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: themeProvider.textColor,
                      ),
                      onPressed: _copyToClipboard,
                      tooltip: 'Copy to Clipboard',
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.paste,
                        size: 18,
                        color: Colors.greenAccent,
                      ),
                      onPressed: _pasteFromClipboard,
                      tooltip: 'Paste from Clipboard',
                      padding: const EdgeInsets.all(8),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: themeProvider.textColor,
                        side: BorderSide(color: themeProvider.textColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: _handleSavePreset,
                      child: const Text("Save to Library"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
