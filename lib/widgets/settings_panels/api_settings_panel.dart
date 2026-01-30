import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';

class ApiSettingsPanel extends StatelessWidget {
  final TextEditingController apiKeyController;
  final TextEditingController localIpController;

  const ApiSettingsPanel({
    super.key,
    required this.apiKeyController,
    required this.localIpController,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("API Key (BYOK)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeProvider.appThemeColor,
            fontSize: scaleProvider.systemFontSize,
            shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [],
          )
        ),
        const SizedBox(height: 5),
        
        if (chatProvider.currentProvider != AiProvider.local) ...[
          TextField(
            controller: apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: "Paste AI Studio Key...",
              border: OutlineInputBorder(
                borderSide: themeProvider.enableBloom ? BorderSide(color: themeProvider.appThemeColor) : const BorderSide(),
              ),
              enabledBorder: themeProvider.enableBloom 
                ? OutlineInputBorder(borderSide: BorderSide(color: themeProvider.appThemeColor.withOpacity(0.5)))
                : const OutlineInputBorder(),
              filled: true, isDense: true,
            ),
            style: TextStyle(fontSize: scaleProvider.systemFontSize - 2),
          ),
          const SizedBox(height: 20),
        ] else ...[
          TextField(
            controller: localIpController,
            decoration: InputDecoration(
              hintText: "http://192.168.1.X:1234/v1",
              labelText: "Local Server Address",
              labelStyle: TextStyle(color: Colors.greenAccent, fontSize: scaleProvider.systemFontSize),
              border: const OutlineInputBorder(),
              filled: true, isDense: true
            ),
            style: TextStyle(fontSize: scaleProvider.systemFontSize - 2),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text("Ensure your local AI is listening on Network (0.0.0.0)", style: TextStyle(fontSize: scaleProvider.systemFontSize - 4, color: Colors.grey)),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
