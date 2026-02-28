import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';

/// Placeholder panel for regex scripting.
///
/// Will be fleshed out in Phase 8 with full SillyTavern-compatible regex
/// script management (find/replace, scope targeting, min/max depth, trim
/// strings, etc.).
class RegexPanel extends StatefulWidget {
  const RegexPanel({super.key});

  @override
  State<RegexPanel> createState() => _RegexPanelState();
}

class _RegexPanelState extends State<RegexPanel> {
  bool _enableRegex = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: themeProvider.containerFillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Master toggle
          SwitchListTile(
            title: Text(
              "Enable Regex Scripts",
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: scaleProvider.systemFontSize,
              ),
            ),
            subtitle: Text(
              "Apply find/replace rules to messages",
              style: TextStyle(
                color: themeProvider.subtitleColor,
                fontSize: scaleProvider.systemFontSize * 0.8,
              ),
            ),
            value: _enableRegex,
            activeThumbColor: Colors.blueAccent,
            onChanged: (val) => setState(() => _enableRegex = val),
          ),

          // Placeholder body
          Opacity(
            opacity: _enableRegex ? 1.0 : 0.5,
            child: AbsorbPointer(
              absorbing: !_enableRegex,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.find_replace,
                      size: 48,
                      color: themeProvider.faintColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No regex scripts defined.",
                      style: TextStyle(
                        color: themeProvider.faintColor,
                        fontSize: scaleProvider.systemFontSize * 0.9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Import a character card or preset with regex scripts,\nor add them manually once this feature is complete.",
                      style: TextStyle(
                        color: themeProvider.faintestColor,
                        fontSize: scaleProvider.systemFontSize * 0.7,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
