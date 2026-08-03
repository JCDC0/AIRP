/// Token accounting shared by the context meter, the per-message usage badge
/// and the lorebook budget.
///
/// AIRP talks to a dozen providers with as many different tokenizers, so an
/// exact local tokenizer is neither cheap nor portable. Instead the context
/// meter is anchored to the real `prompt_tokens` the provider reports on the
/// previous turn and only the text added since that anchor is estimated. A
/// per-provider calibration ratio corrects the residual drift, so the estimate
/// converges on the provider's own accounting after a single exchange.
class TokenUtils {
  TokenUtils._();

  /// Per-message envelope cost (role markers, delimiters).
  static const int perMessageOverhead = 4;

  /// Flat cost for one attached image. Gemini bills 258 tokens per tile and
  /// OpenAI-compatible vision models land in the same order of magnitude.
  static const int perImageTokens = 258;

  static const double minCalibration = 0.5;
  static const double maxCalibration = 2.0;

  /// Weight given to a new observation when updating a calibration ratio.
  static const double calibrationSmoothing = 0.4;

  static final RegExp _cjk = RegExp(
    '[　-〿぀-ゟ゠-ヿㇰ-ㇿ'
    '㐀-䶿一-鿿豈-﫿＀-￯]',
  );

  /// Estimates the token cost of [text].
  ///
  /// Latin script averages ~4 characters per token including the leading
  /// space that BPE merges into the token, so a plain character count is
  /// already calibrated and needs no extra per-word term. CJK and full-width
  /// characters are roughly one token each.
  static int estimate(String text) {
    if (text.isEmpty) return 0;

    int cjkCount = 0;
    for (final match in _cjk.allMatches(text)) {
      cjkCount += match.end - match.start;
    }

    final int otherChars = text.length - cjkCount;
    if (otherChars <= 0) return cjkCount;
    return cjkCount + (otherChars / 4).ceil();
  }

  /// Estimates the cost of a full request: the assembled system instruction
  /// plus every message that will actually be sent.
  ///
  /// [messageTexts] must already be sanitized for context and windowed to the
  /// active history limit, so this mirrors the outbound payload rather than
  /// the whole conversation.
  static int estimatePrompt({
    required Iterable<String> messageTexts,
    required String systemInstruction,
    int imageCount = 0,
  }) {
    int total = 0;
    int messageCount = 0;
    for (final text in messageTexts) {
      total += estimate(text);
      messageCount++;
    }
    total += messageCount * perMessageOverhead;
    total += imageCount * perImageTokens;
    if (systemInstruction.isNotEmpty) {
      total += estimate(systemInstruction) + perMessageOverhead;
    }
    return total;
  }

  /// Projects the current context size.
  ///
  /// With an anchor available the reported [anchorPromptTokens] is trusted
  /// verbatim and only the difference between [rawEstimate] and
  /// [anchorRawEstimate] is scaled by [calibration]. That difference is
  /// allowed to be negative: deleting or shortening a message inside the
  /// anchored window correctly shrinks the meter.
  static int projectContext({
    required int rawEstimate,
    double calibration = 1.0,
    int? anchorPromptTokens,
    int? anchorRawEstimate,
  }) {
    if (anchorPromptTokens == null || anchorRawEstimate == null) {
      final projected = (rawEstimate * calibration).round();
      return projected < 0 ? 0 : projected;
    }

    final int delta = rawEstimate - anchorRawEstimate;
    final int projected = anchorPromptTokens + (delta * calibration).round();
    return projected < 0 ? 0 : projected;
  }

  /// Folds an observed `prompt_tokens` reading into a calibration ratio.
  ///
  /// Returns [previous] unchanged when the observation is unusable, and
  /// clamps the result so a single outlier turn cannot wreck the meter.
  static double calibrate(double previous, int actualTokens, int rawEstimate) {
    if (actualTokens <= 0 || rawEstimate <= 0) return previous;

    final double observed = actualTokens / rawEstimate;
    final double blended =
        previous * (1 - calibrationSmoothing) + observed * calibrationSmoothing;
    return blended.clamp(minCalibration, maxCalibration);
  }

  /// Normalizes a provider usage payload onto OpenAI-style keys.
  ///
  /// Gemini reports camelCase `usageMetadata` (`promptTokenCount`,
  /// `candidatesTokenCount`, `thoughtsTokenCount`), some OpenAI-compatible
  /// gateways report `input_tokens` / `output_tokens`, and reasoning and
  /// cache figures hide one level down. Everything lands on
  /// `prompt_tokens`, `completion_tokens` and `total_tokens`, with
  /// `reasoning_tokens` and `cached_tokens` added when reported.
  ///
  /// Following OpenAI's semantics, `completion_tokens` includes
  /// `reasoning_tokens`; Gemini's `candidatesTokenCount` excludes thoughts,
  /// so they are added back here.
  static Map<String, dynamic>? normalizeUsage(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;

    final int? reasoning =
        _readInt(raw, const ['reasoning_tokens', 'thoughtsTokenCount']) ??
        _readNested(raw, 'completion_tokens_details', const [
          'reasoning_tokens',
        ]) ??
        _readNested(raw, 'output_tokens_details', const ['reasoning_tokens']);

    final int? cached =
        _readInt(raw, const ['cached_tokens', 'cachedContentTokenCount']) ??
        _readNested(raw, 'prompt_tokens_details', const ['cached_tokens']) ??
        _readNested(raw, 'input_tokens_details', const ['cached_tokens']);

    final int prompt =
        _readInt(raw, const [
          'prompt_tokens',
          'promptTokenCount',
          'input_tokens',
        ]) ??
        0;

    int completion =
        _readInt(raw, const ['completion_tokens', 'output_tokens']) ?? 0;

    final int? candidates = _readInt(raw, const ['candidatesTokenCount']);
    if (completion == 0 && candidates != null) {
      completion = candidates + (reasoning ?? 0);
    }

    int total = _readInt(raw, const ['total_tokens', 'totalTokenCount']) ?? 0;
    if (total == 0) total = prompt + completion;

    if (prompt == 0 && completion == 0 && total == 0) return null;

    return {
      'prompt_tokens': prompt,
      'completion_tokens': completion,
      'total_tokens': total,
      if (reasoning != null && reasoning > 0) 'reasoning_tokens': reasoning,
      if (cached != null && cached > 0) 'cached_tokens': cached,
    };
  }

  static int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static int? _readNested(
    Map<String, dynamic> map,
    String container,
    List<String> keys,
  ) {
    final nested = map[container];
    if (nested is Map) {
      return _readInt(Map<String, dynamic>.from(nested), keys);
    }
    return null;
  }
}
