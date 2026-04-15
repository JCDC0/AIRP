import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compactSessionsForStorage removes regeneration history only', () {
    final sessions = [
      ChatSessionData(
        id: 's1',
        title: 'Conversation',
        modelName: 'model-a',
        tokenCount: 1234,
        systemInstruction: 'sys',
        provider: 'gemini',
        messages: [
          ChatMessage(
            text: 'Final answer',
            isUser: false,
            regenerationVersions: const ['draft', 'final'],
            currentVersionIndex: 1,
          ),
          ChatMessage(
            text: 'User prompt',
            isUser: true,
          ),
        ],
      ),
    ];

    final compacted = ChatProvider.compactSessionsForStorage(sessions);

    expect(compacted, hasLength(1));
    expect(compacted.first.messages.first.text, 'Final answer');
    expect(
      compacted.first.messages.first.text,
      sessions.first.messages.first.regenerationVersions[1],
    );
    expect(compacted.first.messages.first.regenerationVersions, isEmpty);
    expect(compacted.first.messages.first.currentVersionIndex, 0);
    expect(compacted.first.messages[1].text, 'User prompt');
    expect(compacted.first.tokenCount, 1234);
    expect(compacted.first.modelName, 'model-a');
  });
}
