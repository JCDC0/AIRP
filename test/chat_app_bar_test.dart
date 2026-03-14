import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/models/chat_models.dart';
import 'package:airp/widgets/chat_app_bar.dart';

/// Builds a minimal test app that hosts [ChatAppBar].
Widget _buildTestApp({
  required ChatProvider chatProvider,
  required ThemeProvider themeProvider,
  required ScaleProvider scaleProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ChangeNotifierProvider<ScaleProvider>.value(value: scaleProvider),
    ],
    child: MaterialApp(
      home: Scaffold(
        appBar: ChatAppBar(systemFontSize: 16.0),
        body: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    // Provide empty mock storage so providers initialise without errors.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'starring a provider immediately updates the star icon without reopening the menu',
    (WidgetTester tester) async {
      final chatProvider = ChatProvider();
      final themeProvider = ThemeProvider();
      final scaleProvider = ScaleProvider();

      await tester.pumpWidget(
        _buildTestApp(
          chatProvider: chatProvider,
          themeProvider: themeProvider,
          scaleProvider: scaleProvider,
        ),
      );
      // Let async provider init settle.
      await tester.pumpAndSettle();

      // Open the provider picker by tapping the arrow icon in the app-bar title.
      await tester.tap(find.byKey(ChatAppBar.providerPickerTriggerKey));
      await tester.pumpAndSettle();

      // The dialog should now be visible.
      expect(find.byKey(ChatAppBar.providerPickerDialogKey), findsOneWidget);

      // Before starring anything, all star icons should be unfilled.
      final dialogFinder = find.byKey(ChatAppBar.providerPickerDialogKey);
      expect(
        find.descendant(of: dialogFinder, matching: find.byIcon(Icons.star)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: dialogFinder,
          matching: find.byIcon(Icons.star_border),
        ),
        findsWidgets,
      );

      // Pick the first provider in the sorted list (first star_border icon).
      final firstStarButton = find
          .descendant(
            of: dialogFinder,
            matching: find.byIcon(Icons.star_border),
          )
          .first;
      await tester.tap(firstStarButton);
      // Allow the Consumer rebuild triggered by notifyListeners() to complete.
      await tester.pumpAndSettle();

      // The starred icon must now be visible — no close/reopen required.
      expect(
        find.descendant(of: dialogFinder, matching: find.byIcon(Icons.star)),
        findsOneWidget,
      );

      // The starred provider should appear at the top of the list.
      // The first InkWell in the dialog represents the top provider row.
      final providerTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: dialogFinder,
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      // The starred provider must be first in the rendered list.
      expect(chatProvider.starredProviders.length, 1,
          reason: 'Exactly one provider should be starred after one toggle');
      final starredProvider = chatProvider.starredProviders.first;
      final starredName = _providerDisplayNameForTest(starredProvider);
      expect(providerTexts.first, equals(starredName));
    },
  );

  testWidgets(
    'unstarring a provider immediately removes the star icon without reopening',
    (WidgetTester tester) async {
      final chatProvider = ChatProvider();
      final themeProvider = ThemeProvider();
      final scaleProvider = ScaleProvider();

      // Pre-star the Groq provider before the dialog is opened.
      chatProvider.toggleProviderStar(AiProvider.groq);

      await tester.pumpWidget(
        _buildTestApp(
          chatProvider: chatProvider,
          themeProvider: themeProvider,
          scaleProvider: scaleProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Open picker by tapping the arrow icon in the app-bar title.
      await tester.tap(find.byKey(ChatAppBar.providerPickerTriggerKey));
      await tester.pumpAndSettle();

      final dialogFinder = find.byKey(ChatAppBar.providerPickerDialogKey);
      expect(dialogFinder, findsOneWidget);

      // Exactly one filled star visible (for Groq which was pre-starred).
      expect(
        find.descendant(of: dialogFinder, matching: find.byIcon(Icons.star)),
        findsOneWidget,
      );

      // Tap the filled star to un-star.
      await tester.tap(
        find.byKey(ValueKey<String>('provider-star-${AiProvider.groq.name}')),
      );
      await tester.pumpAndSettle();

      // Star should have disappeared immediately.
      expect(
        find.descendant(of: dialogFinder, matching: find.byIcon(Icons.star)),
        findsNothing,
      );
    },
  );
}

/// Mirrors [ChatAppBar._providerDisplayName] so tests can validate ordering
/// without accessing private members.
String _providerDisplayNameForTest(AiProvider provider) {
  switch (provider) {
    case AiProvider.gemini:
      return 'Gemini';
    case AiProvider.openRouter:
      return 'OpenRouter';
    case AiProvider.arliAi:
      return 'ArliAI';
    case AiProvider.nanoGpt:
      return 'NanoGPT';
    case AiProvider.nanoGptImage:
      return 'NanoGPT Image';
    case AiProvider.local:
      return 'Local';
    case AiProvider.openAi:
      return 'OpenAI';
    case AiProvider.huggingFace:
      return 'HuggingFace';
    case AiProvider.groq:
      return 'Groq';
    case AiProvider.vertexAi:
      return 'Vertex AI';
    case AiProvider.blackboxAi:
      return 'Blackbox AI';
    case AiProvider.minimax:
      return 'Minimax';
    case AiProvider.openAiCompatible:
      return 'OpenAI Compatible';
    case AiProvider.deepseek:
      return 'Deepseek';
    case AiProvider.ollama:
      return 'Ollama';
    case AiProvider.qwen:
      return 'Qwen';
    case AiProvider.xAi:
      return 'xAI';
    case AiProvider.zAi:
      return 'Z.ai';
    case AiProvider.mistral:
      return 'Mistral';
  }
}
