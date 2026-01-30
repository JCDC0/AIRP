import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../utils/constants.dart'; 

// ----------------------------------------------------------------------
// THEME PROVIDER
// ----------------------------------------------------------------------
class ThemeProvider extends ChangeNotifier {
  String _fontStyle = 'Default';
  String? _backgroundImagePath; 
  double _backgroundOpacity = 0.7;

// VFX toggles
  bool _enableBloom = false;
  bool _enableMotes = false;
  bool _enableRain = false;
  bool _enableFireflies = false;

// VFX INTENSITY
  int _motesDensity = 75;
  int _rainIntensity = 100;
  int _firefliesCount = 50;

// Color settings
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
  
    // INTENSITY GETTERS
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

  ImageProvider get currentImageProvider {
    if (_backgroundImagePath == null) return const AssetImage(kDefaultBackground);
    if (_backgroundImagePath!.startsWith('assets/')) {
      return AssetImage(_backgroundImagePath!);
    } else {
      return FileImage(File(_backgroundImagePath!));
    }
  }

  TextTheme get currentTextTheme {
    const baseColor = Colors.white;
    final baseTheme = ThemeData.dark().textTheme.apply(bodyColor: baseColor, displayColor: baseColor);
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

  // --- Background Logic ---
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

    Future<void> setBackgroundOpacity(double value) async {
    _backgroundOpacity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_bg_opacity', value);
  }

  Future<void> toggleBloom(bool value) async {
    _enableBloom = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_bloom', value);
  }

  Future<void> toggleMotes(bool value) async {
    _enableMotes = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_motes', value);
  }

  Future<void> toggleRain(bool value) async {
    _enableRain = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_rain', value);
  }

  Future<void> toggleFireflies(bool value) async {
    _enableFireflies = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_fireflies', value);
  }

    // INTENSITY SETTERS
  Future<void> setMotesDensity(int value) async {
    _motesDensity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vfx_motes_density', value);
  }
  Future<void> setRainIntensity(int value) async {
    _rainIntensity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vfx_rain_intensity', value);
  }
  Future<void> setFirefliesCount(int value) async {
    _firefliesCount = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vfx_fireflies_count', value);
  }



  Future<void> updateColor(String type, Color color) async {
    switch (type) {
      case 'userBubble': _userBubbleColor = color; break;
      case 'userText': _userTextColor = color; break;
      case 'aiBubble': _aiBubbleColor = color; break;
      case 'aiText': _aiTextColor = color; break;
      case 'appTheme': _appThemeColor = color; break;
    }
    notifyListeners();
    _saveColors();
  }

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
    _backgroundOpacity = 0.7;
    _motesDensity = 75;
    _rainIntensity = 100;
    _firefliesCount = 50;
    
    notifyListeners();
    _saveColors();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_bloom', false);
    await prefs.setBool('app_enable_motes', false);
    await prefs.setBool('app_enable_rain', false);
        await prefs.setBool('app_enable_fireflies', false);
    await prefs.setDouble('app_bg_opacity', 0.7);
        await prefs.setInt('vfx_motes_density', 75);
    await prefs.setInt('vfx_rain_intensity', 100);
    await prefs.setInt('vfx_fireflies_count', 50);
  }

  Future<void> _saveColors() async {
    final prefs = await SharedPreferences.getInstance();
    
    final int themeVal = (((_appThemeColor.a * 255.0).round() & 0xff) << 24) |
      (((_appThemeColor.r * 255.0).round() & 0xff) << 16) |
      (((_appThemeColor.g * 255.0).round() & 0xff) << 8) |
      ((_appThemeColor.b * 255.0).round() & 0xff);
    await prefs.setInt('color_app_theme', themeVal);

    final int ub = (((_userBubbleColor.a * 255.0).round() & 0xff) << 24) |
      (((_userBubbleColor.r * 255.0).round() & 0xff) << 16) |
      (((_userBubbleColor.g * 255.0).round() & 0xff) << 8) |
      ((_userBubbleColor.b * 255.0).round() & 0xff);
    await prefs.setInt('color_user_bubble', ub);

    final int ut = (((_userTextColor.a * 255.0).round() & 0xff) << 24) |
      (((_userTextColor.r * 255.0).round() & 0xff) << 16) |
      (((_userTextColor.g * 255.0).round() & 0xff) << 8) |
      ((_userTextColor.b * 255.0).round() & 0xff);
    await prefs.setInt('color_user_text', ut);

    final int ab = (((_aiBubbleColor.a * 255.0).round() & 0xff) << 24) |
      (((_aiBubbleColor.r * 255.0).round() & 0xff) << 16) |
      (((_aiBubbleColor.g * 255.0).round() & 0xff) << 8) |
      ((_aiBubbleColor.b * 255.0).round() & 0xff);
    await prefs.setInt('color_ai_bubble', ab);

    final int at = (((_aiTextColor.a * 255.0).round() & 0xff) << 24) |
      (((_aiTextColor.r * 255.0).round() & 0xff) << 16) |
      (((_aiTextColor.g * 255.0).round() & 0xff) << 8) |
      ((_aiTextColor.b * 255.0).round() & 0xff);
    await prefs.setInt('color_ai_text', at);
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
    _backgroundOpacity = prefs.getDouble('app_bg_opacity') ?? 0.7;
    _enableBloom = prefs.getBool('app_enable_bloom') ?? false;
    _enableMotes = prefs.getBool('app_enable_motes') ?? false;
    _enableRain = prefs.getBool('app_enable_rain') ?? false;
        _enableFireflies = prefs.getBool('app_enable_fireflies') ?? false;
    _customImagePaths = prefs.getStringList('app_custom_bg_list') ?? [];
    
    // LOAD INTENSITIES
    _motesDensity = prefs.getInt('vfx_motes_density') ?? 75;
    _rainIntensity = prefs.getInt('vfx_rain_intensity') ?? 100;
    _firefliesCount = prefs.getInt('vfx_fireflies_count') ?? 50;

    final int? themeInt = prefs.getInt('color_app_theme');
    _appThemeColor = themeInt != null ? Color(themeInt) : AppColors.defaultAppTheme;

    final int? userBubbleInt = prefs.getInt('color_user_bubble');
    _userBubbleColor = userBubbleInt != null ? Color(userBubbleInt) : AppColors.defaultUserBubble;

    final int? userTextInt = prefs.getInt('color_user_text');
    _userTextColor = userTextInt != null ? Color(userTextInt) : AppColors.defaultUserText;

    final int? aiBubbleInt = prefs.getInt('color_ai_bubble');
    _aiBubbleColor = aiBubbleInt != null ? Color(aiBubbleInt) : AppColors.defaultAiBubble;

    final int? aiTextInt = prefs.getInt('color_ai_text');
    _aiTextColor = aiTextInt != null ? Color(aiTextInt) : AppColors.defaultAiText;
    
    notifyListeners();
  }

  Future<void> setFont(String fontName) async {
    _fontStyle = fontName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font_style', fontName);
  }
}