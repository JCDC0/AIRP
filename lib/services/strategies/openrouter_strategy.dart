import 'dart:typed_data';
import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import '../chat_api_service.dart';
import 'ai_provider_strategy.dart';

class OpenRouterStrategy extends AiProviderStrategy {
  @override
  AiProvider get provider => AiProvider.openRouter;

  @override
  String get baseUrl => ApiConstants.openRouterBaseUrl;

  @override
  String get prefKey => ApiConstants.prefListOpenRouter;

  @override
  String getStreamUrl({String? customUrl}) =>
      "https://openrouter.ai/api/v1/chat/completions";

  @override
  Map<String, String> getHeaders(String apiKey) {
    return {
      "Authorization": "Bearer $apiKey",
      "HTTP-Referer": "https://airp-chat.com",
      "X-Title": "AIRP Chat",
    };
  }

  @override
  List<ModelInfo> parseModels(dynamic json) {
    final List<dynamic> dataList = json['data'] ?? [];
    return dataList.map<ModelInfo>((e) {
      final pricing = e['pricing'] ?? {};
      return ModelInfo(
        id: e['id'].toString(),
        name: e['name']?.toString() ?? e['id'].toString(),
        description: e['description']?.toString() ?? "",
        contextLength: e['context_length']?.toString() ?? "",
        pricing: "${pricing['prompt'] ?? '0'} / ${pricing['completion'] ?? '0'}",
        created: e['created'],
        rawData: e,
      );
    }).toList();
  }

  @override
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
      extraHeaders: extraHeaders,
      includeUsage: includeUsage,
      depthMessages: depthMessages,
      attachmentBytes: attachmentBytes,
    );
  }
}
