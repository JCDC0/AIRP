import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../utils/constants.dart';

/// Provider for managing the application's visual theme and special effects.
///
/// This class handles font styles, background images, colors, and
/// visual effects like bloom, motes, and rain.
class ThemeProvider extends ChangeNotifier {
  String _fontStyle = 'Default';
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.7;

  bool _enableBloom = false;
  bool _enableMotes = false;
  bool _enableRain = false;
  bool _enableFireflies = false;

  int _motesDensity = 75;
  int _rainIntensity = 100;
  int _firefliesCount = 50;

  Color _userBubbleColor = AppColors.defaultUserBubble;
  Color _userTextColor = AppColors.defaultUserText;
  Color _aiBubbleColor = AppColors.defaultAiBubble;
  Color _aiTextColor = AppColors.defaultAiText;
  Color _appThemeColor = AppColors.defaultAppTheme;

  List<String> _customImagePaths = [];

  String get fontStyle => _fontStyle;
  String? get backgroundImagePath => _backgroundImagePath;
  double get backgroundOpacity => _backgroundOpacity;
  bool get enableBloom => _enableBloom;
  bool get enableMotes => _enableMotes;
  bool get enableRain => _enableRain;
  bool get enableFireflies => _enableFireflies;
  List<String> get customImagePaths => _customImagePaths;

  int get motesDensity => _motesDensity;
  int get rainIntensity => _rainIntensity;
  int get firefliesCount => _firefliesCount;

  Color get userBubbleColor => _userBubbleColor;
  Color get userTextColor => _userTextColor;
  Color get aiBubbleColor => _aiBubbleColor;
  Color get aiTextColor => _aiTextColor;
  Color get appThemeColor => _appThemeColor;

  ThemeProvider() {
    _loadPreferences();
  }

  /// Returns the [ImageProvider] for the current background image.
  ImageProvider get currentImageProvider {
    if (_backgroundImagePath == null) {
      return const AssetImage(kDefaultBackground);
    }
    if (_backgroundImagePath!.startsWith('assets/')) {
      return AssetImage(_backgroundImagePath!);
    } else {
      return FileImage(File(_backgroundImagePath!));
    }
  }

  /// Generates the [TextTheme] based on the selected font style.
  TextTheme get currentTextTheme {
    const baseColor = Colors.white;
    final baseTheme = ThemeData.dark().textTheme.apply(
      bodyColor: baseColor,
      displayColor: baseColor,
    );
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

  /// Sets the background image path and persists the change.
  Future<void> setBackgroundImage(String? path) async {
    _backgroundImagePath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('app_bg_path', path);
    } else {
      await prefs.remove('app_bg_path');
    }
  }

  /// Sets the opacity of the background image overlay.
  Future<void> setBackgroundOpacity(double value) async {
    _backgroundOpacity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_bg_opacity', value);
  }

  /// Toggles the bloom (glow) effect.
  Future<void> toggleBloom(bool value) async {
    _enableBloom = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_bloom', value);
  }

  /// Toggles the floating dust motes effect.
  Future<void> toggleMotes(bool value) async {
    _enableMotes = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_motes', value);
  }

  /// Toggles the falling rain effect.
  Future<void> toggleRain(bool value) async {
    _enableRain = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_rain', value);
  }

  /// Toggles the pulsing fireflies effect.
  Future<void> toggleFireflies(bool value) async {
    _enableFireflies = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_fireflies', value);
  }

  /// Sets the density of floating motes.
  Future<void> setMotesDensity(int value) async {
    _motesDensity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vfx_motes_density', value);
  }

  /// Sets the intensity of the rain effect.
  Future<void> setRainIntensity(int value) async {
    _rainIntensity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vfx_rain_intensity', value);
  }

  /// Sets the number of fireflies displayed.
  Future<void> setFirefliesCount(int value) async {
    _firefliesCount = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vfx_fireflies_count', value);
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

  /// Resets all visual settings to their default values.
  Future<void> resetToDefaults() async {
    _userBubbleColor = AppColors.defaultUserBubble;
    _userTextColor = AppColors.defaultUserText;
    _aiBubbleColor = AppColors.defaultAiBubble;
    _aiTextColor = AppColors.defaultAiText;
    _appThemeColor = AppColors.defaultAppTheme;
    _enableBloom = false;
    _enableMotes = false;
    _enableRain = false;
    _enableFireflies = false;
    _backgroundOpacity = AppDefaults.backgroundOpacity;
    _motesDensity = AppDefaults.motesDensity;
    _rainIntensity = AppDefaults.rainIntensity;
    _firefliesCount = AppDefaults.firefliesCount;

    notifyListeners();
    _saveColors();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_bloom', false);
    await prefs.setBool('app_enable_motes', false);
    await prefs.setBool('app_enable_rain', false);
    await prefs.setBool('app_enable_fireflies', false);
    await prefs.setDouble('app_bg_opacity', AppDefaults.backgroundOpacity);
    await prefs.setInt('vfx_motes_density', AppDefaults.motesDensity);
    await prefs.setInt('vfx_rain_intensity', AppDefaults.rainIntensity);
    await prefs.setInt('vfx_fireflies_count', AppDefaults.firefliesCount);
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
  }

  int _colorToStorageInt(Color color) {
    return (((color.a * 255.0).round() & 0xff) << 24) |
        (((color.r * 255.0).round() & 0xff) << 16) |
        (((color.g * 255.0).round() & 0xff) << 8) |
        ((color.b * 255.0).round() & 0xff);
  }

  Future<void> addCustomImage(String path) async {
    if (!_customImagePaths.contains(path)) {
      _customImagePaths.add(path);
      notifyListeners();
      _saveCustomPaths();
    }
    setBackgroundImage(path);
  }

  Future<void> removeCustomImage(String path) async {
    if (_customImagePaths.contains(path)) {
      _customImagePaths.remove(path);
      if (_backgroundImagePath == path) _backgroundImagePath = null;
      notifyListeners();
      _saveCustomPaths();
    }
  }

  Future<void> _saveCustomPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('app_custom_bg_list', _customImagePaths);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _fontStyle = prefs.getString('app_font_style') ?? 'Default';
    _backgroundImagePath = prefs.getString('app_bg_path');
    _backgroundOpacity =
        prefs.getDouble('app_bg_opacity') ?? AppDefaults.backgroundOpacity;
    _enableBloom = prefs.getBool('app_enable_bloom') ?? false;
    _enableMotes = prefs.getBool('app_enable_motes') ?? false;
    _enableRain = prefs.getBool('app_enable_rain') ?? false;
    _enableFireflies = prefs.getBool('app_enable_fireflies') ?? false;
    _customImagePaths = prefs.getStringList('app_custom_bg_list') ?? [];

    _motesDensity =
        prefs.getInt('vfx_motes_density') ?? AppDefaults.motesDensity;
    _rainIntensity =
        prefs.getInt('vfx_rain_intensity') ?? AppDefaults.rainIntensity;
    _firefliesCount =
        prefs.getInt('vfx_fireflies_count') ?? AppDefaults.firefliesCount;

    final int? themeInt = prefs.getInt('color_app_theme');
    _appThemeColor = themeInt != null
        ? Color(themeInt)
        : AppColors.defaultAppTheme;

    final int? userBubbleInt = prefs.getInt('color_user_bubble');
    _userBubbleColor = userBubbleInt != null
        ? Color(userBubbleInt)
        : AppColors.defaultUserBubble;

    final int? userTextInt = prefs.getInt('color_user_text');
    _userTextColor = userTextInt != null
        ? Color(userTextInt)
        : AppColors.defaultUserText;

    final int? aiBubbleInt = prefs.getInt('color_ai_bubble');
    _aiBubbleColor = aiBubbleInt != null
        ? Color(aiBubbleInt)
        : AppColors.defaultAiBubble;

    final int? aiTextInt = prefs.getInt('color_ai_text');
    _aiTextColor = aiTextInt != null
        ? Color(aiTextInt)
        : AppColors.defaultAiText;

    notifyListeners();
  }

  Future<void> setFont(String fontName) async {
    _fontStyle = fontName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font_style', fontName);
  }

  /// Exports all theme settings as a serializable map.
  Map<String, dynamic> exportSettingsMap() {
    return {
      'fontStyle': _fontStyle,
      'backgroundPath': _backgroundImagePath,
      'backgroundOpacity': _backgroundOpacity,
      'bloom': _enableBloom,
      'motes': _enableMotes,
      'rain': _enableRain,
      'fireflies': _enableFireflies,
      'motesDensity': _motesDensity,
      'rainIntensity': _rainIntensity,
      'firefliesCount': _firefliesCount,
      'colors': {
        'appTheme': _colorToStorageInt(_appThemeColor),
        'userBubble': _colorToStorageInt(_userBubbleColor),
        'userText': _colorToStorageInt(_userTextColor),
        'aiBubble': _colorToStorageInt(_aiBubbleColor),
        'aiText': _colorToStorageInt(_aiTextColor),
      },
    };
  }

  /// Applies theme settings from a previously exported map and persists them.
  Future<void> importSettingsMap(Map<String, dynamic> data) async {
    _fontStyle = data['fontStyle'] as String? ?? _fontStyle;
    _backgroundImagePath = data['backgroundPath'] as String?;
    _backgroundOpacity =
        (data['backgroundOpacity'] as num?)?.toDouble() ?? _backgroundOpacity;
    _enableBloom = data['bloom'] as bool? ?? _enableBloom;
    _enableMotes = data['motes'] as bool? ?? _enableMotes;
    _enableRain = data['rain'] as bool? ?? _enableRain;
    _enableFireflies = data['fireflies'] as bool? ?? _enableFireflies;
    _motesDensity = (data['motesDensity'] as num?)?.toInt() ?? _motesDensity;
    _rainIntensity =
        (data['rainIntensity'] as num?)?.toInt() ?? _rainIntensity;
    _firefliesCount =
        (data['firefliesCount'] as num?)?.toInt() ?? _firefliesCount;

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

    notifyListeners();

    // Persist all imported values
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font_style', _fontStyle);
    if (_backgroundImagePath != null) {
      await prefs.setString('app_bg_path', _backgroundImagePath!);
    } else {
      await prefs.remove('app_bg_path');
    }
    await prefs.setDouble('app_bg_opacity', _backgroundOpacity);
    await prefs.setBool('app_enable_bloom', _enableBloom);
    await prefs.setBool('app_enable_motes', _enableMotes);
    await prefs.setBool('app_enable_rain', _enableRain);
    await prefs.setBool('app_enable_fireflies', _enableFireflies);
    await prefs.setInt('vfx_motes_density', _motesDensity);
    await prefs.setInt('vfx_rain_intensity', _rainIntensity);
    await prefs.setInt('vfx_fireflies_count', _firefliesCount);
    await _saveColors();
  }
}
