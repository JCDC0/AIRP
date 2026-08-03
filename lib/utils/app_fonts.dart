import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Grouping used to keep the font picker navigable as the list grows.
enum AppFontCategory {
  system('System'),
  ui('Interface'),
  serif('Serif'),
  mono('Monospace'),
  handwriting('Handwriting'),
  display('Display'),
  japanese('Japanese');

  const AppFontCategory(this.label);

  final String label;
}

/// One selectable typeface.
///
/// [key] is what gets persisted under `app_font_style` and travels in config
/// packs, so existing keys must never be renamed or reused for a different
/// face. [builder] is null for the platform default.
class AppFont {
  const AppFont({
    required this.key,
    required this.label,
    required this.category,
    this.builder,
  });

  final String key;
  final String label;
  final AppFontCategory category;
  final TextTheme Function(TextTheme base)? builder;

  /// Label as shown in the picker, prefixed with its group.
  String get menuLabel =>
      category == AppFontCategory.system ? label : '${category.label} · $label';
}

/// The font catalogue.
///
/// Single source of truth: `ThemeProvider.currentTextTheme` resolves through it
/// and the text designer builds its menu from it. Previously the switch and the
/// dropdown were two hand-maintained lists that had to agree.
///
/// Faces are fetched by `google_fonts` on first use rather than bundled, so
/// adding entries costs nothing in app size but a face needs one network fetch
/// before it renders.
class AppFonts {
  AppFonts._();

  static const String defaultKey = 'Default';

  static final List<AppFont> all = [
    AppFont(
      key: defaultKey,
      label: 'Default (System)',
      category: AppFontCategory.system,
    ),

    // --- Interface ---
    AppFont(
      key: 'Google',
      label: 'Google Sans (Open Sans)',
      category: AppFontCategory.ui,
      builder: GoogleFonts.openSansTextTheme,
    ),
    AppFont(
      key: 'Apple',
      label: 'Apple SF (Inter)',
      category: AppFontCategory.ui,
      builder: GoogleFonts.interTextTheme,
    ),
    AppFont(
      key: 'CleanThin',
      label: 'Minimalist (Raleway)',
      category: AppFontCategory.ui,
      builder: GoogleFonts.ralewayTextTheme,
    ),
    AppFont(
      key: 'ModernAnime',
      label: 'Light Novel (Quicksand)',
      category: AppFontCategory.ui,
      builder: GoogleFonts.quicksandTextTheme,
    ),
    AppFont(
      key: 'Rounded',
      label: 'Rounded (Nunito)',
      category: AppFontCategory.ui,
      builder: GoogleFonts.nunitoTextTheme,
    ),
    AppFont(
      key: 'Poster',
      label: 'Poster (Montserrat)',
      category: AppFontCategory.ui,
      builder: GoogleFonts.montserratTextTheme,
    ),
    AppFont(
      key: 'Geometric',
      label: 'Geometric (Poppins)',
      category: AppFontCategory.ui,
      builder: GoogleFonts.poppinsTextTheme,
    ),
    AppFont(
      key: 'Legible',
      label: 'High Legibility (Atkinson Hyperlegible)',
      category: AppFontCategory.ui,
      builder: GoogleFonts.atkinsonHyperlegibleTextTheme,
    ),
    AppFont(
      key: 'ReadingEase',
      label: 'Reading Ease (Lexend)',
      category: AppFontCategory.ui,
      builder: GoogleFonts.lexendTextTheme,
    ),

    // --- Serif ---
    AppFont(
      key: 'Claude',
      label: 'Assistant (Source Serif 4)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.sourceSerif4TextTheme,
    ),
    AppFont(
      key: 'Roleplay',
      label: 'Storybook (Lora)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.loraTextTheme,
    ),
    AppFont(
      key: 'Manuscript',
      label: 'Ancient Tome (EB Garamond)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.ebGaramondTextTheme,
    ),
    AppFont(
      key: 'Gothic',
      label: 'Victorian (Crimson Pro)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.crimsonProTextTheme,
    ),
    AppFont(
      key: 'Stylized',
      label: 'Vogue (Playfair Display)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.playfairDisplayTextTheme,
    ),
    AppFont(
      key: 'Broadsheet',
      label: 'Broadsheet (Merriweather)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.merriweatherTextTheme,
    ),
    AppFont(
      key: 'Academic',
      label: 'Academic (Libre Baskerville)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.libreBaskervilleTextTheme,
    ),
    AppFont(
      key: 'Elegant',
      label: 'Elegant (Cormorant Garamond)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.cormorantGaramondTextTheme,
    ),
    AppFont(
      key: 'Novel',
      label: 'Novel (Spectral)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.spectralTextTheme,
    ),
    AppFont(
      key: 'Warm',
      label: 'Warm Print (Bitter)',
      category: AppFontCategory.serif,
      builder: GoogleFonts.bitterTextTheme,
    ),

    // --- Monospace ---
    AppFont(
      key: 'Terminal',
      label: 'Hacker (Space Mono)',
      category: AppFontCategory.mono,
      builder: GoogleFonts.spaceMonoTextTheme,
    ),
    AppFont(
      key: 'Typewriter',
      label: 'Detective (Special Elite)',
      category: AppFontCategory.mono,
      builder: GoogleFonts.specialEliteTextTheme,
    ),
    AppFont(
      key: 'Code',
      label: 'Editor (JetBrains Mono)',
      category: AppFontCategory.mono,
      builder: GoogleFonts.jetBrainsMonoTextTheme,
    ),
    AppFont(
      key: 'Console',
      label: 'Console (IBM Plex Mono)',
      category: AppFontCategory.mono,
      builder: GoogleFonts.ibmPlexMonoTextTheme,
    ),
    AppFont(
      key: 'Ligature',
      label: 'Ligatures (Fira Code)',
      category: AppFontCategory.mono,
      builder: GoogleFonts.firaCodeTextTheme,
    ),

    // --- Handwriting ---
    AppFont(
      key: 'Journal',
      label: 'Handwritten (Caveat)',
      category: AppFontCategory.handwriting,
      builder: GoogleFonts.caveatTextTheme,
    ),
    AppFont(
      key: 'Script',
      label: 'Calligraphy (Dancing Script)',
      category: AppFontCategory.handwriting,
      builder: GoogleFonts.dancingScriptTextTheme,
    ),
    AppFont(
      key: 'Notebook',
      label: 'Notebook (Indie Flower)',
      category: AppFontCategory.handwriting,
      builder: GoogleFonts.indieFlowerTextTheme,
    ),
    AppFont(
      key: 'Casual',
      label: 'Casual Note (Patrick Hand)',
      category: AppFontCategory.handwriting,
      builder: GoogleFonts.patrickHandTextTheme,
    ),
    AppFont(
      key: 'Marker',
      label: 'Marker (Shadows Into Light)',
      category: AppFontCategory.handwriting,
      builder: GoogleFonts.shadowsIntoLightTextTheme,
    ),

    // --- Display ---
    AppFont(
      key: 'Cyber',
      label: 'Neon HUD (Orbitron)',
      category: AppFontCategory.display,
      builder: GoogleFonts.orbitronTextTheme,
    ),
    AppFont(
      key: 'Fantasy',
      label: 'MMORPG (Cinzel)',
      category: AppFontCategory.display,
      builder: GoogleFonts.cinzelTextTheme,
    ),
    AppFont(
      key: 'Epic',
      label: 'Epic Titles (Cinzel Decorative)',
      category: AppFontCategory.display,
      builder: GoogleFonts.cinzelDecorativeTextTheme,
    ),
    AppFont(
      key: 'Medieval',
      label: 'Tavern Sign (MedievalSharp)',
      category: AppFontCategory.display,
      builder: GoogleFonts.medievalSharpTextTheme,
    ),
    AppFont(
      key: 'Runic',
      label: 'Old Kingdom (Uncial Antiqua)',
      category: AppFontCategory.display,
      builder: GoogleFonts.uncialAntiquaTextTheme,
    ),
    AppFont(
      key: 'Blackletter',
      label: 'Blackletter (Pirata One)',
      category: AppFontCategory.display,
      builder: GoogleFonts.pirataOneTextTheme,
    ),
    AppFont(
      key: 'Comic',
      label: 'Comic (Comic Neue)',
      category: AppFontCategory.display,
      builder: GoogleFonts.comicNeueTextTheme,
    ),

    // --- Japanese ---
    AppFont(
      key: 'AnimeSub',
      label: 'Subtitles (Kosugi Maru)',
      category: AppFontCategory.japanese,
      builder: GoogleFonts.kosugiMaruTextTheme,
    ),
    AppFont(
      key: 'JapaneseSans',
      label: 'Japanese Sans (Noto Sans JP)',
      category: AppFontCategory.japanese,
      builder: GoogleFonts.notoSansJpTextTheme,
    ),
    AppFont(
      key: 'JapaneseRound',
      label: 'Japanese Rounded (M PLUS Rounded 1c)',
      category: AppFontCategory.japanese,
      builder: GoogleFonts.mPlusRounded1cTextTheme,
    ),
    AppFont(
      key: 'JapaneseMincho',
      label: 'Japanese Mincho (Sawarabi Mincho)',
      category: AppFontCategory.japanese,
      builder: GoogleFonts.sawarabiMinchoTextTheme,
    ),
  ];

  static final Map<String, AppFont> _byKey = {
    for (final font in all) font.key: font,
  };

  /// Looks up a font, falling back to the platform default for a key written
  /// by a newer build or an edited config pack.
  static AppFont resolve(String key) => _byKey[key] ?? _byKey[defaultKey]!;

  /// Applies the selected face to [base].
  static TextTheme textTheme(String key, TextTheme base) {
    final builder = resolve(key).builder;
    return builder == null ? base : builder(base);
  }
}
