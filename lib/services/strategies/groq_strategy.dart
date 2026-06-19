import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import 'ai_provider_strategy.dart';

class GroqStrategy extends AiProviderStrategy {
  @override
  AiProvider get provider => AiProvider.groq;

  @override
  String get baseUrl => ApiConstants.groqBaseUrl;

  @override
  String get prefKey => ApiConstants.prefListGroq;

  @override
  String getStreamUrl({String? customUrl}) =>
      "https://api.groq.com/openai/v1/chat/completions";

  @override
  List<ModelInfo> parseModels(dynamic json) {
    final List<dynamic> dataList = json['data'] ?? [];
    return dataList.map<ModelInfo>((e) {
      final rawId = e['id'].toString();
      return ModelInfo(
        id: rawId,
        name: e['name']?.toString() ?? formatModelName(rawId),
        description:
            e['description']?.toString() ??
            "Owned by: ${e['owned_by'] ?? 'Unknown'}",
        contextLength:
            (e['context_length'] ?? e['context_window'])?.toString() ?? "",
        created: e['created'],
        rawData: e,
      );
    }).toList();
  }

  // streamResponse inherits the OpenAI-compatible default from
  // [AiProviderStrategy.streamResponse].
}
