import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/file_io_helper.dart';
import '../utils/constants.dart';

/// Provider for managing performance-intensive visual effects and atmospheric settings.
///
/// This includes background images, bloom (glow) toggles, and animated
/// environmental effects like motes, rain, and fireflies.
class VfxProvider extends ChangeNotifier {
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.7;
  bool _enableBloom = false;
  bool _enableLoadingAnimation = true;
  bool _enableMotes = false;
  bool _enableRain = false;
  bool _enableFireflies = false;

  int _motesDensity = 75;
  int _rainIntensity = 100;
  int _firefliesCount = 50;

  List<String> _customImagePaths = [];

  String? get backgroundImagePath => _backgroundImagePath;
  double get backgroundOpacity => _backgroundOpacity;
  bool get enableBloom => _enableBloom;
  bool get enableLoadingAnimation => _enableLoadingAnimation;
  bool get enableMotes => _enableMotes;
  bool get enableRain => _enableRain;
  bool get enableFireflies => _enableFireflies;
  List<String> get customImagePaths => _customImagePaths;

  int get motesDensity => _motesDensity;
  int get rainIntensity => _rainIntensity;
  int get firefliesCount => _firefliesCount;

  VfxProvider() {
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
      return FileIOHelper.imageProviderFromPath(_backgroundImagePath!) ??
          const AssetImage(kDefaultBackground);
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

  /// Toggles the loading animation (spinning indicators) effect.
  Future<void> toggleLoadingAnimation(bool value) async {
    _enableLoadingAnimation = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_loading_animation', value);
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
    _backgroundImagePath = prefs.getString('app_bg_path');
    _backgroundOpacity =
        prefs.getDouble('app_bg_opacity') ?? AppDefaults.backgroundOpacity;
    _enableBloom = prefs.getBool('app_enable_bloom') ?? false;
    _enableLoadingAnimation =
        prefs.getBool('app_enable_loading_animation') ?? true;
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

    notifyListeners();
  }

  /// Resets all VFX settings to their default values.
  Future<void> resetToDefaults() async {
    _enableBloom = false;
    _enableLoadingAnimation = true;
    _enableMotes = false;
    _enableRain = false;
    _enableFireflies = false;
    _backgroundOpacity = AppDefaults.backgroundOpacity;
    _motesDensity = AppDefaults.motesDensity;
    _rainIntensity = AppDefaults.rainIntensity;
    _firefliesCount = AppDefaults.firefliesCount;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enable_bloom', false);
    await prefs.setBool('app_enable_loading_animation', true);
    await prefs.setBool('app_enable_motes', false);
    await prefs.setBool('app_enable_rain', false);
    await prefs.setBool('app_enable_fireflies', false);
    await prefs.setDouble('app_bg_opacity', AppDefaults.backgroundOpacity);
    await prefs.setInt('vfx_motes_density', AppDefaults.motesDensity);
    await prefs.setInt('vfx_rain_intensity', AppDefaults.rainIntensity);
    await prefs.setInt('vfx_fireflies_count', AppDefaults.firefliesCount);
  }

  Map<String, dynamic> exportSettingsMap() {
    return {
      'backgroundPath': _backgroundImagePath,
      'backgroundOpacity': _backgroundOpacity,
      'bloom': _enableBloom,
      'loadingAnimation': _enableLoadingAnimation,
      'motes': _enableMotes,
      'rain': _enableRain,
      'fireflies': _enableFireflies,
      'motesDensity': _motesDensity,
      'rainIntensity': _rainIntensity,
      'firefliesCount': _firefliesCount,
    };
  }

  Future<void> importSettingsMap(Map<String, dynamic> data) async {
    _backgroundImagePath = data['backgroundPath'] as String?;
    _backgroundOpacity =
        (data['backgroundOpacity'] as num?)?.toDouble() ?? _backgroundOpacity;
    _enableBloom = data['bloom'] as bool? ?? _enableBloom;
    _enableLoadingAnimation =
        data['loadingAnimation'] as bool? ?? _enableLoadingAnimation;
    _enableMotes = data['motes'] as bool? ?? _enableMotes;
    _enableRain = data['rain'] as bool? ?? _enableRain;
    _enableFireflies = data['fireflies'] as bool? ?? _enableFireflies;
    _motesDensity = (data['motesDensity'] as num?)?.toInt() ?? _motesDensity;
    _rainIntensity = (data['rainIntensity'] as num?)?.toInt() ?? _rainIntensity;
    _firefliesCount =
        (data['firefliesCount'] as num?)?.toInt() ?? _firefliesCount;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (_backgroundImagePath != null) {
      await prefs.setString('app_bg_path', _backgroundImagePath!);
    } else {
      await prefs.remove('app_bg_path');
    }
    await prefs.setDouble('app_bg_opacity', _backgroundOpacity);
    await prefs.setBool('app_enable_bloom', _enableBloom);
    await prefs.setBool(
      'app_enable_loading_animation',
      _enableLoadingAnimation,
    );
    await prefs.setBool('app_enable_motes', _enableMotes);
    await prefs.setBool('app_enable_rain', _enableRain);
    await prefs.setBool('app_enable_fireflies', _enableFireflies);
    await prefs.setInt('vfx_motes_density', _motesDensity);
    await prefs.setInt('vfx_rain_intensity', _rainIntensity);
    await prefs.setInt('vfx_fireflies_count', _firefliesCount);
  }
}
