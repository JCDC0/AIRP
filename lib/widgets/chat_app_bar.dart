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
  static const Key providerPickerTriggerKey = Key('provider-picker-trigger');
  static const Key providerPickerDialogKey = Key('provider-picker-dialog');

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

  /// Maps each AiProvider enum value to its user-facing display name.
  static String _providerDisplayName(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini:
        return 'Gemini';
      case AiProvider.openRouter:
        return 'OpenRouter';
      case AiProvider.arliAi:
        return 'ArliAI';
      case AiProvider.nanoGpt:
        return 'NanoGPT';
      case AiProvider.nanoGptImage:
        return 'NanoGPT Image';
      case AiProvider.local:
        return 'Local';
      case AiProvider.openAi:
        return 'OpenAI';
      case AiProvider.huggingFace:
        return 'HuggingFace';
      case AiProvider.groq:
        return 'Groq';
      case AiProvider.vertexAi:
        return 'Vertex AI';
      case AiProvider.blackboxAi:
        return 'Blackbox AI';
      case AiProvider.minimax:
        return 'Minimax';
      case AiProvider.openAiCompatible:
        return 'OpenAI Compatible';
      case AiProvider.deepseek:
        return 'Deepseek';
      case AiProvider.ollama:
        return 'Ollama';
      case AiProvider.qwen:
        return 'Qwen';
      case AiProvider.xAi:
        return 'xAI';
      case AiProvider.zAi:
        return 'Z.ai';
      case AiProvider.mistral:
        return 'Mistral';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    final int maxContext = chatProvider.getMaxContext();
    final int currentTokens = chatProvider.tokenCount;

    Color tokenColor = themeProvider.textColor;
    if (currentTokens >= maxContext) {
      tokenColor = Colors.redAccent;
    } else if (currentTokens >= (maxContext * 2 / 3)) {
      tokenColor = Colors.orangeAccent;
    } else if (currentTokens >= (maxContext / 2)) {
      tokenColor = Colors.yellowAccent;
    }

    final String providerName =
        _providerDisplayName(chatProvider.currentProvider);

    const double baseToolbarHeight = 60.0;
    const double baseBottomHeight = 40.0;
    final double extraHeight = (scaleProvider.systemFontSize - 12).clamp(0, 15);
    final double scaledToolbarHeight = baseToolbarHeight + extraHeight;
    final double scaledBottomHeight = baseBottomHeight + extraHeight * 0.5;

    return AppBar(
      toolbarHeight: scaledToolbarHeight,
      backgroundColor: themeProvider.backgroundImagePath != null
          ? const Color(0xFFFFFFFF).withAlpha(0)
          : themeProvider.scaffoldBackgroundColor,
      leading: IconButton(
        icon: Icon(Icons.menu, size: scaleProvider.iconScale * 24),
        onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
      ),
      title: GestureDetector(
        key: providerPickerTriggerKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => _showProviderPicker(
          context,
          chatProvider,
          themeProvider,
          scaleProvider,
        ),
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
                        color: themeProvider.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: scaleProvider.systemFontSize + 4,
                        shadows: themeProvider.enableBloom
                            ? [
                                Shadow(
                                  color: themeProvider.bloomGlowColor,
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      key: const Key('provider-picker-arrow'),
                      color: themeProvider.textColor,
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
                              themeProvider.bloomGlowColor.withOpacity(0.7),
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
                          color: themeProvider.textColor.withOpacity(0.7),
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

  /// Shows a reactive provider picker dialog.
  ///
  /// The dialog wraps its content in a [Consumer<ChatProvider>] so that
  /// toggling the star on a provider immediately updates the icon and
  /// re-sorts the list without needing to close and reopen the menu.
  static void _showProviderPicker(
    BuildContext context,
    ChatProvider chatProvider,
    ThemeProvider themeProvider,
    ScaleProvider scaleProvider,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);

    showDialog<AiProvider>(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) => Consumer<ChatProvider>(
        builder: (ctx, cp, _) {
          final List<AiProvider> sortedProviders =
              List<AiProvider>.from(AiProvider.values);
          sortedProviders.sort((a, b) {
            final bool aStarred = cp.starredProviders.contains(a);
            final bool bStarred = cp.starredProviders.contains(b);
            if (aStarred && !bStarred) return -1;
            if (!aStarred && bStarred) return 1;
            return _providerDisplayName(a).compareTo(_providerDisplayName(b));
          });

          return Dialog(
            key: providerPickerDialogKey,
            backgroundColor: themeProvider.dropdownColor,
            elevation: themeProvider.enableBloom ? 12 : 8,
            shadowColor: themeProvider.enableBloom
                ? themeProvider.bloomGlowColor.withOpacity(0.5)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sortedProviders.length,
              itemBuilder: (_, i) {
                final AiProvider provider = sortedProviders[i];
                final bool isStarred = cp.starredProviders.contains(provider);
                return SizedBox(
                  key: ValueKey<String>('provider-row-${provider.name}'),
                  height: scaleProvider.systemFontSize * 2.5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              Navigator.of(dialogContext).pop(provider),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            child: Text(
                              _providerDisplayName(provider),
                              key: ValueKey<String>(
                                'provider-label-${provider.name}',
                              ),
                              style: TextStyle(
                                fontSize: scaleProvider.systemFontSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: ValueKey<String>('provider-star-${provider.name}'),
                        icon: Icon(
                          isStarred ? Icons.star : Icons.star_border,
                          size: scaleProvider.systemFontSize * 1.2,
                          color: isStarred
                              ? Colors.amber
                              : themeProvider.subtitleColor,
                        ),
                        onPressed: () => cp.toggleProviderStar(provider),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    ).then((AiProvider? result) {
      if (result != null) {
        chatProvider.setProvider(result);
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              "Switched to ${_providerDisplayName(result)}",
            ),
          ),
        );
      }
    });
  }

  /// Helper to build a standard [ModelSelector] for providers that maintain
  /// a model list. Keeps the switch statement DRY.
  Widget _standardModelSelector(
    ChatProvider chatProvider,
    List<ModelInfo> models,
    String selectedModel,
    String placeholder,
  ) {
    return ModelSelector(
      modelsList: models,
      selectedModel: selectedModel,
      onSelected: chatProvider.setModel,
      placeholder: placeholder,
      isCompact: true,
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
        return _standardModelSelector(
          chatProvider,
          chatProvider.geminiModelsList,
          chatProvider.selectedGeminiModel,
          "Select Gemini Model",
        );
      case AiProvider.openRouter:
        return _standardModelSelector(
          chatProvider,
          chatProvider.openRouterModelsList,
          chatProvider.openRouterModel,
          "Select OpenRouter Model",
        );
      case AiProvider.arliAi:
        return _standardModelSelector(
          chatProvider,
          chatProvider.arliAiModelsList,
          chatProvider.arliAiModel,
          "Select ArliAI Model",
        );
      case AiProvider.nanoGpt:
        return _standardModelSelector(
          chatProvider,
          chatProvider.nanoGptModelsList,
          chatProvider.nanoGptModel,
          'Select NanoGPT Model',
        );
      case AiProvider.nanoGptImage:
        return _standardModelSelector(
          chatProvider,
          chatProvider.nanoGptImageModelsList,
          chatProvider.nanoGptImageModel,
          'Select NanoGPT Image Model',
        );
      case AiProvider.openAi:
        return _standardModelSelector(
          chatProvider,
          chatProvider.openAiModelsList,
          chatProvider.openAiModel,
          'Select OpenAI Model',
        );
      case AiProvider.huggingFace:
        return _standardModelSelector(
          chatProvider,
          chatProvider.huggingFaceModelsList,
          chatProvider.huggingFaceModel,
          'Select HuggingFace Model',
        );
      case AiProvider.groq:
        return _standardModelSelector(
          chatProvider,
          chatProvider.groqModelsList,
          chatProvider.groqModel,
          'Select Groq Model',
        );
      case AiProvider.vertexAi:
        return _standardModelSelector(
          chatProvider,
          chatProvider.vertexAiModelsList,
          chatProvider.vertexAiModel,
          'Select Vertex AI Model',
        );
      case AiProvider.blackboxAi:
        return _standardModelSelector(
          chatProvider,
          chatProvider.blackboxAiModelsList,
          chatProvider.blackboxAiModel,
          'Select Blackbox AI Model',
        );
      case AiProvider.minimax:
        return _standardModelSelector(
          chatProvider,
          chatProvider.minimaxModelsList,
          chatProvider.minimaxModel,
          'Select Minimax Model',
        );
      case AiProvider.openAiCompatible:
        return _standardModelSelector(
          chatProvider,
          chatProvider.openAiCompatibleModelsList,
          chatProvider.openAiCompatibleModel,
          'Select Model',
        );
      case AiProvider.deepseek:
        return _standardModelSelector(
          chatProvider,
          chatProvider.deepseekModelsList,
          chatProvider.deepseekModel,
          'Select Deepseek Model',
        );
      case AiProvider.ollama:
        return _standardModelSelector(
          chatProvider,
          chatProvider.ollamaModelsList,
          chatProvider.ollamaModel,
          'Select Ollama Model',
        );
      case AiProvider.qwen:
        return _standardModelSelector(
          chatProvider,
          chatProvider.qwenModelsList,
          chatProvider.qwenModel,
          'Select Qwen Model',
        );
      case AiProvider.xAi:
        return _standardModelSelector(
          chatProvider,
          chatProvider.xAiModelsList,
          chatProvider.xAiModel,
          'Select xAI Model',
        );
      case AiProvider.zAi:
        return _standardModelSelector(
          chatProvider,
          chatProvider.zAiModelsList,
          chatProvider.zAiModel,
          'Select Z.ai Model',
        );
      case AiProvider.mistral:
        return _standardModelSelector(
          chatProvider,
          chatProvider.mistralModelsList,
          chatProvider.mistralModel,
          'Select Mistral Model',
        );
      case AiProvider.local:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  chatProvider.localModelName.isNotEmpty
                      ? chatProvider.localModelName
                      : "Local Model",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: scaleProvider.systemFontSize + 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.computer,
                color: themeProvider.subtitleColor,
                size: 16,
              ),
            ],
          ),
        );
    }
  }
}
