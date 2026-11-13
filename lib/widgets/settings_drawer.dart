import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/scale_provider.dart';
import '../models/chat_models.dart';
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
import 'settings_panels/update_settings_panel.dart';

/// A drawer widget that contains all application settings.
///
/// This drawer is a clean composer for modular settings panels.
/// Most panels are now self-contained and reactive, eliminating the need
/// for manual controller synchronization in this widget.
class SettingsDrawer extends StatelessWidget {
  /// A version number used to force a reset of the drawer state.
  final int resetVersion;

  const SettingsDrawer({super.key, this.resetVersion = 0});

  /// One style for every section title in this drawer.
  ///
  /// These nine titles were hand-styled and only two carried the bloom
  /// shadow, so switching Bloom on lit a couple of headings and left the rest
  /// flat. [emphasised] keeps the louder one-off glow that marks Layout &
  /// Scaling as unseen.
  Text _sectionTitle(
    String label, {
    required ThemeProvider theme,
    required VfxProvider vfx,
    required ScaleProvider scale,
    Color? color,
    bool emphasised = false,
  }) {
    final lit = emphasised || vfx.enableBloom;
    return Text(
      label,
      style: TextStyle(
        color: color ?? theme.textColor,
        fontWeight: FontWeight.bold,
        fontSize: scale.systemFontSize,
        shadows: lit
            ? [
                Shadow(
                  color: theme.bloomGlowColor,
                  blurRadius: emphasised ? 15 : 10,
                ),
              ]
            : const <Shadow>[],
      ),
    );
  }

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
            scaleProvider.drawerWidth +
            (scaleProvider.systemFontSize - 12) * 10,
        height: double.infinity,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsHeader(),

                  const UpdateSettingsPanel(),

                  ExpansionTile(
                    key: Key('core_components_$resetVersion'),
                    initiallyExpanded: false,
                    title: _sectionTitle(
                      "Core Components",
                      theme: themeProvider,
                      vfx: vfxProvider,
                      scale: scaleProvider,
                    ),
                    subtitle: Text(
                      chatProvider.currentProvider.displayName,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    collapsedIconColor: themeProvider.textColor,
                    iconColor: themeProvider.textColor,
                    children: [
                      const ApiSettingsPanel(),
                      const Divider(),
                      const ModelSettingsPanel(),
                    ],
                  ),

                  ExpansionTile(
                    key: Key('system_prompt_$resetVersion'),
                    initiallyExpanded: false,
                    title: _sectionTitle(
                      "Main System Prompt",
                      theme: themeProvider,
                      vfx: vfxProvider,
                      scale: scaleProvider,
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
                    title: _sectionTitle(
                      "Generation Parameters",
                      theme: themeProvider,
                      vfx: vfxProvider,
                      scale: scaleProvider,
                    ),
                    subtitle: Text(
                      settingsProvider.enableGenerationSettings
                          ? 'Temperature · Top P · Top K · Repetition'
                          : 'Off: provider defaults',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    trailing: Switch(
                      value: settingsProvider.enableGenerationSettings,
                      activeThumbColor: themeProvider.textColor,
                      onChanged: (val) {
                        settingsProvider.setEnableGenerationSettings(val);
                        settingsProvider.saveSettings(showConfirmation: false);
                      },
                    ),
                    collapsedIconColor: themeProvider.textColor,
                    iconColor: themeProvider.textColor,
                    children: [const GenerationSettingsPanel()],
                  ),

                  ExpansionTile(
                    key: Key('web_search_settings_$resetVersion'),
                    initiallyExpanded: false,
                    title: _sectionTitle(
                      "Web Search",
                      theme: themeProvider,
                      vfx: vfxProvider,
                      scale: scaleProvider,
                    ),
                    subtitle: Text(
                      chatProvider.webSearchUnsupportedReason() ??
                          (settingsProvider.enableGrounding
                              ? 'On: the model may search'
                              : 'Off: no search tool offered'),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    // Same flag as the web search button above the chat input, so
                    // the two stay in step.
                    trailing: Switch(
                      value: settingsProvider.enableGrounding,
                      activeThumbColor: themeProvider.textColor,
                      onChanged:
                          chatProvider.webSearchUnsupportedReason() == null
                          ? (val) {
                              settingsProvider.setEnableGrounding(val);
                              settingsProvider.saveSettings(
                                showConfirmation: false,
                              );
                            }
                          : null,
                    ),
                    collapsedIconColor: themeProvider.textColor,
                    iconColor: themeProvider.textColor,
                    children: [const WebSearchSettingsPanel()],
                  ),

                  ExpansionTile(
                    key: Key('character_card_$resetVersion'),
                    initiallyExpanded:
                        chatProvider.characterCard.name.isNotEmpty,
                    title: _sectionTitle(
                      "Character Card",
                      theme: themeProvider,
                      vfx: vfxProvider,
                      scale: scaleProvider,
                      color: Colors.orangeAccent,
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
                    title: _sectionTitle(
                      "Text Designer",
                      theme: themeProvider,
                      vfx: vfxProvider,
                      scale: scaleProvider,
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
                    title: _sectionTitle(
                      "Layout & Scaling",
                      theme: themeProvider,
                      vfx: vfxProvider,
                      scale: scaleProvider,
                      emphasised: scaleProvider.shouldGlow,
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
                    title: _sectionTitle(
                      "Visuals & Atmosphere",
                      theme: themeProvider,
                      vfx: vfxProvider,
                      scale: scaleProvider,
                    ),
                    collapsedIconColor: themeProvider.textColor,
                    iconColor: themeProvider.textColor,
                    children: [const VisualSettingsPanel()],
                  ),

                  ExpansionTile(
                    key: Key('library_settings_$resetVersion'),
                    initiallyExpanded: false,
                    title: _sectionTitle(
                      "Settings Library",
                      theme: themeProvider,
                      vfx: vfxProvider,
                      scale: scaleProvider,
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
                  child: Icon(Icons.save, size: 24 * scaleProvider.iconScale),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
