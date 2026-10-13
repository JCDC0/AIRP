import 'dart:convert';

import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/providers/settings_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/providers/update_provider.dart';
import 'package:airp/providers/vfx_provider.dart';
import 'package:airp/services/chat_api_service.dart';
import 'package:airp/widgets/settings_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
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

  final history = <ChatMessage>[ChatMessage(text: 'hi', isUser: true)];

  group('OpenAI-compatible with streaming off', () {
    Future<(Map<String, dynamic>, String)> run(
      String responseBody, {
      bool includeUsage = false,
    }) async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(responseBody, 200);
      });
      final out = await ChatApiService.streamOpenAiCompatible(
        apiKey: 'k',
        baseUrl: 'https://api.example.com/v1/chat/completions',
        model: 'm',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        imagePaths: const [],
        includeUsage: includeUsage,
        stream: false,
        client: client,
      ).join();
      return (sent, out);
    }

    final reply = const JsonEncoder.withIndent('  ').convert({
      'choices': [
        {
          'message': {
            'role': 'assistant',
            'reasoning': 'thinking it over',
            'content': 'line one\nline two',
          },
        },
      ],
      'usage': {
        'prompt_tokens': 5,
        'completion_tokens': 7,
        'total_tokens': 12,
      },
    });

    test('asks for a whole reply and drops stream_options', () async {
      final (sent, _) = await run(reply, includeUsage: true);
      expect(sent['stream'], isFalse);
      expect(sent.containsKey('stream_options'), isFalse);
    });

    test('emits reasoning and content in the streamed format', () async {
      final (_, out) = await run(reply);
      expect(out, '<think>\nthinking it over\n</think>\nline one\nline two');
    });

    test('forwards usage when usage stats are on', () async {
      final (_, out) = await run(reply, includeUsage: true);
      expect(out, contains('[[USAGE:'));
      expect(out, contains('"total_tokens":12'));
    });

    test('an empty 200 says so instead of leaving a blank bubble', () async {
      final (_, out) = await run('{"choices": []}');
      expect(out, contains('**Empty reply:**'));
    });

    test('streaming on still sends stream true', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('data: [DONE]\n\n', 200);
      });
      await ChatApiService.streamOpenAiCompatible(
        apiKey: 'k',
        baseUrl: 'https://api.example.com/v1/chat/completions',
        model: 'm',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        imagePaths: const [],
        includeUsage: true,
        client: client,
      ).toList();
      expect(sent['stream'], isTrue);
      expect(sent['stream_options'], {'include_usage': true});
    });
  });

  group('Gemini with streaming off', () {
    test('uses generateContent without alt=sse', () {
      final url = ChatApiService.buildGeminiGenerateUrl(
        'models/gemini-3-flash-preview',
        ' key ',
      );
      expect(url.path, endsWith('/gemini-3-flash-preview:generateContent'));
      expect(url.queryParameters.containsKey('alt'), isFalse);
      expect(url.queryParameters['key'], 'key');
    });

    test('splits thought parts from the answer in one response', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(
          const JsonEncoder.withIndent('  ').convert({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'weighing it', 'thought': true},
                    {'text': 'the answer'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
        );
      });
      final out = await ChatApiService.streamGeminiResponse(
        apiKey: 'k',
        modelName: 'models/gemini-3-flash-preview',
        history: history,
        userMessage: 'hi',
        systemInstruction: '',
        imagePaths: const [],
        stream: false,
        client: client,
      ).join();
      expect(requested.path, endsWith(':generateContent'));
      expect(out, '<think>\nweighing it\n</think>\nthe answer');
    });
  });

  group('SettingsProvider streaming', () {
    test('defaults to on', () async {
      final settings = SettingsProvider();
      await _flushAsyncInit();
      expect(settings.enableStreaming, isTrue);
    });

    test('persists and round-trips through a config pack', () async {
      final settings = SettingsProvider();
      await _flushAsyncInit();
      settings.setEnableStreaming(false);
      await settings.saveSettings(showConfirmation: false);

      final reloaded = SettingsProvider();
      await _flushAsyncInit();
      expect(reloaded.enableStreaming, isFalse);

      final target = SettingsProvider();
      await _flushAsyncInit();
      await target.importSettingsMap(settings.exportSettingsMap());
      expect(target.enableStreaming, isFalse);
    });
  });

  testWidgets('Stream Replies switch turns streaming off', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => VfxProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProxyProvider<SettingsProvider, ChatProvider>(
            create: (_) => ChatProvider(),
            update: (_, settings, chat) => chat!..updateSettings(settings),
          ),
          ChangeNotifierProvider(create: (_) => ScaleProvider()),
          ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, height: 1200, child: SettingsDrawer()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final settings =
        tester.element(find.byType(SettingsDrawer)).read<SettingsProvider>();
    final streamSwitch = find.widgetWithText(SwitchListTile, 'Stream Replies');

    await tester.ensureVisible(streamSwitch);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Text appears as it is generated'), findsOneWidget);

    await tester.tap(streamSwitch);
    await tester.pump(const Duration(milliseconds: 300));
    expect(settings.enableStreaming, isFalse);
    expect(find.text('Off: the reply appears when complete'), findsOneWidget);
  });
}
