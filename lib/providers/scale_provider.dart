import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Defines the category of device for responsive scaling.
enum DeviceType { phone, tablet, desktop }

/// Provider for managing UI scaling, font sizes, and layout dimensions.
///
/// This class provides responsive presets for different device types
/// and allows fine-grained control over individual scaling parameters.
class ScaleProvider extends ChangeNotifier {
  DeviceType _deviceType = DeviceType.phone;
  double _chatFontSize = 14.0;
  double _systemFontSize = 12.0;
  double _drawerWidth = 300.0;
  double _iconScale = 1.0;
  double _inputAreaScale = 1.0;
  bool _shouldGlow = false;
  bool _isFirstRun = true;

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

    if (prefs.containsKey('scale_device_type')) {
      _isFirstRun = false;

      final deviceTypeIndex = prefs.getInt('scale_device_type') ?? 0;
      _deviceType = DeviceType.values[deviceTypeIndex];

      _chatFontSize = prefs.getDouble('scale_chat_font_size') ?? 14.0;
      _systemFontSize = prefs.getDouble('scale_system_font_size') ?? 12.0;
      _drawerWidth = prefs.getDouble('scale_drawer_width') ?? 300.0;
      _iconScale = prefs.getDouble('scale_icon_scale') ?? 1.0;
      _inputAreaScale = prefs.getDouble('scale_input_area_scale') ?? 1.0;

      _shouldGlow = !(prefs.getBool('scale_settings_seen') ?? false);
    } else {
      _isFirstRun = true;
      _shouldGlow = true;
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
    _isFirstRun = false;
    notifyListeners();
  }

  Future<void> setDeviceType(DeviceType type) async {
    _deviceType = type;

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
        _systemFontSize = 14.0;
        _drawerWidth = 450.0;
        _iconScale = 1.2;
        _inputAreaScale = 7;
        break;
      case DeviceType.desktop:
        _chatFontSize = 21.0;
        _systemFontSize = 18.0;
        _drawerWidth = 600.0;
        _iconScale = 2.0;
        _inputAreaScale = 10;
        break;
    }

    notifyListeners();
    await _saveAll();
  }

  /// Sets the font size for chat messages and persists the change.
  Future<void> setChatFontSize(double value) async {
    _chatFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scale_chat_font_size', value);
  }

  /// Sets the font size for system UI elements and persists the change.
  Future<void> setSystemFontSize(double value) async {
    _systemFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scale_system_font_size', value);
  }

  /// Sets the width of side drawers and persists the change.
  Future<void> setDrawerWidth(double value) async {
    _drawerWidth = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scale_drawer_width', value);
  }

  /// Sets the scaling factor for icons and persists the change.
  Future<void> setIconScale(double value) async {
    _iconScale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scale_icon_scale', value);
  }

  /// Sets the scaling factor for the input area and persists the change.
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

  /// Exports all scale settings as a serializable map.
  Map<String, dynamic> exportSettingsMap() {
    return {
      'deviceType': _deviceType.index,
      'chatFontSize': _chatFontSize,
      'systemFontSize': _systemFontSize,
      'drawerWidth': _drawerWidth,
      'iconScale': _iconScale,
      'inputAreaScale': _inputAreaScale,
    };
  }

  /// Applies scale settings from a previously exported map and persists them.
  Future<void> importSettingsMap(Map<String, dynamic> data) async {
    final deviceIndex = data['deviceType'] as int?;
    if (deviceIndex != null &&
        deviceIndex >= 0 &&
        deviceIndex < DeviceType.values.length) {
      _deviceType = DeviceType.values[deviceIndex];
    }
    _chatFontSize =
        (data['chatFontSize'] as num?)?.toDouble() ?? _chatFontSize;
    _systemFontSize =
        (data['systemFontSize'] as num?)?.toDouble() ?? _systemFontSize;
    _drawerWidth =
        (data['drawerWidth'] as num?)?.toDouble() ?? _drawerWidth;
    _iconScale =
        (data['iconScale'] as num?)?.toDouble() ?? _iconScale;
    _inputAreaScale =
        (data['inputAreaScale'] as num?)?.toDouble() ?? _inputAreaScale;

    _isFirstRun = false;
    notifyListeners();
    await _saveAll();
  }
}
