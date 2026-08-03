import 'package:airp/utils/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalogue', () {
    test('keys are unique', () {
      final keys = AppFonts.all.map((f) => f.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('labels are unique', () {
      final labels = AppFonts.all.map((f) => f.label).toList();
      expect(labels.toSet().length, labels.length);
    });

    test('every key resolves back to its own entry', () {
      for (final font in AppFonts.all) {
        expect(AppFonts.resolve(font.key).key, font.key);
      }
    });

    test('only the default has no builder', () {
      final withoutBuilder = AppFonts.all.where((f) => f.builder == null);
      expect(withoutBuilder.map((f) => f.key), [AppFonts.defaultKey]);
    });

    test('every key that ever shipped is still present', () {
      // These are persisted under `app_font_style` and travel in config packs.
      // Renaming one silently resets a user's font to the system default.
      const shipped = [
        'Default',
        'Google',
        'Apple',
        'Claude',
        'Roleplay',
        'Terminal',
        'Manuscript',
        'Cyber',
        'ModernAnime',
        'AnimeSub',
        'Gothic',
        'Journal',
        'CleanThin',
        'Stylized',
        'Fantasy',
        'Typewriter',
      ];

      final keys = AppFonts.all.map((f) => f.key).toSet();
      for (final key in shipped) {
        expect(keys, contains(key), reason: '$key was dropped or renamed');
      }
    });

    test('the catalogue grew past the original sixteen', () {
      expect(AppFonts.all.length, greaterThan(16));
    });
  });

  group('menuLabel', () {
    test('prefixes the category for real faces', () {
      final font = AppFonts.resolve('Code');
      expect(font.menuLabel, 'Monospace · Editor (JetBrains Mono)');
    });

    test('leaves the system default unprefixed', () {
      expect(AppFonts.resolve(AppFonts.defaultKey).menuLabel, 'Default (System)');
    });
  });

  group('textTheme', () {
    test('returns the base theme untouched for the default', () {
      const base = TextTheme();
      expect(AppFonts.textTheme(AppFonts.defaultKey, base), same(base));
    });

    test('falls back to the base theme for an unknown key', () {
      const base = TextTheme();
      expect(AppFonts.textTheme('NotAFontFromSomeFutureBuild', base), same(base));
    });
  });
}
