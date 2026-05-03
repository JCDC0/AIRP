class ReasoningSplitResult {
  final String reasoning;
  final String content;
  final bool isDone;

  const ReasoningSplitResult({
    required this.reasoning,
    required this.content,
    required this.isDone,
  });
}

/// Utility helpers for parsing and stripping &lt;think&gt; reasoning blocks.
class ReasoningUtils {
  ReasoningUtils._();

  static final RegExp _thinkBlockRegex = RegExp(
    r'<think>([\s\S]*?)(?:</think>|$)',
    caseSensitive: false,
  );

  /// Splits a message into reasoning and visible content.
  ///
  /// Multiple think blocks are merged into one reasoning body separated
  /// by blank lines.
  static ReasoningSplitResult split(String text) {
    final matches = _thinkBlockRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return ReasoningSplitResult(reasoning: '', content: text, isDone: true);
    }

    final reasoningParts = <String>[];
    var isDone = true;

    for (final match in matches) {
      final raw = match.group(0) ?? '';
      final reason = (match.group(1) ?? '').trim();
      if (reason.isNotEmpty) {
        reasoningParts.add(reason);
      }
      if (!raw.toLowerCase().contains('</think>')) {
        isDone = false;
      }
    }

    final content = text.replaceAll(_thinkBlockRegex, '').trim();
    return ReasoningSplitResult(
      reasoning: reasoningParts.join('\n\n').trim(),
      content: content,
      isDone: isDone,
    );
  }

  /// Returns text with all `<think>` blocks removed.
  static String stripThinkBlocks(String text) {
    return text.replaceAll(_thinkBlockRegex, '').trim();
  }

  static bool hasThinkBlocks(String text) {
    return _thinkBlockRegex.hasMatch(text);
  }
}
