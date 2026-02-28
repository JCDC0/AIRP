import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import '../../utils/version.dart';

/// Header widget for the settings panel that displays the application title
/// and version number with theme-aware styling and optional bloom effects.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Text(
          "Main Settings",
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize + 10,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            shadows: themeProvider.enableBloom
                ? [
                    Shadow(
                      color: themeProvider.bloomGlowColor.withOpacity(0.9),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
        ),
        Text(
          "v$appVersion",
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize + 4,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const Divider(),
      ],
    );
  }
}
