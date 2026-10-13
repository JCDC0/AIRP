import 'dart:convert';

import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/providers/settings_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/providers/update_provider.dart';
import 'package:airp/providers/vfx_provider.dart';
import 'package:airp/services/chat_api_service.dart';
import 'package:airp/services/strategies/strategy_resolver.dart';
import 'package:airp/utils/constants.dart';
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

Widget _buildTestApp() {
  return MultiProvider(
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

  group('service tier resolution', () {
    final openRouter = StrategyResolver.resolve(AiProvider.openRouter);

    test('OpenRouter lists default, flex, priority and ultrafast', () {
      expect(
        openRouter.serviceTierOptions.map((o) => o.apiValue).toList(),
        ['default', 'flex', 'priority', 'ultrafast'],
      );
    });

    test('only priority and ultrafast are not recommended, with a warning', () {
      for (final option in openRouter.serviceTierOptions) {
        final expensive =
            option.apiValue == 'priority' || option.apiValue == 'ultrafast';
        expect(option.notRecommended, expensive, reason: option.apiValue);
        if (expensive) expect(option.warning, isNotEmpty);
      }
    });

    test('the setting off sends nothing whatever is stored', () {
      for (final tier in ['default', 'flex', 'priority', 'ultrafast']) {
        expect(openRouter.resolveServiceTier(enabled: false, stored: tier),
            isNull);
      }
    });

    test('default is never sent, because an absent field means default', () {
      expect(
        openRouter.resolveServiceTier(enabled: true, stored: 'default'),
        isNull,
      );
    });

    test('a listed tier is sent as stored', () {
      for (final tier in ['flex', 'priority', 'ultrafast']) {
        expect(openRouter.resolveServiceTier(enabled: true, stored: tier),
            tier);
      }
    });

    test('a stored value the provider does not list is not sent', () {
      expect(openRouter.resolveServiceTier(enabled: true, stored: 'scale'),
          isNull);
      expect(openRouter.resolveServiceTier(enabled: true, stored: ''),
          isNull);
    });

    test('providers without tiers hide the setting and never send one', () {
      for (final provider in AiProvider.values) {
        if (provider == AiProvider.openRouter) continue;
        final strategy = StrategyResolver.resolve(provider);
        expect(strategy.supportsServiceTier, isFalse, reason: provider.name);
        expect(strategy.resolveServiceTier(enabled: true, stored: 'flex'),
            isNull, reason: provider.name);
      }
    });
  });

  group('service_tier in the request body', () {
    final history = <ChatMessage>[ChatMessage(text: 'hi', isUser: true)];
    const url = 'https://openrouter.ai/api/v1/chat/completions';

    Future<Map<String, dynamic>> streamBody(String? tier) async {
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
        serviceTier: tier,
        client: client,
      ).toList();
      return sent;
    }

    test('streamOpenAiCompatible writes the tier', () async {
      expect((await streamBody('flex'))['service_tier'], 'flex');
    });

    test('streamOpenAiCompatible omits the field for null', () async {
      expect((await streamBody(null)).containsKey('service_tier'), isFalse);
    });

    test('requestOpenAiCompatibleWithToolDetection writes the tier', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'answer'},
              },
            ],
          }),
          200,
        );
      });
      await ChatApiService.requestOpenAiCompatibleWithToolDetection(
        apiKey: 'k',
        baseUrl: url,
        model: 'm',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        tools: const [],
        serviceTier: 'priority',
        client: client,
      );
      expect(sent['service_tier'], 'priority');
    });

    test('streamOpenAiCompatibleWithToolDetection writes the tier', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        final chunk = jsonEncode({
          'choices': [
            {
              'delta': {'content': 'answer'},
            },
          ],
        });
        return http.Response('data: $chunk\n\ndata: [DONE]\n\n', 200);
      });
      final aware =
          await ChatApiService.streamOpenAiCompatibleWithToolDetection(
            apiKey: 'k',
            baseUrl: url,
            model: 'm',
            history: history,
            systemInstruction: '',
            userMessage: 'hi',
            tools: const [
              {'type': 'function'},
            ],
            serviceTier: 'ultrafast',
            client: client,
          );
      await aware.textStream?.toList();
      expect(sent['service_tier'], 'ultrafast');
    });
  });

  group('SettingsProvider service tier', () {
    test('defaults to off and Default', () async {
      final settings = SettingsProvider();
      await _flushAsyncInit();
      expect(settings.enableServiceTier, isFalse);
      expect(settings.serviceTier, ChatDefaults.serviceTier);
      expect(settings.effectiveServiceTier, ChatDefaults.serviceTier);
    });

    test('off reports Default but keeps the stored choice', () async {
      final settings = SettingsProvider();
      await _flushAsyncInit();
      settings.setServiceTier('priority');
      expect(settings.effectiveServiceTier, ChatDefaults.serviceTier);
      expect(settings.serviceTier, 'priority');
      settings.setEnableServiceTier(true);
      expect(settings.effectiveServiceTier, 'priority');
    });

    test('persists across reload', () async {
      final settings = SettingsProvider();
      await _flushAsyncInit();
      settings.setEnableServiceTier(true);
      settings.setServiceTier('flex');
      await settings.saveSettings(showConfirmation: false);

      final reloaded = SettingsProvider();
      await _flushAsyncInit();
      expect(reloaded.enableServiceTier, isTrue);
      expect(reloaded.serviceTier, 'flex');
    });

    test('round-trips through a config pack export', () async {
      final source = SettingsProvider();
      await _flushAsyncInit();
      source.setEnableServiceTier(true);
      source.setServiceTier('flex');
      final exported = source.exportSettingsMap();

      final target = SettingsProvider();
      await _flushAsyncInit();
      await target.importSettingsMap(exported);
      expect(target.enableServiceTier, isTrue);
      expect(target.serviceTier, 'flex');
    });

    test('a pack written before the setting existed leaves it alone',
        () async {
      final settings = SettingsProvider();
      await _flushAsyncInit();
      settings.setEnableServiceTier(true);
      settings.setServiceTier('flex');
      await settings.importSettingsMap({
        'generation': {'temperature': 0.5},
        'toggles': {'enableReasoning': false},
      });
      expect(settings.enableServiceTier, isTrue);
      expect(settings.serviceTier, 'flex');
    });
  });

  group('ChatProvider.activeServiceTier', () {
    test('follows the setting and the active provider', () async {
      final settings = SettingsProvider();
      final chat = ChatProvider()..updateSettings(settings);
      await _flushAsyncInit();

      chat.setProvider(AiProvider.openRouter);
      settings.setServiceTier('flex');
      expect(chat.activeServiceTier, isNull);

      settings.setEnableServiceTier(true);
      expect(chat.activeServiceTier, 'flex');

      settings.setServiceTier('default');
      expect(chat.activeServiceTier, isNull);

      settings.setServiceTier('flex');
      chat.setProvider(AiProvider.gemini);
      expect(chat.activeServiceTier, isNull);
    });
  });

  group('Service Tier panel', () {
    final dropdown = find.byKey(const Key('service_tier_dropdown'));
    final tierSwitch = find.widgetWithText(SwitchListTile, 'Service Tier');

    /// The model list above this section shows a loading spinner for a fetch
    /// that never completes under the test clock, so pumpAndSettle would wait
    /// on it forever. A fixed run of frames covers the dropdown and dialog
    /// transitions.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<(ChatProvider, SettingsProvider)> pumpOpenRouter(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(SettingsDrawer));
      final chat = element.read<ChatProvider>();
      final settings = element.read<SettingsProvider>();
      chat.setProvider(AiProvider.openRouter);
      await settle(tester);
      await tester.ensureVisible(tierSwitch);
      await settle(tester);
      return (chat, settings);
    }

    String shownTier(WidgetTester tester) =>
        tester.widget<DropdownButton<String>>(dropdown).value!;

    Future<void> tapSwitch(WidgetTester tester) async {
      await tester.tap(tierSwitch);
      await settle(tester);
    }

    Future<void> pick(WidgetTester tester, String label) async {
      await tester.tap(dropdown);
      await settle(tester);
      await tester.tap(find.textContaining(label).last);
      await settle(tester);
    }

    testWidgets('is hidden for a provider without tiers', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('Service Tier'), findsNothing);
    });

    testWidgets('off shows Default even with Priority stored', (tester) async {
      final (_, settings) = await pumpOpenRouter(tester);
      expect(settings.enableServiceTier, isFalse);
      expect(shownTier(tester), 'default');
      expect(find.text('Off: every request uses Default'), findsOneWidget);

      settings.setServiceTier('priority');
      await settle(tester);
      expect(shownTier(tester), 'default');
    });

    testWidgets('Priority asks first; Cancel keeps Default', (tester) async {
      final (_, settings) = await pumpOpenRouter(tester);
      await tapSwitch(tester);
      expect(settings.enableServiceTier, isTrue);

      await pick(tester, 'Priority');
      expect(find.text('Priority: Not Recommended'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(settings.serviceTier, 'default');
      expect(shownTier(tester), 'default');

      await pick(tester, 'Priority');
      await tester.tap(find.text('Use Priority'));
      await settle(tester);
      expect(settings.serviceTier, 'priority');
      expect(shownTier(tester), 'priority');
    });

    testWidgets('Ultrafast asks first', (tester) async {
      final (_, settings) = await pumpOpenRouter(tester);
      await tapSwitch(tester);

      await pick(tester, 'Ultrafast');
      expect(find.text('Ultrafast: Not Recommended'), findsOneWidget);
      await tester.tap(find.text('Use Ultrafast'));
      await settle(tester);
      expect(settings.serviceTier, 'ultrafast');
    });

    testWidgets('Flex is stored without asking', (tester) async {
      final (_, settings) = await pumpOpenRouter(tester);
      await tapSwitch(tester);

      await pick(tester, 'Flex');
      expect(find.byType(AlertDialog), findsNothing);
      expect(settings.serviceTier, 'flex');
    });

    testWidgets('turning the switch on with Priority stored asks again',
        (tester) async {
      final (_, settings) = await pumpOpenRouter(tester);
      settings.setServiceTier('priority');
      await settle(tester);

      await tapSwitch(tester);
      expect(find.text('Priority: Not Recommended'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(settings.enableServiceTier, isFalse);
      expect(shownTier(tester), 'default');

      await tapSwitch(tester);
      await tester.tap(find.text('Use Priority'));
      await settle(tester);
      expect(settings.enableServiceTier, isTrue);
      expect(shownTier(tester), 'priority');
    });
  });
}
