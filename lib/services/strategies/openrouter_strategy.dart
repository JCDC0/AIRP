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

  /// Tier names and fallback rules from OpenRouter's service tiers guide.
  @override
  List<ServiceTierOption> get serviceTierOptions => const [
    ServiceTierOption(
      'Default',
      'default',
      'Standard capacity and price. No service_tier field is sent.',
    ),
    ServiceTierOption(
      'Flex',
      'flex',
      'Cheaper, slower, lower availability. Returns a capacity error '
          'instead of falling back to standard.',
    ),
    ServiceTierOption(
      'Priority',
      'priority',
      'Faster and more reliable at a higher price. Falls back to standard.',
      notRecommended: true,
      warning:
          'Priority bills above the standard rate on every request it serves. '
          'When no priority endpoint is free, OpenRouter falls back to a '
          'standard endpoint and bills the standard rate. Only some '
          'providers (OpenAI, Anthropic, Google, SpaceXAI) offer it.',
    ),
    ServiceTierOption(
      'Ultrafast',
      'ultrafast',
      'Lowest latency at several times the standard price. Select OpenAI '
          'models only.',
      notRecommended: true,
      warning:
          'Ultrafast bills several times the standard rate and exists only on '
          'select OpenAI models. Other models fall back to priority, then '
          'standard. Before each attempt OpenRouter checks that your balance '
          'covers the maximum output at the ultrafast price, so turn on Max '
          'Output Tokens to keep the request eligible.',
    ),
  ];

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
    final clean = apiKey.trim();
    return {
      if (clean.isNotEmpty) "Authorization": "Bearer $clean",
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
