import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';

/// A panel for configuring API keys and local network connectivity.
///
/// This panel dynamically switches between an API key field and a local
/// server address field based on the selected AI provider.
class ApiSettingsPanel extends StatelessWidget {
  /// Controller for the API key text field.
  final TextEditingController apiKeyController;

  /// Controller for the local server IP address text field.
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
        Text(
          "API Key (BYOK)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize,
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        const SizedBox(height: 5),

        if (chatProvider.currentProvider != AiProvider.local) ...[
          TextField(
            controller: apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: "Paste AI Studio Key...",
              border: OutlineInputBorder(
                borderSide: themeProvider.enableBloom
                    ? BorderSide(color: themeProvider.bloomGlowColor)
                    : const BorderSide(),
              ),
              enabledBorder: themeProvider.enableBloom
                  ? OutlineInputBorder(
                      borderSide: BorderSide(
                        color: themeProvider.bloomGlowColor.withOpacity(0.5),
                      ),
                    )
                  : const OutlineInputBorder(),
              filled: true,
              isDense: true,
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
              labelStyle: TextStyle(
                color: Colors.greenAccent,
                fontSize: scaleProvider.systemFontSize,
              ),
              border: const OutlineInputBorder(),
              filled: true,
              isDense: true,
            ),
            style: TextStyle(fontSize: scaleProvider.systemFontSize - 2),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              "Ensure your local AI is listening on Network (0.0.0.0)",
              style: TextStyle(
                fontSize: scaleProvider.systemFontSize - 4,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
