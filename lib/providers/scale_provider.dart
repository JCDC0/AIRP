import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceType { phone, tablet, desktop }

class ScaleProvider extends ChangeNotifier {
  // State Variables
  DeviceType _deviceType = DeviceType.phone;
  double _chatFontSize = 14.0;
  double _systemFontSize = 12.0;
  double _drawerWidth = 300.0;
  double _iconScale = 1.0;
  double _inputAreaScale = 1.0;
  bool _shouldGlow = false;
  bool _isFirstRun = true;

  // Getters
  DeviceType get deviceType => _deviceType;
  double get chatFontSize => _chatFontSize;
  double get systemFontSize => _systemFontSize;
  double get drawerWidth => _drawerWidth;
  double get iconScale => _iconScale;
  double get inputAreaScale => _inputAreaScale;
  bool get shouldGlow => _shouldGlow;
  bool get isFirstRun => _isFirstRun;

  ScaleProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if this is the first run ever for scaling settings
    if (prefs.containsKey('scale_device_type')) {
      _isFirstRun = false;
      
      // Load saved values
      final deviceTypeIndex = prefs.getInt('scale_device_type') ?? 0;
      _deviceType = DeviceType.values[deviceTypeIndex];
      
      _chatFontSize = prefs.getDouble('scale_chat_font_size') ?? 14.0;
      _systemFontSize = prefs.getDouble('scale_system_font_size') ?? 12.0;
      _drawerWidth = prefs.getDouble('scale_drawer_width') ?? 300.0;
      _iconScale = prefs.getDouble('scale_icon_scale') ?? 1.0;
      _inputAreaScale = prefs.getDouble('scale_input_area_scale') ?? 1.0;
      
      // Check if user has seen the settings
      _shouldGlow = !(prefs.getBool('scale_settings_seen') ?? false);
    } else {
      // First run logic will be triggered via initializeDeviceType
      _isFirstRun = true;
      _shouldGlow = true; // Enable glow for first run
    }
    
    notifyListeners();
  }

  Future<void> initializeDeviceType(BuildContext context) async {
    if (!_isFirstRun) return;

    final width = MediaQuery.of(context).size.width;
    DeviceType detectedType;

    if (width >= 1100) {
      detectedType = DeviceType.desktop;
    } else if (width >= 600) {
      detectedType = DeviceType.tablet;
    } else {
      detectedType = DeviceType.phone;
    }

    await setDeviceType(detectedType);
    _isFirstRun = false; // Prevent re-initialization
    notifyListeners();
  }

  Future<void> setDeviceType(DeviceType type) async {
    _deviceType = type;
    
    // Apply Presets
    switch (type) {
      case DeviceType.phone:
        _chatFontSize = 14.0;
        _systemFontSize = 12.0;
        _drawerWidth = 300.0;
        _iconScale = 1.0;
        _inputAreaScale = 4;
        break;
      case DeviceType.tablet:
        _chatFontSize = 16.0;
        _systemFontSize = 17.0;
        _drawerWidth = 450.0;
        _iconScale = 1.2;
        _inputAreaScale = 7;
        break;
      case DeviceType.desktop:
        _chatFontSize = 21.0;
        _systemFontSize = 20.0;
        _drawerWidth = 600.0;
        _iconScale = 2.0;
        _inputAreaScale = 10;
        break;
    }

    notifyListeners();
    await _saveAll();
  }

  // Individual Setters
  Future<void> setChatFontSize(double value) async {
    _chatFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scale_chat_font_size', value);
  }

  Future<void> setSystemFontSize(double value) async {
    _systemFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scale_system_font_size', value);
  }

  Future<void> setDrawerWidth(double value) async {
    _drawerWidth = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scale_drawer_width', value);
  }

  Future<void> setIconScale(double value) async {
    _iconScale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scale_icon_scale', value);
  }

  Future<void> setInputAreaScale(double value) async {
    _inputAreaScale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scale_input_area_scale', value);
  }

  Future<void> markSettingsAsSeen() async {
    if (!_shouldGlow) return;
    
    _shouldGlow = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scale_settings_seen', true);
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scale_device_type', _deviceType.index);
    await prefs.setDouble('scale_chat_font_size', _chatFontSize);
    await prefs.setDouble('scale_system_font_size', _systemFontSize);
    await prefs.setDouble('scale_drawer_width', _drawerWidth);
    await prefs.setDouble('scale_icon_scale', _iconScale);
    await prefs.setDouble('scale_input_area_scale', _inputAreaScale);
  }
}
