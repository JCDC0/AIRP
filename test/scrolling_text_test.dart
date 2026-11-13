import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airp/widgets/scrolling_text.dart';

/// Guards the one property that makes a scrolling title useful: the whole
/// string has to be in the tree.
///
/// Never `pumpAndSettle` on an overflowing title. It animates forever by
/// design, so a settle call runs to the ten minute fake timeout.
void main() {
  Widget boxed(String text, double width) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: ScrollingText(text, style: const TextStyle(fontSize: 14)),
        ),
      ),
    ),
  );

  testWidgets('an overflowing title is laid out at its full width', (
    tester,
  ) async {
    const long =
        'A conversation title far too long to fit inside its box, twice over';

    await tester.pumpWidget(boxed(long, 120));
    await tester.pump(const Duration(milliseconds: 100));

    // The bug: the text was laid out at the clipped width, so sliding it just
    // moved the same visible words and the rest was nowhere in the tree.
    final size = tester.getSize(find.text(long));
    expect(size.width, greaterThan(120.0));

    expect(
      find.descendant(
        of: find.byType(ScrollingText),
        matching: find.byType(ClipRect),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the slide reaches the end under the theme font and text scale', (
    tester,
  ) async {
    const long =
        'A conversation title far too long to fit inside its box, twice over';

    // The app font arrives through DefaultTextStyle and the system text size
    // through MediaQuery. Measuring the bare style left both out, so the box
    // was narrower than what Text drew and the end of the title was cut off.
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: DefaultTextStyle(
                  style: const TextStyle(letterSpacing: 3),
                  child: ScrollingText(
                    long,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
      ),
    );
  });

  testWidgets('a title that fits renders as a plain Text', (tester) async {
    const short = 'Short';

    await tester.pumpWidget(boxed(short, 300));
    await tester.pump();

    final size = tester.getSize(find.text(short));
    expect(size.width, lessThanOrEqualTo(300.0));

    // No clip and no animation when there is nothing to scroll, which is what
    // keeps a list of short titles from scheduling frames forever.
    expect(
      find.descendant(
        of: find.byType(ScrollingText),
        matching: find.byType(ClipRect),
      ),
      findsNothing,
    );
  });
}
