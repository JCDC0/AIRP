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
}