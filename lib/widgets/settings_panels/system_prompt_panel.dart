import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scale_provider.dart';

/// A panel for editing the system instruction and advanced prompts.
class SystemPromptPanel extends StatefulWidget {
  const SystemPromptPanel({super.key});

  @override
  State<SystemPromptPanel> createState() => _SystemPromptPanelState();
}

class _SystemPromptPanelState extends State<SystemPromptPanel> {
  late TextEditingController _mainPromptController;
  late TextEditingController _advancedPromptController;
  late TextEditingController _promptTitleController;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _mainPromptController = TextEditingController(
      text: chatProvider.systemInstruction,
    );
    _advancedPromptController = TextEditingController(
      text: chatProvider.advancedSystemInstruction,
    );
    _promptTitleController = TextEditingController();
  }

  @override
  void dispose() {
    _mainPromptController.dispose();
    _advancedPromptController.dispose();
    _promptTitleController.dispose();
    super.dispose();
  }

  void _syncControllers(ChatProvider chatProvider) {
    if (_mainPromptController.text != chatProvider.systemInstruction) {
      _mainPromptController.text = chatProvider.systemInstruction;
    }
    if (_advancedPromptController.text != chatProvider.advancedSystemInstruction) {
      _advancedPromptController.text = chatProvider.advancedSystemInstruction;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    _syncControllers(chatProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main System Instruction ──────────────────────────────────────────
        Text(
          "Base System Instruction",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize,
            shadows: vfxProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: _mainPromptController,
          maxLines: 8,
          onChanged: (val) {
            chatProvider.setSystemInstruction(val.trim());
            chatProvider.saveSettings(showConfirmation: false);
          },
          decoration: InputDecoration(
            hintText: "Enter the persona or base instructions for the AI...",
            border: const OutlineInputBorder(),
            filled: true,
            isDense: true,
            hintStyle: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
          ),
          style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.9),
        ),
        const SizedBox(height: 20),

        // ── Advanced System Prompt ───────────────────────────────────────────
        Opacity(
          opacity: settingsProvider.enableAdvancedSystemPrompt ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !settingsProvider.enableAdvancedSystemPrompt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Advanced System Prompt (Post-Lore)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                    fontSize: scaleProvider.systemFontSize,
                    shadows: vfxProvider.enableBloom
                        ? [
                            Shadow(
                              color: themeProvider.bloomGlowColor,
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: _advancedPromptController,
                  maxLines: 12,
                  onChanged: (val) {
                    chatProvider.setAdvancedSystemInstruction(val.trim());
                    chatProvider.saveSettings(showConfirmation: false);
                  },
                  decoration: InputDecoration(
                    hintText: "Formatting rules, depth prompts, etc...",
                    border: const OutlineInputBorder(),
                    filled: true,
                    isDense: true,
                    hintStyle: TextStyle(
                      fontSize: scaleProvider.systemFontSize * 0.8,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.9,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Prompt Saving Section ────────────────────────────────────────────
        Text(
          "Save Current Prompts",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promptTitleController,
                decoration: const InputDecoration(
                  hintText: "Preset Title...",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(fontSize: scaleProvider.systemFontSize),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.save_as, color: Colors.blueAccent),
              onPressed: () {
                final title = _promptTitleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Enter a title first")),
                  );
                  return;
                }
                chatProvider.saveCurrentSystemPrompt(title);
                _promptTitleController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Prompt saved to library")),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
