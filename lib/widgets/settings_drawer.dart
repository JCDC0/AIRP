import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/scale_provider.dart';
import 'settings_panels/settings_header.dart';
import 'settings_panels/api_settings_panel.dart';
import 'settings_panels/model_settings_panel.dart';
import 'settings_panels/system_prompt_panel.dart';
import 'settings_panels/character_card_panel.dart';
import 'settings_panels/text_designer_panel.dart';
import 'settings_panels/generation_settings_panel.dart';
import 'settings_panels/web_search_settings_panel.dart';
import 'settings_panels/visual_settings_panel.dart';
import 'settings_panels/scale_settings_panel.dart';
import 'settings_panels/settings_library_panel.dart';

/// A drawer widget that contains all application settings.
///
/// This drawer is a clean composer for modular settings panels.
/// Most panels are now self-contained and reactive, eliminating the need
/// for manual controller synchronization in this widget.
class SettingsDrawer extends StatelessWidget {
  /// A version number used to force a reset of the drawer state.
  final int resetVersion;

  const SettingsDrawer({super.key, this.resetVersion = 0});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Material(
      elevation: vfxProvider.enableBloom ? 30 : 16,
      shadowColor: vfxProvider.enableBloom
          ? themeProvider.bloomGlowColor.withValues(alpha: 0.9)
          : null,
      color: themeProvider.scaffoldBackgroundColor,
      child: SizedBox(
        width:
            scaleProvider.drawerWidth + (scaleProvider.systemFontSize - 12) * 10,
        height: double.infinity,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsHeader(),

              ExpansionTile(
                key: Key('api_settings_$resetVersion'),
                initiallyExpanded: false,
                title: Text(
                  "API & Connectivity",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                  ),
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                children: [const ApiSettingsPanel()],
              ),

              ExpansionTile(
                key: Key('model_settings_$resetVersion'),
                initiallyExpanded: false,
                title: Text(
                  "Model Configuration",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                  ),
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                children: [const ModelSettingsPanel()],
              ),

              ExpansionTile(
                key: Key('system_prompt_$resetVersion'),
                initiallyExpanded: false,
                title: Text(
                  "Main System Prompt",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                    shadows: vfxProvider.enableBloom
                        ? [
                            Shadow(
                              color: themeProvider.bloomGlowColor,
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                ),
                trailing: Switch(
                  value: settingsProvider.enableSystemPrompt,
                  activeThumbColor: themeProvider.textColor,
                  onChanged: (val) {
                    settingsProvider.setEnableSystemPrompt(val);
                    chatProvider.saveSettings();
                  },
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                children: [const SystemPromptPanel()],
              ),

              ExpansionTile(
                key: Key('generation_settings_$resetVersion'),
                initiallyExpanded: false,
                title: Text(
                  "Generation Parameters",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                  ),
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                children: [const GenerationSettingsPanel()],
              ),

              ExpansionTile(
                key: Key('web_search_settings_$resetVersion'),
                initiallyExpanded: false,
                title: Text(
                  "Web Search",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                  ),
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                children: [const WebSearchSettingsPanel()],
              ),

              ExpansionTile(
                key: Key('character_card_$resetVersion'),
                initiallyExpanded: chatProvider.characterCard.name.isNotEmpty,
                title: Text(
                  "Character Card",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                  ),
                ),
                subtitle: Text(
                  chatProvider.characterCard.name.isNotEmpty
                      ? "Active: ${chatProvider.characterCard.name}"
                      : "Import V1/V2 PNG or JSON cards",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: Switch(
                  value: settingsProvider.enableCharacterCard,
                  activeThumbColor: Colors.orangeAccent,
                  onChanged: (val) {
                    settingsProvider.setEnableCharacterCard(val);
                    chatProvider.saveSettings();
                  },
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                children: [const CharacterCardPanel()],
              ),

              ExpansionTile(
                key: Key('text_designer_$resetVersion'),
                initiallyExpanded: false,
                title: Text(
                  "Text Designer",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                    shadows: vfxProvider.enableBloom
                        ? [
                            Shadow(
                              color: themeProvider.bloomGlowColor,
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                children: [const TextDesignerPanel()],
              ),

              ExpansionTile(
                key: Key('scale_settings_$resetVersion'),
                initiallyExpanded: false,
                onExpansionChanged: (expanded) {
                  if (expanded) {
                    scaleProvider.markSettingsAsSeen();
                  }
                },
                title: Text(
                  "Layout & Scaling",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                    shadows: scaleProvider.shouldGlow
                        ? [
                            Shadow(
                              color: themeProvider.bloomGlowColor,
                              blurRadius: 15,
                            ),
                          ]
                        : null,
                  ),
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                leading: scaleProvider.shouldGlow
                    ? Icon(
                        Icons.new_releases,
                        color: themeProvider.textColor,
                        shadows: [
                          Shadow(
                            color: themeProvider.bloomGlowColor,
                            blurRadius: 10,
                          ),
                        ],
                      )
                    : null,
                children: [const ScaleSettingsPanel()],
              ),

              ExpansionTile(
                key: Key('visual_settings_$resetVersion'),
                initiallyExpanded: false,
                title: Text(
                  "Visuals & Atmosphere",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                  ),
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                children: [const VisualSettingsPanel()],
              ),

              ExpansionTile(
                key: Key('library_settings_$resetVersion'),
                initiallyExpanded: false,
                title: Text(
                  "Settings Library",
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize,
                  ),
                ),
                subtitle: const Text(
                  'Config Packs · Snapshots',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                collapsedIconColor: themeProvider.textColor,
                iconColor: themeProvider.textColor,
                children: [const SettingsLibraryPanel()],
              ),

              const SizedBox(height: 80),
                ],
              ),
            ),

            // ── Falling Save Button ──────────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 800),
              curve: settingsProvider.hasPendingChanges
                  ? Curves.bounceOut
                  : Curves.easeInBack,
              bottom: settingsProvider.hasPendingChanges
                  ? MediaQuery.of(context).viewInsets.bottom + 30
                  : -(56 * scaleProvider.iconScale + 40),
              right: 20,
              child: SizedBox(
                width: 56 * scaleProvider.iconScale,
                height: 56 * scaleProvider.iconScale,
                child: FloatingActionButton(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: themeProvider.scaffoldBackgroundColor,
                  onPressed: () {
                    settingsProvider.saveSettings();
                    chatProvider.saveSettings();
                    settingsProvider.clearDirty();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings Saved'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.lightBlue,
                        duration: Duration(milliseconds: 1500),
                      ),
                    );
                  },
                  elevation: 10,
                  child: Icon(
                    Icons.save,
                    size: 24 * scaleProvider.iconScale,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
