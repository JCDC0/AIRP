import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

/// Provider for managing the application's visual theme (colors and typography).
///
/// This class handles font styles, light/dark mode, and semantic color definitions.
class ThemeProvider extends ChangeNotifier {
  String _fontStyle = 'Default';
  bool _isLightMode = false;

  Color _userBubbleColor = AppColors.defaultUserBubble;
  Color _userTextColor = AppColors.defaultUserText;
  Color _aiBubbleColor = AppColors.defaultAiBubble;
  Color _aiTextColor = AppColors.defaultAiText;
  Color _appThemeColor = AppColors.defaultAppTheme;
  Color? _markdownParagraphColor;
  Color? _markdownItalicColor;
  Color? _markdownBoldColor;
  Color? _markdownBoldItalicColor;
  Color? _markdownH1Color;
  Color? _markdownH2Color;
  Color? _markdownH3Color;
  Color? _markdownLinkColor;
  Color? _markdownInlineCodeColor;
  Color? _markdownCodeBlockColor;
  Color? _markdownBlockquoteColor;
  Color? _markdownListColor;
  Color? _markdownStrikeColor;

  String get fontStyle => _fontStyle;
  bool get isLightMode => _isLightMode;

  Color get userBubbleColor => _userBubbleColor;
  Color get userTextColor => _userTextColor;
  Color get aiBubbleColor => _aiBubbleColor;
  Color get aiTextColor => _aiTextColor;
  Color get appThemeColor => _appThemeColor;
  Color get markdownParagraphColor => _markdownParagraphColor ?? textColor;
  Color get markdownItalicColor => _markdownItalicColor ?? textColor;
  Color get markdownBoldColor => _markdownBoldColor ?? textColor;
  Color get markdownBoldItalicColor =>
      _markdownBoldItalicColor ?? _markdownBoldColor ?? textColor;
  Color get markdownH1Color => _markdownH1Color ?? textColor;
  Color get markdownH2Color => _markdownH2Color ?? textColor;
  Color get markdownH3Color => _markdownH3Color ?? textColor;
  Color get markdownLinkColor => _markdownLinkColor ?? Colors.blueAccent;
  Color get markdownInlineCodeColor => _markdownInlineCodeColor ?? textColor;
  Color get markdownCodeBlockColor => _markdownCodeBlockColor ?? textColor;
  Color get markdownBlockquoteColor =>
      _markdownBlockquoteColor ?? subtitleColor;
  Color get markdownListColor => _markdownListColor ?? textColor;
  Color get markdownStrikeColor => _markdownStrikeColor ?? textColor;

  // ── Semantic colors (adapt to light / dark mode) ──────────────────────

  /// The overall brightness used by MaterialApp / ColorScheme.
  Brightness get brightness =>
      _isLightMode ? Brightness.light : Brightness.dark;

  /// Scaffold / page background.
  Color get scaffoldBackgroundColor =>
      _isLightMode
          ? const Color(0xFFFAFAFA)
          : const Color.fromARGB(255, 0, 0, 0);

  /// Primary surface (drawers, input areas, bottom sheets).
  Color get surfaceColor =>
      _isLightMode ? const Color(0xFFF0F0F0) : const Color(0xFF1E1E1E);

  /// Deeper surface variant.
  Color get surfaceDimColor =>
      _isLightMode ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);

  /// Dropdown menus, dialog backgrounds.
  Color get dropdownColor =>
      _isLightMode ? const Color(0xFFE0E0E0) : const Color(0xFF2C2C2C);

  /// Alternate dialog background (slightly different shade).
  Color get dialogBackgroundColor =>
      _isLightMode ? const Color(0xFFE8E8E8) : const Color(0xFF2A2A2A);

  /// Primary text / icon color.
  Color get textColor => _isLightMode ? Colors.black : Colors.white;

  /// Subtitle / secondary text.
  Color get subtitleColor => _isLightMode ? Colors.black87 : Colors.white70;

  /// Hint / placeholder text.
  Color get hintColor => _isLightMode ? Colors.black54 : Colors.white54;

  /// Dim text.
  Color get dimTextColor => _isLightMode ? Colors.black38 : Colors.white38;

  /// Faint text / icons.
  Color get faintColor => _isLightMode ? Colors.black26 : Colors.white30;

  /// Faintest visible elements.
  Color get faintestColor => _isLightMode ? Colors.black26 : Colors.white24;

  /// Borders.
  Color get borderColor => _isLightMode ? Colors.black12 : Colors.white12;

  /// Dividers.
  Color get dividerColor => _isLightMode ? Colors.black12 : Colors.white10;

  /// Container background fill (cards, chips, tag pills).
  Color get containerFillColor =>
      _isLightMode ? Colors.black.withValues(alpha: 0.06) : Colors.black26;

  /// Deeper container fill.
  Color get containerFillDarkColor =>
      _isLightMode ? Colors.black.withValues(alpha: 0.04) : Colors.black12;

  /// Input field fill colour.
  Color get inputFillColor => _isLightMode ? Colors.white : Colors.black;

  /// Semi-opaque dark overlay.
  Color get overlayDarkColor =>
      _isLightMode ? Colors.black.withValues(alpha: 0.06) : Colors.black87;

  /// Foreground colour on coloured buttons.
  Color get onAccentColor => _isLightMode ? Colors.white : Colors.black;

  /// Bloom shadow colour that works on both backgrounds.
  Color get bloomGlowColor => _isLightMode ? appThemeColor : Colors.white;

  ThemeProvider() {
    _loadPreferences();
  }

  /// Generates the [TextTheme] based on the selected font style.
  TextTheme get currentTextTheme {
    final baseColor = textColor;
    final baseTheme = (_isLightMode ? ThemeData.light() : ThemeData.dark())
        .textTheme
        .apply(bodyColor: baseColor, displayColor: baseColor);
    switch (_fontStyle) {
      case 'Google':
        return GoogleFonts.openSansTextTheme(baseTheme);
      case 'Apple':
        return GoogleFonts.interTextTheme(baseTheme);
      case 'Claude':
        return GoogleFonts.sourceSerif4TextTheme(baseTheme);
      case 'Roleplay':
        return GoogleFonts.loraTextTheme(baseTheme);
      case 'Terminal':
        return GoogleFonts.spaceMonoTextTheme(baseTheme);
      case 'Manuscript':
        return GoogleFonts.ebGaramondTextTheme(baseTheme);
      case 'Cyber':
        return GoogleFonts.orbitronTextTheme(baseTheme);
      case 'ModernAnime':
        return GoogleFonts.quicksandTextTheme(baseTheme);
      case 'AnimeSub':
        return GoogleFonts.kosugiMaruTextTheme(baseTheme);
      case 'Gothic':
        return GoogleFonts.crimsonProTextTheme(baseTheme);
      case 'Journal':
        return GoogleFonts.caveatTextTheme(baseTheme);
      case 'CleanThin':
        return GoogleFonts.ralewayTextTheme(baseTheme);
      case 'Stylized':
        return GoogleFonts.playfairDisplayTextTheme(baseTheme);
      case 'Fantasy':
        return GoogleFonts.cinzelTextTheme(baseTheme);
      case 'Typewriter':
        return GoogleFonts.specialEliteTextTheme(baseTheme);
      default:
        return baseTheme;
    }
  }

  /// Toggles between light and dark mode.
  Future<void> toggleLightMode(bool value) async {
    _isLightMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_light_mode', value);
  }

  /// Updates a specific theme color and persists the change.
  Future<void> updateColor(String type, Color color) async {
    switch (type) {
      case 'userBubble':
        _userBubbleColor = color;
        break;
      case 'userText':
        _userTextColor = color;
        break;
      case 'aiBubble':
        _aiBubbleColor = color;
        break;
      case 'aiText':
        _aiTextColor = color;
        break;
      case 'appTheme':
        _appThemeColor = color;
        break;
    }
    notifyListeners();
    _saveColors();
  }

  /// Updates a markdown styling color and persists the change.
  Future<void> updateMarkdownColor(String type, Color? color) async {
    switch (type) {
      case 'paragraph':
        _markdownParagraphColor = color;
        break;
      case 'italic':
        _markdownItalicColor = color;
        break;
      case 'bold':
        _markdownBoldColor = color;
        break;
      case 'boldItalic':
        _markdownBoldItalicColor = color;
        break;
      case 'h1':
        _markdownH1Color = color;
        break;
      case 'h2':
        _markdownH2Color = color;
        break;
      case 'h3':
        _markdownH3Color = color;
        break;
      case 'link':
        _markdownLinkColor = color;
        break;
      case 'inlineCode':
        _markdownInlineCodeColor = color;
        break;
      case 'codeBlock':
        _markdownCodeBlockColor = color;
        break;
      case 'blockquote':
        _markdownBlockquoteColor = color;
        break;
      case 'list':
        _markdownListColor = color;
        break;
      case 'strike':
        _markdownStrikeColor = color;
        break;
    }
    notifyListeners();
    _saveColors();
  }

  /// Resets theme colors and typography to default values.
  Future<void> resetToDefaults() async {
    _userBubbleColor = AppColors.defaultUserBubble;
    _userTextColor = AppColors.defaultUserText;
    _aiBubbleColor = AppColors.defaultAiBubble;
    _aiTextColor = AppColors.defaultAiText;
    _appThemeColor = AppColors.defaultAppTheme;
    _markdownParagraphColor = null;
    _markdownItalicColor = null;
    _markdownBoldColor = null;
    _markdownBoldItalicColor = null;
    _markdownH1Color = null;
    _markdownH2Color = null;
    _markdownH3Color = null;
    _markdownLinkColor = null;
    _markdownInlineCodeColor = null;
    _markdownCodeBlockColor = null;
    _markdownBlockquoteColor = null;
    _markdownListColor = null;
    _markdownStrikeColor = null;
    _isLightMode = false;
    _fontStyle = 'Default';

    notifyListeners();
    _saveColors();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_light_mode', false);
    await prefs.setString('app_font_style', 'Default');
  }

  Future<void> _saveColors() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('color_app_theme', _colorToStorageInt(_appThemeColor));
    await prefs.setInt(
      'color_user_bubble',
      _colorToStorageInt(_userBubbleColor),
    );
    await prefs.setInt('color_user_text', _colorToStorageInt(_userTextColor));
    await prefs.setInt('color_ai_bubble', _colorToStorageInt(_aiBubbleColor));
    await prefs.setInt('color_ai_text', _colorToStorageInt(_aiTextColor));
    await _saveMarkdownColor(
      prefs,
      'color_md_paragraph',
      _markdownParagraphColor,
    );
    await _saveMarkdownColor(prefs, 'color_md_italic', _markdownItalicColor);
    await _saveMarkdownColor(prefs, 'color_md_bold', _markdownBoldColor);
    await _saveMarkdownColor(
      prefs,
      'color_md_bold_italic',
      _markdownBoldItalicColor,
    );
    await _saveMarkdownColor(prefs, 'color_md_h1', _markdownH1Color);
    await _saveMarkdownColor(prefs, 'color_md_h2', _markdownH2Color);
    await _saveMarkdownColor(prefs, 'color_md_h3', _markdownH3Color);
    await _saveMarkdownColor(prefs, 'color_md_link', _markdownLinkColor);
    await _saveMarkdownColor(
      prefs,
      'color_md_inline_code',
      _markdownInlineCodeColor,
    );
    await _saveMarkdownColor(
      prefs,
      'color_md_code_block',
      _markdownCodeBlockColor,
    );
    await _saveMarkdownColor(
      prefs,
      'color_md_blockquote',
      _markdownBlockquoteColor,
    );
    await _saveMarkdownColor(prefs, 'color_md_list', _markdownListColor);
    await _saveMarkdownColor(prefs, 'color_md_strike', _markdownStrikeColor);
  }

  Future<void> _saveMarkdownColor(
    SharedPreferences prefs,
    String key,
    Color? color,
  ) async {
    if (color == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setInt(key, _colorToStorageInt(color));
  }

  int _colorToStorageInt(Color color) {
    return (((color.a * 255.0).round() & 0xff) << 24) |
        (((color.r * 255.0).round() & 0xff) << 16) |
        (((color.g * 255.0).round() & 0xff) << 8) |
        ((color.b * 255.0).round() & 0xff);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _fontStyle = prefs.getString('app_font_style') ?? 'Default';
    _isLightMode = prefs.getBool('app_light_mode') ?? false;

    final int? themeInt = prefs.getInt('color_app_theme');
    _appThemeColor =
        themeInt != null ? Color(themeInt) : AppColors.defaultAppTheme;

    final int? userBubbleInt = prefs.getInt('color_user_bubble');
    _userBubbleColor =
        userBubbleInt != null
            ? Color(userBubbleInt)
            : AppColors.defaultUserBubble;

    final int? userTextInt = prefs.getInt('color_user_text');
    _userTextColor =
        userTextInt != null ? Color(userTextInt) : AppColors.defaultUserText;

    final int? aiBubbleInt = prefs.getInt('color_ai_bubble');
    _aiBubbleColor =
        aiBubbleInt != null ? Color(aiBubbleInt) : AppColors.defaultAiBubble;

    final int? aiTextInt = prefs.getInt('color_ai_text');
    _aiTextColor =
        aiTextInt != null ? Color(aiTextInt) : AppColors.defaultAiText;

    _markdownParagraphColor = _loadMarkdownColor(prefs, 'color_md_paragraph');
    _markdownItalicColor = _loadMarkdownColor(prefs, 'color_md_italic');
    _markdownBoldColor = _loadMarkdownColor(prefs, 'color_md_bold');
    _markdownBoldItalicColor = _loadMarkdownColor(
      prefs,
      'color_md_bold_italic',
    );
    _markdownH1Color = _loadMarkdownColor(prefs, 'color_md_h1');
    _markdownH2Color = _loadMarkdownColor(prefs, 'color_md_h2');
    _markdownH3Color = _loadMarkdownColor(prefs, 'color_md_h3');
    _markdownLinkColor = _loadMarkdownColor(prefs, 'color_md_link');
    _markdownInlineCodeColor = _loadMarkdownColor(
      prefs,
      'color_md_inline_code',
    );
    _markdownCodeBlockColor = _loadMarkdownColor(prefs, 'color_md_code_block');
    _markdownBlockquoteColor = _loadMarkdownColor(
      prefs,
      'color_md_blockquote',
    );
    _markdownListColor = _loadMarkdownColor(prefs, 'color_md_list');
    _markdownStrikeColor = _loadMarkdownColor(prefs, 'color_md_strike');

    notifyListeners();
  }

  Color? _loadMarkdownColor(SharedPreferences prefs, String key) {
    final value = prefs.getInt(key);
    return value == null ? null : Color(value);
  }

  Future<void> setFont(String fontName) async {
    _fontStyle = fontName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font_style', fontName);
  }

  /// Exports theme colors and typography as a serializable map.
  Map<String, dynamic> exportSettingsMap() {
    return {
      'fontStyle': _fontStyle,
      'lightMode': _isLightMode,
      'colors': {
        'appTheme': _colorToStorageInt(_appThemeColor),
        'userBubble': _colorToStorageInt(_userBubbleColor),
        'userText': _colorToStorageInt(_userTextColor),
        'aiBubble': _colorToStorageInt(_aiBubbleColor),
        'aiText': _colorToStorageInt(_aiTextColor),
        'markdownParagraph': _markdownParagraphColor?.toARGB32(),
        'markdownItalic': _markdownItalicColor?.toARGB32(),
        'markdownBold': _markdownBoldColor?.toARGB32(),
        'markdownBoldItalic': _markdownBoldItalicColor?.toARGB32(),
        'markdownH1': _markdownH1Color?.toARGB32(),
        'markdownH2': _markdownH2Color?.toARGB32(),
        'markdownH3': _markdownH3Color?.toARGB32(),
        'markdownLink': _markdownLinkColor?.toARGB32(),
        'markdownInlineCode': _markdownInlineCodeColor?.toARGB32(),
        'markdownCodeBlock': _markdownCodeBlockColor?.toARGB32(),
        'markdownBlockquote': _markdownBlockquoteColor?.toARGB32(),
        'markdownList': _markdownListColor?.toARGB32(),
        'markdownStrike': _markdownStrikeColor?.toARGB32(),
      },
    };
  }

  /// Applies theme settings from a previously exported map and persists them.
  Future<void> importSettingsMap(Map<String, dynamic> data) async {
    _fontStyle = data['fontStyle'] as String? ?? _fontStyle;
    _isLightMode = data['lightMode'] as bool? ?? _isLightMode;

    final colors = data['colors'] as Map<String, dynamic>? ?? {};
    if (colors['appTheme'] != null) {
      _appThemeColor = Color(colors['appTheme'] as int);
    }
    if (colors['userBubble'] != null) {
      _userBubbleColor = Color(colors['userBubble'] as int);
    }
    if (colors['userText'] != null) {
      _userTextColor = Color(colors['userText'] as int);
    }
    if (colors['aiBubble'] != null) {
      _aiBubbleColor = Color(colors['aiBubble'] as int);
    }
    if (colors['aiText'] != null) {
      _aiTextColor = Color(colors['aiText'] as int);
    }
    _markdownParagraphColor = _colorFromExportedMap(colors['markdownParagraph']);
    _markdownItalicColor = _colorFromExportedMap(colors['markdownItalic']);
    _markdownBoldColor = _colorFromExportedMap(colors['markdownBold']);
    _markdownBoldItalicColor = _colorFromExportedMap(
      colors['markdownBoldItalic'],
    );
    _markdownH1Color = _colorFromExportedMap(colors['markdownH1']);
    _markdownH2Color = _colorFromExportedMap(colors['markdownH2']);
    _markdownH3Color = _colorFromExportedMap(colors['markdownH3']);
    _markdownLinkColor = _colorFromExportedMap(colors['markdownLink']);
    _markdownInlineCodeColor = _colorFromExportedMap(
      colors['markdownInlineCode'],
    );
    _markdownCodeBlockColor = _colorFromExportedMap(colors['markdownCodeBlock']);
    _markdownBlockquoteColor = _colorFromExportedMap(
      colors['markdownBlockquote'],
    );
    _markdownListColor = _colorFromExportedMap(colors['markdownList']);
    _markdownStrikeColor = _colorFromExportedMap(colors['markdownStrike']);

    notifyListeners();

    // Persist all imported values
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font_style', _fontStyle);
    await prefs.setBool('app_light_mode', _isLightMode);
    await _saveColors();
  }

  Color? _colorFromExportedMap(dynamic raw) {
    if (raw is int) return Color(raw);
    return null;
  }
}
