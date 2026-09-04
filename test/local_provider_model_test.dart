import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/services/strategies/strategy_resolver.dart';
import 'package:airp/utils/constants.dart';

/// Seeds the model cache the registry reads on startup, standing in for a
/// completed fetch against the user's own server.
void _seedLocalModels(List<String> ids) {
  SharedPreferences.setMockInitialValues({
    ApiConstants.prefListLocal: ids
        .map((id) => jsonEncode(ModelInfo(id: id, name: id).toJson()))
        .toList(),
  });
}

/// Waits for [ChatProvider]'s async constructor loads to settle.
///
/// The key load runs off a platform channel, so it lands a few event-loop
/// turns after construction. Disposing before it returns trips
/// `notifyListeners` on a disposed notifier.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  // ChatProvider's constructor reaches for secure storage; without the binding
  // every construction logs a wall of initialization warnings.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // flutter_secure_storage has no implementation under `flutter test`.
    // Answering its channel keeps the key load quiet and deterministic.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  group('local provider model resolution', () {
    test('a blank Target Model ID falls back to a placeholder, never empty', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatProvider();
      await _settle();

      expect(provider.localModelName, isEmpty);
      expect(provider.effectiveLocalModel, 'local-model');

      provider.dispose();
    });

    test('a blank Target Model ID resolves to the first discovered model', () async {
      _seedLocalModels(['qwen3-8b', 'gemma-3-12b']);
      final provider = ChatProvider();
      await _settle();

      expect(provider.localModelsList, hasLength(2));
      expect(provider.effectiveLocalModel, 'qwen3-8b');

      provider.dispose();
    });

    test('an explicit Target Model ID wins over discovery', () async {
      _seedLocalModels(['qwen3-8b', 'gemma-3-12b']);
      final provider = ChatProvider();
      await _settle();

      provider.setLocalModelName('gemma-3-12b');
      expect(provider.effectiveLocalModel, 'gemma-3-12b');

      // Clearing it returns to Auto rather than sending an empty model field.
      provider.setLocalModelName('');
      expect(provider.effectiveLocalModel, 'qwen3-8b');

      provider.dispose();
    });

    test('whitespace-only input counts as blank', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatProvider();
      await _settle();

      provider.setLocalModelName('   ');
      expect(provider.effectiveLocalModel, 'local-model');

      provider.dispose();
    });

    test('setModel routes Local through the Target Model ID', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatProvider();
      await _settle();

      provider.setProvider(AiProvider.local);
      provider.setModel('llama-3.2-3b-instruct');

      expect(provider.localModelName, 'llama-3.2-3b-instruct');
      expect(provider.effectiveLocalModel, 'llama-3.2-3b-instruct');

      provider.dispose();
    });

    test('selecting a discovered model surfaces its metadata', () async {
      _seedLocalModels(['qwen3-8b']);
      final provider = ChatProvider();
      await _settle();

      provider.setProvider(AiProvider.local);
      expect(provider.getCurrentModelInfo()?.id, 'qwen3-8b');

      provider.dispose();
    });
  });

  group('local provider model discovery', () {
    test('the local strategy lists models off the user endpoint', () {
      final strategy = StrategyResolver.resolve(AiProvider.local);

      // llama.cpp and LM Studio both answer on /v1; a bare root and a full
      // completions URL are the other two shapes a user pastes.
      expect(
        strategy.getModelsUrl(customBase: 'http://192.168.1.15:1234/v1'),
        'http://192.168.1.15:1234/v1/models',
      );
      expect(
        strategy.getModelsUrl(customBase: 'http://localhost:8080'),
        'http://localhost:8080/models',
      );
      expect(
        strategy.getModelsUrl(
          customBase: 'http://localhost:8080/v1/chat/completions',
        ),
        'http://localhost:8080/v1/models',
      );
    });

    test('editing the local endpoint schedules a model fetch', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatProvider();
      await _settle();

      // The debounce is what keeps a typed endpoint from firing a request per
      // keystroke; the fetch itself needs a live server, so this only asserts
      // that the setter is wired and does not fire synchronously.
      provider.setLocalIp('http://localhost:8080/v1');
      expect(provider.isLoadingLocalModels, isFalse);
      expect(provider.localIp, 'http://localhost:8080/v1');

      provider.dispose();
    });
  });
}
