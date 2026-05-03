import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scale_provider.dart';
import 'settings_slider.dart';

/// A panel for configuring AI model generation parameters.
///
/// This panel provides controls for message history limits, reasoning effort,
/// temperature, sampling parameters (Top P/K), and output token limits.
class GenerationSettingsPanel extends StatefulWidget {
  const GenerationSettingsPanel({super.key});

  @override
  State<GenerationSettingsPanel> createState() =>
      _GenerationSettingsPanelState();
}

class _GenerationSettingsPanelState extends State<GenerationSettingsPanel> {
  Future<bool> _confirmEnableRawEdit(
    BuildContext context,
    ThemeProvider themeProvider,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text(
          'Enable Raw Reasoning Edit?',
          style: TextStyle(color: themeProvider.textColor),
        ),
        content: Text(
          'This allows editing the full assistant block, including <think> tags. '
          'Improper edits may corrupt context and reduce model quality.',
          style: TextStyle(color: themeProvider.subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  String _formatBackupTimestamp(int? ts) {
    if (ts == null) return 'No backup metadata available.';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return 'Latest backup: ${dt.toLocal()}';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Message History",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: vfxProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withValues(
                          alpha: 0.9,
                        ),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
          ),
          subtitle: Text(
            "Limits conversation context",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize * 0.8,
              color: Colors.grey,
            ),
          ),
          value: settingsProvider.enableMsgHistory,
          activeThumbColor: Colors.greenAccent,
          onChanged: (val) {
            settingsProvider.setEnableMsgHistory(val);
            chatProvider.saveSettings();
          },
        ),

        Opacity(
          opacity: settingsProvider.enableMsgHistory ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !settingsProvider.enableMsgHistory,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsSlider(
                  title: "(Msg History) Limit",
                  value: settingsProvider.historyLimit.toDouble(),
                  min: 0,
                  max: 2000,
                  divisions: 499,
                  activeColor: Colors.greenAccent,
                  isInt: true,
                  fontSize: scaleProvider.systemFontSize,
                  onChanged: (val) {
                    settingsProvider.setHistoryLimit(val.toInt());
                    chatProvider.saveSettings();
                  },
                ),
                Text(
                  "Note: Lower this if you get 'Context Window Exceeded' errors.",
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.8,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Reasoning Mode",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: vfxProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withValues(
                          alpha: 0.9,
                        ),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
          ),
          subtitle: Text(
            "Enables thinking models",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize * 0.8,
              color: Colors.grey,
            ),
          ),
          value: settingsProvider.enableReasoning,
          activeThumbColor: Colors.purpleAccent,
          onChanged: (val) {
            settingsProvider.setEnableReasoning(val);
            if (val && settingsProvider.reasoningEffort == "none") {
              settingsProvider.setReasoningEffort("medium");
            }
            chatProvider.saveSettings();
          },
        ),

        Opacity(
          opacity: settingsProvider.enableReasoning ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !settingsProvider.enableReasoning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Reasoning / Thinking Effort",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: themeProvider.containerFillColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: vfxProvider.enableBloom
                          ? themeProvider.bloomGlowColor.withValues(alpha: 0.5)
                          : themeProvider.borderColor,
                    ),
                    boxShadow: vfxProvider.enableBloom
                        ? [
                            BoxShadow(
                              color: themeProvider.bloomGlowColor.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: settingsProvider.reasoningEffort,
                      dropdownColor: themeProvider.dropdownColor,
                      icon: Icon(
                        Icons.psychology,
                        color: themeProvider.textColor,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: "none",
                          child: Text(
                            "Disabled (None)",
                            style: TextStyle(
                              fontSize: scaleProvider.systemFontSize,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: "low",
                          child: Text(
                            "Low / Minimal",
                            style: TextStyle(
                              fontSize: scaleProvider.systemFontSize,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: "medium",
                          child: Text(
                            "Medium",
                            style: TextStyle(
                              fontSize: scaleProvider.systemFontSize,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: "high",
                          child: Text(
                            "High / Deep Think",
                            style: TextStyle(
                              fontSize: scaleProvider.systemFontSize,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          settingsProvider.setReasoningEffort(val);
                          chatProvider.saveSettings();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Controls the depth of thought (Thinking Models Only).",
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.8,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Reasoning Efficiency",
            style: TextStyle(fontSize: scaleProvider.systemFontSize),
          ),
          subtitle: Text(
            "Strip <think> blocks from stored sessions and outbound context (disables persistence)",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize * 0.8,
              color: Colors.grey,
            ),
          ),
          value: settingsProvider.enableReasoningEfficiency,
          activeThumbColor: Colors.tealAccent,
          onChanged: (val) {
            settingsProvider.setEnableReasoningEfficiency(val);
            chatProvider.saveSettings();
          },
        ),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Persist Reasoning Blocks",
            style: TextStyle(fontSize: scaleProvider.systemFontSize),
          ),
          subtitle: Text(
            "Keep think blocks in local JSON (turns efficiency mode off)",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize * 0.8,
              color: Colors.grey,
            ),
          ),
          value: settingsProvider.persistReasoningBlocks,
          activeThumbColor: Colors.cyanAccent,
          onChanged: (val) {
            settingsProvider.setPersistReasoningBlocks(val);
            chatProvider.saveSettings();
          },
        ),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Developer Mode",
            style: TextStyle(fontSize: scaleProvider.systemFontSize),
          ),
          subtitle: Text(
            "Unlock advanced reasoning controls",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize * 0.8,
              color: Colors.grey,
            ),
          ),
          value: settingsProvider.enableDeveloperMode,
          activeThumbColor: Colors.amberAccent,
          onChanged: (val) {
            settingsProvider.setEnableDeveloperMode(val);
            chatProvider.saveSettings();
          },
        ),

        Opacity(
          opacity: settingsProvider.enableDeveloperMode ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !settingsProvider.enableDeveloperMode,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Raw Reasoning Edit",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                  subtitle: Text(
                    "Allow editing full assistant block including <think> tags",
                    style: TextStyle(
                      fontSize: scaleProvider.systemFontSize * 0.8,
                      color: Colors.grey,
                    ),
                  ),
                  value: settingsProvider.enableRawReasoningEdit,
                  activeThumbColor: Colors.orangeAccent,
                  onChanged: (val) async {
                    if (!val) {
                      settingsProvider.setEnableRawReasoningEdit(false);
                      await chatProvider.saveSettings();
                      return;
                    }

                    var allow = true;
                    if (!settingsProvider.rawReasoningEditWarningAcknowledged) {
                      allow = await _confirmEnableRawEdit(
                        context,
                        themeProvider,
                      );
                    }

                    if (!allow) return;

                    if (!settingsProvider.rawReasoningEditWarningAcknowledged) {
                      settingsProvider.acknowledgeRawEditWarning();
                    }

                    settingsProvider.setEnableRawReasoningEdit(true);
                    await chatProvider.saveSettings();
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FutureBuilder<bool>(
                    future: chatProvider.hasSessionsBackup(),
                    builder: (context, hasBackupSnap) {
                      final hasBackup = hasBackupSnap.data ?? false;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: hasBackup
                                ? () async {
                                    final restored = await chatProvider
                                        .restoreLatestSessionsBackup();
                                    if (!context.mounted) return;
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          restored
                                              ? 'Restored latest session backup.'
                                              : 'No valid backup found to restore.',
                                        ),
                                        duration: const Duration(
                                          milliseconds: 1400,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.restore),
                            label: const Text('Restore Latest Session Backup'),
                          ),
                          FutureBuilder<int?>(
                            future: chatProvider
                                .getLatestSessionsBackupTimestamp(),
                            builder: (context, tsSnap) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Text(
                                  _formatBackupTimestamp(tsSnap.data),
                                  style: TextStyle(
                                    fontSize:
                                        scaleProvider.systemFontSize * 0.75,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Generation Settings",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: vfxProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withValues(
                          alpha: 0.9,
                        ),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
          ),
          subtitle: Text(
            "Temperature, Top P, Top K controls",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize * 0.8,
              color: Colors.grey,
            ),
          ),
          value: settingsProvider.enableGenerationSettings,
          activeThumbColor: Colors.orangeAccent,
          onChanged: (val) {
            settingsProvider.setEnableGenerationSettings(val);
            chatProvider.saveSettings();
          },
        ),

        Opacity(
          opacity: settingsProvider.enableGenerationSettings ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !settingsProvider.enableGenerationSettings,
            child: Column(
              children: [
                SettingsSlider(
                  title: "Temperature (Creativity)",
                  value: settingsProvider.temperature,
                  min: 0.0,
                  max: 2.0,
                  divisions: 40,
                  activeColor: Colors.redAccent,
                  fontSize: scaleProvider.systemFontSize,
                  onChanged: (val) {
                    settingsProvider.setTemperature(val);
                    chatProvider.saveSettings();
                  },
                ),

                SettingsSlider(
                  title: "Top P (Nucleus Sampling)",
                  value: settingsProvider.topP,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: Colors.purpleAccent,
                  fontSize: scaleProvider.systemFontSize,
                  onChanged: (val) {
                    settingsProvider.setTopP(val);
                    chatProvider.saveSettings();
                  },
                ),

                SettingsSlider(
                  title: "Top K (Vocabulary Size)",
                  value: settingsProvider.topK.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  activeColor: Colors.orangeAccent,
                  isInt: true,
                  fontSize: scaleProvider.systemFontSize,
                  onChanged: (val) {
                    settingsProvider.setTopK(val.toInt());
                    chatProvider.saveSettings();
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Max Output Tokens",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: vfxProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withValues(
                          alpha: 0.9,
                        ),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
          ),
          subtitle: Text(
            "Limits response length",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize * 0.8,
              color: Colors.grey,
            ),
          ),
          value: settingsProvider.enableMaxOutputTokens,
          activeThumbColor: Colors.blueAccent,
          onChanged: (val) {
            settingsProvider.setEnableMaxOutputTokens(val);
            chatProvider.saveSettings();
          },
        ),

        Opacity(
          opacity: settingsProvider.enableMaxOutputTokens ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !settingsProvider.enableMaxOutputTokens,
            child: SettingsSlider(
              title: "Max Output Tokens",
              value: settingsProvider.maxOutputTokens.toDouble(),
              min: 256,
              max: 8192,
              activeColor: Colors.blueAccent,
              isInt: true,
              fontSize: scaleProvider.systemFontSize,
              onChanged: (val) {
                settingsProvider.setMaxOutputTokens(val.toInt());
                chatProvider.saveSettings();
              },
            ),
          ),
        ),
        const Divider(height: 5),
      ],
    );
  }
}
