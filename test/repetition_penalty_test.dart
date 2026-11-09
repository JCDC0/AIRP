import 'dart:convert';

import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/settings_provider.dart';
import 'package:airp/services/chat_api_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _flushAsyncInit() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChatProvider.activeRepetitionPenalty', () {
    test('null at the neutral value and when the section is off', () async {
      final settings = SettingsProvider();
      final chat = ChatProvider()..updateSettings(settings);
      await _flushAsyncInit();

      expect(chat.activeRepetitionPenalty, isNull);

      settings.setRepetitionPenalty(1.15);
      expect(chat.activeRepetitionPenalty, 1.15);

      settings.setEnableGenerationSettings(false);
      expect(chat.activeRepetitionPenalty, isNull);

      settings.setEnableGenerationSettings(true);
      settings.setRepetitionPenalty(1.0);
      expect(chat.activeRepetitionPenalty, isNull);
    });

    test('survives an export/import round trip', () async {
      final source = SettingsProvider();
      await _flushAsyncInit();
      source.setRepetitionPenalty(1.25);

      final target = SettingsProvider();
      await _flushAsyncInit();
      await target.importSettingsMap(source.exportSettingsMap());
      expect(target.repetitionPenalty, 1.25);
    });
  });

  group('repetition_penalty in the request body', () {
    final history = <ChatMessage>[ChatMessage(text: 'hi', isUser: true)];
    const url = 'https://openrouter.ai/api/v1/chat/completions';

    Future<Map<String, dynamic>> streamBody(double? penalty) async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('data: [DONE]\n\n', 200);
      });
      await ChatApiService.streamOpenAiCompatible(
        apiKey: 'k',
        baseUrl: url,
        model: 'm',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        imagePaths: const [],
        repetitionPenalty: penalty,
        client: client,
      ).toList();
      return sent;
    }

    test('written when set', () async {
      expect((await streamBody(1.1))['repetition_penalty'], 1.1);
    });

    test('omitted for null', () async {
      expect(
        (await streamBody(null)).containsKey('repetition_penalty'),
        isFalse,
      );
    });
  });
}
