import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _flushAsyncInit() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('provider stars persist across provider reload', () async {
    final provider = ChatProvider();
    await _flushAsyncInit();

    provider.toggleProviderStar(AiProvider.groq);
    await _flushAsyncInit();

    final reloaded = ChatProvider();
    await _flushAsyncInit();

    expect(reloaded.starredProviders.contains(AiProvider.groq), isTrue);
  });

  test('model bookmarks persist across provider reload', () async {
    final provider = ChatProvider();
    await _flushAsyncInit();

    await provider.toggleModelBookmark('models/test-model');

    final reloaded = ChatProvider();
    await _flushAsyncInit();

    expect(reloaded.bookmarkedModels.contains('models/test-model'), isTrue);
  });

  test('model sort mode defaults to Newest', () async {
    final provider = ChatProvider();
    await _flushAsyncInit();

    expect(provider.modelPickerSortMode, equals('Newest'));
  });

  test('model sort mode persists across provider reload', () async {
    final provider = ChatProvider();
    await _flushAsyncInit();

    await provider.setModelPickerSortMode('Name (Z-A)');

    final reloaded = ChatProvider();
    await _flushAsyncInit();

    expect(reloaded.modelPickerSortMode, equals('Name (Z-A)'));
  });

  test('deepseek model persists and restores with the session provider', () async {
    final provider = ChatProvider();
    await _flushAsyncInit();

    provider.loadSession(
      ChatSessionData(
        id: 'deepseek-session',
        title: 'DeepSeek',
        messages: [ChatMessage(text: 'hello', isUser: true)],
        modelName: 'deepseek-chat',
        tokenCount: 7,
        systemInstruction: '',
        provider: 'deepseek',
      ),
    );

    provider.setModel('deepseek-reasoner');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('airp_provider', provider.currentProvider.name);
    await prefs.setString(
      ApiConstants.prefModelDeepseek,
      provider.selectedModel,
    );

    final reloaded = ChatProvider();
    await _flushAsyncInit();

    expect(reloaded.currentProvider, equals(AiProvider.deepseek));
    expect(reloaded.deepseekModel, equals('deepseek-reasoner'));
    expect(reloaded.selectedModel, equals('deepseek-reasoner'));
  });

  test(
    'openai compatible model persists and restores with the session provider',
    () async {
      final provider = ChatProvider();
      await _flushAsyncInit();

      provider.loadSession(
        ChatSessionData(
          id: 'openai-compatible-session',
          title: 'OpenAI Compatible',
          messages: [ChatMessage(text: 'hello', isUser: true)],
          modelName: 'custom-model',
          tokenCount: 9,
          systemInstruction: '',
          provider: 'openAiCompatible',
        ),
      );

      provider.setModel('custom-model-v2');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('airp_provider', provider.currentProvider.name);
      await prefs.setString(
        ApiConstants.prefModelOpenAiCompatible,
        provider.selectedModel,
      );

      final reloaded = ChatProvider();
      await _flushAsyncInit();

      expect(reloaded.currentProvider, equals(AiProvider.openAiCompatible));
      expect(reloaded.openAiCompatibleModel, equals('custom-model-v2'));
      expect(reloaded.selectedModel, equals('custom-model-v2'));
    },
  );
}