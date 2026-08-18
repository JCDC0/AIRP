import 'package:airp/models/chat_models.dart';
import 'package:airp/services/chat_api_service.dart';
import 'package:airp/services/strategies/ai_provider_strategy.dart';
import 'package:airp/services/strategies/nvidia_strategy.dart';
import 'package:airp/services/strategies/ollama_strategy.dart';
import 'package:airp/services/strategies/strategy_resolver.dart';
import 'package:airp/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OllamaStrategy endpoint handling', () {
    final strategy = OllamaStrategy();

    test('accepts a bare server root', () {
      expect(
        strategy.getStreamUrl(customUrl: 'http://localhost:11434'),
        'http://localhost:11434/v1/chat/completions',
      );
      expect(
        strategy.getModelsUrl(customBase: 'http://localhost:11434'),
        'http://localhost:11434/api/tags',
      );
    });

    test('accepts a root the user already suffixed with /v1', () {
      expect(
        strategy.getStreamUrl(customUrl: 'http://10.0.0.2:11434/v1/'),
        'http://10.0.0.2:11434/v1/chat/completions',
      );
      expect(
        strategy.getModelsUrl(customBase: 'http://10.0.0.2:11434/v1'),
        'http://10.0.0.2:11434/api/tags',
      );
    });

    test('accepts a full chat completions URL', () {
      expect(
        strategy.getStreamUrl(
          customUrl: 'http://host:11434/v1/chat/completions',
        ),
        'http://host:11434/v1/chat/completions',
      );
    });

    test('falls back to the default root when the endpoint is blank', () {
      expect(
        strategy.getStreamUrl(customUrl: ''),
        '${ApiConstants.ollamaDefaultEndpoint}/v1/chat/completions',
      );
    });

    test('parses the native /api/tags payload with model metadata', () {
      final models = strategy.parseModels({
        'models': [
          {
            'name': 'llama3.2:latest',
            'model': 'llama3.2:latest',
            'size': 2019393189,
            'details': {
              'family': 'llama',
              'parameter_size': '3.2B',
              'quantization_level': 'Q4_K_M',
            },
          },
        ],
      });

      expect(models, hasLength(1));
      expect(models.first.id, 'llama3.2:latest');
      expect(models.first.description, contains('3.2B'));
      expect(models.first.description, contains('Q4_K_M'));
      expect(models.first.description, contains('GB'));
    });

    test('still parses an OpenAI-compatible /v1/models payload', () {
      final models = strategy.parseModels({
        'data': [
          {'id': 'qwen3:8b', 'owned_by': 'library'},
        ],
      });

      expect(models, hasLength(1));
      expect(models.first.id, 'qwen3:8b');
    });
  });

  group('NvidiaStrategy', () {
    final strategy = NvidiaStrategy();

    test('drops NIMs that have no chat completions route', () {
      final models = strategy.parseModels({
        'data': [
          {'id': 'nvidia/llama-3.1-nemotron-70b-instruct', 'owned_by': 'nvidia'},
          {'id': 'nvidia/nv-embedqa-e5-v5', 'owned_by': 'nvidia'},
          {'id': 'nvidia/llama-3.2-nv-rerankqa-1b-v2', 'owned_by': 'nvidia'},
          {'id': 'nvidia/nvclip', 'owned_by': 'nvidia'},
          {'id': 'meta/llama-3.1-8b-instruct', 'owned_by': 'meta'},
        ],
      });

      expect(
        models.map((m) => m.id),
        ['meta/llama-3.1-8b-instruct', 'nvidia/llama-3.1-nemotron-70b-instruct'],
      );
    });

    test('streams against the chat completions route', () {
      expect(
        strategy.getStreamUrl(),
        'https://integrate.api.nvidia.com/v1/chat/completions',
      );
    });

    test('sends the key as a bearer token', () {
      expect(strategy.getHeaders('nvapi-test'), {
        'Authorization': 'Bearer nvapi-test',
      });
    });
  });

  group('model list URL resolution', () {
    test('hosted providers ignore a null custom base', () {
      final strategy = StrategyResolver.resolve(AiProvider.nvidia);
      expect(strategy.getModelsUrl(), ApiConstants.nvidiaBaseUrl);
    });

    test('user-owned endpoints gain the /models path', () {
      final strategy = StrategyResolver.resolve(AiProvider.openAiCompatible);
      expect(
        strategy.getModelsUrl(customBase: 'https://api.example.com/v1'),
        'https://api.example.com/v1/models',
      );
      expect(
        strategy.getModelsUrl(customBase: 'https://api.example.com/v1/models/'),
        'https://api.example.com/v1/models',
      );
      expect(
        strategy.getModelsUrl(
          customBase: 'https://api.example.com/v1/chat/completions',
        ),
        'https://api.example.com/v1/models',
      );
    });

    test('a blank custom base leaves an unconfigured provider empty', () {
      final strategy = StrategyResolver.resolve(AiProvider.local);
      expect(strategy.getModelsUrl(customBase: '  '), '');
    });
  });

  group('reasoning request format', () {
    Map<String, dynamic> bodyFor(AiProvider provider, String effort) {
      final body = <String, dynamic>{};
      StrategyResolver.resolve(provider).applyReasoningEffort(body, effort);
      return body;
    }

    test('NVIDIA sends reasoning_effort and omits it when disabled', () {
      expect(bodyFor(AiProvider.nvidia, 'high'), {'reasoning_effort': 'high'});
      expect(bodyFor(AiProvider.nvidia, 'none'), isEmpty);
    });

    test('NVIDIA never offers an effort its API rejects', () {
      final values = StrategyResolver.resolve(
        AiProvider.nvidia,
      ).reasoningEffortOptions.map((o) => o.apiValue);
      expect(values, isNot(contains('xhigh')));
      expect(values, isNot(contains('max')));
    });

    test('Ollama always sends reasoning_effort, including none', () {
      // Ollama auto-enables thinking when the field is absent, so omitting it
      // would make Disabled unreachable.
      expect(bodyFor(AiProvider.ollama, 'none'), {'reasoning_effort': 'none'});
      expect(bodyFor(AiProvider.ollama, 'medium'), {
        'reasoning_effort': 'medium',
      });
    });

    test('Ollama does not offer xhigh, which its API rejects', () {
      final values = StrategyResolver.resolve(
        AiProvider.ollama,
      ).reasoningEffortOptions.map((o) => o.apiValue);
      expect(values, isNot(contains('xhigh')));
    });

    test('NanoGPT always sends reasoning_effort and offers xhigh', () {
      expect(bodyFor(AiProvider.nanoGpt, 'none'), {'reasoning_effort': 'none'});
      expect(
        StrategyResolver.resolve(
          AiProvider.nanoGpt,
        ).reasoningEffortOptions.map((o) => o.apiValue),
        contains('xhigh'),
      );
    });

    test('DeepSeek sends the thinking object, which defaults to on', () {
      expect(bodyFor(AiProvider.deepseek, 'high'), {
        'thinking': {'type': 'enabled'},
        'reasoning_effort': 'high',
      });
      expect(bodyFor(AiProvider.deepseek, 'none'), {
        'thinking': {'type': 'disabled'},
      });
    });

    test('DeepSeek offers only the ladder its API accepts', () {
      expect(
        StrategyResolver.resolve(
          AiProvider.deepseek,
        ).reasoningEffortOptions.map((o) => o.apiValue),
        ['none', 'low', 'high', 'max'],
      );
    });

    test('OpenRouter emits both formats for its Max level', () {
      expect(bodyFor(AiProvider.openRouter, 'xhigh'), {
        'reasoning_effort': 'xhigh',
        'reasoning': {'effort': 'xhigh'},
      });
    });

    test('every live provider resolves a strategy', () {
      for (final provider in AiProvider.values) {
        expect(
          () => StrategyResolver.resolve(provider),
          returnsNormally,
          reason: '${provider.name} must resolve',
        );
      }
    });
  });

  group('Gemini thinkingConfig', () {
    test('sends nothing when the user has reasoning switched off', () {
      expect(
        ChatApiService.buildGeminiThinkingConfig(
          'models/gemini-3-flash-preview',
          null,
        ),
        isNull,
      );
    });

    test('Gemini 3 takes a thinkingLevel', () {
      expect(
        ChatApiService.buildGeminiThinkingConfig(
          'models/gemini-3-flash-preview',
          'high',
        ),
        {'includeThoughts': true, 'thinkingLevel': 'high'},
      );
      expect(
        ChatApiService.buildGeminiThinkingConfig('models/gemini-3.1-pro', 'none'),
        {'includeThoughts': false, 'thinkingLevel': 'minimal'},
      );
    });

    test('Gemini 2.5 takes a thinkingBudget instead', () {
      expect(
        ChatApiService.buildGeminiThinkingConfig('models/gemini-2.5-flash', 'low'),
        {'includeThoughts': true, 'thinkingBudget': 4096},
      );
      expect(
        ChatApiService.buildGeminiThinkingConfig('models/gemini-2.5-flash', 'none'),
        {'includeThoughts': false, 'thinkingBudget': 0},
      );
    });

    test('Gemini 2.5 Pro cannot disable thinking, so it goes dynamic', () {
      expect(
        ChatApiService.buildGeminiThinkingConfig('models/gemini-2.5-pro', 'none'),
        {'includeThoughts': false, 'thinkingBudget': -1},
      );
    });

    test('a non-Gemini id gets includeThoughts alone', () {
      expect(
        ChatApiService.buildGeminiThinkingConfig('models/gemma-3-27b-it', 'high'),
        {'includeThoughts': true},
      );
    });

    test('an effort the family does not name degrades to its default', () {
      expect(
        ChatApiService.buildGeminiThinkingConfig(
          'models/gemini-3-flash-preview',
          'xhigh',
        ),
        {'includeThoughts': true, 'thinkingLevel': 'high'},
      );
    });
  });

  test('appendModelsPath is idempotent', () {
    const url = 'https://api.example.com/v1/models';
    expect(AiProviderStrategy.appendModelsPath(url), url);
    expect(
      AiProviderStrategy.appendModelsPath(
        AiProviderStrategy.appendModelsPath('https://api.example.com/v1'),
      ),
      url,
    );
  });
}
