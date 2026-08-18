import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import 'ai_provider_strategy.dart';

/// Strategy for a local (or self-hosted) Ollama server.
///
/// The user configures a bare server root such as `http://localhost:11434`.
/// Ollama exposes two surfaces from that root: a native API under `/api` and
/// an OpenAI-compatible API under `/v1`. This strategy chats over `/v1` and
/// lists models over the native `/api/tags`, which is the only one of the two
/// that reports parameter size, quantization, and family.
class OllamaStrategy extends OpenAiCompatibleStrategy {
  OllamaStrategy()
    : super(
        provider: AiProvider.ollama,
        baseUrl: '${ApiConstants.ollamaDefaultEndpoint}/api/tags',
        prefKey: ApiConstants.prefListOllama,
        thinkingFormat: ThinkingFormat.reasoningEffortAlways,
      );

  /// Ollama's OpenAI layer maps `reasoning_effort` onto its native `think`
  /// parameter and accepts `none|low|medium|high`. It auto-enables thinking
  /// for any thinking-capable model when the field is absent, so the field is
  /// sent on every request; omitting it would make Disabled unreachable.
  /// `xhigh` is deliberately not offered: Ollama rejects it.

  /// Strips any API suffix the user pasted, leaving the bare server root.
  ///
  /// `http://host:11434`, `http://host:11434/`, `http://host:11434/v1` and
  /// `http://host:11434/v1/chat/completions` all reduce to `http://host:11434`.
  static String serverRoot(String rawEndpoint) {
    var url = rawEndpoint.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return ApiConstants.ollamaDefaultEndpoint;

    for (final suffix in const [
      '/v1/chat/completions',
      '/api/chat',
      '/api/tags',
      '/v1/models',
      '/v1',
    ]) {
      if (url.endsWith(suffix)) {
        url = url.substring(0, url.length - suffix.length);
        break;
      }
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url.isEmpty ? ApiConstants.ollamaDefaultEndpoint : url;
  }

  @override
  String getStreamUrl({String? customUrl}) =>
      '${serverRoot(customUrl ?? ApiConstants.ollamaDefaultEndpoint)}'
      '/v1/chat/completions';

  @override
  String getModelsUrl({String? customBase}) =>
      '${serverRoot(customBase ?? ApiConstants.ollamaDefaultEndpoint)}'
      '/api/tags';

  /// Parses `/api/tags`, falling back to the OpenAI-compatible `{data: []}`
  /// shape so a reverse proxy that only exposes `/v1/models` still lists.
  @override
  List<ModelInfo> parseModels(dynamic json) {
    if (json is Map && json['models'] is List) {
      final List<dynamic> tags = json['models'];
      return tags.map<ModelInfo>((e) {
        final id = (e['model'] ?? e['name'] ?? '').toString();
        final details = e['details'] as Map<String, dynamic>? ?? const {};
        return ModelInfo(
          id: id,
          name: formatModelName(id),
          description: _describe(e, details),
          contextLength: '',
          pricing: '',
          rawData: e,
        );
      }).where((m) => m.id.isNotEmpty).toList();
    }
    return super.parseModels(json);
  }

  static String _describe(dynamic entry, Map<String, dynamic> details) {
    final parts = <String>[];
    final family = details['family']?.toString();
    if (family != null && family.isNotEmpty) parts.add(family);

    final params = details['parameter_size']?.toString();
    if (params != null && params.isNotEmpty) parts.add(params);

    final quant = details['quantization_level']?.toString();
    if (quant != null && quant.isNotEmpty) parts.add(quant);

    final size = entry['size'];
    if (size is num && size > 0) {
      parts.add('${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB');
    }

    return parts.isEmpty ? 'Local Ollama model' : parts.join(' · ');
  }
}
