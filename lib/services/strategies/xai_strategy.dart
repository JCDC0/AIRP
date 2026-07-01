import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import 'ai_provider_strategy.dart';

/// Strategy for xAI (Grok) via their OpenAI-compatible endpoint.
///
/// xAI supports `reasoning_effort: none|low|medium|high` on reasoning models
/// such as `grok-4.3`, so we explicitly emit the parameter even when the user
/// disables reasoning.
class XAiStrategy extends AiProviderStrategy {
  @override
  AiProvider get provider => AiProvider.xAi;

  @override
  String get baseUrl => ApiConstants.xAiBaseUrl;

  @override
  String get prefKey => ApiConstants.prefListXAi;

  @override
  void applyReasoningEffort(Map<String, dynamic> bodyMap, String effort) {
    bodyMap['reasoning_effort'] = effort;
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
}
