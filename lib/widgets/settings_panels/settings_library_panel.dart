import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/preset_model.dart';
import '../../services/library_service.dart';
import '../../services/file_io_helper.dart';

/// Unified Settings Library panel.
///
/// Hosts two tabs:
///  - **Config Packs** — custom rules manager + preset import / export (former PresetPanel).
///  - **Snapshots**    — selective full-state `.airp` export / smart import (former LibraryPanel).
class SettingsLibraryPanel extends StatefulWidget {
  final TextEditingController mainPromptController;
  final TextEditingController advancedPromptController;
  final TextEditingController promptTitleController;
  final VoidCallback onPromptChanged;

  const SettingsLibraryPanel({
    super.key,
    required this.mainPromptController,
    required this.advancedPromptController,
    required this.promptTitleController,
    required this.onPromptChanged,
  });

  @override
  State<SettingsLibraryPanel> createState() => _SettingsLibraryPanelState();
}

class _SettingsLibraryPanelState extends State<SettingsLibraryPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Config Packs state ──────────────────────────────────────────────────
  late TextEditingController _ruleLabelController;
  late TextEditingController _newRuleContentController;
  List<Map<String, dynamic>> _customRules = [];

  static const String kCustomRulesKey = 'airp_custom_rules';
  static const String _kLegacyCustomRulesKey = 'custom_sys_prompt_rules';

  // ── Snapshots state ─────────────────────────────────────────────────────
  bool _exportConversations = true;
  bool _exportSystemPrompt = true;
  bool _exportAdvancedPrompt = true;
  bool _exportGenerationParams = true;
  bool _exportLayoutScaling = true;
  bool _exportVisualsAtmosphere = true;
  bool _exportCharacterCard = true;
  bool _exportSubsystemState = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ruleLabelController = TextEditingController();
    _newRuleContentController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomRules());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ruleLabelController.dispose();
    _newRuleContentController.dispose();
    super.dispose();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _loadCustomRules() async {
    final prefs = await SharedPreferences.getInstance();
    String? json = prefs.getString(kCustomRulesKey);
    if (json == null) {
      json = prefs.getString(_kLegacyCustomRulesKey);
      if (json != null) {
        await prefs.setString(kCustomRulesKey, json);
        await prefs.remove(_kLegacyCustomRulesKey);
      }
    }
    if (json != null) {
      try {
        final decoded = jsonDecode(json) as List<dynamic>;
        _customRules = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint('Error loading custom rules: $e');
      }
    }
    if (mounted) setState(() => _rebuildAdvancedPrompt());
  }

  Future<void> _saveCustomRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kCustomRulesKey, jsonEncode(_customRules));
  }

  void _rebuildAdvancedPrompt() {
    widget.advancedPromptController.text = _customRules
        .where((r) => r['active'] == true)
        .map((r) => (r['content'] as String).trim())
        .join('\n\n');
    widget.onPromptChanged();
  }

  // ── Config Pack import / export ─────────────────────────────────────────

  Future<void> _importConfigPack() async {
    try {
      final content = await FileIOHelper.pickAndReadString(extensions: ['json']);
      if (content == null) return;
      final preset = SystemPreset.fromJson(jsonDecode(content));
      widget.promptTitleController.text = preset.name;
      widget.mainPromptController.text = preset.systemPrompt;

      final existing = [..._customRules];
      final labels = existing.map((r) => r['label']).toSet();
      for (final rule in preset.customRules) {
        if (!labels.contains(rule['label'])) {
          existing.add(rule);
          labels.add(rule['label']);
        }
      }
      setState(() {
        _customRules = existing;
        _saveCustomRules();
        _rebuildAdvancedPrompt();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Imported config pack '${preset.name}'!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _exportConfigPack() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final preset = SystemPreset(
      name: widget.promptTitleController.text.isNotEmpty
          ? widget.promptTitleController.text
          : 'Untitled Config Pack',
      systemPrompt: widget.mainPromptController.text,
      advancedPrompt: widget.advancedPromptController.text,
      customRules: _customRules,
      generationSettings: {
        'temperature': chatProvider.temperature,
        'top_p': chatProvider.topP,
        'top_k': chatProvider.topK,
      },
    );
    try {
      final jsonStr = await LibraryService.exportPreset(preset);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final saved = await FileIOHelper.saveFile(
        bytes: bytes,
        fileName: '${preset.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.json',
        extensions: ['json'],
        dialogTitle: 'Export Config Pack',
      );
      if (saved && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Config pack exported!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  // ── Rule CRUD ────────────────────────────────────────────────────────────

  void _addRule() {
    final text = _newRuleContentController.text.trim();
    if (text.isEmpty) return;
    final label = _ruleLabelController.text.trim().isNotEmpty
        ? _ruleLabelController.text.trim()
        : (text.length > 25 ? '${text.substring(0, 25)}…' : text);
    setState(() {
      _customRules.add({'content': text, 'active': true, 'label': label});
      _newRuleContentController.clear();
      _ruleLabelController.clear();
      _saveCustomRules();
      _rebuildAdvancedPrompt();
    });
  }

  void _editRule(int index) {
    final sp = Provider.of<ScaleProvider>(context, listen: false);
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final rule = _customRules[index];
    final label = TextEditingController(text: rule['label']);
    final content = TextEditingController(text: rule['content']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.dropdownColor,
        title: Text('Edit Rule',
            style: TextStyle(color: tp.textColor, fontSize: sp.systemFontSize)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: InputDecoration(
                  labelText: 'Rule Name',
                  filled: true,
                  fillColor: tp.containerFillDarkColor),
              style: TextStyle(
                  color: tp.textColor, fontSize: sp.systemFontSize * 0.8),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: content,
              maxLines: 4,
              decoration: InputDecoration(
                  labelText: 'Rule Content',
                  filled: true,
                  fillColor: tp.containerFillDarkColor),
              style: TextStyle(
                  color: tp.textColor, fontSize: sp.systemFontSize * 0.8),
            ),
          ],
        ),
        actions: [
          TextButton(
              child: Text('Cancel',
                  style: TextStyle(fontSize: sp.systemFontSize * 0.8)),
              onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text('Save',
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: sp.systemFontSize * 0.8)),
            onPressed: () {
              setState(() {
                _customRules[index]['label'] = label.text.trim();
                _customRules[index]['content'] = content.text.trim();
                _saveCustomRules();
                if (_customRules[index]['active'] == true) _rebuildAdvancedPrompt();
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRule(int index) {
    final sp = Provider.of<ScaleProvider>(context, listen: false);
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final label = _customRules[index]['label'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.dropdownColor,
        title: Text('Delete Rule?',
            style: TextStyle(
                color: Colors.redAccent, fontSize: sp.systemFontSize)),
        content: Text("Delete '$label'?\n\nThis cannot be undone.",
            style: TextStyle(
                color: tp.subtitleColor, fontSize: sp.systemFontSize * 0.8)),
        actions: [
          TextButton(
              child: Text('Cancel',
                  style: TextStyle(fontSize: sp.systemFontSize * 0.8)),
              onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text('DELETE',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: sp.systemFontSize * 0.8)),
            onPressed: () {
              final wasActive = _customRules[index]['active'] == true;
              setState(() {
                _customRules.removeAt(index);
                _saveCustomRules();
                if (wasActive) _rebuildAdvancedPrompt();
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ── Snapshot export / import ─────────────────────────────────────────────

  Future<void> _handleSnapshotExport() async {
    // Capture providers and messenger BEFORE any async gap
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final options = ExportOptions(
        conversations: _exportConversations,
        systemPrompt: _exportSystemPrompt,
        advancedSystemPrompt: _exportAdvancedPrompt,
        generationParams: _exportGenerationParams,
        layoutScaling: _exportLayoutScaling,
        visualsAtmosphere: _exportVisualsAtmosphere,
        characterCard: _exportCharacterCard,
        sillyTavernState: _exportSubsystemState,
      );
      final jsonString = await LibraryService.exportLibraryAsync(
        chatProvider: chatProvider,
        themeProvider: themeProvider,
        scaleProvider: scaleProvider,
        options: options,
      );
      final bytes = utf8.encode(jsonString);
      final saved = await FileIOHelper.saveFile(
        bytes: bytes,
        fileName: 'airp_snapshot.airp',
        dialogTitle: 'Save AIRP Snapshot',
      );
      if (!saved) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Snapshot exported!'),
            duration: Duration(seconds: 3)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _handleSnapshotImport() async {
    // Capture messenger before any async gap
    final messenger = ScaffoldMessenger.of(context);

    final fileContent = await FileIOHelper.pickAndReadString(
        dialogTitle: 'Select AIRP Snapshot File');
    if (fileContent == null) return;
    if (!mounted) return;

    final preview = _parsePreview(fileContent);
    if (preview == null) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Invalid .airp file format'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Capture context-dependents before the showDialog await
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildImportDialog(ctx, preview),
    );
    if (confirmed != true) return;

    final result = await LibraryService.importLibrary(
      fileContent: fileContent,
      chatProvider: chatProvider,
      themeProvider: themeProvider,
      scaleProvider: scaleProvider,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? Colors.greenAccent : Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  _SnapshotPreview? _parsePreview(String content) {
    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (!data.containsKey('airp_library_version')) return null;
      int convCount = 0;
      List<String> convTitles = [];
      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings?['sessions'] != null) {
        final sessions = settings!['sessions'] as List<dynamic>;
        convCount = sessions.length;
        convTitles = sessions
            .take(3)
            .map((s) =>
                (s as Map<String, dynamic>)['title'] as String? ?? 'Untitled')
            .toList();
      }
      final sections = <String>[];
      if (data['generation'] != null) sections.add('Generation Parameters');
      if (data['theme'] != null) sections.add('Visuals & Atmosphere');
      if (data['scale'] != null) sections.add('Layout & Scaling');
      return _SnapshotPreview(
        appVersion: data['app_version'] as String? ?? 'unknown',
        convCount: convCount,
        convTitles: convTitles,
        sections: sections,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildImportDialog(BuildContext ctx, _SnapshotPreview preview) {
    final tp = Provider.of<ThemeProvider>(ctx);
    final sp = Provider.of<ScaleProvider>(ctx);
    final fs = sp.systemFontSize;
    return AlertDialog(
      backgroundColor: tp.dropdownColor,
      title: Row(children: [
        Icon(Icons.preview, color: tp.textColor, size: fs * 1.5),
        const SizedBox(width: 8),
        Text('Import Preview',
            style: TextStyle(color: tp.textColor, fontSize: fs + 2)),
      ]),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('From version: ${preview.appVersion}',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: fs * 0.85,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            if (preview.convCount > 0) ...[
              Text('${preview.convCount} conversation(s)',
                  style:
                      TextStyle(color: tp.subtitleColor, fontSize: fs * 0.9)),
              ...preview.convTitles.map((t) => Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text('→ $t',
                        style: TextStyle(
                            color: tp.hintColor, fontSize: fs * 0.85),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  )),
              if (preview.convCount > 3)
                Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text('…and ${preview.convCount - 3} more',
                        style: TextStyle(
                            color: tp.dimTextColor,
                            fontSize: fs * 0.85,
                            fontStyle: FontStyle.italic))),
              const SizedBox(height: 10),
            ],
            if (preview.sections.isNotEmpty) ...[
              Text('Settings to overwrite:',
                  style: TextStyle(
                      color: tp.textColor,
                      fontSize: fs * 0.95,
                      fontWeight: FontWeight.bold)),
              ...preview.sections.map((s) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.greenAccent, size: fs),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(s,
                              style: TextStyle(
                                  color: tp.subtitleColor,
                                  fontSize: fs * 0.9))),
                    ]),
                  )),
              const SizedBox(height: 10),
            ],
            Divider(color: tp.faintestColor),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: Colors.orangeAccent, size: fs),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Settings overwritten. Conversations & prompts merged. API keys never imported.',
                  style: TextStyle(
                      color: Colors.orangeAccent.withValues(alpha: 0.9),
                      fontSize: fs * 0.8),
                ),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
            child: Text('Cancel', style: TextStyle(fontSize: fs)),
            onPressed: () => Navigator.pop(ctx, false)),
        TextButton(
          child: Text('Import',
              style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: fs)),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final sp = Provider.of<ScaleProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final fs = sp.systemFontSize;

    return Column(
      children: [
        // ── Tab bar ──
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: tp.containerFillColor,
            border: Border(bottom: BorderSide(color: tp.borderColor)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: tp.textColor,
            unselectedLabelColor: tp.faintColor,
            indicatorColor: tp.textColor,
            indicatorWeight: 2,
            labelStyle: TextStyle(
                fontSize: fs * 0.82, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: fs * 0.82),
            tabs: const [
              Tab(text: 'Config Packs'),
              Tab(text: 'Snapshots'),
            ],
          ),
        ),

        // ── Tab views ──
        SizedBox(
          // Avoid unbounded-height error inside a Column
          height: 2000,
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildConfigPacksTab(tp, sp, chatProvider, fs),
              _buildSnapshotsTab(tp, sp, fs),
            ],
          ),
        ),
      ],
    );
  }

  // ── Config Packs tab ────────────────────────────────────────────────────

  Widget _buildConfigPacksTab(
      ThemeProvider tp, ScaleProvider sp, ChatProvider chatProvider, double fs) {
    return Opacity(
      opacity: chatProvider.enableAdvancedSystemPrompt ? 1.0 : 0.5,
      child: AbsorbPointer(
        absorbing: !chatProvider.enableAdvancedSystemPrompt,
        child: Container(
          decoration: BoxDecoration(
            color: tp.containerFillColor,
            border: Border.all(color: tp.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Import / Export row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _importConfigPack,
                        icon: const Icon(Icons.arrow_downward, size: 14),
                        label: Text('Import',
                            style: TextStyle(fontSize: fs * 0.8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportConfigPack,
                        icon: const Icon(Icons.arrow_upward, size: 14),
                        label: Text('Export',
                            style: TextStyle(fontSize: fs * 0.8)),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: tp.borderColor, height: 1),

              // Rule list
              if (_customRules.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No custom rules defined.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center),
                ),

              ..._customRules.asMap().entries.map((entry) {
                final i = entry.key;
                final rule = entry.value;
                return ListTile(
                  dense: true,
                  title: Text(rule['label'],
                      style: TextStyle(
                          color: tp.subtitleColor, fontSize: fs * 0.8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    (rule['content'] as String).replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tp.faintColor, fontSize: 10),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.edit,
                        color: Colors.blueAccent, size: 16),
                    onPressed: () => _editRule(i),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close,
                            color: tp.faintestColor, size: 16),
                        onPressed: () => _confirmDeleteRule(i),
                      ),
                      Switch(
                        value: rule['active'] == true,
                        activeThumbColor: Colors.blueAccent,
                        onChanged: (val) => setState(() {
                          rule['active'] = val;
                          _rebuildAdvancedPrompt();
                        }),
                      ),
                    ],
                  ),
                );
              }),

              Divider(color: tp.borderColor),

              // Add new rule
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _ruleLabelController,
                      decoration: InputDecoration(
                        labelText: 'Rule Name',
                        hintText: 'Name',
                        isDense: true,
                        filled: true,
                        fillColor: tp.containerFillDarkColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newRuleContentController,
                      maxLines: 8,
                      minLines: 3,
                      decoration: InputDecoration(
                        labelText: 'New Rule Content',
                        hintText: 'Enter custom rule content…',
                        hintStyle: TextStyle(fontSize: fs * 0.8),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: tp.containerFillColor,
                      ),
                      style: TextStyle(fontSize: fs),
                      onSubmitted: (_) => _addRule(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('Add Rule'),
                        onPressed: _addRule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tp.dropdownColor,
                          foregroundColor: Colors.greenAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Preview generated prompt
              ExpansionTile(
                title: Text('View Generated Advanced Prompt',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: widget.advancedPromptController,
                      readOnly: true,
                      maxLines: 5,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: tp.containerFillDarkColor,
                        border: const OutlineInputBorder(),
                      ),
                      style: TextStyle(
                          fontSize: 12, color: tp.subtitleColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Snapshots tab ────────────────────────────────────────────────────────

  Widget _buildSnapshotsTab(
      ThemeProvider tp, ScaleProvider sp, double fs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          'Export or import all app settings as a portable .airp snapshot.',
          style: TextStyle(fontSize: fs * 0.8, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.greenAccent,
              side: const BorderSide(color: Colors.greenAccent),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              textStyle: TextStyle(
                  fontSize: fs, fontWeight: FontWeight.bold),
            ),
            icon: Icon(Icons.upload_file, size: fs * 1.4),
            label: const Text('Export Snapshot'),
            onPressed: _handleSnapshotExport,
          ),
        ),
        const SizedBox(height: 8),

        _buildSnapshotSwitch('Conversations', _exportConversations,
            (v) => setState(() => _exportConversations = v), tp, fs),
        _buildSnapshotSwitch('System Prompt', _exportSystemPrompt,
            (v) => setState(() => _exportSystemPrompt = v), tp, fs),
        _buildSnapshotSwitch(
            'Advanced System Prompt',
            _exportAdvancedPrompt,
            (v) => setState(() => _exportAdvancedPrompt = v),
            tp,
            fs),
        _buildSnapshotSwitch(
            'Generation Parameters',
            _exportGenerationParams,
            (v) => setState(() => _exportGenerationParams = v),
            tp,
            fs),
        _buildSnapshotSwitch('Layout Scaling', _exportLayoutScaling,
            (v) => setState(() => _exportLayoutScaling = v), tp, fs),
        _buildSnapshotSwitch(
            'Visuals & Atmosphere',
            _exportVisualsAtmosphere,
            (v) => setState(() => _exportVisualsAtmosphere = v),
            tp,
            fs),
        _buildSnapshotSwitch('Character Card', _exportCharacterCard,
            (v) => setState(() => _exportCharacterCard = v), tp, fs),
        _buildSnapshotSwitch(
            'World Lore / Text Transforms / Style Rules',
            _exportSubsystemState,
            (v) => setState(() => _exportSubsystemState = v),
            tp,
            fs),

        const Divider(height: 24),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: tp.textColor,
              side: BorderSide(color: tp.textColor),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              textStyle: TextStyle(
                  fontSize: fs, fontWeight: FontWeight.bold),
            ),
            icon: Icon(Icons.download, size: fs * 1.4),
            label: const Text('Import Snapshot'),
            onPressed: _handleSnapshotImport,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '⚠ Import overwrites settings but merges prompts & chats.',
          style: TextStyle(
            fontSize: fs * 0.7,
            color: Colors.orangeAccent.withValues(alpha: 0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSnapshotSwitch(String label, bool value,
      ValueChanged<bool> onChanged, ThemeProvider tp, double fs) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label,
          style: TextStyle(fontSize: fs * 0.85, color: tp.subtitleColor)),
      value: value,
      activeThumbColor: tp.textColor,
      onChanged: onChanged,
    );
  }
}

// ── Snapshot preview data ────────────────────────────────────────────────

class _SnapshotPreview {
  final String appVersion;
  final int convCount;
  final List<String> convTitles;
  final List<String> sections;

  const _SnapshotPreview({
    required this.appVersion,
    required this.convCount,
    required this.convTitles,
    required this.sections,
  });
}
