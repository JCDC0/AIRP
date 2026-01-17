import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../models/chat_models.dart';
import '../utils/constants.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(75);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final tokenColor = chatProvider.tokenCount > 1000000 ? Colors.redAccent : themeProvider.appThemeColor;

    return AppBar(
      toolbarHeight: 75,
      backgroundColor: themeProvider.backgroundImagePath != null
          ? const Color(0xFFFFFFFF).withAlpha((0 * 255).round())
          : const Color.fromARGB(255, 0, 0, 0),
      leading: Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(c).openDrawer())),
      
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
          const PopupMenuItem<AiProvider>(
            value: AiProvider.openAi,
            enabled: false,
            child: Row(children: [Icon(Icons.lock, color: Colors.grey), SizedBox(width: 8), Text('AIRP - OpenAI (Soon)')]),
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
                        : "OpenAI"}',
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
            // 3. Model Name (Subtitle/Bottom Line)
            Text(
              cleanModelName(chatProvider.selectedModel),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),

      actions: [
        Builder(builder: (c) => IconButton(icon: const Icon(Icons.settings), onPressed: () => Scaffold.of(c).openEndDrawer())),
      ],
    );
  }
}
