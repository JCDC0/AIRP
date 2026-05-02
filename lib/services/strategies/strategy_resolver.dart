import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import 'ai_provider_strategy.dart';
import 'gemini_strategy.dart';
import 'openrouter_strategy.dart';
import 'huggingface_strategy.dart';
import 'nanogpt_strategy.dart';
import 'arliai_strategy.dart';
import 'groq_strategy.dart';

class StrategyResolver {
  static final Map<AiProvider, AiProviderStrategy> _strategies = {
    AiProvider.gemini: GeminiStrategy(),
    AiProvider.openRouter: OpenRouterStrategy(),
    AiProvider.huggingFace: HuggingFaceStrategy(),
    AiProvider.nanoGpt: NanoGptStrategy(),
    AiProvider.arliAi: ArliAiStrategy(),
    AiProvider.groq: GroqStrategy(),

    // OpenAI Compatible Defaults
    AiProvider.nvidia: OpenAiCompatibleStrategy(
      provider: AiProvider.nvidia,
      baseUrl: ApiConstants.nvidiaBaseUrl,
      prefKey: ApiConstants.prefListNvidia,
    ),
    AiProvider.openAi: OpenAiCompatibleStrategy(
      provider: AiProvider.openAi,
      baseUrl: ApiConstants.openAiBaseUrl,
      prefKey: ApiConstants.prefListOpenAi,
    ),
    AiProvider.blackboxAi: OpenAiCompatibleStrategy(
      provider: AiProvider.blackboxAi,
      baseUrl: ApiConstants.blackboxAiBaseUrl,
      prefKey: ApiConstants.prefListBlackboxAi,
    ),
    AiProvider.minimax: OpenAiCompatibleStrategy(
      provider: AiProvider.minimax,
      baseUrl: ApiConstants.minimaxBaseUrl,
      prefKey: ApiConstants.prefListMinimax,
    ),
    AiProvider.deepseek: OpenAiCompatibleStrategy(
      provider: AiProvider.deepseek,
      baseUrl: ApiConstants.deepseekBaseUrl,
      prefKey: ApiConstants.prefListDeepseek,
    ),
    AiProvider.qwen: OpenAiCompatibleStrategy(
      provider: AiProvider.qwen,
      baseUrl: ApiConstants.qwenBaseUrl,
      prefKey: ApiConstants.prefListQwen,
    ),
    AiProvider.xAi: OpenAiCompatibleStrategy(
      provider: AiProvider.xAi,
      baseUrl: ApiConstants.xAiBaseUrl,
      prefKey: ApiConstants.prefListXAi,
    ),
    AiProvider.zAi: OpenAiCompatibleStrategy(
      provider: AiProvider.zAi,
      baseUrl: ApiConstants.zAiBaseUrl,
      prefKey: ApiConstants.prefListZAi,
    ),
    AiProvider.mistral: OpenAiCompatibleStrategy(
      provider: AiProvider.mistral,
      baseUrl: ApiConstants.mistralBaseUrl,
      prefKey: ApiConstants.prefListMistral,
    ),
    AiProvider.ollama: OpenAiCompatibleStrategy(
      provider: AiProvider.ollama,
      baseUrl: ApiConstants.ollamaDefaultBaseUrl,
      prefKey: ApiConstants.prefListOllama,
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
