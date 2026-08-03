import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airp/models/character_card.dart';
import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/settings_provider.dart';
import 'package:airp/utils/token_utils.dart';

/// Integration guard for the context meter.
///
/// The counting helpers are unit tested in `token_utils_test.dart`; what
/// matters here is that [ChatProvider] actually calls them, feeds them the
/// assembled prompt, and keeps the number live as messages change.
ChatSessionData _session({
  required List<ChatMessage> messages,
  String systemInstruction = 'sys',
  String id = 's1',
}) {
  return ChatSessionData(
    id: id,
    title: 'Conversation',
    modelName: 'model-a',
    tokenCount: 0,
    systemInstruction: systemInstruction,
    provider: 'openRouter',
    messages: messages,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatProvider chat;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    chat = ChatProvider()..updateSettings(SettingsProvider());
  });

  test('estimates the prompt when no usage has been reported', () {
    chat.loadSession(
      _session(messages: [ChatMessage(text: 'abcd', isUser: true)]),
    );

    // One message (1 token plus envelope) and the system instruction
    // (1 token plus envelope).
    expect(chat.tokenCount, 1 + 4 + 1 + 4);
  });

  test('anchors to the prompt_tokens the provider reported', () {
    chat.loadSession(
      _session(
        messages: [
          ChatMessage(text: 'hi', isUser: true),
          ChatMessage(
            text: 'reply',
            isUser: false,
            usage: const {
              'prompt_tokens': 5000,
              'completion_tokens': 2,
              'total_tokens': 5002,
            },
          ),
        ],
      ),
    );

    // The anchor covers everything up to the reply, so only the reply itself
    // is estimated on top of the reported 5000.
    expect(chat.tokenCount, 5000 + TokenUtils.estimate('reply') + 4);
  });

  test('anchors from a raw Gemini usage payload saved by an older build', () {
    chat.loadSession(
      _session(
        messages: [
          ChatMessage(text: 'hi', isUser: true),
          ChatMessage(
            text: 'reply',
            isUser: false,
            usage: const {
              'promptTokenCount': 5000,
              'candidatesTokenCount': 2,
              'totalTokenCount': 5002,
            },
          ),
        ],
      ),
    );

    expect(chat.tokenCount, 5000 + TokenUtils.estimate('reply') + 4);
  });

  test('shrinks when a message is deleted', () {
    chat.loadSession(
      _session(
        messages: [
          ChatMessage(text: 'a' * 400, isUser: true),
          ChatMessage(text: 'b' * 400, isUser: false),
        ],
      ),
    );
    final before = chat.tokenCount;

    chat.deleteMessage(1);

    expect(chat.tokenCount, lessThan(before));
    expect(chat.tokenCount, before - (400 / 4).ceil() - 4);
  });

  test('counts the assembled system instruction, not the raw prompt', () {
    chat.loadSession(
      _session(messages: [ChatMessage(text: 'abcd', isUser: true)]),
    );
    final withoutCard = chat.tokenCount;

    chat.setCharacterCard(
      CharacterCard(name: 'Ada', description: 'd' * 400),
    );
    chat.updateTokenCount();

    // The character card is injected into the system instruction by
    // PromptPipelineService, so the meter has to see it.
    expect(chat.tokenCount, greaterThan(withoutCard + 100));
  });

  test('counts only the messages inside the active history window', () {
    final settings = SettingsProvider()..setHistoryLimit(1);
    chat.updateSettings(settings);

    chat.loadSession(
      _session(
        messages: [
          ChatMessage(text: 'c' * 400, isUser: true),
          ChatMessage(text: 'd' * 4, isUser: false),
        ],
      ),
    );

    // The 400-character message falls outside the one-message window.
    expect(chat.tokenCount, 1 + 4 + 1 + 4);
  });
}
