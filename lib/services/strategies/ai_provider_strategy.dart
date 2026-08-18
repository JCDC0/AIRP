import 'dart:typed_data';
import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import '../chat_api_service.dart';

/// The reasoning/thinking request format a provider expects in the
/// OpenAI-compatible request body. Each provider's official docs specify a
/// different key for enabling reasoning; this enum tells [ChatApiService]
/// which one to emit (and which to omit).
enum ThinkingFormat {
  /// Send no reasoning parameter at all. For endpoints whose reasoning
  /// behaviour is not controllable from the request body.
  none,

  /// Emit `reasoning_effort: "<effort>"`, and omit the field entirely when
  /// the user disables reasoning. Correct where an absent field means "off".
  /// NVIDIA NIM validates this field and rejects anything outside
  /// `low|medium|high`, so `xhigh` must not be offered for it.
  reasoningEffort,

  /// Emit `reasoning_effort` on EVERY request, including the literal `none`.
  ///
  /// Required by providers that turn thinking ON when the field is absent:
  /// Ollama auto-enables thinking for any thinking-capable model it loads, so
  /// omitting the field is not "off", it is "default on".
  reasoningEffortAlways,

  /// Emit `thinking: {"type": "enabled"|"disabled"}` plus `reasoning_effort`
  /// when enabled. The DeepSeek V4 format, whose thinking mode defaults to ON
  /// at `high` when nothing is sent.
  thinkingObject,
}

/// A UI-facing label and its corresponding API value for a reasoning effort
/// setting.
class ReasoningEffortOption {
  final String label;
  final String apiValue;

  const ReasoningEffortOption(this.label, this.apiValue);
}

/// Default reasoning effort options shown when a provider does not override
/// [AiProviderStrategy.reasoningEffortOptions].
const List<ReasoningEffortOption> kDefaultReasoningEfforts = [
  ReasoningEffortOption('Disabled (None)', 'none'),
  ReasoningEffortOption('Low / Minimal', 'low'),
  ReasoningEffortOption('Medium', 'medium'),
  ReasoningEffortOption('High / Deep Think', 'high'),
];

/// Base strategy for AI provider-specific logic (URL generation, headers, parsing, and streaming).
abstract class AiProviderStrategy {
  AiProvider get provider;

  /// The default base URL for this provider's model list.
  String get baseUrl;

  /// The SharedPreferences key for caching this provider's models.
  String get prefKey;

  /// The reasoning request format this provider expects. Defaults to the
  /// OpenAI-native [ThinkingFormat.reasoningEffort]; providers whose docs
  /// specify a different format override this.
  ThinkingFormat get thinkingFormat => ThinkingFormat.reasoningEffort;

  /// Whether the provider supports a "Max" reasoning effort (e.g. `xhigh`).
  bool get supportsMaxReasoningEffort => false;

  /// The reasoning effort options shown in the UI for this provider.
  ///
  /// Providers that support a maximum effort level should override
  /// [supportsMaxReasoningEffort] or this getter directly.
  List<ReasoningEffortOption> get reasoningEffortOptions {
    final options = List<ReasoningEffortOption>.from(kDefaultReasoningEfforts);
    if (supportsMaxReasoningEffort) {
      options.add(const ReasoningEffortOption('Max', 'xhigh'));
    }
    return options;
  }

  /// Applies this provider's reasoning request field to [bodyMap].
  ///
  /// [effort] is the stored API value (`none`, `low`, `medium`, `high`, or
  /// `xhigh`). The base implementation respects [thinkingFormat]; providers
  /// with special needs (e.g. OpenRouter's dual format) may override this.
  void applyReasoningEffort(Map<String, dynamic> bodyMap, String effort) =>
      applyThinkingFormat(bodyMap, effort, thinkingFormat);

  /// Writes [format]'s reasoning fields into [bodyMap].
  ///
  /// Static so [ChatApiService] can apply the same rules for callers that do
  /// not hand it a strategy callback, instead of keeping its own copy of the
  /// switch in three request builders.
  static void applyThinkingFormat(
    Map<String, dynamic> bodyMap,
    String effort,
    ThinkingFormat format,
  ) {
    final enabled = effort != 'none';
    switch (format) {
      case ThinkingFormat.none:
        break;
      case ThinkingFormat.reasoningEffort:
        if (enabled) {
          bodyMap['reasoning_effort'] = effort;
        }
        break;
      case ThinkingFormat.reasoningEffortAlways:
        bodyMap['reasoning_effort'] = effort;
        break;
      case ThinkingFormat.thinkingObject:
        bodyMap['thinking'] = {'type': enabled ? 'enabled' : 'disabled'};
        if (enabled) {
          bodyMap['reasoning_effort'] = effort;
        }
        break;
    }
  }

  /// Returns the streaming endpoint URL.
  String getStreamUrl({String? customUrl}) => customUrl ?? baseUrl;

  /// Returns the model-list URL for this provider.
  ///
  /// [customBase] is the user-configured server root for providers that run
  /// against an endpoint the user owns (Local, OpenAI Compatible, Ollama).
  /// When it is null or blank the provider's fixed [baseUrl] is used, so
  /// hosted providers need no override.
  String getModelsUrl({String? customBase}) {
    final base = customBase?.trim() ?? '';
    if (base.isEmpty) return baseUrl;
    return appendModelsPath(base);
  }

  /// Normalizes a user-entered server root into a `/models` listing URL.
  ///
  /// Accepts a bare root (`http://host:1234`), a versioned root
  /// (`http://host:1234/v1`), or a URL that already points at the listing.
  static String appendModelsPath(String rawBase) {
    var url = rawBase.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return '';
    if (url.endsWith('/models')) return url;
    if (url.endsWith('/chat/completions')) {
      url = url.substring(0, url.length - '/chat/completions'.length);
    }
    return '$url/models';
  }

  /// Generates the necessary headers for API requests.
  Map<String, String> getHeaders(String apiKey) {
    if (apiKey.isEmpty) return {};
    return {"Authorization": "Bearer $apiKey"};
  }

  /// Parses the raw JSON response from the models endpoint.
  List<ModelInfo> parseModels(dynamic json);

  /// Cleans up a model ID for display if needed.
  String formatModelName(String rawId) => cleanModelName(rawId);

  /// Streams a response from this provider.
  ///
  /// The default implementation forwards every argument to
  /// [ChatApiService.streamOpenAiCompatible], which is correct for any
  /// OpenAI-compatible endpoint. Providers with a non-OpenAI protocol (e.g.
  /// Gemini's SDK) override this method.
  Stream<String> streamResponse({
    required String apiKey,
    required String baseUrl,
    required String model,
    required List<ChatMessage> history,
    required String systemInstruction,
    required String userMessage,
    required List<String> imagePaths,
    double? temperature,
    double? topP,
    int? topK,
    int? maxTokens,
    bool enableGrounding = false,
    String? reasoningEffort,
    Map<String, String>? extraHeaders,
    bool includeUsage = false,
    List<Map<String, dynamic>>? depthMessages,
    Map<String, Uint8List>? attachmentBytes,
    List<Map<String, dynamic>>? extraMessages,
    bool disableSafety = true,
  }) {
    return ChatApiService.streamOpenAiCompatible(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      history: history,
      systemInstruction: systemInstruction,
      userMessage: userMessage,
      imagePaths: imagePaths,
      temperature: temperature,
      topP: topP,
      topK: topK,
      maxTokens: maxTokens,
      enableGrounding: enableGrounding,
      reasoningEffort: reasoningEffort,
      applyReasoningEffort: applyReasoningEffort,
      extraHeaders: extraHeaders,
      includeUsage: includeUsage,
      depthMessages: depthMessages,
      attachmentBytes: attachmentBytes,
      extraMessages: extraMessages,
    );
  }
}

/// A standard strategy for OpenAI-compatible providers.
class OpenAiCompatibleStrategy extends AiProviderStrategy {
  @override
  final AiProvider provider;
  @override
  final String baseUrl;
  @override
  final String prefKey;
  @override
  final ThinkingFormat thinkingFormat;

  OpenAiCompatibleStrategy({
    required this.provider,
    required this.baseUrl,
    required this.prefKey,
    this.thinkingFormat = ThinkingFormat.reasoningEffort,
  });

  @override
  String getStreamUrl({String? customUrl}) {
    String url = customUrl ?? baseUrl;
    if (url.isEmpty) return "";
    
    // Clean trailing slash
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    
    // If the URL explicitly ends with /models, replace it with /chat/completions
    if (url.endsWith('/models')) {
      url = "${url.substring(0, url.length - 7)}/chat/completions";
    } else if (!url.contains('/chat/completions')) {
      // For custom endpoints that might just be the root (e.g. localhost)
      url = "$url/chat/completions";
    }
    
    return url;
  }

  @override
  List<ModelInfo> parseModels(dynamic json) {
    final List<dynamic> dataList = json['data'] ?? [];
    return dataList.map<ModelInfo>((e) {
      final rawId = e['id'].toString();
      final pricing = e['pricing'] ?? {};
      return ModelInfo(
        id: rawId,
        name: e['name']?.toString() ?? formatModelName(rawId),
        description:
            e['description']?.toString() ??
            "Owned by: ${e['owned_by'] ?? 'Unknown'}",
        contextLength:
            (e['context_length'] ?? e['context_window'])?.toString() ?? "",
        pricing:
            pricing.isNotEmpty
                ? "${pricing['prompt'] ?? '0'} / ${pricing['completion'] ?? '0'}"
                : "",
        created: e['created'],
        rawData: e,
      );
    }).toList();
  }

  // streamResponse inherits the OpenAI-compatible default from
  // [AiProviderStrategy.streamResponse].
}
