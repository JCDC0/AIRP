import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/settings_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/providers/vfx_provider.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/widgets/settings_panels/system_prompt_panel.dart';

/// Hosts [SystemPromptPanel] with the four providers it reads.
Widget _buildTestApp(ChatProvider chatProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<VfxProvider>(create: (_) => VfxProvider()),
      ChangeNotifierProvider<ScaleProvider>(create: (_) => ScaleProvider()),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SystemPromptPanel()),
      ),
    ),
  );
}

/// The prompt textarea is the multiline field; the title field above it is
/// single-line.
Finder _promptField() => find.byWidgetPredicate(
  (w) => w is TextField && w.maxLines == 12,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('system prompt editing', () {
    testWidgets('a trailing space survives instead of being trimmed away', (
      tester,
    ) async {
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_buildTestApp(chatProvider));
      await tester.pumpAndSettle();

      await tester.enterText(_promptField(), 'You are helpful.');
      await tester.pump();
      await tester.enterText(_promptField(), 'You are helpful. ');
      await tester.pump();

      final field = tester.widget<TextField>(_promptField());
      expect(field.controller!.text, 'You are helpful. ');
      expect(chatProvider.systemInstruction, 'You are helpful. ');
    });

    testWidgets('a space typed at the front does not jump the caret to the end',
        (tester) async {
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_buildTestApp(chatProvider));
      await tester.pumpAndSettle();

      await tester.enterText(_promptField(), 'rules');
      await tester.pump();

      final controller = tester.widget<TextField>(_promptField()).controller!;

      // Put the caret at the very front and type a space there, the way the
      // field's own onChanged would report it.
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.enterText(_promptField(), ' rules');
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();

      expect(controller.text, ' rules');
      expect(controller.selection.baseOffset, 1);
      expect(chatProvider.systemInstruction, ' rules');
    });

    testWidgets('an external change still syncs while the field is unfocused', (
      tester,
    ) async {
      final chatProvider = ChatProvider();
      await tester.pumpWidget(_buildTestApp(chatProvider));
      await tester.pumpAndSettle();

      chatProvider.setSystemInstruction('loaded from a config pack');
      await tester.pumpAndSettle();

      final controller = tester.widget<TextField>(_promptField()).controller!;
      expect(controller.text, 'loaded from a config pack');
    });
  });
}
