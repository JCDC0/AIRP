import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';
import 'provider_model_selector.dart';

/// A settings panel for configuring the conversation title and selecting AI models.
///
/// This panel provides a text field for the title and a provider-specific
/// model selector widget.
class ModelSettingsPanel extends StatelessWidget {
  /// Controller for the conversation title text field.
  final TextEditingController titleController;

  /// Controller for the OpenRouter model selection text field.
  final TextEditingController openRouterModelController;

  /// Controller for the Groq model selection text field.
  final TextEditingController groqModelController;

  const ModelSettingsPanel({
    super.key,
    required this.titleController,
    required this.openRouterModelController,
    required this.groqModelController,
  });

  /// Returns the number of available models for the current provider.
  int _getModelCount(ChatProvider provider) {
    switch (provider.currentProvider) {
      case AiProvider.gemini:
        return provider.geminiModelsList.length;
      case AiProvider.openRouter:
        return provider.openRouterModelsList.length;
      case AiProvider.arliAi:
        return provider.arliAiModelsList.length;
      case AiProvider.nanoGpt:
        return provider.nanoGptModelsList.length;
      case AiProvider.nanoGptImage:
        return provider.nanoGptImageModelsList.length;
      case AiProvider.openAi:
        return provider.openAiModelsList.length;
      case AiProvider.huggingFace:
        return provider.huggingFaceModelsList.length;
      case AiProvider.groq:
        return provider.groqModelsList.length;
      case AiProvider.vertexAi:
        return provider.vertexAiModelsList.length;
      case AiProvider.blackboxAi:
        return provider.blackboxAiModelsList.length;
      case AiProvider.minimax:
        return provider.minimaxModelsList.length;
      case AiProvider.openAiCompatible:
        return provider.openAiCompatibleModelsList.length;
      case AiProvider.deepseek:
        return provider.deepseekModelsList.length;
      case AiProvider.ollama:
        return provider.ollamaModelsList.length;
      case AiProvider.qwen:
        return provider.qwenModelsList.length;
      case AiProvider.xAi:
        return provider.xAiModelsList.length;
      case AiProvider.zAi:
        return provider.zAiModelsList.length;
      case AiProvider.mistral:
        return provider.mistralModelsList.length;
      default:
        return 0;
    }
  }

  Widget _buildDetailRow(String label, String value, ThemeProvider themeProvider, ScaleProvider scaleProvider) {
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
                fontSize: scaleProvider.systemFontSize * 0.8,
                color: themeProvider.faintestColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: scaleProvider.systemFontSize * 0.8,
                color: themeProvider.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override

  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Conversation Title",
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
        Container(
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
                      color: themeProvider.bloomGlowColor.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: titleController,
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
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        const SizedBox(height: 5),

        Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Manual Model Input",
                style: TextStyle(
                  color: themeProvider.textColor,
                  fontSize: scaleProvider.systemFontSize * 0.9,
                ),
              ),
              Switch(
                value: chatProvider.enableManualModelInput,
                onChanged: (val) {
                  chatProvider.setEnableManualModelInput(val);
                },
                activeColor: themeProvider.bloomGlowColor,
              ),
            ],
          ),
        ),

        if (chatProvider.currentProvider == AiProvider.gemini)
          ProviderModelSelector(
            modelsList: chatProvider.geminiModelsList,
            selectedModel: chatProvider.selectedGeminiModel,
            onSelected: chatProvider.setModel,
            placeholder: "models/gemini-3-flash-preview",
            isLoading: chatProvider.isLoadingGeminiModels,
            onRefresh: chatProvider.fetchGeminiModels,
            refreshButtonColor: Colors.blueAccent,
          )
        else if (chatProvider.currentProvider == AiProvider.openRouter)
          ProviderModelSelector(
            modelsList: chatProvider.openRouterModelsList,
            selectedModel: chatProvider.openRouterModel,
            onSelected: (val) {
              chatProvider.setModel(val);
              openRouterModelController.text = val;
            },
            placeholder: "vendor/model-name",
            isLoading: chatProvider.isLoadingOpenRouterModels,
            onRefresh: chatProvider.fetchOpenRouterModels,
            refreshButtonColor: Colors.purpleAccent,
            controller: openRouterModelController,
          ),

        if (chatProvider.currentProvider == AiProvider.local) ...[
          const SizedBox(height: 5),
          TextField(
            onChanged: chatProvider.setLocalModelName,
            controller: TextEditingController(
              text: chatProvider.localModelName,
            ),
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
            onRefresh: chatProvider.fetchArliAiModels,
            refreshButtonColor: Colors.orangeAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.nanoGpt)
          ProviderModelSelector(
            modelsList: chatProvider.nanoGptModelsList,
            selectedModel: chatProvider.nanoGptModel,
            onSelected: chatProvider.setModel,
            placeholder: 'aion-labs/aion-rp-llama-3.1-8b',
            isLoading: chatProvider.isLoadingNanoGptModels,
            onRefresh: chatProvider.fetchNanoGptModels,
            refreshButtonColor: Colors.yellowAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.nanoGptImage)
          ProviderModelSelector(
            modelsList: chatProvider.nanoGptImageModelsList,
            selectedModel: chatProvider.nanoGptImageModel,
            onSelected: chatProvider.setModel,
            placeholder: 'nano-banana',
            isLoading: chatProvider.isLoadingNanoGptModels,
            onRefresh: chatProvider.fetchNanoGptModels,
            refreshButtonColor: Colors.purpleAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.openAi)
          ProviderModelSelector(
            modelsList: chatProvider.openAiModelsList,
            selectedModel: chatProvider.openAiModel,
            onSelected: chatProvider.setModel,
            placeholder: "gpt-4o",
            isLoading: chatProvider.isLoadingOpenAiModels,
            onRefresh: chatProvider.fetchOpenAiModels,
            refreshButtonColor: Colors.greenAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.huggingFace)
          ProviderModelSelector(
            modelsList: chatProvider.huggingFaceModelsList,
            selectedModel: chatProvider.huggingFaceModel,
            onSelected: chatProvider.setModel,
            placeholder: "meta-llama/Meta-Llama-3-8B-Instruct",
            isLoading: chatProvider.isLoadingHuggingFaceModels,
            onRefresh: chatProvider.fetchHuggingFaceModels,
            refreshButtonColor: Colors.amberAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.groq)
          ProviderModelSelector(
            modelsList: chatProvider.groqModelsList,
            selectedModel: chatProvider.groqModel,
            onSelected: (val) {
              chatProvider.setModel(val);
              groqModelController.text = val;
            },
            placeholder: "llama3-8b-8192",
            isLoading: chatProvider.isLoadingGroqModels,
            onRefresh: chatProvider.fetchGroqModels,
            refreshButtonColor: Colors.deepOrangeAccent,
            controller: groqModelController,
          ),

        if (chatProvider.currentProvider == AiProvider.vertexAi)
          ProviderModelSelector(
            modelsList: chatProvider.vertexAiModelsList,
            selectedModel: chatProvider.vertexAiModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select Vertex AI Model",
            isLoading: chatProvider.isLoadingVertexAiModels,
            onRefresh: chatProvider.fetchVertexAiModels,
            refreshButtonColor: Colors.lightBlueAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.blackboxAi)
          ProviderModelSelector(
            modelsList: chatProvider.blackboxAiModelsList,
            selectedModel: chatProvider.blackboxAiModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select Blackbox AI Model",
            isLoading: chatProvider.isLoadingBlackboxAiModels,
            onRefresh: chatProvider.fetchBlackboxAiModels,
            refreshButtonColor: Colors.grey,
          ),

        if (chatProvider.currentProvider == AiProvider.minimax)
          ProviderModelSelector(
            modelsList: chatProvider.minimaxModelsList,
            selectedModel: chatProvider.minimaxModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select Minimax Model",
            isLoading: chatProvider.isLoadingMinimaxModels,
            onRefresh: chatProvider.fetchMinimaxModels,
            refreshButtonColor: Colors.redAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.openAiCompatible)
          ProviderModelSelector(
            modelsList: chatProvider.openAiCompatibleModelsList,
            selectedModel: chatProvider.openAiCompatibleModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select Model",
            isLoading: chatProvider.isLoadingOpenAiCompatibleModels,
            onRefresh: chatProvider.fetchOpenAiCompatibleModels,
            refreshButtonColor: Colors.tealAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.deepseek)
          ProviderModelSelector(
            modelsList: chatProvider.deepseekModelsList,
            selectedModel: chatProvider.deepseekModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select Deepseek Model",
            isLoading: chatProvider.isLoadingDeepseekModels,
            onRefresh: chatProvider.fetchDeepseekModels,
            refreshButtonColor: Colors.blueAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.ollama)
          ProviderModelSelector(
            modelsList: chatProvider.ollamaModelsList,
            selectedModel: chatProvider.ollamaModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select Ollama Model",
            isLoading: chatProvider.isLoadingOllamaModels,
            onRefresh: chatProvider.fetchOllamaModels,
            refreshButtonColor: Colors.white70,
          ),

        if (chatProvider.currentProvider == AiProvider.qwen)
          ProviderModelSelector(
            modelsList: chatProvider.qwenModelsList,
            selectedModel: chatProvider.qwenModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select Qwen Model",
            isLoading: chatProvider.isLoadingQwenModels,
            onRefresh: chatProvider.fetchQwenModels,
            refreshButtonColor: Colors.purpleAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.xAi)
          ProviderModelSelector(
            modelsList: chatProvider.xAiModelsList,
            selectedModel: chatProvider.xAiModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select xAI Model",
            isLoading: chatProvider.isLoadingXAiModels,
            onRefresh: chatProvider.fetchXAiModels,
            refreshButtonColor: Colors.blue,
          ),

        if (chatProvider.currentProvider == AiProvider.zAi)
          ProviderModelSelector(
            modelsList: chatProvider.zAiModelsList,
            selectedModel: chatProvider.zAiModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select Z.ai Model",
            isLoading: chatProvider.isLoadingZAiModels,
            onRefresh: chatProvider.fetchZAiModels,
            refreshButtonColor: Colors.cyanAccent,
          ),

        if (chatProvider.currentProvider == AiProvider.mistral)
          ProviderModelSelector(
            modelsList: chatProvider.mistralModelsList,
            selectedModel: chatProvider.mistralModel,
            onSelected: chatProvider.setModel,
            placeholder: "Select Mistral Model",
            isLoading: chatProvider.isLoadingMistralModels,
            onRefresh: chatProvider.fetchMistralModels,
            refreshButtonColor: Colors.orange,
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
                  color: themeProvider.borderColor.withOpacity(0.5),
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
                      color: themeProvider.textColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow("ID", activeModel.id, themeProvider, scaleProvider),
                  if (activeModel.name.isNotEmpty && activeModel.name != activeModel.id)
                    _buildDetailRow("Name", activeModel.name, themeProvider, scaleProvider),
                  _buildDetailRow("Context", "${chatProvider.formatNumber(activeModel.contextLength)} tokens", themeProvider, scaleProvider),
                  _buildDetailRow("Pricing", activeModel.pricing, themeProvider, scaleProvider),
                  if (activeModel.description != "No description provided.") ...[
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
                  ]
                ],
              ),
            );
          },
        ),
        
        // --- Added Settings (Moved from System Prompt) ---
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Grounding / Web Search",
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
          value: chatProvider.enableGrounding,
          activeThumbColor: Colors.greenAccent,
          onChanged:
              (chatProvider.currentProvider == AiProvider.gemini ||
                  chatProvider.currentProvider == AiProvider.openRouter ||
                  chatProvider.currentProvider == AiProvider.arliAi ||
                  chatProvider.currentProvider == AiProvider.nanoGpt)
              ? (val) {
                  chatProvider.setEnableGrounding(val);
                  chatProvider.saveSettings();
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
              "Applies to Gemini Only",
              style: TextStyle(
                fontSize: scaleProvider.systemFontSize * 0.8,
                color: Colors.grey,
              ),
            ),
            value: chatProvider.disableSafety,
            activeThumbColor: Colors.redAccent,
            onChanged: (val) {
              chatProvider.setDisableSafety(val);
              chatProvider.saveSettings();
            },
          ),

        if (chatProvider.currentProvider == AiProvider.openRouter)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              "Request Usage Stats",
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
              "Appends token usage info to response",
              style: TextStyle(
                fontSize: scaleProvider.systemFontSize * 0.8,
                color: Colors.grey,
              ),
            ),
            value: chatProvider.enableUsage,
            activeThumbColor: Colors.tealAccent,
            onChanged: (val) {
              chatProvider.setEnableUsage(val);
              chatProvider.saveSettings();
            },
          ),

      ],
    );
  }
}
