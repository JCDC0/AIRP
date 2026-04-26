import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import 'settings_color_picker.dart';

/// A panel for designing text presentation across the app.
class TextDesignerPanel extends StatelessWidget {
  const TextDesignerPanel({super.key});

  Widget _buildMarkdownPickerRow(
    BuildContext context,
    ScaleProvider scaleProvider,
    ThemeProvider themeProvider,
    List<_MarkdownColorEntry> entries,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: entries
          .map(
            (entry) => SettingsColorPicker(
              label: entry.label,
              color: entry.color(themeProvider),
              onSave: (color) => themeProvider.updateMarkdownColor(
                entry.type,
                color,
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
            shadows: themeProvider.enableBloom
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
            shadows: themeProvider.enableBloom
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
              color: themeProvider.enableBloom
                  ? themeProvider.bloomGlowColor.withValues(alpha: 0.5)
                  : themeProvider.borderColor,
            ),
            boxShadow: themeProvider.enableBloom
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
              items: const [
                DropdownMenuItem(value: 'Default', child: Text('Default (System)')),
                DropdownMenuItem(value: 'Google', child: Text('Google Sans (Open Sans)')),
                DropdownMenuItem(value: 'Apple', child: Text('Apple SF (Inter)')),
                DropdownMenuItem(value: 'Claude', child: Text('Assistant (Source Serif 4)')),
                DropdownMenuItem(value: 'Roleplay', child: Text('Storybook (Lora)')),
                DropdownMenuItem(value: 'Terminal', child: Text('Hacker (Space Mono)')),
                DropdownMenuItem(value: 'Manuscript', child: Text('Ancient Tome (EB Garamond)')),
                DropdownMenuItem(value: 'Cyber', child: Text('Neon HUD (Orbitron)')),
                DropdownMenuItem(value: 'ModernAnime', child: Text('Light Novel (Quicksand)')),
                DropdownMenuItem(value: 'AnimeSub', child: Text('Subtitles (Kosugi Maru)')),
                DropdownMenuItem(value: 'Gothic', child: Text('Victorian (Crimson Text)')),
                DropdownMenuItem(value: 'Journal', child: Text('Handwritten (Caveat)')),
                DropdownMenuItem(value: 'CleanThin', child: Text('Minimalist (Raleway)')),
                DropdownMenuItem(value: 'Stylized', child: Text('Vogue (Playfair Display)')),
                DropdownMenuItem(value: 'Fantasy', child: Text('MMORPG (Cinzel)')),
                DropdownMenuItem(value: 'Typewriter', child: Text('Detective (Special Elite)')),
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
            shadows: themeProvider.enableBloom
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
            shadows: themeProvider.enableBloom
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 10)]
                : [],
          ),
        ),
        const SizedBox(height: 12),
        _buildMarkdownPickerRow(
          context,
          scaleProvider,
          themeProvider,
          [
            _MarkdownColorEntry('Paragraph', 'paragraph', (t) => t.markdownParagraphColor),
            _MarkdownColorEntry('Italic', 'italic', (t) => t.markdownItalicColor),
            _MarkdownColorEntry('Bold', 'bold', (t) => t.markdownBoldColor),
            _MarkdownColorEntry('Bold Italic', 'boldItalic', (t) => t.markdownBoldItalicColor),
            _MarkdownColorEntry('H1', 'h1', (t) => t.markdownH1Color),
            _MarkdownColorEntry('H2', 'h2', (t) => t.markdownH2Color),
            _MarkdownColorEntry('H3', 'h3', (t) => t.markdownH3Color),
            _MarkdownColorEntry('Link', 'link', (t) => t.markdownLinkColor),
            _MarkdownColorEntry('Inline Code', 'inlineCode', (t) => t.markdownInlineCodeColor),
            _MarkdownColorEntry('Code Block', 'codeBlock', (t) => t.markdownCodeBlockColor),
            _MarkdownColorEntry('Blockquote', 'blockquote', (t) => t.markdownBlockquoteColor),
            _MarkdownColorEntry('List', 'list', (t) => t.markdownListColor),
            _MarkdownColorEntry('Strike', 'strike', (t) => t.markdownStrikeColor),
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