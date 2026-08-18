import 'package:airp/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('markdown colours retained for roleplay prose', () {
    test('the three configurable elements round-trip through prefs', () async {
      final theme = ThemeProvider();
      await _settle();

      await theme.updateMarkdownColor('paragraph', const Color(0xFF112233));
      await theme.updateMarkdownColor('italic', const Color(0xFF445566));
      await theme.updateMarkdownColor('bold', const Color(0xFF778899));
      await _settle();

      final reloaded = ThemeProvider();
      await _settle();

      expect(reloaded.markdownParagraphColor, const Color(0xFF112233));
      expect(reloaded.markdownItalicColor, const Color(0xFF445566));
      expect(reloaded.markdownBoldColor, const Color(0xFF778899));
    });

    test('an unset element falls back to the bubble text colour', () async {
      final theme = ThemeProvider();
      await _settle();

      expect(theme.markdownParagraphColor, theme.textColor);
      expect(theme.markdownItalicColor, theme.textColor);
      expect(theme.markdownBoldColor, theme.textColor);
    });

    test('resetToDefaults clears the three overrides', () async {
      final theme = ThemeProvider();
      await _settle();

      await theme.updateMarkdownColor('bold', const Color(0xFFAABBCC));
      expect(theme.markdownBoldColor, const Color(0xFFAABBCC));

      await theme.resetToDefaults();
      expect(theme.markdownBoldColor, theme.textColor);
    });
  });

  group('retired markdown pickers', () {
    test('structural elements still resolve a colour to render with', () async {
      final theme = ThemeProvider();
      await _settle();

      // Headings, bullets and strikethrough are no longer tintable, but the
      // Summarize drawer emits headings and bullets, so they must still paint.
      expect(theme.markdownStructureColor, theme.textColor);
      expect(theme.markdownBlockquoteColor, theme.subtitleColor);
      expect(theme.markdownLinkColor, isNot(theme.textColor));
    });

    test('a retired type is ignored instead of throwing', () async {
      final theme = ThemeProvider();
      await _settle();

      // A config pack written before 0.7.30.3 still carries these types.
      for (final retired in const [
        'boldItalic',
        'h1',
        'h2',
        'h3',
        'link',
        'inlineCode',
        'codeBlock',
        'blockquote',
        'list',
        'strike',
      ]) {
        await expectLater(
          theme.updateMarkdownColor(retired, const Color(0xFFFF0000)),
          completes,
        );
      }

      expect(theme.markdownStructureColor, theme.textColor);
      expect(theme.markdownParagraphColor, theme.textColor);
    });

    test('an export from an older build imports without error', () async {
      final theme = ThemeProvider();
      await _settle();

      await theme.importSettingsMap({
        'colors': {
          'markdownParagraph': const Color(0xFF010203).toARGB32(),
          'markdownBold': const Color(0xFF040506).toARGB32(),
          'markdownH1': const Color(0xFFFF0000).toARGB32(),
          'markdownCodeBlock': const Color(0xFF00FF00).toARGB32(),
          'markdownStrike': const Color(0xFF0000FF).toARGB32(),
        },
      });

      expect(theme.markdownParagraphColor, const Color(0xFF010203));
      expect(theme.markdownBoldColor, const Color(0xFF040506));
      expect(theme.markdownStructureColor, theme.textColor);
    });
  });
}
