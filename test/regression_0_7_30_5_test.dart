import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/providers/settings_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/providers/vfx_provider.dart';
import 'package:airp/utils/constants.dart';
import 'package:airp/widgets/settings_panels/system_prompt_panel.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

Widget _promptApp(ChatProvider chatProvider) => MultiProvider(
  providers: [
    ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
    ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
    ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ChangeNotifierProvider<VfxProvider>(create: (_) => VfxProvider()),
    ChangeNotifierProvider<ScaleProvider>(create: (_) => ScaleProvider()),
  ],
  child: const MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: SystemPromptPanel())),
  ),
);

Finder _promptField() =>
    find.byWidgetPredicate((w) => w is TextField && w.maxLines == 12);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  group('Local carries a real model name into messages and sessions', () {
    test('a blank Target Model ID does not leave the model name empty', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatProvider();
      await _settle();

      provider.setProvider(AiProvider.local);

      // What the reply bubble and the saved session record. Before this it was
      // the empty string, because _selectedModel took the raw blank field.
      expect(provider.activeModelId, 'local-model');

      provider.dispose();
    });

    test('the discovered model wins once the server has been listed', () async {
      SharedPreferences.setMockInitialValues({
        ApiConstants.prefListLocal: [
          jsonEncode(ModelInfo(id: 'qwen3-8b', name: 'qwen3-8b').toJson()),
        ],
      });
      final provider = ChatProvider();
      await _settle();

      provider.setProvider(AiProvider.local);
      expect(provider.activeModelId, 'qwen3-8b');

      provider.dispose();
    });
  });

  group('debounced settings survive the app going away', () {
    test('flushPendingSave writes a settings edit that is still pending',
        () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ChatProvider();
      await _settle();

      provider.setLocalIp('http://192.168.1.50:8080/v1');
      provider.saveSettingsDebounced();

      // Backgrounded before the 600 ms debounce elapses.
      await provider.flushPendingSave();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(ApiConstants.prefLocalIp),
        'http://192.168.1.50:8080/v1',
      );

      provider.dispose();
    });
  });

  group('system prompt panel', () {
    testWidgets('an external prompt change lands even while the field is focused',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_promptApp(chatProvider));
      await tester.pumpAndSettle();

      await tester.enterText(_promptField(), 'my own draft');
      await tester.pumpAndSettle();

      final controller = tester.widget<TextField>(_promptField()).controller!;

      // A config pack import or character card load while the drawer is open
      // and the textarea still holds focus.
      chatProvider.setSystemInstruction('loaded from a config pack');
      await tester.pumpAndSettle();

      // Stranding the draft here is not cosmetic: the next keystroke writes
      // the stale text straight back over the imported prompt.
      expect(controller.text, 'loaded from a config pack');

      await tester.pumpWidget(const SizedBox());
      chatProvider.dispose();
      await tester.pump();
    });

    testWidgets('typing is still not interrupted by its own echo', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_promptApp(chatProvider));
      await tester.pumpAndSettle();

      await tester.enterText(_promptField(), 'rules');
      await tester.pumpAndSettle();

      final controller = tester.widget<TextField>(_promptField()).controller!;
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.enterText(_promptField(), ' rules');
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();

      expect(controller.text, ' rules');
      expect(controller.selection.baseOffset, 1);

      await tester.pumpWidget(const SizedBox());
      chatProvider.dispose();
      await tester.pump();
    });
  });
}
