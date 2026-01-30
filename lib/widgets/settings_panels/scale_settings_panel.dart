import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/scale_provider.dart';
import '../../providers/theme_provider.dart';
import '../settings_slider.dart';

class ScaleSettingsPanel extends StatelessWidget {
  const ScaleSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeColor = themeProvider.appThemeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Device Presets
          Text("Device Presets", style: TextStyle(color: Colors.grey, fontSize: scaleProvider.systemFontSize * 0.8)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPresetButton(context, DeviceType.phone, "Phone", scaleProvider, themeColor),
              const SizedBox(width: 8),
              _buildPresetButton(context, DeviceType.tablet, "Tablet", scaleProvider, themeColor),
              const SizedBox(width: 8),
              _buildPresetButton(context, DeviceType.desktop, "Desktop", scaleProvider, themeColor),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Sliders
          SettingsSlider(
            title: "Chat Font Size",
            value: scaleProvider.chatFontSize,
            min: 10.0,
            max: 30.0,
            activeColor: themeColor,
            onChanged: (val) => scaleProvider.setChatFontSize(val),
            isInt: false,
            fontSize: scaleProvider.systemFontSize,
          ),
          const SizedBox(height: 12),
          
          SettingsSlider(
            title: "System Font Size",
            value: scaleProvider.systemFontSize,
            min: 10.0,
            max: 24.0,
            activeColor: themeColor,
            onChanged: (val) => scaleProvider.setSystemFontSize(val),
            isInt: false,
            fontSize: scaleProvider.systemFontSize,
          ),
          const SizedBox(height: 12),

          SettingsSlider(
            title: "Drawer Width",
            value: scaleProvider.drawerWidth,
            min: 250.0,
            max: 600.0,
            activeColor: themeColor,
            onChanged: (val) => scaleProvider.setDrawerWidth(val),
            isInt: true,
            fontSize: scaleProvider.systemFontSize,
          ),
          const SizedBox(height: 12),

          SettingsSlider(
            title: "Icon Scale",
            value: scaleProvider.iconScale,
            min: 0.8,
            max: 2.0,
            activeColor: themeColor,
            onChanged: (val) => scaleProvider.setIconScale(val),
            isInt: false,
            fontSize: scaleProvider.systemFontSize,
          ),
          const SizedBox(height: 12),

          SettingsSlider(
            title: "Input Area Scale",
            value: scaleProvider.inputAreaScale,
            min: 1.0,
            max: 10.0,
            divisions: 9,
            activeColor: themeColor,
            onChanged: (val) => scaleProvider.setInputAreaScale(val),
            isInt: true,
            fontSize: scaleProvider.systemFontSize,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(
    BuildContext context, 
    DeviceType type, 
    String label, 
    ScaleProvider provider, 
    Color activeColor
  ) {
    final bool isActive = provider.deviceType == type;
    
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? activeColor.withOpacity(0.2) : Colors.black26,
          foregroundColor: isActive ? activeColor : Colors.grey,
          side: BorderSide(
            color: isActive ? activeColor : Colors.transparent,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => provider.setDeviceType(type),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: provider.systemFontSize)),
      ),
    );
  }
}
