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
  bool get supportsMaxReasoningEffort => true;

  @override
  void applyReasoningEffort(Map<String, dynamic> bodyMap, String effort) {
    // OpenRouter accepts both the OpenAI-compatible `reasoning_effort` key and
    // its newer unified `reasoning` object. Emit both for `xhigh` so gateways
    // that only understand one of the two can still honor the request.
    bodyMap['reasoning_effort'] = effort;
    if (effort == 'xhigh') {
      bodyMap['reasoning'] = {'effort': effort};
    }
  }

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
