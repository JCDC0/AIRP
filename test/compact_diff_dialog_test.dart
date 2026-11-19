import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/providers/scale_provider.dart';
import 'package:airp/providers/theme_provider.dart';
import 'package:airp/widgets/compact_diff_dialog.dart';

/// The review popup after a compaction. Its job is to make an append-only
/// chronicle run obvious, so that is what these check.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(WidgetTester tester, String before, String after) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ScaleProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CompactDiffDialog(
              title: 'Chronicle changes',
              before: before,
              after: after,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an append-only run is called out', (tester) async {
    await show(
      tester,
      '## Key Events\n\n- Day 1.',
      '## Key Events\n\n- Day 1.\n- Day 2.',
    );
    expect(find.text('+1 added'), findsOneWidget);
    expect(find.text('~0 edited'), findsOneWidget);
    expect(find.textContaining('only added to it'), findsOneWidget);
  });

  testWidgets('a revising run is not called an append', (tester) async {
    await show(
      tester,
      '## Key Events\n\n- Day 1: they meet at the bar.',
      '## Key Events\n\n- Day 1: they meet at the club.\n- Day 2.',
    );
    expect(find.text('~1 edited'), findsOneWidget);
    expect(find.textContaining('only added to it'), findsNothing);
  });
}
