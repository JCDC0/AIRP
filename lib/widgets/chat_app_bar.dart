import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/scale_provider.dart';
import '../models/chat_models.dart';
import 'model_selector.dart';

/// The custom app bar used in the chat screen.
///
/// This app bar displays the current AI provider, token usage statistics,
/// and provides access to navigation and settings drawers. It also
/// includes a model selector in the bottom section.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Callback triggered when the navigation drawer should be opened.
  final VoidCallback? onOpenDrawer;

  /// Callback triggered when the settings drawer should be opened.
  final VoidCallback? onOpenEndDrawer;

  /// The base font size for system UI elements.
  final double systemFontSize;

  const ChatAppBar({
    super.key,
    this.onOpenDrawer,
    this.onOpenEndDrawer,
    required this.systemFontSize,
  });

  @override
  Size get preferredSize {
    const double baseToolbarHeight = 60.0;
    const double baseBottomHeight = 40.0;
    final double extraHeight = (systemFontSize - 12).clamp(0, 15);
    final double scaledToolbarHeight = baseToolbarHeight + extraHeight;
    final double scaledBottomHeight = baseBottomHeight + extraHeight * 0.5;
    return Size.fromHeight(scaledToolbarHeight + scaledBottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    
    final int maxContext = chatProvider.getMaxContext();
    final int currentTokens = chatProvider.tokenCount;
    
    Color tokenColor = themeProvider.appThemeColor;
    if (currentTokens >= maxContext) {
      tokenColor = Colors.redAccent;
    } else if (currentTokens >= (maxContext * 2 / 3)) {
      tokenColor = Colors.orangeAccent;
    } else if (currentTokens >= (maxContext / 2)) {
      tokenColor = Colors.yellowAccent;
    }

    final String providerName =
        chatProvider.currentProvider == AiProvider.gemini
            ? "Gemini"
            : chatProvider.currentProvider == AiProvider.openRouter
            ? "OpenRouter"
            : chatProvider.currentProvider == AiProvider.arliAi
            ? "ArliAI"
            : chatProvider.currentProvider == AiProvider.nanoGpt
            ? "NanoGPT"
            : chatProvider.currentProvider == AiProvider.local
            ? "Local"
            : chatProvider.currentProvider == AiProvider.openAi
            ? "OpenAI"
            : chatProvider.currentProvider == AiProvider.groq
            ? "Groq"
            : "HuggingFace";

    const double baseToolbarHeight = 60.0;
    const double baseBottomHeight = 40.0;
    final double extraHeight = (scaleProvider.systemFontSize - 12).clamp(0, 15);
    final double scaledToolbarHeight = baseToolbarHeight + extraHeight;
    final double scaledBottomHeight = baseBottomHeight + extraHeight * 0.5;

    return AppBar(
      toolbarHeight: scaledToolbarHeight,
      backgroundColor: themeProvider.backgroundImagePath != null
          ? const Color(0xFFFFFFFF).withAlpha(0)
          : const Color.fromARGB(255, 0, 0, 0),
      leading: IconButton(
        icon: Icon(Icons.menu, size: scaleProvider.iconScale * 24),
        onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
      ),
      title: PopupMenuButton<AiProvider>(
        initialValue: chatProvider.currentProvider,
        color: const Color(0xFF2C2C2C),
        shadowColor: themeProvider.enableBloom
            ? themeProvider.appThemeColor.withOpacity(0.5)
            : null,
        elevation: themeProvider.enableBloom ? 12 : 8,
        onSelected: (AiProvider result) {
          chatProvider.setProvider(result);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Switched to ${result.name.toUpperCase()}")),
          );
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<AiProvider>>[
          PopupMenuItem<AiProvider>(
            height: scaleProvider.systemFontSize * 2.5,
            value: AiProvider.gemini,
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: themeProvider.appThemeColor),
                const SizedBox(width: 8),
                Text(
                  'Gemini',
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
                ),
              ],
            ),
          ),
          PopupMenuItem<AiProvider>(
            height: scaleProvider.systemFontSize * 2.5,
            value: AiProvider.openRouter,
            child: Row(
              children: [
                Icon(Icons.router, color: themeProvider.appThemeColor),
                const SizedBox(width: 8),
                Text(
                  'OpenRouter',
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
                ),
              ],
            ),
          ),
          PopupMenuItem<AiProvider>(
            height: scaleProvider.systemFontSize * 2.5,
            value: AiProvider.arliAi,
            child: Row(
              children: [
                Icon(Icons.alternate_email, color: themeProvider.appThemeColor),
                const SizedBox(width: 8),
                Text(
                  'ArliAI',
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
                ),
              ],
            ),
          ),
          PopupMenuItem<AiProvider>(
            height: scaleProvider.systemFontSize * 2.5,
            value: AiProvider.nanoGpt,
            child: Row(
              children: [
                Icon(Icons.bolt, color: themeProvider.appThemeColor),
                const SizedBox(width: 8),
                Text(
                  'NanoGPT',
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
                ),
              ],
            ),
          ),
          PopupMenuItem<AiProvider>(
            height: scaleProvider.systemFontSize * 2.5,
            value: AiProvider.local,
            child: Row(
              children: [
                Icon(Icons.laptop_mac, color: themeProvider.appThemeColor),
                const SizedBox(width: 8),
                Text(
                  'Local',
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
                ),
              ],
            ),
          ),
          PopupMenuItem<AiProvider>(
            height: scaleProvider.systemFontSize * 2.5,
            value: AiProvider.openAi,
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_mosaic,
                  color: themeProvider.appThemeColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'OpenAI',
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
                ),
              ],
            ),
          ),
          PopupMenuItem<AiProvider>(
            height: scaleProvider.systemFontSize * 2.5,
            value: AiProvider.huggingFace,
            child: Row(
              children: [
                Icon(Icons.emoji_emotions, color: themeProvider.appThemeColor),
                const SizedBox(width: 8),
                Text(
                  'HuggingFace',
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
                ),
              ],
            ),
          ),
          PopupMenuItem<AiProvider>(
            height: scaleProvider.systemFontSize * 2.5,
            value: AiProvider.groq,
            child: Row(
              children: [
                Icon(Icons.speed, color: themeProvider.appThemeColor),
                const SizedBox(width: 8),
                Text(
                  'Groq',
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
                ),
              ],
            ),
          ),
        ],
        child: SizedBox(
          width: 300 + (scaleProvider.systemFontSize * 10),
          child: Padding(
            padding: EdgeInsets.only(
              top: scaleProvider.systemFontSize * 1,
              bottom: scaleProvider.systemFontSize * 0.6,
              left: 8.0,
              right: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Context: ${chatProvider.tokenCount} / ${chatProvider.formatNumber(maxContext.toString())}",
                  style: TextStyle(
                    color: tokenColor.withOpacity(0.8),
                    fontSize: scaleProvider.systemFontSize - 2,
                    fontWeight: FontWeight.w600,
                    shadows: themeProvider.enableBloom
                        ? [Shadow(color: tokenColor, blurRadius: 6)]
                        : [],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      providerName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: themeProvider.appThemeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: scaleProvider.systemFontSize + 4,
                        shadows: themeProvider.enableBloom
                            ? [
                                Shadow(
                                  color: themeProvider.appThemeColor,
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: themeProvider.appThemeColor,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.settings, size: scaleProvider.iconScale * 24),
          onPressed:
              onOpenEndDrawer ?? () => Scaffold.of(context).openEndDrawer(),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(scaledBottomHeight),
        child: Container(
          height: scaledBottomHeight,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          child: Row(
            children: [
              Expanded(
                child: _buildModelSelector(
                  context,
                  chatProvider,
                  themeProvider,
                  scaleProvider,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 40, // Fixed width to prevent layout shift
                child: chatProvider.isRefreshingModels
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              themeProvider.appThemeColor.withOpacity(0.7),
                            ),
                          ),
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.refresh,
                          size: 20,
                          color: themeProvider.appThemeColor.withOpacity(0.7),
                        ),
                        onPressed: chatProvider.isLoading 
                            ? null 
                            : () => chatProvider.refreshCurrentModels(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelector(
    BuildContext context,
    ChatProvider chatProvider,
    ThemeProvider themeProvider,
    ScaleProvider scaleProvider,
  ) {
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  chatProvider.localModelName.isNotEmpty
                      ? chatProvider.localModelName
                      : "Local Model",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: scaleProvider.systemFontSize + 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.computer, color: Colors.white70, size: 16),
            ],
          ),
        );
    }
  }
}
