import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';

/// A panel for configuring API keys and network connectivity.
///
/// This panel manages its own text controllers to provide a smooth typing
/// experience while reactively updating the central providers.
class ApiSettingsPanel extends StatefulWidget {
  const ApiSettingsPanel({super.key});

  @override
  State<ApiSettingsPanel> createState() => _ApiSettingsPanelState();
}

class _ApiSettingsPanelState extends State<ApiSettingsPanel> {
  late TextEditingController _apiKeyController;
  late TextEditingController _localIpController;
  late TextEditingController _vertexAiEndpointController;
  late TextEditingController _openAiCompatibleEndpointController;
  late TextEditingController _ollamaEndpointController;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    _apiKeyController = TextEditingController(text: _getApiKey(chatProvider));
    _localIpController = TextEditingController(text: chatProvider.localIp);
    _vertexAiEndpointController = TextEditingController(
      text: chatProvider.vertexAiEndpoint,
    );
    _openAiCompatibleEndpointController = TextEditingController(
      text: chatProvider.openAiCompatibleEndpoint,
    );
    _ollamaEndpointController = TextEditingController(
      text: chatProvider.ollamaEndpoint,
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _localIpController.dispose();
    _vertexAiEndpointController.dispose();
    _openAiCompatibleEndpointController.dispose();
    _ollamaEndpointController.dispose();
    super.dispose();
  }

  String _getApiKey(ChatProvider provider) {
    switch (provider.currentProvider) {
      case AiProvider.gemini: return provider.geminiKey;
      case AiProvider.openRouter: return provider.openRouterKey;
      case AiProvider.openAi: return provider.openAiKey;
      case AiProvider.arliAi: return provider.arliAiKey;
      case AiProvider.nanoGpt: return provider.nanoGptKey;
      case AiProvider.nvidia: return provider.nvidiaKey;
      case AiProvider.huggingFace: return provider.huggingFaceKey;
      case AiProvider.groq: return provider.groqKey;
      case AiProvider.vertexAi: return provider.vertexAiKey;
      case AiProvider.blackboxAi: return provider.blackboxAiKey;
      case AiProvider.minimax: return provider.minimaxKey;
      case AiProvider.openAiCompatible: return provider.openAiCompatibleKey;
      case AiProvider.deepseek: return provider.deepseekKey;
      case AiProvider.ollama: return provider.ollamaKey;
      case AiProvider.qwen: return provider.qwenKey;
      case AiProvider.xAi: return provider.xAiKey;
      case AiProvider.zAi: return provider.zAiKey;
      case AiProvider.mistral: return provider.mistralKey;
      case AiProvider.mimo: return provider.mimoKey;
      case AiProvider.local: return "";
    }
  }

  void _updateApiKey(ChatProvider chatProvider, String val) {
    chatProvider.setApiKey(val.trim());
    chatProvider.saveSettings(showConfirmation: false);
  }

  void _syncControllers(ChatProvider chatProvider) {
    final currentKey = _getApiKey(chatProvider);
    if (_apiKeyController.text != currentKey) {
      _apiKeyController.text = currentKey;
    }
    if (_localIpController.text != chatProvider.localIp) {
      _localIpController.text = chatProvider.localIp;
    }
    if (_vertexAiEndpointController.text != chatProvider.vertexAiEndpoint) {
      _vertexAiEndpointController.text = chatProvider.vertexAiEndpoint;
    }
    if (_openAiCompatibleEndpointController.text != chatProvider.openAiCompatibleEndpoint) {
      _openAiCompatibleEndpointController.text = chatProvider.openAiCompatibleEndpoint;
    }
    if (_ollamaEndpointController.text != chatProvider.ollamaEndpoint) {
      _ollamaEndpointController.text = chatProvider.ollamaEndpoint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    // Sync only if we are not actively typing (heuristic: check focus)
    // Actually, for simplicity and to avoid caret jumps, only sync if different.
    // Manual sync here is still better than having it in the parent SettingsDrawer.
    _syncControllers(chatProvider);

    final bool requiresEndpoint =
        chatProvider.currentProvider == AiProvider.local ||
        chatProvider.currentProvider == AiProvider.vertexAi ||
        chatProvider.currentProvider == AiProvider.openAiCompatible ||
        chatProvider.currentProvider == AiProvider.ollama;

    final bool requiresApiKey =
        chatProvider.currentProvider != AiProvider.local &&
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
              shadows: vfxProvider.enableBloom
                  ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                  : [],
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            onChanged: (val) => _updateApiKey(chatProvider, val),
            decoration: InputDecoration(
              hintText: "Paste API Key or Bearer Token...",
              border: OutlineInputBorder(
                borderSide: vfxProvider.enableBloom
                    ? BorderSide(color: themeProvider.bloomGlowColor)
                    : const BorderSide(),
              ),
              enabledBorder: vfxProvider.enableBloom
                  ? OutlineInputBorder(
                      borderSide: BorderSide(
                        color: themeProvider.bloomGlowColor.withValues(alpha: 0.5),
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
              shadows: vfxProvider.enableBloom
                  ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                  : [],
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _getEndpointController(chatProvider.currentProvider),
            onChanged: (val) => _updateEndpoint(chatProvider, val),
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
      case AiProvider.vertexAi: return _vertexAiEndpointController;
      case AiProvider.openAiCompatible: return _openAiCompatibleEndpointController;
      case AiProvider.ollama: return _ollamaEndpointController;
      case AiProvider.local:
      default: return _localIpController;
    }
  }

  void _updateEndpoint(ChatProvider chatProvider, String val) {
    final provider = chatProvider.currentProvider;
    final cleaned = val.trim();
    switch (provider) {
      case AiProvider.vertexAi:
        chatProvider.setVertexAiEndpoint(cleaned);
        break;
      case AiProvider.openAiCompatible:
        chatProvider.setOpenAiCompatibleEndpoint(cleaned);
        break;
      case AiProvider.ollama:
        chatProvider.setOllamaEndpoint(cleaned);
        break;
      case AiProvider.local:
      default:
        chatProvider.setLocalIp(cleaned);
    }
    chatProvider.saveSettings(showConfirmation: false);
  }

  String _getEndpointHint(AiProvider provider) {
    switch (provider) {
      case AiProvider.vertexAi: return "https://{region}-aiplatform.googleapis.com/...";
      case AiProvider.openAiCompatible: return "https://api.your-provider.com/v1";
      case AiProvider.ollama: return "http://localhost:11434/v1";
      case AiProvider.local:
      default: return "http://192.168.1.X:1234/v1";
    }
  }

  String _getEndpointHelpText(AiProvider provider) {
    switch (provider) {
      case AiProvider.vertexAi: return "Requires full URL up to /v1beta1/projects/.../chat/completions";
      case AiProvider.openAiCompatible: return "Base URL ending before /chat/completions";
      case AiProvider.ollama: return "Default is usually http://localhost:11434/v1";
      case AiProvider.local:
      default: return "Ensure your local AI is listening on Network (0.0.0.0)";
    }
  }
}
