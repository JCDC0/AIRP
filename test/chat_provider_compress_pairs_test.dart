import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the ordering of the trailing pairs seeded into a summarize branch.
///
/// A regression here inverts every pair, so the branched conversation reads
/// assistant-then-user and the model sees answers before their questions.
void main() {
  List<ChatMessage> conversation(int turns) => [
    for (var t = 1; t <= turns; t++) ...[
      ChatMessage(text: 'User$t', isUser: true),
      ChatMessage(text: 'AI$t', isUser: false),
    ],
  ];

  List<String> labels(List<ChatMessage> messages) =>
      messages.map((m) => m.text).toList();

  test('collectTrailingPairs keeps user turns above their replies', () {
    final pairs = ChatProvider.collectTrailingPairs(conversation(3), 2);

    expect(labels(pairs), ['User2', 'AI2', 'User3', 'AI3']);
  });

  test('collectTrailingPairs returns whole conversation when n exceeds it', () {
    final pairs = ChatProvider.collectTrailingPairs(conversation(2), 10);

    expect(labels(pairs), ['User1', 'AI1', 'User2', 'AI2']);
  });

  test('collectTrailingPairs anchors on assistant turns', () {
    final messages = [
      ChatMessage(text: 'User1', isUser: true),
      ChatMessage(text: 'User2', isUser: true),
      ChatMessage(text: 'AI1', isUser: false),
      ChatMessage(text: 'User3', isUser: true),
      ChatMessage(text: 'AI2', isUser: false),
    ];

    final pairs = ChatProvider.collectTrailingPairs(messages, 2);

    expect(labels(pairs), ['User2', 'AI1', 'User3', 'AI2']);
  });

  test('collectTrailingPairs tolerates an assistant turn with no prompt', () {
    final messages = [
      ChatMessage(text: 'AI1', isUser: false),
      ChatMessage(text: 'User1', isUser: true),
      ChatMessage(text: 'AI2', isUser: false),
    ];

    final pairs = ChatProvider.collectTrailingPairs(messages, 2);

    expect(labels(pairs), ['AI1', 'User1', 'AI2']);
  });

  test('collectTrailingPairs drops streaming notifiers', () {
    final messages = conversation(1);
    final pairs = ChatProvider.collectTrailingPairs(messages, 1);

    expect(pairs.every((m) => m.contentNotifier == null), isTrue);
  });

  test('collectTrailingPairs returns empty for an empty conversation', () {
    expect(ChatProvider.collectTrailingPairs(const [], 3), isEmpty);
  });
}
