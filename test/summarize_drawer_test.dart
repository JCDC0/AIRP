import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airp/providers/chat_provider.dart';
import 'package:airp/services/compaction_service.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/providers/vfx_provider.dart';
import 'package:airp/utils/constants.dart';
import 'package:airp/widgets/settings_panels/settings_slider.dart';
import 'package:airp/widgets/summarize_drawer.dart';

import 'package:flutter/services.dart';

Widget _buildTestApp(ChatProvider chatProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<VfxProvider>(create: (_) => VfxProvider()),
      ChangeNotifierProvider<ScaleProvider>(create: (_) => ScaleProvider()),
    ],
    child: const MaterialApp(home: Scaffold(body: SummarizeDrawer())),
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

  testWidgets('SummarizeDrawer renders with SettingsSlider and adjusted width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    await tester.pumpWidget(_buildTestApp(chatProvider));
    await tester.pumpAndSettle();

    expect(find.text('Summarize / Context'), findsOneWidget);

    final listViewScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Chat blocks to carry'),
      100,
      scrollable: listViewScrollable,
    );
    expect(find.text('Chat blocks to carry'), findsOneWidget);
    expect(find.byType(SettingsSlider), findsOneWidget);

    // Verify drawer width is at least 300px (adjusted from the old cramped 250px)
    final materialFinder = find.byType(Material).first;
    final size = tester.getSize(materialFinder);
    expect(size.width, greaterThanOrEqualTo(300.0));
  });

  testWidgets('carrying chat blocks can be set to 0 via textbox', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    await tester.pumpWidget(_buildTestApp(chatProvider));
    await tester.pumpAndSettle();

    final listViewScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byType(SettingsSlider),
      100,
      scrollable: listViewScrollable,
    );

    // The textfield inside SettingsSlider
    final numberFieldFinder = find.descendant(
      of: find.byType(SettingsSlider),
      matching: find.byType(TextField),
    );
    expect(numberFieldFinder, findsOneWidget);

    // Type '0' into the number field
    await tester.enterText(numberFieldFinder, '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SummarizeDefaults.prefBlockCount), 0);
  });

  testWidgets('compaction mode selector persists the chosen mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    await tester.pumpWidget(_buildTestApp(chatProvider));
    await tester.pumpAndSettle();

    // The selector sits in the fixed footer, so it is reachable without
    // scrolling the rule list. That is the whole point of putting it there.
    final dropdown = find.byKey(const Key('compact_mode_dropdown'));
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compact to Chronicle').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(SummarizeDefaults.prefCompactMode),
      SummarizeDefaults.modeChronicle,
    );
  });

  testWidgets('legacy prompts migrate into two rules, and rules can be added', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // A user who had edited the old two prompts must not silently lose them.
    SharedPreferences.setMockInitialValues({
      SummarizeDefaults.prefCompressPrompt: 'MY OWN SUMMARY PROMPT',
      SummarizeDefaults.prefVoiceSamplesPrompt: 'MY OWN VOICES PROMPT',
    });

    final chatProvider = ChatProvider();
    await tester.pumpWidget(_buildTestApp(chatProvider));
    await tester.pumpAndSettle();

    expect(find.text('MY OWN SUMMARY PROMPT'), findsOneWidget);
    expect(find.text('MY OWN VOICES PROMPT'), findsOneWidget);
    expect(find.text(SummarizeDefaults.ruleNameSummary), findsOneWidget);
    expect(find.text(SummarizeDefaults.ruleNameVoices), findsOneWidget);

    final addButton = find.byKey(const Key('add_rule_button'));
    await tester.scrollUntilVisible(
      addButton,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final stored = CompactionService.decodeRules(
      prefs.getString(SummarizeDefaults.prefCompactRules),
    );
    expect(stored, isNotNull);
    expect(stored!.length, 3);
    expect(stored[0].prompt, 'MY OWN SUMMARY PROMPT');
  });

  testWidgets('editing a prompt does not revert the rule name', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    await tester.pumpWidget(_buildTestApp(chatProvider));
    await tester.pumpAndSettle();

    Finder fieldWithHint(String hint) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint,
    );

    // Both edits land without anything forcing a rebuild in between, which is
    // the case the card's captured rule used to go stale in: the name came
    // back as whatever it was at the last build.
    await tester.enterText(fieldWithHint('Rule name').first, 'Key Events');
    await tester.enterText(
      fieldWithHint('What this rule should contribute…').first,
      'Write the chronology.',
    );

    final prefs = await SharedPreferences.getInstance();
    final stored = CompactionService.decodeRules(
      prefs.getString(SummarizeDefaults.prefCompactRules),
    );

    expect(stored, isNotNull);
    expect(stored!.first.name, 'Key Events');
    expect(stored.first.prompt, 'Write the chronology.');
  });
}
