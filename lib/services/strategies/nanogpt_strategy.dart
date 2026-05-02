import 'dart:typed_data';
import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import '../chat_api_service.dart';
import 'ai_provider_strategy.dart';

class NanoGptStrategy extends AiProviderStrategy {
  @override
  AiProvider get provider => AiProvider.nanoGpt;

  @override
  String get baseUrl => ApiConstants.nanoGptBaseUrl;

  @override
  String get prefKey => ApiConstants.prefListNanoGpt;

  @override
  List<ModelInfo> parseModels(dynamic json) {
    final List<dynamic> dataList = json['data'] ?? [];
    return dataList.map<ModelInfo>((e) {
      final pricing = e['pricing'] ?? {};
      double prompt = double.tryParse(pricing['prompt']?.toString() ?? "0") ?? 0;
      double completion =
          double.tryParse(pricing['completion']?.toString() ?? "0") ?? 0;
      if (prompt > 0) prompt /= 1000000;
      if (completion > 0) completion /= 1000000;
      return ModelInfo(
        id: e['id'].toString(),
        name: e['name']?.toString() ?? formatModelName(e['id'].toString()),
        description:
            e['description']?.toString() ??
            "Owned by: ${e['owned_by'] ?? 'Unknown'}",
        contextLength:
            (e['context_length'] ?? e['context_window'])?.toString() ?? "",
        pricing: "$prompt / $completion",
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
