import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scale_provider.dart';
import '../../services/strategies/ai_provider_strategy.dart';
import '../../services/strategies/strategy_resolver.dart';
import '../../models/chat_models.dart';
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
  AiProviderStrategy _strategyFor(AiProvider provider) {
    return StrategyResolver.resolve(provider);
  }

  /// Returns the stored reasoning effort if the current provider supports it;
  /// otherwise falls back to the closest supported value.
  String _effectiveReasoningEffort(String stored, AiProvider provider) {
    final strategy = _strategyFor(provider);
    final supported =
        strategy.reasoningEffortOptions.map((o) => o.apiValue).toSet();
    if (supported.contains(stored)) return stored;
    // Step down to the nearest level the provider actually accepts rather
    // than silently reading as Disabled: DeepSeek has no `medium`, NVIDIA
    // rejects `xhigh`, and Ollama accepts neither `xhigh` nor `max`.
    const fallbacks = <String, List<String>>{
      'xhigh': ['max', 'high'],
      'max': ['xhigh', 'high'],
      'medium': ['high', 'low'],
      'low': ['low', 'medium'],
      'high': ['high', 'max'],
    };
    for (final candidate in fallbacks[stored] ?? const <String>[]) {
      if (supported.contains(candidate)) return candidate;
    }
    return 'none';
  }

  List<DropdownMenuItem<String>> _buildReasoningEffortItems(
    AiProvider provider,
    double fontSize,
  ) {
    final strategy = _strategyFor(provider);
    return strategy.reasoningEffortOptions
        .map(
          (option) => DropdownMenuItem(
            value: option.apiValue,
            child: Text(
              option.label,
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        )
        .toList();
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
            settingsProvider.markDirty();
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
                    settingsProvider.markDirty();
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
            settingsProvider.markDirty();
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
                      value: _effectiveReasoningEffort(
                        settingsProvider.reasoningEffort,
                        chatProvider.currentProvider,
                      ),
                      dropdownColor: themeProvider.dropdownColor,
                      icon: Icon(
                        Icons.psychology,
                        color: themeProvider.textColor,
                      ),
                      items: _buildReasoningEffortItems(
                        chatProvider.currentProvider,
                        scaleProvider.systemFontSize,
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          settingsProvider.setReasoningEffort(val);
                          settingsProvider.markDirty();
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
            settingsProvider.markDirty();
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
                    settingsProvider.markDirty();
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
                    settingsProvider.markDirty();
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
                    settingsProvider.markDirty();
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
            settingsProvider.markDirty();
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
                settingsProvider.markDirty();
              },
            ),
          ),
        ),
        const Divider(height: 5),
      ],
    );
  }
}
