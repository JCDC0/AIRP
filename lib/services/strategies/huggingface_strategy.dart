import 'dart:typed_data';
import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import '../chat_api_service.dart';
import 'ai_provider_strategy.dart';

class HuggingFaceStrategy extends AiProviderStrategy {
  @override
  AiProvider get provider => AiProvider.huggingFace;

  @override
  String get baseUrl => ApiConstants.huggingFaceBaseUrl;

  @override
  String get prefKey => ApiConstants.prefListHuggingFace;

  @override
  List<ModelInfo> parseModels(dynamic json) {
    final List<dynamic> dataList = json;
    return dataList
        .map<ModelInfo>(
          (e) => ModelInfo(
            id: e['id'].toString(),
            name: e['name']?.toString() ?? formatModelName(e['id'].toString()),
            description: e['description']?.toString() ?? "",
          ),
        )
        .toList();
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
    List<Map<String, dynamic>>? extraMessages,
    dynamic providerSession,
  }) {
    return ChatApiService.streamOpenAiCompatible(
      apiKey: apiKey,
      baseUrl: "https://router.huggingface.co/v1/chat/completions",
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
      extraMessages: extraMessages,
    );
  }
}
