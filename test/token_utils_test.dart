import 'package:airp/utils/token_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimate', () {
    test('empty text costs nothing', () {
      expect(TokenUtils.estimate(''), 0);
    });

    test('latin text is charged at four characters per token', () {
      expect(TokenUtils.estimate('Hello, world!'), 4);
    });

    test('CJK characters are charged at roughly one token each', () {
      expect(TokenUtils.estimate('日本語のテキスト'), 8);
    });

    test('mixed scripts charge each run on its own scale', () {
      // 3 CJK characters plus 4 other characters ("AI" and two spaces).
      expect(TokenUtils.estimate('AI と 日本'), 4);
    });

    test('grows monotonically with length', () {
      final short = TokenUtils.estimate('a' * 40);
      final long = TokenUtils.estimate('a' * 400);
      expect(long, greaterThan(short));
    });
  });

  group('estimatePrompt', () {
    test('charges messages, envelopes and the system instruction', () {
      final total = TokenUtils.estimatePrompt(
        messageTexts: const ['abcd', 'efgh'],
        systemInstruction: 'xyz',
      );

      // 1 + 1 message tokens, 2 envelopes, 1 + 1 envelope for the instruction.
      expect(total, 1 + 1 + (2 * TokenUtils.perMessageOverhead) + 1 + 4);
    });

    test('omits the envelope when there is no system instruction', () {
      final withoutSystem = TokenUtils.estimatePrompt(
        messageTexts: const ['abcd'],
        systemInstruction: '',
      );

      expect(withoutSystem, 1 + TokenUtils.perMessageOverhead);
    });

    test('charges a flat rate per image', () {
      final base = TokenUtils.estimatePrompt(
        messageTexts: const ['abcd'],
        systemInstruction: '',
      );
      final withImages = TokenUtils.estimatePrompt(
        messageTexts: const ['abcd'],
        systemInstruction: '',
        imageCount: 2,
      );

      expect(withImages - base, 2 * TokenUtils.perImageTokens);
    });
  });

  group('projectContext', () {
    test('scales the raw estimate when no anchor is available', () {
      expect(
        TokenUtils.projectContext(rawEstimate: 100, calibration: 1.2),
        120,
      );
    });

    test('trusts the anchor and scales only the growth since', () {
      expect(
        TokenUtils.projectContext(
          rawEstimate: 900,
          calibration: 1.2,
          anchorPromptTokens: 1000,
          anchorRawEstimate: 800,
        ),
        1120,
      );
    });

    test('shrinks when messages are removed from the anchored window', () {
      expect(
        TokenUtils.projectContext(
          rawEstimate: 700,
          calibration: 1.2,
          anchorPromptTokens: 1000,
          anchorRawEstimate: 800,
        ),
        880,
      );
    });

    test('never reports a negative context', () {
      expect(
        TokenUtils.projectContext(
          rawEstimate: 0,
          anchorPromptTokens: 100,
          anchorRawEstimate: 900,
        ),
        0,
      );
    });

    test('ignores a half-supplied anchor', () {
      expect(
        TokenUtils.projectContext(rawEstimate: 100, anchorPromptTokens: 5000),
        100,
      );
    });
  });

  group('calibrate', () {
    test('moves partway towards the observed ratio', () {
      expect(TokenUtils.calibrate(1.0, 1200, 1000), closeTo(1.08, 0.0001));
    });

    test('keeps the previous ratio when the reading is unusable', () {
      expect(TokenUtils.calibrate(1.1, 0, 1000), 1.1);
      expect(TokenUtils.calibrate(1.1, 500, 0), 1.1);
    });

    test('clamps a wild observation to the ceiling', () {
      expect(TokenUtils.calibrate(1.0, 100000, 1000), TokenUtils.maxCalibration);
    });

    test('stays inside the bounds however the readings run', () {
      var ratio = 1.0;
      for (var i = 0; i < 20; i++) {
        ratio = TokenUtils.calibrate(ratio, 1, 1000);
      }
      expect(ratio, TokenUtils.minCalibration);

      for (var i = 0; i < 20; i++) {
        ratio = TokenUtils.calibrate(ratio, 100000, 1000);
      }
      expect(ratio, TokenUtils.maxCalibration);
    });
  });

  group('normalizeUsage', () {
    test('passes an OpenAI payload through unchanged', () {
      final usage = TokenUtils.normalizeUsage({
        'prompt_tokens': 10,
        'completion_tokens': 5,
        'total_tokens': 15,
      });

      expect(usage, {
        'prompt_tokens': 10,
        'completion_tokens': 5,
        'total_tokens': 15,
      });
    });

    test('maps Gemini usageMetadata and folds thoughts into completion', () {
      final usage = TokenUtils.normalizeUsage({
        'promptTokenCount': 100,
        'candidatesTokenCount': 40,
        'thoughtsTokenCount': 10,
        'totalTokenCount': 150,
      });

      expect(usage!['prompt_tokens'], 100);
      expect(usage['completion_tokens'], 50);
      expect(usage['total_tokens'], 150);
      expect(usage['reasoning_tokens'], 10);
    });

    test('derives a missing total from the parts', () {
      final usage = TokenUtils.normalizeUsage({
        'promptTokenCount': 100,
        'candidatesTokenCount': 40,
      });

      expect(usage!['total_tokens'], 140);
    });

    test('accepts input/output aliases', () {
      final usage = TokenUtils.normalizeUsage({
        'input_tokens': 30,
        'output_tokens': 12,
      });

      expect(usage!['prompt_tokens'], 30);
      expect(usage['completion_tokens'], 12);
      expect(usage['total_tokens'], 42);
    });

    test('reads reasoning and cache figures from nested detail objects', () {
      final usage = TokenUtils.normalizeUsage({
        'prompt_tokens': 10,
        'completion_tokens': 20,
        'total_tokens': 30,
        'completion_tokens_details': {'reasoning_tokens': 7},
        'prompt_tokens_details': {'cached_tokens': 3},
      });

      expect(usage!['reasoning_tokens'], 7);
      expect(usage['cached_tokens'], 3);
      // OpenAI already counts reasoning inside completion_tokens.
      expect(usage['completion_tokens'], 20);
    });

    test('omits absent reasoning and cache keys', () {
      final usage = TokenUtils.normalizeUsage({
        'prompt_tokens': 10,
        'completion_tokens': 5,
        'total_tokens': 15,
      });

      expect(usage!.containsKey('reasoning_tokens'), isFalse);
      expect(usage.containsKey('cached_tokens'), isFalse);
    });

    test('returns null for null, empty and unrecognized payloads', () {
      expect(TokenUtils.normalizeUsage(null), isNull);
      expect(TokenUtils.normalizeUsage({}), isNull);
      expect(TokenUtils.normalizeUsage({'something_else': 4}), isNull);
    });
  });
}
