import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late TextEditingController _openAiCompatibleEndpointController;
  late TextEditingController _ollamaEndpointController;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    _apiKeyController = TextEditingController(text: _getApiKey(chatProvider));
    _localIpController = TextEditingController(text: chatProvider.localIp);
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
    _openAiCompatibleEndpointController.dispose();
    _ollamaEndpointController.dispose();
    super.dispose();
  }

  String _getApiKey(ChatProvider provider) {
    switch (provider.currentProvider) {
      case AiProvider.gemini: return provider.geminiKey;
      case AiProvider.openRouter: return provider.openRouterKey;
      case AiProvider.nanoGpt: return provider.nanoGptKey;
      case AiProvider.nvidia: return provider.nvidiaKey;
      case AiProvider.openAiCompatible: return provider.openAiCompatibleKey;
      case AiProvider.deepseek: return provider.deepseekKey;
      case AiProvider.ollama: return provider.ollamaKey;
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
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 18),
                    tooltip: 'Copy key',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _apiKeyController.text),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('API key copied'),
                            duration: Duration(milliseconds: 800),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_paste, size: 18),
                    tooltip: 'Paste key',
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      final text = data?.text ?? '';
                      if (text.trim().isEmpty) return;
                      _apiKeyController.text = text.trim();
                      _updateApiKey(chatProvider, text);
                    },
                  ),
                ],
              ),
            ),
            style: TextStyle(fontSize: scaleProvider.systemFontSize - 2),
          ),
          if (_getApiKey(chatProvider).trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildModelLoadRow(chatProvider, scaleProvider),
          ],
          const SizedBox(height: 2),
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
          if (!requiresApiKey && _getEndpoint(chatProvider).trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildModelLoadRow(chatProvider, scaleProvider),
          ],
          const SizedBox(height: 2),
        ],
      ],
    );
  }

  /// Refresh button plus the outcome of the last model fetch.
  ///
  /// A failed fetch used to be swallowed by the registry, so entering a valid
  /// key against an unreachable endpoint looked identical to entering a bad
  /// one: nothing happened either way.
  Widget _buildModelLoadRow(
    ChatProvider chatProvider,
    ScaleProvider scaleProvider,
  ) {
    final String? error = chatProvider.currentModelFetchError;
    final int count = chatProvider.currentModelsList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          icon: chatProvider.isRefreshingModels
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_sync, size: 18),
          label: Text(
            chatProvider.isRefreshingModels
                ? 'Loading…'
                : (count == 0 ? 'Load Models' : 'Refresh Models'),
          ),
          onPressed: chatProvider.isRefreshingModels
              ? null
              : () => chatProvider.refreshCurrentModels(),
        ),
        if (!chatProvider.isRefreshingModels)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  error != null
                      ? Icons.error_outline
                      : (count > 0 ? Icons.check_circle_outline : Icons.info_outline),
                  size: scaleProvider.systemFontSize - 2,
                  color: error != null
                      ? Colors.redAccent
                      : (count > 0 ? Colors.greenAccent : Colors.grey),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error ??
                        (count > 0
                            ? '$count models available.'
                            : 'No models loaded yet.'),
                    style: TextStyle(
                      fontSize: scaleProvider.systemFontSize - 4,
                      color: error != null ? Colors.redAccent : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  TextEditingController _getEndpointController(AiProvider provider) {
    switch (provider) {
      case AiProvider.openAiCompatible: return _openAiCompatibleEndpointController;
      case AiProvider.ollama: return _ollamaEndpointController;
      case AiProvider.local:
      default: return _localIpController;
    }
  }

  String _getEndpoint(ChatProvider chatProvider) {
    switch (chatProvider.currentProvider) {
      case AiProvider.openAiCompatible: return chatProvider.openAiCompatibleEndpoint;
      case AiProvider.ollama: return chatProvider.ollamaEndpoint;
      case AiProvider.local:
      default: return chatProvider.localIp;
    }
  }

  void _updateEndpoint(ChatProvider chatProvider, String val) {
    final provider = chatProvider.currentProvider;
    final cleaned = val.trim();
    switch (provider) {
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
      case AiProvider.openAiCompatible: return "https://api.your-provider.com/v1";
      case AiProvider.ollama: return "http://localhost:11434";
      case AiProvider.local:
      default: return "http://192.168.1.X:1234/v1";
    }
  }

  String _getEndpointHelpText(AiProvider provider) {
    switch (provider) {
      case AiProvider.openAiCompatible: return "Base URL ending before /chat/completions";
      case AiProvider.ollama: return "Server root, with or without /v1. Default: http://localhost:11434";
      case AiProvider.local:
      default: return "Ensure your local AI is listening on Network (0.0.0.0)";
    }
  }
}
