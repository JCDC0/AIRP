import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import 'ai_provider_strategy.dart';

class NanoGptStrategy extends AiProviderStrategy {
  @override
  AiProvider get provider => AiProvider.nanoGpt;

  @override
  String get baseUrl => ApiConstants.nanoGptBaseUrl;

  @override
  String get prefKey => ApiConstants.prefListNanoGpt;

  @override
  String getStreamUrl({String? customUrl}) =>
      'https://nano-gpt.com/api/v1/chat/completions';

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

  // streamResponse inherits the OpenAI-compatible default from
  // [AiProviderStrategy.streamResponse].
}
