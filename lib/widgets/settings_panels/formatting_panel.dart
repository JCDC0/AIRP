import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';

/// Placeholder panel for advanced formatting options.
///
/// Will be fleshed out in Phase 8 with custom separator, instruct toggle,
/// depth prompt override, and other SillyTavern-compatible formatting
/// controls.
class FormattingPanel extends StatefulWidget {
  const FormattingPanel({super.key});

  @override
  State<FormattingPanel> createState() => _FormattingPanelState();
}

class _FormattingPanelState extends State<FormattingPanel> {
  bool _enableFormatting = false;

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
              "Enable Advanced Formatting",
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: scaleProvider.systemFontSize,
              ),
            ),
            subtitle: Text(
              "Custom separators, instruct mode, depth prompts",
              style: TextStyle(
                color: themeProvider.subtitleColor,
                fontSize: scaleProvider.systemFontSize * 0.8,
              ),
            ),
            value: _enableFormatting,
            activeThumbColor: Colors.blueAccent,
            onChanged: (val) => setState(() => _enableFormatting = val),
          ),

          // Placeholder body
          Opacity(
            opacity: _enableFormatting ? 1.0 : 0.5,
            child: AbsorbPointer(
              absorbing: !_enableFormatting,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.text_format,
                      size: 48,
                      color: themeProvider.faintColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No formatting overrides active.",
                      style: TextStyle(
                        color: themeProvider.faintColor,
                        fontSize: scaleProvider.systemFontSize * 0.9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Configure message separators, instruct sequences,\nand depth prompt injection once this feature is complete.",
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
