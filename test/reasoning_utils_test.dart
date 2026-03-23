import 'package:airp/services/reasoning_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReasoningUtils.split', () {
    test('returns content unchanged when no think block exists', () {
      const input = 'Hello world';
      final result = ReasoningUtils.split(input);

      expect(result.reasoning, '');
      expect(result.content, input);
      expect(result.isDone, true);
    });

    test('extracts reasoning and visible content for closed think blocks', () {
      const input = '<think>inner</think>final answer';
      final result = ReasoningUtils.split(input);

      expect(result.reasoning, 'inner');
      expect(result.content, 'final answer');
      expect(result.isDone, true);
    });

    test('handles case-insensitive think tags', () {
      const input = '<THINK>inner</THINK>final answer';
      final result = ReasoningUtils.split(input);

      expect(result.reasoning, 'inner');
      expect(result.content, 'final answer');
      expect(result.isDone, true);
    });

    test('merges multiple think blocks', () {
      const input = '<think>a</think>mid<think>b</think>end';
      final result = ReasoningUtils.split(input);

      expect(result.reasoning, 'a\n\nb');
      expect(result.content, 'midend');
      expect(result.isDone, true);
    });

    test('marks result incomplete when final think block is unclosed', () {
      const input = '<think>partial reasoning';
      final result = ReasoningUtils.split(input);

      expect(result.reasoning, 'partial reasoning');
      expect(result.content, '');
      expect(result.isDone, false);
    });
  });

  group('ReasoningUtils.stripThinkBlocks', () {
    test('removes all reasoning blocks', () {
      const input = 'before<think>x</think>middle<think>y</think>after';
      final result = ReasoningUtils.stripThinkBlocks(input);

      expect(result, 'beforemiddleafter');
    });
  });

  group('ReasoningUtils.hasThinkBlocks', () {
    test('returns true when think block exists', () {
      expect(ReasoningUtils.hasThinkBlocks('a<think>x</think>b'), true);
    });

    test('returns false when think block does not exist', () {
      expect(ReasoningUtils.hasThinkBlocks('plain response'), false);
    });
  });
}
