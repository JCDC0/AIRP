import 'dart:typed_data';
import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import '../chat_api_service.dart';

/// The reasoning/thinking request format a provider expects in the
/// OpenAI-compatible request body. Each provider's official docs specify a
/// different key for enabling reasoning; this enum tells [ChatApiService]
/// which one to emit (and which to omit).
enum ThinkingFormat {
  /// Send no reasoning parameter. Used by providers whose reasoning models
  /// reason automatically (e.g. DeepSeek `deepseek-reasoner`, Mistral
  /// Magistral, Xiaomi MiMo-7B-RL).
  none,

  /// Emit `reasoning_effort: "<effort>"`. The OpenAI-native format used by
  /// OpenAI o-series, xAI Grok, Groq, Nvidia, Minimax, Blackbox, etc.
  reasoningEffort,

  /// Emit `enable_thinking: true|false`. The Qwen/DashScope format.
  enableThinking,

  /// Emit `thinking: {type: "enabled"|"disabled"}`. The Z.AI/Zhipu GLM format.
  thinkingObject,
}

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

  /// Returns the streaming endpoint URL.
  String getStreamUrl({String? customUrl}) => customUrl ?? baseUrl;

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
    dynamic providerSession,
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
      thinkingFormat: thinkingFormat,
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
