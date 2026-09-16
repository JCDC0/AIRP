import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/providers/vfx_provider.dart';
import 'package:airp/providers/settings_provider.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/providers/update_provider.dart';
import 'package:airp/widgets/settings_drawer.dart';

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
        body: SizedBox(
          width: 400,
          height: 1200,
          child: SettingsDrawer(),
        ),
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

  group('Core Components drawer', () {
    testWidgets('renders Core Components ExpansionTile', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Core Components'), findsOneWidget);
    });

    testWidgets('Core Components is initially expanded and contains API Key section', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('API Key (BYOK)'), findsOneWidget);
    });

    testWidgets('Core Components shows provider display name as subtitle', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Gemini'), findsWidgets);
    });

    testWidgets('collapsing Core Components hides API Key section', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('API Key (BYOK)'), findsOneWidget);

      await tester.tap(find.text('Core Components'));
      await tester.pumpAndSettle();

      expect(find.text('API Key (BYOK)'), findsNothing);
    });

    testWidgets('other ExpansionTile sections still render', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Main System Prompt'), findsOneWidget);
      expect(find.text('Generation Parameters'), findsOneWidget);
      expect(find.text('Web Search'), findsOneWidget);
    });
  });

  group('UpdateProvider', () {
    test('starts with no update available', () {
      final provider = UpdateProvider();
      expect(provider.updateAvailable, isFalse);
      expect(provider.isChecking, isFalse);
      expect(provider.isDownloading, isFalse);
      expect(provider.downloadProgress, 0.0);
      expect(provider.error, isNull);
    });

    test('dismiss clears release info', () {
      final provider = UpdateProvider();
      provider.dismiss();
      expect(provider.updateAvailable, isFalse);
    });
  });
}
