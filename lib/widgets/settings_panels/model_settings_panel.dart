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
      case AiProvider.openAi:
        return provider.openAiModelsList.length;
      case AiProvider.huggingFace:
        return provider.huggingFaceModelsList.length;
      case AiProvider.groq:
        return provider.groqModelsList.length;
      default:
        return 0;
    }
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
            color: themeProvider.appThemeColor,
            fontSize: scaleProvider.systemFontSize,
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)]
                : [],
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: themeProvider.enableBloom
                  ? themeProvider.appThemeColor.withOpacity(0.5)
                  : Colors.white12,
            ),
            boxShadow: themeProvider.enableBloom
                ? [
                    BoxShadow(
                      color: themeProvider.appThemeColor.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: titleController,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: scaleProvider.systemFontSize,
            ),
            decoration: InputDecoration(
              hintText: "Type a title...",
              hintStyle: TextStyle(
                color: Colors.white24,
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
                color: themeProvider.appThemeColor,
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
                ? [const Shadow(color: Colors.white, blurRadius: 10)]
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
            placeholder: "aion-labs/aion-rp-llama-3.1-8b",
            isLoading: chatProvider.isLoadingNanoGptModels,
            onRefresh: chatProvider.fetchNanoGptModels,
            refreshButtonColor: Colors.yellowAccent,
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
        const SizedBox(height: 16),
        
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
                        color: themeProvider.appThemeColor.withOpacity(0.9),
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
                          color: themeProvider.appThemeColor.withOpacity(0.9),
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
                          color: themeProvider.appThemeColor.withOpacity(0.9),
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
