import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/scale_provider.dart';
import '../../utils/app_fonts.dart';
import 'settings_color_picker.dart';

/// A panel for designing text presentation across the app.
class TextDesignerPanel extends StatelessWidget {
  const TextDesignerPanel({super.key});

  Widget _buildMarkdownPickerList(
    BuildContext context,
    ScaleProvider scaleProvider,
    ThemeProvider themeProvider,
    List<_MarkdownColorEntry> entries,
  ) {
    return Column(
      children: entries
          .map(
            (entry) => _buildMarkdownPickerListItem(
              context,
              scaleProvider,
              themeProvider,
              entry,
            ),
          )
          .toList(),
    );
  }

  Widget _buildMarkdownPickerListItem(
    BuildContext context,
    ScaleProvider scaleProvider,
    ThemeProvider themeProvider,
    _MarkdownColorEntry entry,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showMarkdownColorPickerDialog(
          context,
          scaleProvider,
          themeProvider,
          entry,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: entry.color(themeProvider),
                  shape: BoxShape.circle,
                  border: Border.all(color: themeProvider.textColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: entry.color(themeProvider).withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.label,
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize,
                    color: themeProvider.textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarkdownColorPickerDialog(
    BuildContext context,
    ScaleProvider scaleProvider,
    ThemeProvider themeProvider,
    _MarkdownColorEntry entry,
  ) {
    Color tempColor = entry.color(themeProvider);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: themeProvider.dropdownColor,
            title: Text(
              'Pick ${entry.label} Color',
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: scaleProvider.systemFontSize,
              ),
            ),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: tempColor,
                onColorChanged: (color) {
                  setDialogState(() => tempColor = color);
                },
                pickerAreaHeightPercent: 0.7,
                enableAlpha: false,
                displayThumbColor: true,
                paletteType: PaletteType.hsvWithHue,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  themeProvider.updateMarkdownColor(entry.type, tempColor);
                  Navigator.pop(context);
                },
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: scaleProvider.systemFontSize * 0.8,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Text Designer',
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize + 10,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            shadows: vfxProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        const Divider(height: 10),
        Text(
          'Global Interface Font',
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            shadows: vfxProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: themeProvider.containerFillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: vfxProvider.enableBloom
                  ? themeProvider.bloomGlowColor.withValues(alpha: 0.5)
                  : themeProvider.borderColor,
            ),
            boxShadow: vfxProvider.enableBloom
                ? [
                    BoxShadow(
                      color: themeProvider.bloomGlowColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: themeProvider.fontStyle,
              dropdownColor: themeProvider.dropdownColor,
              icon: Icon(Icons.text_fields, color: themeProvider.textColor),
              items: [
                for (final font in AppFonts.all)
                  DropdownMenuItem(
                    value: font.key,
                    child: Text(font.menuLabel, overflow: TextOverflow.ellipsis),
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
          'Chat Customization',
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            shadows: vfxProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SettingsColorPicker(
              label: 'User BG',
              color: themeProvider.userBubbleColor,
              onSave: (c) => themeProvider.updateColor(
                'userBubble',
                c.withAlpha(((themeProvider.userBubbleColor.a * 255.0).round() & 0xff)),
              ),
            ),
            SettingsColorPicker(
              label: 'User Text',
              color: themeProvider.userTextColor,
              onSave: (c) => themeProvider.updateColor('userText', c),
            ),
            SettingsColorPicker(
              label: 'AI BG',
              color: themeProvider.aiBubbleColor,
              onSave: (c) => themeProvider.updateColor(
                'aiBubble',
                c.withAlpha(((themeProvider.aiBubbleColor.a * 255.0).round() & 0xff)),
              ),
            ),
            SettingsColorPicker(
              label: 'AI Text',
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
                'User Opacity:',
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize * 0.8,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Text(
                '${(themeProvider.userBubbleColor.a * 100).toInt()}%',
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
                'AI Opacity:',
                style: TextStyle(
                  fontSize: scaleProvider.systemFontSize * 0.8,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Text(
                '${(themeProvider.aiBubbleColor.a * 100).toInt()}%',
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
              'Reset Text Designer',
              style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: themeProvider.dropdownColor,
                  title: Text(
                    'Reset Text Designer?',
                    style: TextStyle(color: themeProvider.textColor),
                  ),
                  content: Text(
                    'This will revert text, chat, and markdown styling.',
                    style: TextStyle(color: themeProvider.subtitleColor),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
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
        const Divider(),
        Text(
          'Markdown Colors',
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            shadows: vfxProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'The three elements roleplay prose actually uses. Headings, lists, '
            'quotes, links and code still render, following the bubble text '
            'colour.',
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize - 4,
              color: themeProvider.subtitleColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildMarkdownPickerList(
          context,
          scaleProvider,
          themeProvider,
          [
            // Roleplay prose is narration, "dialogue" and *actions*. Every
            // other markdown element still renders, but follows the bubble
            // text colour rather than carrying a picker nobody moved.
            _MarkdownColorEntry('Narration', 'paragraph', (t) => t.markdownParagraphColor),
            _MarkdownColorEntry('Italic (actions)', 'italic', (t) => t.markdownItalicColor),
            _MarkdownColorEntry('Bold (emphasis)', 'bold', (t) => t.markdownBoldColor),
          ],
        ),
      ],
    );
  }
}

class _MarkdownColorEntry {
  final String label;
  final String type;
  final Color Function(ThemeProvider) color;

  const _MarkdownColorEntry(this.label, this.type, this.color);
}