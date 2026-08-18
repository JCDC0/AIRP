import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import '../../utils/model_details.dart';
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
  late FocusNode _titleFocusNode;

  /// Explicit controller for the model description box. Without one it would
  /// claim the PrimaryScrollController that the settings drawer around it
  /// already owns, which trips the "attached to multiple scroll views" assert.
  final ScrollController _descriptionScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _titleController = TextEditingController(text: chatProvider.currentTitle);
    _openRouterModelController = TextEditingController(
      text: chatProvider.openRouterModel,
    );
    _titleFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _openRouterModelController.dispose();
    _titleFocusNode.dispose();
    _descriptionScrollController.dispose();
    super.dispose();
  }

  void _syncControllers(ChatProvider chatProvider) {
    if (!_titleFocusNode.hasFocus &&
        _titleController.text != chatProvider.currentTitle) {
      _titleController.text = chatProvider.currentTitle;
    }
    if (_openRouterModelController.text != chatProvider.openRouterModel) {
      _openRouterModelController.text = chatProvider.openRouterModel;
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
            focusNode: _titleFocusNode,
            onChanged: (val) {
              chatProvider.setTitle(val);
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

        if (chatProvider.currentProvider == AiProvider.deepseek)
          ProviderModelSelector(
            modelsList: chatProvider.deepseekModelsList,
            selectedModel: chatProvider.deepseekModel,
            onSelected: chatProvider.setModel,
            placeholder: 'deepseek-chat',
            isLoading: chatProvider.isLoadingDeepseekModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.deepseek),
            refreshButtonColor: Colors.blueAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.xAi)
          ProviderModelSelector(
            modelsList: chatProvider.xAiModelsList,
            selectedModel: chatProvider.xAiModel,
            onSelected: chatProvider.setModel,
            placeholder: 'grok-4',
            isLoading: chatProvider.isLoadingXAiModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.xAi),
            refreshButtonColor: Colors.white70,
          ),

        if (chatProvider.currentProvider == AiProvider.ollama)
          ProviderModelSelector(
            modelsList: chatProvider.ollamaModelsList,
            selectedModel: chatProvider.ollamaModel,
            onSelected: chatProvider.setModel,
            placeholder: 'llama3.2:latest',
            isLoading: chatProvider.isLoadingOllamaModels,
            onRefresh: () => chatProvider.refreshModels(AiProvider.ollama),
            refreshButtonColor: Colors.tealAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.openAiCompatible)
          ProviderModelSelector(
            modelsList: chatProvider.openAiCompatibleModelsList,
            selectedModel: chatProvider.openAiCompatibleModel,
            onSelected: chatProvider.setModel,
            placeholder: 'vendor/model-name',
            isLoading: chatProvider.isLoadingOpenAiCompatibleModels,
            onRefresh: () =>
                chatProvider.refreshModels(AiProvider.openAiCompatible),
            refreshButtonColor: Colors.orangeAccent,
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
                  for (final detail in ModelDetails.extract(activeModel))
                    _buildDetailRow(
                      detail.label,
                      detail.value,
                      themeProvider,
                      scaleProvider,
                    ),
                  if (activeModel.description !=
                      "No description provided.") ...[
                    const SizedBox(height: 4),
                    // Scrolls instead of ellipsizing at three lines: OpenRouter
                    // ships multi-paragraph descriptions and the rest of the
                    // text was unreachable.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: scaleProvider.systemFontSize * 0.75 * 1.3 * 8,
                      ),
                      child: Scrollbar(
                        controller: _descriptionScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _descriptionScrollController,
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            activeModel.description,
                            style: TextStyle(
                              fontSize: scaleProvider.systemFontSize * 0.75,
                              color: themeProvider.faintestColor,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
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
            chatProvider.webSearchUnsupportedReason() ??
                (chatProvider.currentProvider == AiProvider.gemini
                    ? "Uses Google Search (Native)"
                    : chatProvider.currentProvider == AiProvider.openRouter
                    ? "Uses OpenRouter Web Plugin"
                    : (settingsProvider.searchProvider ==
                            SearchProvider.provider
                        ? "Native grounding"
                        : "AI decides when to search (tool call)")),
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize * 0.8,
              color: Colors.grey,
            ),
          ),
          value: settingsProvider.enableGrounding,
          activeThumbColor: Colors.greenAccent,
          onChanged:
              chatProvider.webSearchUnsupportedReason() == null
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
    if (provider.currentProvider == AiProvider.local) return 1;
    return provider.currentModelsList.length;
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
