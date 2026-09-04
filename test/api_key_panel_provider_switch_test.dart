import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/providers/vfx_provider.dart';
import 'package:airp/widgets/settings_panels/api_settings_panel.dart';

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

Finder _keyField() =>
    find.byWidgetPredicate((w) => w is TextField && w.obscureText);

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

  testWidgets(
    'switching provider repaints the key field even while it holds focus',
    (tester) async {
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_buildTestApp(chatProvider));
      await tester.pumpAndSettle();

      chatProvider.setProvider(AiProvider.gemini);
      await tester.pumpAndSettle();

      await tester.enterText(_keyField(), 'gemini-secret');
      await tester.pumpAndSettle();
      expect(chatProvider.geminiKey, 'gemini-secret');

      // The field keeps focus after typing, exactly as it does on a device
      // when the user taps the provider dropdown without dismissing the
      // keyboard first.
      final controller = tester.widget<TextField>(_keyField()).controller!;
      expect(tester.widget<TextField>(_keyField()).focusNode!.hasFocus, isTrue);

      chatProvider.setProvider(AiProvider.openRouter);
      await tester.pumpAndSettle();

      // OpenRouter has no key, so the box must be empty. Showing Gemini's key
      // here reads as "OpenRouter is configured" while the send path has
      // nothing to send.
      expect(controller.text, isEmpty);
      expect(chatProvider.openRouterKey, isEmpty);

      // Unmount before disposing so the panel's controllers go first, then let
      // ChatProvider cancel the model auto-fetch and settings-save debounces.
      await tester.pumpWidget(const SizedBox());
      chatProvider.dispose();
      await tester.pump();
    },
  );

  testWidgets('an unfocused key field still follows a provider switch', (
    tester,
  ) async {
    final chatProvider = ChatProvider();
    await tester.pumpWidget(_buildTestApp(chatProvider));
    await tester.pumpAndSettle();

    await tester.enterText(_keyField(), 'gemini-secret');
    await tester.pumpAndSettle();

    final controller = tester.widget<TextField>(_keyField()).controller!;
    tester.widget<TextField>(_keyField()).focusNode!.unfocus();
    await tester.pumpAndSettle();

    chatProvider.setProvider(AiProvider.openRouter);
    await tester.pumpAndSettle();

    expect(controller.text, isEmpty);

    await tester.pumpWidget(const SizedBox());
    chatProvider.dispose();
    await tester.pump();
  });

  testWidgets('a blank key for the active provider is reported before sending',
      (tester) async {
    final chatProvider = ChatProvider();
    await tester.pumpWidget(_buildTestApp(chatProvider));
    await tester.pumpAndSettle();

    chatProvider.setProvider(AiProvider.openRouter);
    await tester.pumpAndSettle();

    // Sending with an empty slot used to go out as `Authorization: Bearer `,
    // which OpenRouter answers with a flat 401 Missing Authentication header.
    expect(chatProvider.missingCredentialError(), contains('OpenRouter'));

    await tester.enterText(_keyField(), 'sk-or-v1-something');
    await tester.pumpAndSettle();
    expect(chatProvider.missingCredentialError(), isNull);

    await tester.pumpWidget(const SizedBox());
    chatProvider.dispose();
    await tester.pump();
  });
}
