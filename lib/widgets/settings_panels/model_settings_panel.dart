import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_models.dart';
import '../model_selector.dart';

class ModelSettingsPanel extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController openRouterModelController;

  const ModelSettingsPanel({
    super.key,
    required this.titleController,
    required this.openRouterModelController,
  });

  int _getModelCount(ChatProvider provider) {
    switch (provider.currentProvider) {
      case AiProvider.gemini: return provider.geminiModelsList.length;
      case AiProvider.openRouter: return provider.openRouterModelsList.length;
      case AiProvider.arliAi: return provider.arliAiModelsList.length;
      case AiProvider.nanoGpt: return provider.nanoGptModelsList.length;
      case AiProvider.openAi: return provider.openAiModelsList.length;
      case AiProvider.huggingFace: return provider.huggingFaceModelsList.length;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Conversation Title", 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: themeProvider.appThemeColor,
            shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [],
          )
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
            boxShadow: themeProvider.enableBloom ? [BoxShadow(color: themeProvider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : [],
          ),
          child: TextField(
            controller: titleController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: "Type a title...",
              hintStyle: const TextStyle(color: Colors.white24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              suffixIcon: Icon(Icons.edit, size: 16, color: themeProvider.appThemeColor),
            ),
            // onChanged: chatProvider.setTitle, // Removed for Save button logic
          ),
        ),
        const SizedBox(height: 20),

        Text("Model Selection ${_getModelCount(chatProvider) > 0 ? "(${_getModelCount(chatProvider)})" : ""}", style: TextStyle(fontWeight: FontWeight.bold, shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.white, blurRadius: 10)] : [])),
        const SizedBox(height: 5),

        // ============================================
        // GEMINI UI
        // ============================================
        if (chatProvider.currentProvider == AiProvider.gemini) ...[
          if (chatProvider.geminiModelsList.isNotEmpty)
            ModelSelector(
              modelsList: chatProvider.geminiModelsList,
              selectedModel: chatProvider.selectedGeminiModel,
              onSelected: chatProvider.setModel,
              placeholder: "Select Gemini Model",
            )
            else
            TextField(
              decoration: const InputDecoration(hintText: "models/gemini-3-flash-preview", border: OutlineInputBorder(), isDense: true),
              onChanged: chatProvider.setModel,
              controller: TextEditingController(text: chatProvider.selectedGeminiModel),
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: chatProvider.isLoadingGeminiModels 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.cloud_sync, size: 16),
              label: Text(chatProvider.isLoadingGeminiModels ? "Fetching..." : "Refresh Model List"),
              onPressed: chatProvider.isLoadingGeminiModels ? null : chatProvider.fetchGeminiModels,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
            ),
          ),
        ]

        // ============================================
        // OPENROUTER UI
        // ============================================
        else if (chatProvider.currentProvider == AiProvider.openRouter) ...[
          if (chatProvider.openRouterModelsList.isNotEmpty)
            ModelSelector(
              modelsList: chatProvider.openRouterModelsList,
              selectedModel: chatProvider.openRouterModel,
              onSelected: (val) {
                chatProvider.setModel(val);
                openRouterModelController.text = val;
              },
              placeholder: "Select OpenRouter Model",
            )
          else
            TextField(
              controller: openRouterModelController,
              decoration: const InputDecoration(hintText: "vendor/model-name", border: OutlineInputBorder(), isDense: true),
              style: const TextStyle(fontSize: 13),
              // onChanged: (val) { chatProvider.setModel(val.trim()); }, // Removed for Save button logic
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: chatProvider.isLoadingOpenRouterModels 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.cloud_sync, size: 16),
              label: Text(chatProvider.isLoadingOpenRouterModels ? "Fetching..." : "Refresh Model List"),
              onPressed: chatProvider.isLoadingOpenRouterModels ? null : chatProvider.fetchOpenRouterModels,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.purpleAccent),
            ),
          ),
        ],
        // -------------------------------------------
        // LOCAL UI
        // -------------------------------------------
        if (chatProvider.currentProvider == AiProvider.local) ...[
           const SizedBox(height: 5),
           TextField(
             onChanged: chatProvider.setLocalModelName,
             controller: TextEditingController(text: chatProvider.localModelName),
             decoration: const InputDecoration(
               hintText: "local-model",
               labelText: "Target Model ID (Optional)",
               border: OutlineInputBorder(), 
               isDense: true
             ),
             style: const TextStyle(fontSize: 13),
           ),
        ],

        // ============================================
        // ARLI AI UI
        // ============================================
        if (chatProvider.currentProvider == AiProvider.arliAi) ...[
          if (chatProvider.arliAiModelsList.isNotEmpty)
            ModelSelector(
              modelsList: chatProvider.arliAiModelsList,
              selectedModel: chatProvider.arliAiModel,
              onSelected: chatProvider.setModel,
              placeholder: "Select ArliAI Model",
            )
          else
            TextField(
              controller: TextEditingController(text: chatProvider.arliAiModel),
              decoration: const InputDecoration(hintText: "Gemma-3-27B-Big-Tiger-v3", border: OutlineInputBorder(), isDense: true),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) { chatProvider.setModel(val.trim()); },
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: chatProvider.isLoadingArliAiModels 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.cloud_sync, size: 16),
              label: Text(chatProvider.isLoadingArliAiModels ? "Fetching..." : "Refresh Model List"),
              onPressed: chatProvider.isLoadingArliAiModels ? null : chatProvider.fetchArliAiModels,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent),
            ),
          ),
        ],

        // ============================================
        // NANOGPT UI
        // ============================================
        if (chatProvider.currentProvider == AiProvider.nanoGpt) ...[
          if (chatProvider.nanoGptModelsList.isNotEmpty)
            ModelSelector(
              modelsList: chatProvider.nanoGptModelsList,
              selectedModel: chatProvider.nanoGptModel,
              onSelected: chatProvider.setModel,
              placeholder: "Select NanoGPT Model",
            )
          else
            TextField(
              controller: TextEditingController(text: chatProvider.nanoGptModel),
              decoration: const InputDecoration(hintText: "aion-labs/aion-rp-llama-3.1-8b", border: OutlineInputBorder(), isDense: true),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) { chatProvider.setModel(val.trim()); },
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: chatProvider.isLoadingNanoGptModels
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync, size: 16),
              label: Text(chatProvider.isLoadingNanoGptModels ? "Fetching..." : "Refresh Model List"),
              onPressed: chatProvider.isLoadingNanoGptModels ? null : chatProvider.fetchNanoGptModels,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.yellowAccent),
            ),
          ),
        ],

        // ============================================
        // OPENAI UI
        // ============================================
        if (chatProvider.currentProvider == AiProvider.openAi) ...[
          if (chatProvider.openAiModelsList.isNotEmpty)
            ModelSelector(
              modelsList: chatProvider.openAiModelsList,
              selectedModel: chatProvider.openAiModel,
              onSelected: chatProvider.setModel,
              placeholder: "Select OpenAI Model",
            )
          else
            TextField(
              controller: TextEditingController(text: chatProvider.openAiModel),
              decoration: const InputDecoration(hintText: "gpt-4o", border: OutlineInputBorder(), isDense: true),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) { chatProvider.setModel(val.trim()); },
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: chatProvider.isLoadingOpenAiModels
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync, size: 16),
              label: Text(chatProvider.isLoadingOpenAiModels ? "Fetching..." : "Refresh Model List"),
              onPressed: chatProvider.isLoadingOpenAiModels ? null : chatProvider.fetchOpenAiModels,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.greenAccent),
            ),
          ),
        ],

        // ============================================
        // HUGGINGFACE UI
        // ============================================
        if (chatProvider.currentProvider == AiProvider.huggingFace) ...[
          if (chatProvider.huggingFaceModelsList.isNotEmpty)
            ModelSelector(
              modelsList: chatProvider.huggingFaceModelsList,
              selectedModel: chatProvider.huggingFaceModel,
              onSelected: chatProvider.setModel,
              placeholder: "Select HuggingFace Model",
            )
          else
            TextField(
              controller: TextEditingController(text: chatProvider.huggingFaceModel),
              decoration: const InputDecoration(hintText: "meta-llama/Meta-Llama-3-8B-Instruct", border: OutlineInputBorder(), isDense: true),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) { chatProvider.setModel(val.trim()); },
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: chatProvider.isLoadingHuggingFaceModels
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync, size: 16),
              label: Text(chatProvider.isLoadingHuggingFaceModels ? "Fetching..." : "Refresh Top Models"),
              onPressed: chatProvider.isLoadingHuggingFaceModels ? null : chatProvider.fetchHuggingFaceModels,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.amberAccent),
            ),
          ),
        ],
      ],
    );
  }
}
