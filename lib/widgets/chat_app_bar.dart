import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../models/chat_models.dart';
import 'model_selector.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenEndDrawer;

  const ChatAppBar({
    super.key,
    this.onOpenDrawer,
    this.onOpenEndDrawer,
  });

  @override
  Size get preferredSize => const Size.fromHeight(85);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final tokenColor = chatProvider.tokenCount > 1000000 ? Colors.redAccent : themeProvider.appThemeColor;

    return AppBar(
      toolbarHeight: 40,
      backgroundColor: themeProvider.backgroundImagePath != null
          ? const Color(0xFFFFFFFF).withAlpha((0 * 255).round())
          : const Color.fromARGB(255, 0, 0, 0),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
      ),
      
      title: PopupMenuButton<AiProvider>(
        initialValue: chatProvider.currentProvider,
        color: const Color(0xFF2C2C2C),
        shadowColor: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : null,
        elevation: themeProvider.enableBloom ? 12 : 8,
        onSelected: (AiProvider result) {
          chatProvider.setProvider(result);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to ${result.name.toUpperCase()}")));
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<AiProvider>>[
          PopupMenuItem<AiProvider>(
            value: AiProvider.gemini,
            child: Row(children: [Icon(Icons.auto_awesome, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - Gemini')]),
          ),
          PopupMenuItem<AiProvider>(
            value: AiProvider.openRouter,
            child: Row(children: [Icon(Icons.router, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - OpenRouter')]),
          ),
          PopupMenuItem<AiProvider>(
            value: AiProvider.arliAi,
            child: Row(children: [Icon(Icons.alternate_email, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - ArliAI')]),
          ),
          PopupMenuItem<AiProvider>(
            value: AiProvider.nanoGpt,
            child: Row(children: [Icon(Icons.bolt, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - NanoGPT')]),
          ),
          PopupMenuItem<AiProvider>(
            value: AiProvider.local,
            child: Row(children: [Icon(Icons.laptop_mac, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - Local')]),
          ),
          PopupMenuItem<AiProvider>(
            value: AiProvider.openAi,
            child: Row(children: [Icon(Icons.auto_awesome_mosaic, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - OpenAI')]),
          ),
          PopupMenuItem<AiProvider>(
            value: AiProvider.huggingFace,
            child: Row(children: [Icon(Icons.emoji_emotions, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - HuggingFace')]),
          ),
          PopupMenuItem<AiProvider>(
            value: AiProvider.groq,
            child: Row(children: [Icon(Icons.speed, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - Groq')]),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Token Counter (Top Line)
            Text(
              "Context: ${chatProvider.tokenCount} / 1,048,576",
              style: TextStyle(
                color: tokenColor.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                shadows: themeProvider.enableBloom ? [Shadow(color: tokenColor, blurRadius: 6)] : [],
              ),
            ),
            // 2. Provider Selector (Middle Line)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'AIRP - ${chatProvider.currentProvider == AiProvider.gemini ? "Gemini"
                        : chatProvider.currentProvider == AiProvider.openRouter ? "OpenRouter"
                        : chatProvider.currentProvider == AiProvider.arliAi ? "ArliAI"
                        : chatProvider.currentProvider == AiProvider.nanoGpt ? "NanoGPT"
                        : chatProvider.currentProvider == AiProvider.local ? "Local"
                        : chatProvider.currentProvider == AiProvider.openAi ? "OpenAI"
                        : chatProvider.currentProvider == AiProvider.groq ? "Groq"
                        : "HuggingFace"} ${_getModelCount(chatProvider) > 0 ? "(${_getModelCount(chatProvider)})" : ""}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: themeProvider.appThemeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 8)] : [],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: themeProvider.appThemeColor, size: 18),
              ],
            ),
          ],
        ),
      ),

      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: onOpenEndDrawer ?? () => Scaffold.of(context).openEndDrawer(),
        ),
      ],
      
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: _buildModelSelector(context, chatProvider, themeProvider),
        ),
      ),
    );
  }

  Widget _buildModelSelector(BuildContext context, ChatProvider chatProvider, ThemeProvider themeProvider) {
    switch (chatProvider.currentProvider) {
      case AiProvider.gemini:
        return ModelSelector(
          modelsList: chatProvider.geminiModelsList,
          selectedModel: chatProvider.selectedGeminiModel,
          onSelected: chatProvider.setModel,
          placeholder: "Select Gemini Model",
          isCompact: true,
        );
      case AiProvider.openRouter:
        return ModelSelector(
          modelsList: chatProvider.openRouterModelsList,
          selectedModel: chatProvider.openRouterModel,
          onSelected: chatProvider.setModel,
          placeholder: "Select OpenRouter Model",
          isCompact: true,
        );
      case AiProvider.arliAi:
        return ModelSelector(
          modelsList: chatProvider.arliAiModelsList,
          selectedModel: chatProvider.arliAiModel,
          onSelected: chatProvider.setModel,
          placeholder: "Select ArliAI Model",
          isCompact: true,
        );
      case AiProvider.nanoGpt:
        return ModelSelector(
          modelsList: chatProvider.nanoGptModelsList,
          selectedModel: chatProvider.nanoGptModel,
          onSelected: chatProvider.setModel,
          placeholder: "Select NanoGPT Model",
          isCompact: true,
        );
      case AiProvider.openAi:
        return ModelSelector(
          modelsList: chatProvider.openAiModelsList,
          selectedModel: chatProvider.openAiModel,
          onSelected: chatProvider.setModel,
          placeholder: "Select OpenAI Model",
          isCompact: true,
        );
      case AiProvider.huggingFace:
        return ModelSelector(
          modelsList: chatProvider.huggingFaceModelsList,
          selectedModel: chatProvider.huggingFaceModel,
          onSelected: chatProvider.setModel,
          placeholder: "Select HuggingFace Model",
          isCompact: true,
        );
      case AiProvider.groq:
        return ModelSelector(
          modelsList: chatProvider.groqModelsList,
          selectedModel: chatProvider.groqModel,
          onSelected: chatProvider.setModel,
          placeholder: "Select Groq Model",
          isCompact: true,
        );
      case AiProvider.local:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
            boxShadow: themeProvider.enableBloom ? [BoxShadow(color: themeProvider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  chatProvider.currentProvider == AiProvider.local
                      ? (chatProvider.localModelName.isNotEmpty ? chatProvider.localModelName : "Local Model")
                      : "Model Selection Unavailable",
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (chatProvider.currentProvider == AiProvider.local)
                 const Icon(Icons.computer, color: Colors.white70, size: 16),
            ],
          ),
        );
    }
  }

  int _getModelCount(ChatProvider provider) {
    switch (provider.currentProvider) {
      case AiProvider.gemini: return provider.geminiModelsList.length;
      case AiProvider.openRouter: return provider.openRouterModelsList.length;
      case AiProvider.arliAi: return provider.arliAiModelsList.length;
      case AiProvider.nanoGpt: return provider.nanoGptModelsList.length;
      case AiProvider.openAi: return provider.openAiModelsList.length;
      case AiProvider.huggingFace: return provider.huggingFaceModelsList.length;
      case AiProvider.groq: return provider.groqModelsList.length;
      default: return 0;
    }
  }
}
