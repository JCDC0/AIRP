import 'package:airp/models/chat_models.dart';
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
    test('reasoningEffort providers emit the OpenAI field', () {
      final body = <String, dynamic>{};
      StrategyResolver.resolve(
        AiProvider.nvidia,
      ).applyReasoningEffort(body, 'high');
      expect(body['reasoning_effort'], 'high');
    });

    test('none providers stay silent', () {
      final body = <String, dynamic>{};
      StrategyResolver.resolve(
        AiProvider.deepseek,
      ).applyReasoningEffort(body, 'high');
      expect(body, isEmpty);
    });

    test('disabled reasoning omits the field entirely', () {
      final body = <String, dynamic>{};
      StrategyResolver.resolve(
        AiProvider.xAi,
      ).applyReasoningEffort(body, 'none');
      expect(body['reasoning_effort'], 'none');
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
