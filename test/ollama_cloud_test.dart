import 'dart:convert';
import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/providers/vfx_provider.dart';
import 'package:airp/services/chat_api_service.dart';
import 'package:airp/services/model_registry_service.dart';
import 'package:airp/widgets/settings_panels/api_settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp(ChatProvider chatProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<VfxProvider>(create: (_) => VfxProvider()),
      ChangeNotifierProvider<ScaleProvider>(create: (_) => ScaleProvider()),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: ApiSettingsPanel())),
    ),
  );
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

  group('ChatApiService OpenAI-compatible request headers', () {
    final history = <ChatMessage>[ChatMessage(text: 'hello', isUser: true)];

    test('streamOpenAiCompatible omits Authorization when key is empty', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response('data: [DONE]\n\n', 200);
      });

      final stream = ChatApiService.streamOpenAiCompatible(
        apiKey: '',
        baseUrl: 'https://api.example.com/chat/completions',
        model: 'llama3',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        imagePaths: const [],
        client: client,
      );
      await stream.toList();

      expect(authHeader, isNull);
    });

    test('streamOpenAiCompatible sends Authorization when key is set', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response('data: [DONE]\n\n', 200);
      });

      final stream = ChatApiService.streamOpenAiCompatible(
        apiKey: 'ollama-key-123',
        baseUrl: 'https://api.example.com/chat/completions',
        model: 'llama3',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        imagePaths: const [],
        client: client,
      );
      await stream.toList();

      expect(authHeader, 'Bearer ollama-key-123');
    });

    test('requestOpenAiCompatibleWithToolDetection omits Authorization when key is empty', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'role': 'assistant', 'content': 'answer'}},
            ],
          }),
          200,
        );
      });

      await ChatApiService.requestOpenAiCompatibleWithToolDetection(
        apiKey: '',
        baseUrl: 'https://api.example.com/chat/completions',
        model: 'llama3',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        tools: const [],
        client: client,
      );

      expect(authHeader, isNull);
    });

    test('requestOpenAiCompatibleWithToolDetection sends Authorization when key is set', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'role': 'assistant', 'content': 'answer'}},
            ],
          }),
          200,
        );
      });

      await ChatApiService.requestOpenAiCompatibleWithToolDetection(
        apiKey: 'ollama-key-456',
        baseUrl: 'https://api.example.com/chat/completions',
        model: 'llama3',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        tools: const [],
        client: client,
      );

      expect(authHeader, 'Bearer ollama-key-456');
    });

    test('streamOpenAiCompatibleWithToolDetection omits Authorization when key is empty', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response('data: [DONE]\n\n', 200);
      });

      await ChatApiService.streamOpenAiCompatibleWithToolDetection(
        apiKey: '',
        baseUrl: 'https://api.example.com/chat/completions',
        model: 'llama3',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        tools: const [],
        client: client,
      );

      expect(authHeader, isNull);
    });

    test('streamOpenAiCompatibleWithToolDetection sends Authorization when key is set', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response('data: [DONE]\n\n', 200);
      });

      await ChatApiService.streamOpenAiCompatibleWithToolDetection(
        apiKey: 'ollama-key-789',
        baseUrl: 'https://api.example.com/chat/completions',
        model: 'llama3',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        tools: const [],
        client: client,
      );

      expect(authHeader, 'Bearer ollama-key-789');
    });

    test('streamOpenAiCompatible omits Authorization when key is whitespace', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response('data: [DONE]\n\n', 200);
      });

      final stream = ChatApiService.streamOpenAiCompatible(
        apiKey: '   ',
        baseUrl: 'https://api.example.com/chat/completions',
        model: 'llama3',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        imagePaths: const [],
        client: client,
      );
      await stream.toList();

      expect(authHeader, isNull);
    });

    test('requestOpenAiCompatibleWithToolDetection omits Authorization when key is whitespace', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'role': 'assistant', 'content': 'answer'}},
            ],
          }),
          200,
        );
      });

      await ChatApiService.requestOpenAiCompatibleWithToolDetection(
        apiKey: '   ',
        baseUrl: 'https://api.example.com/chat/completions',
        model: 'llama3',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        tools: const [],
        client: client,
      );

      expect(authHeader, isNull);
    });

    test('streamOpenAiCompatibleWithToolDetection omits Authorization when key is whitespace', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response('data: [DONE]\n\n', 200);
      });

      await ChatApiService.streamOpenAiCompatibleWithToolDetection(
        apiKey: '   ',
        baseUrl: 'https://api.example.com/chat/completions',
        model: 'llama3',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        tools: const [],
        client: client,
      );

      expect(authHeader, isNull);
    });

    test('ModelRegistryService.fetchModels passes Authorization when key is set for Ollama', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'models': []}), 200);
      });

      await http.runWithClient(() async {
        final registry = ModelRegistryService(onStateChanged: () {});
        await registry.fetchModels(AiProvider.ollama, 'ollama-cloud-key');
      }, () => client);

      expect(authHeader, 'Bearer ollama-cloud-key');
    });

    test('ModelRegistryService.fetchModels omits Authorization when key is empty for Ollama', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'models': []}), 200);
      });

      await http.runWithClient(() async {
        final registry = ModelRegistryService(onStateChanged: () {});
        await registry.fetchModels(AiProvider.ollama, '');
      }, () => client);

      expect(authHeader, isNull);
    });

    test('ModelRegistryService.fetchModels omits Authorization when key is whitespace for Ollama', () async {
      String? authHeader;
      final client = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'models': []}), 200);
      });

      await http.runWithClient(() async {
        final registry = ModelRegistryService(onStateChanged: () {});
        await registry.fetchModels(AiProvider.ollama, '   ');
      }, () => client);

      expect(authHeader, isNull);
    });

    testWidgets('ChatProvider.missingCredentialError verifies endpoint and allows blank key for Ollama', (tester) async {
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_buildTestApp(chatProvider));
      await tester.pumpAndSettle();

      chatProvider.setProvider(AiProvider.ollama);
      await tester.pumpAndSettle();
      expect(chatProvider.missingCredentialError(), isNull);

      chatProvider.setOllamaEndpoint('');
      await tester.pumpAndSettle();
      expect(chatProvider.missingCredentialError(), contains('Ollama'));

      chatProvider.setOllamaEndpoint('https://ollama.com');
      await tester.pumpAndSettle();
      expect(chatProvider.missingCredentialError(), isNull);

      chatProvider.setApiKey('ollama-token');
      await tester.pumpAndSettle();
      expect(chatProvider.missingCredentialError(), isNull);

      await tester.pumpWidget(const SizedBox());
      chatProvider.dispose();
      await tester.pump();
    });
  });

  group('Ollama API settings panel widget tests', () {
    Finder keyField() =>
        find.byWidgetPredicate((w) => w is TextField && w.obscureText);

    Finder loadModelsRow() => find.text('Load Models');

    testWidgets('Ollama API settings panel shows API key field and exactly one Load Models row when key is empty', (
      tester,
    ) async {
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_buildTestApp(chatProvider));
      await tester.pumpAndSettle();

      chatProvider.setProvider(AiProvider.ollama);
      await tester.pumpAndSettle();

      expect(keyField(), findsOneWidget);
      expect(loadModelsRow(), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      chatProvider.dispose();
      await tester.pump();
    });

    testWidgets('Ollama API settings panel displays exactly one Load Models row when API key is populated', (
      tester,
    ) async {
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_buildTestApp(chatProvider));
      await tester.pumpAndSettle();

      chatProvider.setProvider(AiProvider.ollama);
      await tester.pumpAndSettle();

      expect(keyField(), findsOneWidget);
      await tester.enterText(keyField(), 'ollama-cloud-token');
      await tester.pumpAndSettle();

      expect(loadModelsRow(), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      chatProvider.dispose();
      await tester.pump();
    });

    testWidgets('Local API settings panel omits API key field and displays exactly one Load Models row', (
      tester,
    ) async {
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_buildTestApp(chatProvider));
      await tester.pumpAndSettle();

      chatProvider.setProvider(AiProvider.local);
      await tester.pumpAndSettle();

      expect(keyField(), findsNothing);
      expect(loadModelsRow(), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      chatProvider.dispose();
      await tester.pump();
    });

    testWidgets('OpenAI-Compatible settings panel displays Load Models row only when key is populated', (
      tester,
    ) async {
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_buildTestApp(chatProvider));
      await tester.pumpAndSettle();

      chatProvider.setProvider(AiProvider.openAiCompatible);
      await tester.pumpAndSettle();

      expect(keyField(), findsOneWidget);
      expect(loadModelsRow(), findsNothing);

      await tester.enterText(keyField(), 'compatible-token');
      await tester.pumpAndSettle();

      expect(loadModelsRow(), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      chatProvider.dispose();
      await tester.pump();
    });
  });
}
