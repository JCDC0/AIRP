import '../../models/chat_models.dart';
import '../../utils/constants.dart';
import 'ai_provider_strategy.dart';

/// Strategy for the DeepSeek platform API.
///
/// DeepSeek V4 controls thinking with a `thinking` object rather than the
/// OpenAI `reasoning_effort` field alone, and its thinking mode is ON by
/// default at `high`. Sending nothing therefore does not mean "no reasoning",
/// which is what AIRP assumed before `0.7.30.1`; the object is now always sent
/// so Disabled is honoured.
///
/// DeepSeek's effort ladder is `low | high | max`. It has no `medium`, so the
/// generic four-step menu is replaced with the levels the API accepts.
class DeepseekStrategy extends OpenAiCompatibleStrategy {
  DeepseekStrategy()
    : super(
        provider: AiProvider.deepseek,
        baseUrl: ApiConstants.deepseekBaseUrl,
        prefKey: ApiConstants.prefListDeepseek,
        thinkingFormat: ThinkingFormat.thinkingObject,
      );

  @override
  List<ReasoningEffortOption> get reasoningEffortOptions => const [
    ReasoningEffortOption('Disabled (None)', 'none'),
    ReasoningEffortOption('Low / Minimal', 'low'),
    ReasoningEffortOption('High / Deep Think', 'high'),
    ReasoningEffortOption('Max', 'max'),
  ];
}
