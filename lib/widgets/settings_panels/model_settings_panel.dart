import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';
import 'provider_model_selector.dart';

/// A settings panel for configuring the conversation title and selecting AI models.
///
/// This panel manages its own text controllers to provide a smooth typing
/// experience while reactively updating the central providers.
class ModelSettingsPanel extends StatefulWidget {
  const ModelSettingsPanel({super.key});

  @override
  State<ModelSettingsPanel> createState() => _ModelSettingsPanelState();
}

class _ModelSettingsPanelState extends State<ModelSettingsPanel> {
  late TextEditingController _titleController;
  late TextEditingController _openRouterModelController;
  late TextEditingController _groqModelController;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _titleController = TextEditingController(text: chatProvider.currentTitle);
    _openRouterModelController = TextEditingController(
      text: chatProvider.openRouterModel,
    );
    _groqModelController = TextEditingController(text: chatProvider.groqModel);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _openRouterModelController.dispose();
    _groqModelController.dispose();
    super.dispose();
  }

  void _syncControllers(ChatProvider chatProvider) {
    if (_titleController.text != chatProvider.currentTitle) {
      _titleController.text = chatProvider.currentTitle;
    }
    if (_openRouterModelController.text != chatProvider.openRouterModel) {
      _openRouterModelController.text = chatProvider.openRouterModel;
    }
    if (_groqModelController.text != chatProvider.groqModel) {
      _groqModelController.text = chatProvider.groqModel;
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
        Text(
          "Conversation Title",
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
        Container(
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
                      color: themeProvider.bloomGlowColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: _titleController,
            onChanged: (val) {
              chatProvider.setTitle(val.trim());
              chatProvider.saveSettings(showConfirmation: false);
            },
            style: TextStyle(
              color: themeProvider.textColor,
              fontWeight: FontWeight.bold,
              fontSize: scaleProvider.systemFontSize,
            ),
            decoration: InputDecoration(
              hintText: "Type a title...",
              hintStyle: TextStyle(
                color: themeProvider.faintestColor,
                fontSize: scaleProvider.systemFontSize,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              suffixIcon: Icon(
                Icons.edit,
                size: 16,
                color: themeProvider.textColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          "Model Selection ${_getModelCount(chatProvider) > 0 ? "(${_getModelCount(chatProvider)})" : ""}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: scaleProvider.systemFontSize,
            shadows: vfxProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        const SizedBox(height: 5),

        if (chatProvider.currentProvider == AiProvider.gemini)
          ProviderModelSelector(
            modelsList: chatProvider.geminiModelsList,
            selectedModel: chatProvider.selectedGeminiModel,
            onSelected: chatProvider.setModel,
            placeholder: "models/gemini-3-flash-preview",
            isLoading: chatProvider.isLoadingGeminiModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.gemini),
            refreshButtonColor: Colors.blueAccent,
          )
        else if (chatProvider.currentProvider == AiProvider.openRouter)
          ProviderModelSelector(
            modelsList: chatProvider.openRouterModelsList,
            selectedModel: chatProvider.openRouterModel,
            onSelected: (val) {
              chatProvider.setModel(val);
              _openRouterModelController.text = val;
            },
            placeholder: "vendor/model-name",
            isLoading: chatProvider.isLoadingOpenRouterModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.openRouter),
            refreshButtonColor: Colors.purpleAccent,
            controller: _openRouterModelController,
          ),

        if (chatProvider.currentProvider == AiProvider.local) ...[
          const SizedBox(height: 5),
          TextField(
            onChanged: (val) {
              chatProvider.setLocalModelName(val);
              chatProvider.saveSettings(showConfirmation: false);
            },
            controller: TextEditingController(text: chatProvider.localModelName),
            decoration: InputDecoration(
              hintText: "local-model",
              hintStyle: TextStyle(fontSize: scaleProvider.systemFontSize),
              labelText: "Target Model ID (Optional)",
              labelStyle: TextStyle(fontSize: scaleProvider.systemFontSize),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            style: TextStyle(fontSize: scaleProvider.systemFontSize),
          ),
        ],

        if (chatProvider.currentProvider == AiProvider.arliAi)
          ProviderModelSelector(
            modelsList: chatProvider.arliAiModelsList,
            selectedModel: chatProvider.arliAiModel,
            onSelected: chatProvider.setModel,
            placeholder: "Gemma-3-27B-Big-Tiger-v3",
            isLoading: chatProvider.isLoadingArliAiModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.arliAi),
            refreshButtonColor: Colors.orangeAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.nanoGpt)
          ProviderModelSelector(
            modelsList: chatProvider.nanoGptModelsList,
            selectedModel: chatProvider.nanoGptModel,
            onSelected: chatProvider.setModel,
            placeholder: 'aion-labs/aion-rp-llama-3.1-8b',
            isLoading: chatProvider.isLoadingNanoGptModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.nanoGpt),
            refreshButtonColor: Colors.yellowAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.nvidia)
          ProviderModelSelector(
            modelsList: chatProvider.nvidiaModelsList,
            selectedModel: chatProvider.nvidiaModel,
            onSelected: chatProvider.setModel,
            placeholder: 'nvidia/llama-3.1-nemotron-ultra-253b-v1',
            isLoading: chatProvider.isLoadingNvidiaModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.nvidia),
            refreshButtonColor: Colors.lightGreenAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.openAi)
          ProviderModelSelector(
            modelsList: chatProvider.openAiModelsList,
            selectedModel: chatProvider.openAiModel,
            onSelected: chatProvider.setModel,
            placeholder: "gpt-4o",
            isLoading: chatProvider.isLoadingOpenAiModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.openAi),
            refreshButtonColor: Colors.greenAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.huggingFace)
          ProviderModelSelector(
            modelsList: chatProvider.huggingFaceModelsList,
            selectedModel: chatProvider.huggingFaceModel,
            onSelected: chatProvider.setModel,
            placeholder: "meta-llama/Meta-Llama-3-8B-Instruct",
            isLoading: chatProvider.isLoadingHuggingFaceModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.huggingFace),
            refreshButtonColor: Colors.amberAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.groq)
          ProviderModelSelector(
            modelsList: chatProvider.groqModelsList,
            selectedModel: chatProvider.groqModel,
            onSelected: (val) {
              chatProvider.setModel(val);
              _groqModelController.text = val;
            },
            placeholder: "llama3-8b-8192",
            isLoading: chatProvider.isLoadingGroqModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.groq),
            refreshButtonColor: Colors.deepOrangeAccent,
            controller: _groqModelController,
          ),
        const SizedBox(height: 16),

        // --- Selected Model Details UI ---
        Builder(
          builder: (context) {
            final activeModel = chatProvider.getCurrentModelInfo();
            if (activeModel == null) return const SizedBox.shrink();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: themeProvider.containerFillColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: themeProvider.borderColor.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Selected Model Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: scaleProvider.systemFontSize * 0.85,
                      color: themeProvider.textColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    "ID",
                    activeModel.id,
                    themeProvider,
                    scaleProvider,
                  ),
                  if (activeModel.name.isNotEmpty &&
                      activeModel.name != activeModel.id)
                    _buildDetailRow(
                      "Name",
                      activeModel.name,
                      themeProvider,
                      scaleProvider,
                    ),
                  _buildDetailRow(
                    "Context",
                    "${chatProvider.formatNumber(activeModel.contextLength)} tokens",
                    themeProvider,
                    scaleProvider,
                  ),
                  if (activeModel.pricing.isNotEmpty)
                    _buildDetailRow(
                      "Pricing",
                      _formatPricing(activeModel.pricing),
                      themeProvider,
                      scaleProvider,
                    ),
                  if (activeModel.description !=
                      "No description provided.") ...[
                    const SizedBox(height: 4),
                    Text(
                      activeModel.description,
                      style: TextStyle(
                        fontSize: scaleProvider.systemFontSize * 0.75,
                        color: themeProvider.faintestColor,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        // --- Advanced Model Parameters ---
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Grounding / Web Search",
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
            chatProvider.currentProvider == AiProvider.gemini
                ? "Uses Google Search (Native)"
                : chatProvider.currentProvider == AiProvider.openRouter
                ? "Uses OpenRouter Web Plugin"
                : "Not available on this provider",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize * 0.8,
              color: Colors.grey,
            ),
          ),
          value: settingsProvider.enableGrounding,
          activeThumbColor: Colors.greenAccent,
          onChanged:
              (chatProvider.currentProvider == AiProvider.gemini ||
                  chatProvider.currentProvider == AiProvider.openRouter ||
                  chatProvider.currentProvider == AiProvider.arliAi ||
                  chatProvider.currentProvider == AiProvider.nanoGpt)
              ? (val) {
                  settingsProvider.setEnableGrounding(val);
                  chatProvider.saveSettings(showConfirmation: false);
                }
              : null,
        ),

        if (chatProvider.currentProvider == AiProvider.gemini)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              "Disable Safety Filters",
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
              "Applies to Gemini Only",
              style: TextStyle(
                fontSize: scaleProvider.systemFontSize * 0.8,
                color: Colors.grey,
              ),
            ),
            value: settingsProvider.disableSafety,
            activeThumbColor: Colors.redAccent,
            onChanged: (val) {
              settingsProvider.setDisableSafety(val);
              chatProvider.saveSettings(showConfirmation: false);
            },
          ),

        if (chatProvider.currentProvider == AiProvider.openRouter)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              "Request Usage Stats",
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
              "Appends token usage info to response",
              style: TextStyle(
                fontSize: scaleProvider.systemFontSize * 0.8,
                color: Colors.grey,
              ),
            ),
            value: settingsProvider.enableUsage,
            activeThumbColor: Colors.tealAccent,
            onChanged: (val) {
              settingsProvider.setEnableUsage(val);
              chatProvider.saveSettings(showConfirmation: false);
            },
          ),
      ],
    );
  }

  /// Returns the number of available models for the current provider.
  int _getModelCount(ChatProvider provider) {
    switch (provider.currentProvider) {
      case AiProvider.gemini: return provider.geminiModelsList.length;
      case AiProvider.openRouter: return provider.openRouterModelsList.length;
      case AiProvider.arliAi: return provider.arliAiModelsList.length;
      case AiProvider.nanoGpt: return provider.nanoGptModelsList.length;
      case AiProvider.nvidia: return provider.nvidiaModelsList.length;
      case AiProvider.openAi: return provider.openAiModelsList.length;
      case AiProvider.huggingFace: return provider.huggingFaceModelsList.length;
      case AiProvider.groq: return provider.groqModelsList.length;
      case AiProvider.local: return 1;
      default: return 0;
    }
  }

  /// Formats pricing string from per-token to per-million tokens format.
  String _formatPricing(String p) {
    try {
      final parts = p.split(' / ');
      if (parts.length != 2) return p;
      double input = double.tryParse(parts[0]) ?? 0;
      double output = double.tryParse(parts[1]) ?? 0;
      if (input < 0 || output < 0) return "Variable / Dynamic";
      if (input == 0 && output == 0) return "Free / Unknown";
      double inputM = input * 1000000;
      double outputM = output * 1000000;
      return "Input: \$${inputM.toStringAsFixed(2)}/M | Output: \$${outputM.toStringAsFixed(2)}/M";
    } catch (_) { return p; }
  }

  Widget _buildDetailRow(String label, String value, ThemeProvider tp, ScaleProvider sp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: sp.systemFontSize * 0.8,
                color: tp.faintestColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: sp.systemFontSize * 0.8,
                color: tp.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
