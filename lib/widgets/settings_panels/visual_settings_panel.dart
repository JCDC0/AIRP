import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../providers/scale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/file_io_helper.dart';
import '../../utils/constants.dart';
import 'settings_slider.dart';

/// A panel for customizing the application's atmosphere and background.
///
/// This panel provides controls for background image selection, bloom effects,
/// and environmental VFX (motes, rain, fireflies).
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

        // ── Light Mode Toggle ──────────────────────────────────────
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

        // ── Visual Effects ─────────────────────────────────────────
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Enable Bloom (Glow)",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: themeProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withValues(
                          alpha: 0.9,
                        ),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
          ),
          subtitle: Text(
            "Adds a dreamy glow effect",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize - 2,
              color: Colors.grey,
            ),
          ),
          value: themeProvider.enableBloom,
          activeThumbColor: themeProvider.textColor,
          onChanged: (val) => themeProvider.toggleBloom(val),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Loading Animation",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              shadows: themeProvider.enableBloom
                  ? [
                      Shadow(
                        color: themeProvider.bloomGlowColor.withValues(
                          alpha: 0.9,
                        ),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
          ),
          subtitle: Text(
            "Spinning indicators on icons and input area",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize - 2,
              color: Colors.grey,
            ),
          ),
          value: themeProvider.enableLoadingAnimation,
          activeThumbColor: themeProvider.textColor,
          onChanged: (val) => themeProvider.toggleLoadingAnimation(val),
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

        const Divider(),
        // ── Background Selection Gallery ───────────────────────────
        Text(
          'Chat Backgrounds',
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        const SizedBox(height: 10),
        if (themeProvider.backgroundImagePath != null &&
            themeProvider.backgroundImagePath != kDefaultBackground) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  themeProvider.setBackgroundImage(null);
                  Provider.of<ChatProvider>(
                    context,
                    listen: false,
                  ).autoSaveCurrentSession(clearBackground: true);
                },
                child: const Text(
                  "RESET TO DEFAULT",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: themeProvider.containerFillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeProvider.borderColor),
          ),
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount:
                1 +
                themeProvider.customImagePaths.length +
                kAssetBackgrounds.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) themeProvider.addCustomImage(image.path);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: themeProvider.textColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: themeProvider.textColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          color: themeProvider.textColor,
                        ),
                        Text(
                          "Add",
                          style: TextStyle(
                            fontSize: scaleProvider.systemFontSize * 0.7,
                            color: themeProvider.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final int adjustedIndex = index - 1;
              final int customCount = themeProvider.customImagePaths.length;
              String path;
              bool isCustom;

              if (adjustedIndex < customCount) {
                path = themeProvider.customImagePaths[adjustedIndex];
                isCustom = true;
              } else {
                path = kAssetBackgrounds[adjustedIndex - customCount];
                isCustom = false;
              }

              final bool isSelected = themeProvider.backgroundImagePath == path;

              return InkWell(
                onTap: () {
                  themeProvider.setBackgroundImage(path);
                  Provider.of<ChatProvider>(
                    context,
                    listen: false,
                  ).autoSaveCurrentSession(backgroundImagePath: path);
                },
                onLongPress:
                    isCustom
                        ? () {
                          HapticFeedback.mediumImpact();
                          themeProvider.removeCustomImage(path);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Image Deleted"),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(milliseconds: 500),
                            ),
                          );
                        }
                        : null,
                splashColor: Colors.redAccent.withValues(alpha: 0.8),
                highlightColor: Colors.redAccent.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          isCustom
                              ? FileIOHelper.imageWidgetFromPath(
                                path,
                                fit: BoxFit.cover,
                              )
                              : Image.asset(path, fit: BoxFit.cover),
                    ),
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: themeProvider.textColor,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            color: themeProvider.textColor,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 15),
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

        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              "Reset to Defaults",
              style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      backgroundColor: themeProvider.surfaceColor,
                      title: Text(
                        "Reset Theme?",
                        style: TextStyle(color: themeProvider.textColor),
                      ),
                      content: Text(
                        "This will revert all colors and visual settings.",
                        style: TextStyle(color: themeProvider.subtitleColor),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.greenAccent,
                          ),
                          onPressed: () {
                            themeProvider.resetToDefaults();
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
              );
            },
          ),
        ),
      ],
    );
  }
}
