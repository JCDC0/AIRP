import 'package:airp/models/chat_models.dart';
import 'package:airp/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the repair for conversations that appear to shift by one turn.
///
/// A streamed reply is seeded as an empty assistant message. If that seed
/// reaches disk without ever being filled in, the reloaded conversation shows a
/// blank bubble between a prompt and the next turn, so every later reply looks
/// like it sits under the wrong message.
void main() {
  ChatSessionData session(List<ChatMessage> messages) => ChatSessionData(
    id: 's1',
    title: 'Conversation',
    messages: messages,
    modelName: 'model-a',
    tokenCount: 42,
    systemInstruction: 'sys',
    backgroundImage: 'bg.png',
    provider: 'gemini',
    isBookmarked: true,
  );

  List<String> labels(ChatSessionData s) =>
      s.messages.map((m) => '${m.isUser ? 'U' : 'A'}:${m.text}').toList();

  test('drops an unfilled streaming placeholder', () {
    final repaired = SessionService.dropEmptyAssistantPlaceholders(
      session([
        ChatMessage(text: 'Q1', isUser: true),
        ChatMessage(text: 'A1', isUser: false),
        ChatMessage(text: 'Q2', isUser: true),
        ChatMessage(text: '', isUser: false),
      ]),
    );

    expect(labels(repaired), ['U:Q1', 'A:A1', 'U:Q2']);
  });

  test('drops a placeholder stranded between turns', () {
    final repaired = SessionService.dropEmptyAssistantPlaceholders(
      session([
        ChatMessage(text: 'Q1', isUser: true),
        ChatMessage(text: '   ', isUser: false),
        ChatMessage(text: 'Q2', isUser: true),
        ChatMessage(text: 'A2', isUser: false),
      ]),
    );

    expect(labels(repaired), ['U:Q1', 'U:Q2', 'A:A2']);
  });

  test('keeps empty user messages', () {
    final repaired = SessionService.dropEmptyAssistantPlaceholders(
      session([
        ChatMessage(text: '', isUser: true, imagePaths: const ['pic.png']),
        ChatMessage(text: 'A1', isUser: false),
      ]),
    );

    expect(repaired.messages, hasLength(2));
  });

  test('keeps an empty assistant message that still carries content', () {
    final repaired = SessionService.dropEmptyAssistantPlaceholders(
      session([
        ChatMessage(text: 'Q1', isUser: true),
        ChatMessage(
          text: '',
          isUser: false,
          regenerationVersions: const ['an earlier draft'],
        ),
        ChatMessage(text: '', isUser: false, imagePaths: const ['gen.png']),
        ChatMessage(text: '', isUser: false, usage: const {'total': 10}),
      ]),
    );

    expect(repaired.messages, hasLength(4));
  });

  test('returns the same instance when nothing needs repair', () {
    final original = session([
      ChatMessage(text: 'Q1', isUser: true),
      ChatMessage(text: 'A1', isUser: false),
    ]);

    expect(
      SessionService.dropEmptyAssistantPlaceholders(original),
      same(original),
    );
  });

  test('preserves session metadata while repairing', () {
    final repaired = SessionService.dropEmptyAssistantPlaceholders(
      session([
        ChatMessage(text: 'Q1', isUser: true),
        ChatMessage(text: '', isUser: false),
      ]),
    );

    expect(repaired.id, 's1');
    expect(repaired.title, 'Conversation');
    expect(repaired.modelName, 'model-a');
    expect(repaired.tokenCount, 42);
    expect(repaired.systemInstruction, 'sys');
    expect(repaired.backgroundImage, 'bg.png');
    expect(repaired.provider, 'gemini');
    expect(repaired.isBookmarked, isTrue);
  });
}
