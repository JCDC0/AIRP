import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import '../../utils/constants.dart';

class MessageBubbleMetadata extends StatelessWidget {
  final ChatMessage msg;
  final ThemeProvider themeProvider;
  final ScaleProvider scaleProvider;
  final Color textColor;
  final bool useBloom;

  const MessageBubbleMetadata({
    super.key,
    required this.msg,
    required this.themeProvider,
    required this.scaleProvider,
    required this.textColor,
    required this.useBloom,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.isUser) return const SizedBox.shrink();

    final List<Widget> children = [];

    if (msg.modelName != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: themeProvider.containerFillColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: useBloom
                      ? [
                          BoxShadow(
                            color: themeProvider.containerFillColor,
                            blurRadius: 4,
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  cleanModelName(msg.modelName!),
                  style: TextStyle(
                    fontSize: scaleProvider.chatFontSize - 4,
                    color: textColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    shadows: useBloom
                        ? [
                            Shadow(
                              color: textColor.withValues(alpha: 0.9),
                              blurRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                ),
              ),
              if (msg.reasoningRecovered)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Recovered final answer from reasoning-only output',
                    style: TextStyle(
                      fontSize: scaleProvider.chatFontSize - 5,
                      color: Colors.amberAccent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (msg.usage != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: themeProvider.containerFillColor,
              borderRadius: BorderRadius.circular(4),
              boxShadow: useBloom
                  ? [
                      BoxShadow(
                        color: themeProvider.containerFillColor,
                        blurRadius: 4,
                      ),
                    ]
                  : [],
            ),
            child: Text(
              "Usage: ${msg.usage!['prompt_tokens'] ?? 0} in + ${msg.usage!['completion_tokens'] ?? 0} out = ${msg.usage!['total_tokens'] ?? 0} total",
              style: TextStyle(
                fontSize: scaleProvider.chatFontSize - 4,
                color: textColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                shadows: useBloom
                    ? [
                        Shadow(
                          color: textColor.withValues(alpha: 0.9),
                          blurRadius: 4,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
