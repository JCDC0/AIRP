import 'package:airp/models/chat_models.dart';
import 'package:airp/utils/model_details.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _asMap(List<ModelDetail> details) => {
  for (final d in details) d.label: d.value,
};

void main() {
  test('returns nothing when the provider sent no raw payload', () {
    expect(ModelDetails.extract(ModelInfo(id: 'm', name: 'M')), isEmpty);
    expect(
      ModelDetails.extract(ModelInfo(id: 'm', name: 'M', rawData: const {})),
      isEmpty,
    );
  });

  test('surfaces the OpenRouter architecture and provider blocks', () {
    final details = _asMap(
      ModelDetails.extract(
        ModelInfo(
          id: 'openai/gpt-4o',
          name: 'GPT-4o',
          rawData: const {
            'canonical_slug': 'openai/gpt-4o',
            'architecture': {
              'modality': 'text+image->text',
              'input_modalities': ['text', 'image'],
              'output_modalities': ['text'],
              'tokenizer': 'GPT',
              'instruct_type': null,
            },
            'top_provider': {
              'context_length': 128000,
              'max_completion_tokens': 16384,
              'is_moderated': true,
            },
            'supported_parameters': ['temperature', 'top_p', 'tools'],
          },
        ),
      ),
    );

    expect(details['Slug'], 'openai/gpt-4o');
    expect(details['Modality'], 'text+image->text');
    expect(details['Input'], 'text, image');
    expect(details['Tokenizer'], 'GPT');
    expect(details['Provider Context'], '128,000');
    expect(details['Max Output'], '16,384');
    expect(details['Moderated'], 'Yes');
    expect(details['Supported Parameters'], 'temperature, top_p, tools');
  });

  test('drops keys the provider left null or blank', () {
    final details = _asMap(
      ModelDetails.extract(
        ModelInfo(
          id: 'm',
          name: 'M',
          rawData: const {
            'canonical_slug': '',
            'architecture': {'tokenizer': 'Llama3', 'instruct_type': null},
          },
        ),
      ),
    );

    expect(details.containsKey('Slug'), isFalse);
    expect(details.containsKey('Instruct Type'), isFalse);
    expect(details['Tokenizer'], 'Llama3');
  });

  test('reads the flatter shape other gateways use', () {
    final details = _asMap(
      ModelDetails.extract(
        ModelInfo(
          id: 'llama-3.1-8b',
          name: 'Llama 3.1 8B',
          rawData: const {
            'owned_by': 'Meta',
            'context_window': 131072,
            'max_completion_tokens': 8192,
            'active': true,
          },
        ),
      ),
    );

    expect(details['Owner'], 'Meta');
    expect(details['Context Window'], '131,072');
    expect(details['Max Output'], '8,192');
    expect(details['Active'], 'Yes');
  });

  test('prefers the provider block over a duplicate top-level key', () {
    final details = _asMap(
      ModelDetails.extract(
        ModelInfo(
          id: 'm',
          name: 'M',
          rawData: const {
            'top_provider': {'max_completion_tokens': 4096},
            'max_completion_tokens': 999,
          },
        ),
      ),
    );

    expect(details['Max Output'], '4,096');
  });

  test('flattens per-request limits into their own rows', () {
    final details = _asMap(
      ModelDetails.extract(
        ModelInfo(
          id: 'm',
          name: 'M',
          rawData: const {
            'per_request_limits': {
              'prompt_tokens': '1000000',
              'completion_tokens': '20000',
            },
          },
        ),
      ),
    );

    expect(details['Limit: Prompt Tokens'], '1000000');
    expect(details['Limit: Completion Tokens'], '20000');
  });
}
