import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/scale_provider.dart';
import '../../providers/theme_provider.dart';
import 'settings_slider.dart';

/// A panel for customizing the application's atmosphere and background.
class VisualSettingsPanel extends StatelessWidget {
  const VisualSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visuals & Atmosphere',
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize + 10,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        const Divider(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Light Mode',
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                  shadows: themeProvider.enableBloom
                      ? [
                          Shadow(
                            color: themeProvider.bloomGlowColor,
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
            Switch(
              value: themeProvider.isLightMode,
              activeThumbColor: themeProvider.textColor,
              onChanged: (value) => themeProvider.toggleLightMode(value),
            ),
          ],
        ),
        const Divider(height: 10),
        Text(
          'Background Opacity',
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                'Dimmer:',
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize * 0.8,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Text(
                '${(themeProvider.backgroundOpacity * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                  fontSize: scaleProvider.systemFontSize * 0.8,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: themeProvider.backgroundOpacity,
          min: 0.0,
          max: 1.0,
          activeColor: themeProvider.textColor,
          inactiveColor: Colors.grey[800],
          onChanged: (value) => themeProvider.setBackgroundOpacity(value),
        ),
        const Divider(),
        Text(
          'Environmental Effects',
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            shadows: themeProvider.enableBloom
                ? [
                    Shadow(
                      color: themeProvider.bloomGlowColor.withValues(alpha: 0.9),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Floating Dust Motes',
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: themeProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withValues(alpha: 0.9),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
          ),
          subtitle: Text(
            'Subtle, glowing particles',
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize - 2,
              color: Colors.grey,
            ),
          ),
          value: themeProvider.enableMotes,
          activeThumbColor: themeProvider.textColor,
          onChanged: (value) => themeProvider.toggleMotes(value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Gentle Rain',
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: themeProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withValues(alpha: 0.9),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
          ),
          subtitle: Text(
            'A calming, rainy mood',
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize - 2,
              color: Colors.grey,
            ),
          ),
          value: themeProvider.enableRain,
          activeThumbColor: themeProvider.textColor,
          onChanged: (value) => themeProvider.toggleRain(value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Glowing Fireflies',
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: themeProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withValues(alpha: 0.9),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
          ),
          subtitle: Text(
            'Blinking lights for a cozy vibe',
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize - 2,
              color: Colors.grey,
            ),
          ),
          value: themeProvider.enableFireflies,
          activeThumbColor: themeProvider.textColor,
          onChanged: (value) => themeProvider.toggleFireflies(value),
        ),
        const Divider(),
        if (themeProvider.enableMotes)
          SettingsSlider(
            title: 'Motes Density',
            value: themeProvider.motesDensity.toDouble(),
            min: 1,
            max: 150,
            isInt: true,
            activeColor: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize * 0.8,
            onChanged: (value) => themeProvider.setMotesDensity(value.toInt()),
          ),
        if (themeProvider.enableRain)
          SettingsSlider(
            title: 'Rainfall Intensity',
            value: themeProvider.rainIntensity.toDouble(),
            min: 1,
            max: 200,
            isInt: true,
            activeColor: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize * 0.8,
            onChanged: (value) => themeProvider.setRainIntensity(value.toInt()),
          ),
        if (themeProvider.enableFireflies)
          SettingsSlider(
            title: 'Fireflies Count',
            value: themeProvider.firefliesCount.toDouble(),
            min: 1,
            max: 100,
            isInt: true,
            activeColor: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize * 0.8,
            onChanged: (value) => themeProvider.setFirefliesCount(value.toInt()),
          ),
      ],
    );
  }
}