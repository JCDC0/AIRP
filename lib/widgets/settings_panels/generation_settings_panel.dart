import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
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
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
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
              shadows: themeProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withOpacity(0.9),
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
          value: chatProvider.enableMsgHistory,
          activeThumbColor: Colors.greenAccent,
          onChanged: (val) {
            chatProvider.setEnableMsgHistory(val);
            chatProvider.saveSettings();
          },
        ),

        Opacity(
          opacity: chatProvider.enableMsgHistory ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !chatProvider.enableMsgHistory,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsSlider(
                  title: "(Msg History) Limit",
                  value: chatProvider.historyLimit.toDouble(),
                  min: 0,
                  max: 2000,
                  divisions: 499,
                  activeColor: Colors.greenAccent,
                  isInt: true,
                  fontSize: scaleProvider.systemFontSize,
                  onChanged: (val) {
                    chatProvider.setHistoryLimit(val.toInt());
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
              shadows: themeProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withOpacity(0.9),
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
          value: chatProvider.enableReasoning,
          activeThumbColor: Colors.purpleAccent,
          onChanged: (val) {
            chatProvider.setEnableReasoning(val);
            if (val && chatProvider.reasoningEffort == "none") {
              chatProvider.setReasoningEffort("medium");
            }
            chatProvider.saveSettings();
          },
        ),

        Opacity(
          opacity: chatProvider.enableReasoning ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !chatProvider.enableReasoning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Reasoning / Thinking Effort",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                    shadows: themeProvider.enableBloom
                        ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
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
                      color: themeProvider.enableBloom
                          ? themeProvider.bloomGlowColor.withOpacity(0.5)
                          : themeProvider.borderColor,
                    ),
                    boxShadow: themeProvider.enableBloom
                        ? [
                            BoxShadow(
                              color: themeProvider.bloomGlowColor.withOpacity(
                                0.1,
                              ),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: chatProvider.reasoningEffort,
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
                          chatProvider.setReasoningEffort(val);
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
            "Generation Settings",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: themeProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withOpacity(0.9),
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
          value: chatProvider.enableGenerationSettings,
          activeThumbColor: Colors.orangeAccent,
          onChanged: (val) {
            chatProvider.setEnableGenerationSettings(val);
            chatProvider.saveSettings();
          },
        ),

        Opacity(
          opacity: chatProvider.enableGenerationSettings ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !chatProvider.enableGenerationSettings,
            child: Column(
              children: [
                SettingsSlider(
                  title: "Temperature (Creativity)",
                  value: chatProvider.temperature,
                  min: 0.0,
                  max: 2.0,
                  divisions: 40,
                  activeColor: Colors.redAccent,
                  fontSize: scaleProvider.systemFontSize,
                  onChanged: (val) {
                    chatProvider.setTemperature(val);
                    chatProvider.saveSettings();
                  },
                ),

                SettingsSlider(
                  title: "Top P (Nucleus Sampling)",
                  value: chatProvider.topP,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: Colors.purpleAccent,
                  fontSize: scaleProvider.systemFontSize,
                  onChanged: (val) {
                    chatProvider.setTopP(val);
                    chatProvider.saveSettings();
                  },
                ),

                SettingsSlider(
                  title: "Top K (Vocabulary Size)",
                  value: chatProvider.topK.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  activeColor: Colors.orangeAccent,
                  isInt: true,
                  fontSize: scaleProvider.systemFontSize,
                  onChanged: (val) {
                    chatProvider.setTopK(val.toInt());
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
              shadows: themeProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withOpacity(0.9),
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
          value: chatProvider.enableMaxOutputTokens,
          activeThumbColor: Colors.blueAccent,
          onChanged: (val) {
            chatProvider.setEnableMaxOutputTokens(val);
            chatProvider.saveSettings();
          },
        ),

        Opacity(
          opacity: chatProvider.enableMaxOutputTokens ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !chatProvider.enableMaxOutputTokens,
            child: SettingsSlider(
              title: "Max Output Tokens",
              value: chatProvider.maxOutputTokens.toDouble(),
              min: 256,
              max: 8192,
              activeColor: Colors.blueAccent,
              isInt: true,
              fontSize: scaleProvider.systemFontSize,
              onChanged: (val) {
                chatProvider.setMaxOutputTokens(val.toInt());
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
