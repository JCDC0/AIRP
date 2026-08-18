import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import 'ai_provider_strategy.dart';
import 'gemini_strategy.dart';
import 'openrouter_strategy.dart';
import 'nanogpt_strategy.dart';
import 'nvidia_strategy.dart';
import 'ollama_strategy.dart';
import 'xai_strategy.dart';

/// Resolves the appropriate [AiProviderStrategy] for a given [AiProvider].
///
/// This registry centrally manages the mapping between providers and their
/// specific API logic, ensuring the rest of the application remains agnostic
/// to provider-specific implementation details.
class StrategyResolver {
  static final Map<AiProvider, AiProviderStrategy> _strategies = {
    AiProvider.gemini: GeminiStrategy(),
    AiProvider.openRouter: OpenRouterStrategy(),
    AiProvider.nanoGpt: NanoGptStrategy(),
    AiProvider.nvidia: NvidiaStrategy(),
    AiProvider.xAi: XAiStrategy(),
    AiProvider.ollama: OllamaStrategy(),

    // OpenAI Compatible Defaults
    AiProvider.deepseek: OpenAiCompatibleStrategy(
      provider: AiProvider.deepseek,
      baseUrl: ApiConstants.deepseekBaseUrl,
      prefKey: ApiConstants.prefListDeepseek,
      thinkingFormat: ThinkingFormat.none,
    ),
    AiProvider.openAiCompatible: OpenAiCompatibleStrategy(
      provider: AiProvider.openAiCompatible,
      baseUrl: '',
      prefKey: ApiConstants.prefListOpenAiCompatible,
    ),
    AiProvider.local: OpenAiCompatibleStrategy(
      provider: AiProvider.local,
      baseUrl: '',
      prefKey: ApiConstants.prefListLocal,
    ),
  };

  static AiProviderStrategy resolve(AiProvider provider) {
    final strategy = _strategies[provider];
    if (strategy == null) {
      // Fallback for custom or local providers
      return OpenAiCompatibleStrategy(
        provider: provider,
        baseUrl: '',
        prefKey: 'airp_list_${provider.name}',
      );
    }
    return strategy;
  }
}
