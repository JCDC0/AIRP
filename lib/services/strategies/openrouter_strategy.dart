import '../../models/chat_models.dart';
import '../../utils/constants.dart';
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

  // streamResponse inherits the OpenAI-compatible default from
  // [AiProviderStrategy.streamResponse].
}
