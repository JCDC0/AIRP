import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import '../chat_api_service.dart';
import 'ai_provider_strategy.dart';

class GeminiStrategy extends AiProviderStrategy {
  @override
  AiProvider get provider => AiProvider.gemini;

  @override
  String get baseUrl => ApiConstants.geminiBaseUrl;

  @override
  String get prefKey => ApiConstants.prefListGemini;

  @override
  String getStreamUrl({String? customUrl}) => ''; // Uses SDK

  @override
  Map<String, String> getHeaders(String apiKey) => {};

  @override
  List<ModelInfo> parseModels(dynamic json) {
    final List<dynamic> models = json['models'] ?? [];
    return models
        .where((m) {
          final methods = List<String>.from(
            m['supportedGenerationMethods'] ?? [],
          );
          return methods.contains('generateContent');
        })
        .map<ModelInfo>(
          (m) => ModelInfo(
            id: m['name'].toString(),
            name: m['displayName']?.toString() ?? m['name'].toString(),
            description: m['description']?.toString() ?? "",
            contextLength: m['inputTokenLimit']?.toString() ?? "",
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
    if (providerSession is! ChatSession) {
      throw Exception('GeminiStrategy requires a ChatSession');
    }
    return ChatApiService.streamGeminiResponse(
      chatSession: providerSession,
      message: userMessage,
      imagePaths: imagePaths,
      modelName: model,
      attachmentBytes: attachmentBytes,
    );
  }
}
