import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';

/// A panel for configuring API keys and network connectivity.
///
/// This panel dynamically switches between an API key field and a server
/// address field based on the selected AI provider.
class ApiSettingsPanel extends StatelessWidget {
  /// Controller for the API key text field.
  final TextEditingController apiKeyController;

  /// Controller for the local server IP address text field.
  final TextEditingController localIpController;
  
  /// Controller for the Vertex AI endpoint URL.
  final TextEditingController vertexAiEndpointController;
  
  /// Controller for the generic OpenAI Compatible endpoint URL.
  final TextEditingController openAiCompatibleEndpointController;
  
  /// Controller for the Ollama endpoint URL.
  final TextEditingController ollamaEndpointController;

  const ApiSettingsPanel({
    super.key,
    required this.apiKeyController,
    required this.localIpController,
    required this.vertexAiEndpointController,
    required this.openAiCompatibleEndpointController,
    required this.ollamaEndpointController,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    // Determines if the current provider requires an endpoint URL
    final bool requiresEndpoint = chatProvider.currentProvider == AiProvider.local ||
                                  chatProvider.currentProvider == AiProvider.vertexAi ||
                                  chatProvider.currentProvider == AiProvider.openAiCompatible ||
                                  chatProvider.currentProvider == AiProvider.ollama;

    // Determines if the current provider requires an API key
    final bool requiresApiKey = chatProvider.currentProvider != AiProvider.local &&
                                chatProvider.currentProvider != AiProvider.ollama;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (requiresApiKey) ...[
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
          TextField(
            controller: apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: "Paste API Key or Bearer Token...",
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
        ],

        if (requiresEndpoint) ...[
          Text(
            "Server Endpoint URL",
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
          TextField(
            controller: _getEndpointController(chatProvider.currentProvider),
            decoration: InputDecoration(
              hintText: _getEndpointHint(chatProvider.currentProvider),
              labelText: "Endpoint Address",
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
              _getEndpointHelpText(chatProvider.currentProvider),
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

  TextEditingController _getEndpointController(AiProvider provider) {
    switch (provider) {
      case AiProvider.vertexAi:
        return vertexAiEndpointController;
      case AiProvider.openAiCompatible:
        return openAiCompatibleEndpointController;
      case AiProvider.ollama:
        return ollamaEndpointController;
      case AiProvider.local:
      default:
        return localIpController;
    }
  }

  String _getEndpointHint(AiProvider provider) {
    switch (provider) {
      case AiProvider.vertexAi:
        return "https://{region}-aiplatform.googleapis.com/...";
      case AiProvider.openAiCompatible:
        return "https://api.your-provider.com/v1";
      case AiProvider.ollama:
        return "http://localhost:11434/v1";
      case AiProvider.local:
      default:
        return "http://192.168.1.X:1234/v1";
    }
  }

  String _getEndpointHelpText(AiProvider provider) {
    switch (provider) {
      case AiProvider.vertexAi:
        return "Requires full URL up to /v1beta1/projects/.../chat/completions";
      case AiProvider.openAiCompatible:
        return "Base URL ending before /chat/completions";
      case AiProvider.ollama:
        return "Default is usually http://localhost:11434/v1";
      case AiProvider.local:
      default:
        return "Ensure your local AI is listening on Network (0.0.0.0)";
    }
  }
}
