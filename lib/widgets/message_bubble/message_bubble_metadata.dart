import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_models.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import '../../utils/constants.dart';
import '../../utils/token_utils.dart';

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
      final timestampStr = DateFormat('MMMM d, y - h:mm:ssa').format(msg.timestamp);
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
                  '${cleanModelName(msg.modelName!)} - $timestampStr',
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

    // Normalized on read so sessions saved before 0.7.29.1, which stored raw
    // provider payloads, still render instead of showing zeroes.
    final usage = TokenUtils.normalizeUsage(msg.usage);
    if (usage != null) {
      final int? reasoningTokens = usage['reasoning_tokens'] as int?;
      final int? cachedTokens = usage['cached_tokens'] as int?;
      final extras = <String>[
        if (reasoningTokens != null) "$reasoningTokens reasoning",
        if (cachedTokens != null) "$cachedTokens cached",
      ];
      final usageLabel = StringBuffer(
        "Usage: ${usage['prompt_tokens']} in + ${usage['completion_tokens']} out"
        " = ${usage['total_tokens']} total",
      );
      if (extras.isNotEmpty) usageLabel.write(" (${extras.join(', ')})");

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
              usageLabel.toString(),
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
