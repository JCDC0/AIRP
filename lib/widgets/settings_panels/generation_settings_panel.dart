import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../settings_slider.dart';

class GenerationSettingsPanel extends StatelessWidget {
  const GenerationSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSlider(
          title: "(Msg History) Limit",
          value: chatProvider.historyLimit.toDouble(),
          min: 2,
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
          style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
        const Divider(),

        // --- REASONING MODE ---
        const SizedBox(height: 10),
         Text("Reasoning / Thinking Effort", style: TextStyle(fontWeight: FontWeight.bold, fontSize: scaleProvider.systemFontSize, shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.white, blurRadius: 10)] : [])),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
            boxShadow: themeProvider.enableBloom ? [BoxShadow(color: themeProvider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : [],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: chatProvider.reasoningEffort,
              dropdownColor: const Color(0xFF2C2C2C),
              icon: Icon(Icons.psychology, color: themeProvider.appThemeColor),
              items: [
                DropdownMenuItem(value: "none", child: Text("Disabled (None)", style: TextStyle(fontSize: scaleProvider.systemFontSize))),
                DropdownMenuItem(value: "low", child: Text("Low / Minimal", style: TextStyle(fontSize: scaleProvider.systemFontSize))),
                DropdownMenuItem(value: "medium", child: Text("Medium", style: TextStyle(fontSize: scaleProvider.systemFontSize))),
                DropdownMenuItem(value: "high", child: Text("High / Deep Think", style: TextStyle(fontSize: scaleProvider.systemFontSize))),
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
          style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
        const Divider(),
        
        // --- TEMPERATURE ---
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

        // --- TOP P ---
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

        // --- TOP K ---
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

        // --- MAX OUTPUT TOKENS ---
        SettingsSlider(
          title: "Max Output Tokens",
          value: chatProvider.maxOutputTokens.toDouble(),
          min: 256,
          max: 32768,
          activeColor: Colors.blueAccent,
          isInt: true,
          fontSize: scaleProvider.systemFontSize,
          onChanged: (val) {
            chatProvider.setMaxOutputTokens(val.toInt());
            chatProvider.saveSettings();
          },
        ),
        const Divider(height: 5),
      ],
    );
  }
}
