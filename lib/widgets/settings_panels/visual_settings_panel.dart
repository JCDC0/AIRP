import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import '../../utils/constants.dart';
import 'settings_color_picker.dart';
import 'settings_slider.dart';

/// A panel for customizing the application's visual style and atmosphere.
///
/// This panel provides controls for font selection, color customization
/// (bubbles, text, theme), bloom effects, and environmental VFX (motes, rain, fireflies).
/// It also includes a background image gallery with support for custom uploads.
class VisualSettingsPanel extends StatelessWidget {
  const VisualSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text(
          "Visuals & Atmosphere",
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize + 10,
            fontWeight: FontWeight.bold,
            color: themeProvider.appThemeColor,
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)]
                : [],
          ),
        ),
        const Divider(height: 10),

        Text(
          "Global Interface Font",
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize,
            fontWeight: FontWeight.bold,
            color: themeProvider.appThemeColor,
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)]
                : [],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: themeProvider.enableBloom
                  ? themeProvider.appThemeColor.withOpacity(0.5)
                  : Colors.white12,
            ),
            boxShadow: themeProvider.enableBloom
                ? [
                    BoxShadow(
                      color: themeProvider.appThemeColor.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: themeProvider.fontStyle,
              dropdownColor: const Color(0xFF2C2C2C),
              icon: Icon(Icons.text_fields, color: themeProvider.appThemeColor),
              items: [
                DropdownMenuItem(
                  value: 'Default',
                  child: Text(
                    "Default (System)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Google',
                  child: Text(
                    "Google Sans (Open Sans)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Apple',
                  child: Text(
                    "Apple SF (Inter)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Claude',
                  child: Text(
                    "Assistant (Source Serif 4)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Roleplay',
                  child: Text(
                    "Storybook (Lora)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Terminal',
                  child: Text(
                    "Hacker (Space Mono)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Manuscript',
                  child: Text(
                    "Ancient Tome (EB Garamond)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Cyber',
                  child: Text(
                    "Neon HUD (Orbitron)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'ModernAnime',
                  child: Text(
                    "Light Novel (Quicksand)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'AnimeSub',
                  child: Text(
                    "Subtitles (Kosugi Maru)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Gothic',
                  child: Text(
                    "Victorian (Crimson Text)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Journal',
                  child: Text(
                    "Handwritten (Caveat)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'CleanThin',
                  child: Text(
                    "Minimalist (Raleway)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Stylized',
                  child: Text(
                    "Vogue (Playfair Display)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Fantasy',
                  child: Text(
                    "MMORPG (Cinzel)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Typewriter',
                  child: Text(
                    "Detective (Special Elite)",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                ),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) themeProvider.setFont(newValue);
              },
            ),
          ),
        ),

        const Divider(),
        Text(
          "Chat Customization",
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize,
            fontWeight: FontWeight.bold,
            color: themeProvider.appThemeColor,
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)]
                : [],
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 15),
            SettingsColorPicker(
              label: "App Theme",
              color: themeProvider.appThemeColor,
              onSave: (c) => themeProvider.updateColor('appTheme', c),
            ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SettingsColorPicker(
                  label: "User BG",
                  color: themeProvider.userBubbleColor,
                  onSave: (c) => themeProvider.updateColor(
                    'userBubble',
                    c.withAlpha(
                      ((themeProvider.userBubbleColor.a * 255.0).round() &
                          0xff),
                    ),
                  ),
                ),
                SettingsColorPicker(
                  label: "User Text",
                  color: themeProvider.userTextColor,
                  onSave: (c) => themeProvider.updateColor('userText', c),
                ),
                SettingsColorPicker(
                  label: "AI BG",
                  color: themeProvider.aiBubbleColor,
                  onSave: (c) => themeProvider.updateColor(
                    'aiBubble',
                    c.withAlpha(
                      ((themeProvider.aiBubbleColor.a * 255.0).round() & 0xff),
                    ),
                  ),
                ),
                SettingsColorPicker(
                  label: "AI Text",
                  color: themeProvider.aiTextColor,
                  onSave: (c) => themeProvider.updateColor('aiText', c),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    "User Opacity:",
                    style: TextStyle(
                      fontSize: scaleProvider.systemFontSize * 0.8,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${(themeProvider.userBubbleColor.a * 100).toInt()}%",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: themeProvider.appThemeColor,
                      fontSize: scaleProvider.systemFontSize * 0.8,
                    ),
                  ),
                ],
              ),
            ),
            Slider(
              value: themeProvider.userBubbleColor.a,
              min: 0.0,
              max: 1.0,
              activeColor: themeProvider.userBubbleColor.withAlpha(255),
              inactiveColor: Colors.grey[800],
              onChanged: (val) {
                themeProvider.updateColor(
                  'userBubble',
                  themeProvider.userBubbleColor.withAlpha((val * 255).round()),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    "AI Opacity:",
                    style: TextStyle(
                      fontSize: scaleProvider.systemFontSize * 0.8,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${(themeProvider.aiBubbleColor.a * 100).toInt()}%",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: themeProvider.appThemeColor,
                      fontSize: scaleProvider.systemFontSize * 0.8,
                    ),
                  ),
                ],
              ),
            ),
            Slider(
              value: themeProvider.aiBubbleColor.a,
              min: 0.0,
              max: 1.0,
              activeColor: themeProvider.aiBubbleColor.withAlpha(255),
              inactiveColor: Colors.grey[800],
              onChanged: (val) {
                themeProvider.updateColor(
                  'aiBubble',
                  themeProvider.aiBubbleColor.withAlpha((val * 255).round()),
                );
              },
            ),

            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(
                  "Reset to Defaults",
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.8,
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF2C2C2C),
                      title: const Text(
                        "Reset Theme?",
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        "This will revert all colors and visual settings.",
                        style: TextStyle(color: Colors.white70),
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
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Enable Bloom (Glow)",
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize,
                  shadows: themeProvider.enableBloom
                      ? [
                          Shadow(
                            color: themeProvider.appThemeColor.withOpacity(0.9),
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
              activeThumbColor: themeProvider.appThemeColor,
              onChanged: (val) => themeProvider.toggleBloom(val),
            ),
            const Divider(),
            Text(
              "Environmental Effects",
              style: TextStyle(
                fontSize: scaleProvider.systemFontSize,
                fontWeight: FontWeight.bold,
                color: themeProvider.appThemeColor.withOpacity(0.8),
                shadows: themeProvider.enableBloom
                    ? [
                        Shadow(
                          color: themeProvider.appThemeColor.withOpacity(0.9),
                          blurRadius: 20,
                        ),
                      ]
                    : [],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Floating Dust Motes",
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize,
                  shadows: themeProvider.enableBloom
                      ? [
                          Shadow(
                            color: themeProvider.appThemeColor.withOpacity(0.9),
                            blurRadius: 20,
                          ),
                        ]
                      : [],
                ),
              ),
              subtitle: Text(
                "Subtle, glowing particles",
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize - 2,
                  color: Colors.grey,
                ),
              ),
              value: themeProvider.enableMotes,
              activeThumbColor: themeProvider.appThemeColor,
              onChanged: (val) => themeProvider.toggleMotes(val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Gentle Rain",
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize,
                  shadows: themeProvider.enableBloom
                      ? [
                          Shadow(
                            color: themeProvider.appThemeColor.withOpacity(0.9),
                            blurRadius: 20,
                          ),
                        ]
                      : [],
                ),
              ),
              subtitle: Text(
                "A calming, rainy mood",
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize - 2,
                  color: Colors.grey,
                ),
              ),
              value: themeProvider.enableRain,
              activeThumbColor: themeProvider.appThemeColor,
              onChanged: (val) => themeProvider.toggleRain(val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Glowing Fireflies",
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize,
                  shadows: themeProvider.enableBloom
                      ? [
                          Shadow(
                            color: themeProvider.appThemeColor.withOpacity(0.9),
                            blurRadius: 20,
                          ),
                        ]
                      : [],
                ),
              ),
              subtitle: Text(
                "Blinking lights for a cozy vibe",
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize - 2,
                  color: Colors.grey,
                ),
              ),
              value: themeProvider.enableFireflies,
              activeThumbColor: themeProvider.appThemeColor,
              onChanged: (val) => themeProvider.toggleFireflies(val),
            ),
            const Divider(),
            if (themeProvider.enableMotes)
              SettingsSlider(
                title: "Motes Density",
                value: themeProvider.motesDensity.toDouble(),
                min: 1,
                max: 150,
                isInt: true,
                activeColor: themeProvider.appThemeColor,
                fontSize: scaleProvider.systemFontSize * 0.8,
                onChanged: (val) => themeProvider.setMotesDensity(val.toInt()),
              ),
            if (themeProvider.enableRain)
              SettingsSlider(
                title: "Rainfall Intensity",
                value: themeProvider.rainIntensity.toDouble(),
                min: 1,
                max: 200,
                isInt: true,
                activeColor: themeProvider.appThemeColor,
                fontSize: scaleProvider.systemFontSize * 0.8,
                onChanged: (val) => themeProvider.setRainIntensity(val.toInt()),
              ),
            if (themeProvider.enableFireflies)
              SettingsSlider(
                title: "Fireflies Count",
                value: themeProvider.firefliesCount.toDouble(),
                min: 1,
                max: 100,
                isInt: true,
                activeColor: themeProvider.appThemeColor,
                fontSize: scaleProvider.systemFontSize * 0.8,
                onChanged: (val) =>
                    themeProvider.setFirefliesCount(val.toInt()),
              ),

            const SizedBox(height: 10),
            if (themeProvider.backgroundImagePath != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () =>
                        themeProvider.setBackgroundImage("assets/default.jpg"),
                    child: const Text(
                      "CLEAR BACKGROUND",
                      style: TextStyle(fontSize: 15, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
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
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image != null) {
                          themeProvider.addCustomImage(image.path);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: themeProvider.appThemeColor.withAlpha(
                            (0.1 * 255).round(),
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: themeProvider.appThemeColor.withAlpha(
                              (0.5 * 255).round(),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: themeProvider.appThemeColor,
                            ),
                            Text(
                              "Add",
                              style: TextStyle(
                                fontSize: scaleProvider.systemFontSize * 0.7,
                                color: themeProvider.appThemeColor,
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

                  final bool isSelected =
                      themeProvider.backgroundImagePath == path;

                  return InkWell(
                    onTap: () => themeProvider.setBackgroundImage(path),
                    onLongPress: isCustom
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
                    splashColor: Colors.redAccent.withAlpha(
                      (0.8 * 255).round(),
                    ),
                    highlightColor: Colors.redAccent.withAlpha(
                      (0.4 * 255).round(),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isCustom
                              ? Image.file(File(path), fit: BoxFit.cover)
                              : Image.asset(path, fit: BoxFit.cover),
                        ),
                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: themeProvider.appThemeColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.check_circle,
                                color: themeProvider.appThemeColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (themeProvider.backgroundImagePath != null) ...[
              const SizedBox(height: 5),
              Text(
                "Dimmer: ${(themeProvider.backgroundOpacity * 100).toInt()}%",
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize * 0.8,
                  color: Colors.grey,
                ),
              ),
              Slider(
                value: themeProvider.backgroundOpacity,
                min: 0.0,
                max: 0.95,
                activeColor: themeProvider.appThemeColor,
                inactiveColor: Colors.grey[800],
                onChanged: (val) => themeProvider.setBackgroundOpacity(val),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
