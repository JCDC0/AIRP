import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import 'ai_provider_strategy.dart';

/// Strategy for NVIDIA NIM (`integrate.api.nvidia.com`).
///
/// The catalogue endpoint lists every hosted NIM, including embedding,
/// reranking and image-similarity models that have no `/chat/completions`
/// route at all. Those are dropped here so picking one cannot produce a 404
/// that looks like a bad API key. Entries carry no context window or pricing,
/// so the description falls back to the publisher.
class NvidiaStrategy extends AiProviderStrategy {
  @override
  AiProvider get provider => AiProvider.nvidia;

  @override
  String get baseUrl => ApiConstants.nvidiaBaseUrl;

  @override
  String get prefKey => ApiConstants.prefListNvidia;

  @override
  String getStreamUrl({String? customUrl}) =>
      "https://integrate.api.nvidia.com/v1/chat/completions";

  /// Model id fragments that identify a non-conversational NIM.
  static final RegExp _nonChatModel = RegExp(
    r'(embed|rerank|nvclip|retriever-parse)',
    caseSensitive: false,
  );

  @override
  List<ModelInfo> parseModels(dynamic json) {
    final List<dynamic> dataList = json['data'] ?? [];
    final models = dataList
        .map<ModelInfo>((e) {
          final rawId = e['id'].toString();
          return ModelInfo(
            id: rawId,
            name: formatModelName(rawId),
            description: "Published by ${e['owned_by'] ?? 'NVIDIA'}",
            contextLength: (e['context_length'] ?? '').toString(),
            pricing: '',
            created: e['created'],
            rawData: e,
          );
        })
        .where((m) => m.id.isNotEmpty && !_nonChatModel.hasMatch(m.id))
        .toList();

    models.sort((a, b) => a.id.compareTo(b.id));
    return models;
  }
}
