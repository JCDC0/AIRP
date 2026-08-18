import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_fonts.dart';
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
  /// Roleplay prose is narration, `"dialogue"` and `*actions*`, so only three
  /// markdown elements are worth tinting separately. Headings, lists,
  /// blockquotes, links, strikethrough and code still render; they follow the
  /// bubble's text colour instead of carrying their own picker. See
  /// `docs/agents/ARCHITECTURE.md`.
  Color? _markdownParagraphColor;
  Color? _markdownItalicColor;
  Color? _markdownBoldColor;

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

  /// Colour for headings, list bullets and strikethrough. Not user-tintable;
  /// it tracks the bubble's text colour so structured output (the Summarize
  /// drawer emits headings and bullets) stays legible under any theme.
  Color get markdownStructureColor => textColor;

  /// Colour for blockquotes, which read as an aside rather than prose.
  Color get markdownBlockquoteColor => subtitleColor;

  /// Colour for links. Web search answers are full of them, so they keep a
  /// distinct hue rather than blending into the paragraph.
  Color get markdownLinkColor => Colors.blueAccent;

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
    return AppFonts.textTheme(_fontStyle, baseTheme);
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
  ///
  /// Unknown types are ignored rather than throwing, so a config pack written
  /// by a build that still had the retired pickers applies cleanly.
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
      default:
        return;
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
