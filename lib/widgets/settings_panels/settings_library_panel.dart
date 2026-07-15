import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/config_pack.dart';
import '../../services/config_pack_service.dart';
import '../../services/library_service.dart';
import '../../services/file_io_helper.dart';

/// Unified Settings Library panel.
///
/// Hosts two tabs:
///  - **Config Packs** — named settings bundles (capture / apply / export /
///    import) plus tolerant SillyTavern preset import.
///  - **Snapshots**    — selective full-state `.airp` export / smart import.
class SettingsLibraryPanel extends StatefulWidget {
  const SettingsLibraryPanel({super.key});

  @override
  State<SettingsLibraryPanel> createState() => _SettingsLibraryPanelState();
}

class _SettingsLibraryPanelState extends State<SettingsLibraryPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Config Packs state ──────────────────────────────────────────────────
  List<ConfigPack> _packs = [];

  // ── Snapshots state ─────────────────────────────────────────────────────
  bool _exportConversations = true;
  bool _exportSystemPrompt = true;
  bool _exportGenerationParams = true;
  bool _exportLayoutScaling = true;
  bool _exportVisualsAtmosphere = true;
  bool _exportCharacterCard = true;
  bool _exportSubsystemState = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPacks());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Config Packs ──────────────────────────────────────────────────────────

  Future<void> _loadPacks() async {
    final packs = await ConfigPackService.listPacks();
    if (mounted) setState(() => _packs = packs);
  }

  ThemeProvider get _tp => Provider.of<ThemeProvider>(context, listen: false);
  ScaleProvider get _sp => Provider.of<ScaleProvider>(context, listen: false);

  Future<String?> _promptForName({
    required String hint,
    String initial = '',
    String title = 'Name',
  }) async {
    final tp = _tp;
    final fs = _sp.systemFontSize;
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.dropdownColor,
        title: Text(title, style: TextStyle(color: tp.textColor, fontSize: fs)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: tp.containerFillDarkColor,
          ),
          style: TextStyle(color: tp.textColor, fontSize: fs * 0.8),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _saveCurrentAsPack() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final vfxProvider = Provider.of<VfxProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);

    final name = await _promptForName(hint: 'Pack name');
    if (name == null || name.trim().isEmpty) return;

    final pack = ConfigPackService.captureCurrent(
      chatProvider: chatProvider,
      settingsProvider: settingsProvider,
      themeProvider: themeProvider,
      vfxProvider: vfxProvider,
      scaleProvider: scaleProvider,
      name: name.trim(),
    );
    await ConfigPackService.savePack(pack);
    await _loadPacks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved pack '${pack.name}'")),
      );
    }
  }

  Future<void> _confirmApplyPack(ConfigPack pack) async {
    final tp = _tp;
    final fs = _sp.systemFontSize;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.dropdownColor,
        title: Text('Apply pack?',
            style: TextStyle(color: tp.textColor, fontSize: fs)),
        content: Text(
          "Apply '${pack.name}'? This overwrites all settings. "
          'Conversations and API keys are not affected.',
          style: TextStyle(color: tp.subtitleColor, fontSize: fs * 0.8),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _applyPack(pack);
  }

  Future<void> _applyPack(ConfigPack pack) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final vfxProvider = Provider.of<VfxProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ConfigPackService.applyPack(
        pack,
        chatProvider: chatProvider,
        settingsProvider: settingsProvider,
        themeProvider: themeProvider,
        vfxProvider: vfxProvider,
        scaleProvider: scaleProvider,
      );
      messenger.showSnackBar(
        SnackBar(content: Text("Applied pack '${pack.name}'")),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Apply failed: $e')),
      );
    }
  }

  Future<void> _renamePack(ConfigPack pack) async {
    final name = await _promptForName(
      hint: 'New name',
      initial: pack.name,
      title: 'Rename pack',
    );
    if (name == null || name.trim().isEmpty || name.trim() == pack.name) return;
    await ConfigPackService.renamePack(pack.name, name.trim());
    await _loadPacks();
  }

  Future<void> _confirmDeletePack(ConfigPack pack) async {
    final tp = _tp;
    final fs = _sp.systemFontSize;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.dropdownColor,
        title: Text('Delete pack?',
            style: TextStyle(color: Colors.redAccent, fontSize: fs)),
        content: Text("Delete '${pack.name}'?\n\nThis cannot be undone.",
            style: TextStyle(color: tp.subtitleColor, fontSize: fs * 0.8)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DELETE')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ConfigPackService.deletePack(pack.name);
    await _loadPacks();
  }

  Future<void> _exportPackToFile(ConfigPack pack) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final jsonStr =
          const JsonEncoder.withIndent('  ').convert(pack.toJson());
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final saved = await FileIOHelper.saveFile(
        bytes: bytes,
        fileName:
            '${pack.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.json',
        extensions: ['json'],
        dialogTitle: 'Export Config Pack',
      );
      if (saved && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Config pack exported!')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportCurrentToFile() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final vfxProvider = Provider.of<VfxProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final name = await _promptForName(hint: 'Pack name');
    if (name == null || name.trim().isEmpty) return;
    final pack = ConfigPackService.captureCurrent(
      chatProvider: chatProvider,
      settingsProvider: settingsProvider,
      themeProvider: themeProvider,
      vfxProvider: vfxProvider,
      scaleProvider: scaleProvider,
      name: name.trim(),
    );
    await _exportPackToFile(pack);
  }

  Future<void> _importAirpPackFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final content =
        await FileIOHelper.pickAndReadString(dialogTitle: 'Select Config Pack');
    if (content == null) return;
    final pack = ConfigPackService.parsePackFile(content);
    if (pack == null) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Not a valid AIRP config pack'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    await ConfigPackService.savePack(pack);
    await _loadPacks();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text("Imported pack '${pack.name}'")),
      );
    }
  }

  Future<void> _importSillyTavernPreset() async {
    final messenger = ScaffoldMessenger.of(context);
    final content = await FileIOHelper.pickAndReadString(
        dialogTitle: 'Select SillyTavern Preset');
    if (content == null) return;
    try {
      final pack = ConfigPackService.importSillyTavernPreset(content);
      await ConfigPackService.savePack(pack);
      await _loadPacks();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text(
                  "Imported SillyTavern preset '${pack.name}' — tap to apply.")),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  // ── Snapshot export / import ─────────────────────────────────────────────

  Future<void> _handleSnapshotExport() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final vfxProvider = Provider.of<VfxProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final options = ExportOptions(
        conversations: _exportConversations,
        systemPrompt: _exportSystemPrompt,
        generationParams: _exportGenerationParams,
        layoutScaling: _exportLayoutScaling,
        visualsAtmosphere: _exportVisualsAtmosphere,
        characterCard: _exportCharacterCard,
        sillyTavernState: _exportSubsystemState,
      );
      final jsonString = await LibraryService.exportLibraryAsync(
        chatProvider: chatProvider,
        themeProvider: themeProvider,
        vfxProvider: vfxProvider,
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

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final vfxProvider = Provider.of<VfxProvider>(context, listen: false);
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
      vfxProvider: vfxProvider,
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
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
          height: MediaQuery.of(context).size.height * 0.6,
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildConfigPacksTab(tp, sp, chatProvider, settingsProvider, fs),
              _buildSnapshotsTab(tp, sp, fs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigPacksTab(
      ThemeProvider tp, ScaleProvider sp, ChatProvider chatProvider, SettingsProvider settingsProvider, double fs) {
    return Container(
      decoration: BoxDecoration(
        color: tp.containerFillColor,
        border: Border.all(color: tp.borderColor),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saveCurrentAsPack,
                    icon: const Icon(Icons.save, size: 14),
                    label: Text('Save Current',
                        style: TextStyle(fontSize: fs * 0.8)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _exportCurrentToFile,
                    icon: const Icon(Icons.arrow_upward, size: 14),
                    label: Text('Export',
                        style: TextStyle(fontSize: fs * 0.8)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _importAirpPackFile,
                    icon: const Icon(Icons.arrow_downward, size: 14),
                    label: Text('Import Pack',
                        style: TextStyle(fontSize: fs * 0.8)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _importSillyTavernPreset,
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: Text('Import ST Preset',
                        style: TextStyle(fontSize: fs * 0.8)),
                  ),
                ],
              ),
            ),
            Divider(color: tp.borderColor, height: 1),
            if (_packs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No saved config packs. Use "Save Current".',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center),
              ),
            ..._packs.map((pack) => ListTile(
                  dense: true,
                  onTap: () => _confirmApplyPack(pack),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(pack.name,
                            style: TextStyle(
                                color: tp.subtitleColor, fontSize: fs * 0.85),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (pack.sourceFormat == 'sillytavern')
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text('ST',
                              style: TextStyle(
                                  color: tp.faintColor,
                                  fontSize: fs * 0.6,
                                  fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    pack.description.isNotEmpty
                        ? pack.description
                        : 'Tap to apply',
                    style:
                        TextStyle(color: tp.faintColor, fontSize: fs * 0.65),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Export',
                        icon: Icon(Icons.download, size: 16, color: tp.textColor),
                        onPressed: () => _exportPackToFile(pack),
                      ),
                      IconButton(
                        tooltip: 'Rename',
                        icon: Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                        onPressed: () => _renamePack(pack),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        onPressed: () => _confirmDeletePack(pack),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotsTab(ThemeProvider tp, ScaleProvider sp, double fs) {
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
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              textStyle: TextStyle(fontSize: fs, fontWeight: FontWeight.bold),
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
        _buildSnapshotSwitch('Generation Parameters', _exportGenerationParams,
            (v) => setState(() => _exportGenerationParams = v), tp, fs),
        _buildSnapshotSwitch('Layout Scaling', _exportLayoutScaling,
            (v) => setState(() => _exportLayoutScaling = v), tp, fs),
        _buildSnapshotSwitch('Visuals & Atmosphere', _exportVisualsAtmosphere,
            (v) => setState(() => _exportVisualsAtmosphere = v), tp, fs),
        _buildSnapshotSwitch('Character Card', _exportCharacterCard,
            (v) => setState(() => _exportCharacterCard = v), tp, fs),
        _buildSnapshotSwitch('World Lore / Text Transforms / Style Rules', _exportSubsystemState,
            (v) => setState(() => _exportSubsystemState = v), tp, fs),

        const Divider(height: 24),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: tp.textColor,
              side: BorderSide(color: tp.textColor),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              textStyle: TextStyle(fontSize: fs, fontWeight: FontWeight.bold),
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
