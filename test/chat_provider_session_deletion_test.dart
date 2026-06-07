import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _flushAsyncInit() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('deleting active session does not recreate it in recents', () async {
    final provider = ChatProvider();
    await _flushAsyncInit();

    final session = ChatSessionData(
      id: 'session-to-delete',
      title: 'Delete me',
      messages: [ChatMessage(text: 'hello', isUser: true)],
      modelName: 'model-a',
      tokenCount: 5,
      systemInstruction: '',
      provider: 'gemini',
    );

    provider.savedSessions.add(session);
    provider.loadSession(session);

    await provider.deleteSession(session.id);
    await _flushAsyncInit();

    expect(provider.savedSessions.where((s) => s.id == session.id), isEmpty);
    expect(provider.savedSessions, isEmpty);
    expect(provider.currentSessionId, isNull);
    expect(provider.messages, isEmpty);
    expect(provider.tokenCount, 0);
  });

  test('loading a deepseek session keeps the deepseek provider and model', () async {
    final provider = ChatProvider();
    await _flushAsyncInit();

    final session = ChatSessionData(
      id: 'deepseek-session',
      title: 'DeepSeek',
      messages: [ChatMessage(text: 'hello', isUser: true)],
      modelName: 'deepseek-chat',
      tokenCount: 5,
      systemInstruction: '',
      provider: 'deepseek',
    );

    provider.loadSession(session);
    await _flushAsyncInit();

    expect(provider.currentProvider, AiProvider.deepseek);
    expect(provider.deepseekModel, 'deepseek-chat');
    expect(provider.selectedModel, 'deepseek-chat');
  });
}
