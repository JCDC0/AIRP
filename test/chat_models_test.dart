import 'package:flutter_test/flutter_test.dart';
import 'package:airp/models/chat_models.dart';

void main() {
  test('ChatMessage serialization round-trip', () {
    final message = ChatMessage(
      text: 'Hello',
      isUser: true,
      imagePaths: ['a.png'],
      modelName: 'model-x',
      usage: {'tokens': 42},
      thoughtSignature: 'sig',
      reasoningRecovered: true,
    );

    final json = message.toJson();
    final restored = ChatMessage.fromJson(json);

    expect(restored.text, message.text);
    expect(restored.isUser, message.isUser);
    expect(restored.imagePaths, message.imagePaths);
    expect(restored.modelName, message.modelName);
    expect(restored.usage, message.usage);
    expect(restored.thoughtSignature, message.thoughtSignature);
    expect(restored.reasoningRecovered, message.reasoningRecovered);
  });

  test('ChatSessionData defaults are applied', () {
    final session = ChatSessionData.fromJson({});
    expect(session.title, 'Untitled');
    expect(session.provider, 'gemini');
    expect(session.modelName, 'models/gemini-3-flash-preview');
    expect(session.messages, isEmpty);
  });

  test('ChatMessage reasoningRecovered defaults to false', () {
    final message = ChatMessage.fromJson({'text': 'x', 'isUser': false});
    expect(message.reasoningRecovered, false);
  });
}
