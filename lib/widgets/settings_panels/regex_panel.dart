import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/regex_models.dart';
import '../../services/regex_service.dart';

/// Panel for managing global and character-scoped regex scripts.
///
/// Provides a reorderable list of scripts with per-script editing,
/// a test panel for live regex preview, and import/export as JSON.
/// Reads and writes state via [ChatProvider.globalRegexScripts] and
/// [ChatProvider.setGlobalRegexScripts].
class RegexPanel extends StatefulWidget {
  const RegexPanel({super.key});

  @override
  State<RegexPanel> createState() => _RegexPanelState();
}

class _RegexPanelState extends State<RegexPanel> {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns a short human-readable summary of which targets a script affects.
  String _affectsSummary(RegexScript s) {
    final parts = <String>[];
    if (s.affectsUserInput) parts.add('User');
    if (s.affectsAiOutput) parts.add('AI');
    if (s.affectsWorldInfo) parts.add('WI');
    if (s.affectsReasoning) parts.add('Think');
    if (parts.isEmpty) return 'No target';
    return parts.join(' \u00b7 ');
  }

  /// Returns a short badge string for the script's ephemerality.
  String _ephemeralBadge(RegexScript s) {
    if (s.displayOnly) return '  \u27e8display-only\u27e9';
    if (s.promptOnly) return '  \u27e8prompt-only\u27e9';
    return '';
  }

  // ---------------------------------------------------------------------------
  // Reorder
  // ---------------------------------------------------------------------------

  void _onReorder(int oldIndex, int newIndex, List<RegexScript> scripts) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (newIndex > oldIndex) newIndex--;
    final moved = scripts.removeAt(oldIndex);
    scripts.insert(newIndex, moved);
    for (int i = 0; i < scripts.length; i++) {
      scripts[i] = scripts[i].copyWith(sortOrder: i);
    }
    chatProvider.setGlobalRegexScripts(List.from(scripts));
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  void _addScript() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final newScript = RegexScript(
      id: DateTime.now().millisecondsSinceEpoch,
      scriptName: 'New Script',
      affectsAiOutput: true,
    );
    final updated = [...chatProvider.globalRegexScripts, newScript];
    chatProvider.setGlobalRegexScripts(updated);
    _openEditDialog(newScript);
  }

  void _deleteScript(RegexScript script) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text('Delete Script?',
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: scaleProvider.systemFontSize)),
        content: Text(
          "Delete '${script.scriptName.isNotEmpty ? script.scriptName : 'Unnamed'}'?\n\nThis cannot be undone.",
          style: TextStyle(
              color: themeProvider.subtitleColor,
              fontSize: scaleProvider.systemFontSize * 0.8),
        ),
        actions: [
          TextButton(
            child: Text('Cancel',
                style:
                    TextStyle(fontSize: scaleProvider.systemFontSize * 0.8)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text('DELETE',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: scaleProvider.systemFontSize * 0.8)),
            onPressed: () {
              final updated = chatProvider.globalRegexScripts
                  .where((s) => s.id != script.id)
                  .toList();
              chatProvider.setGlobalRegexScripts(updated);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _toggleScript(RegexScript script, bool enabled) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final updated = chatProvider.globalRegexScripts
        .map((s) => s.id == script.id ? s.copyWith(enabled: enabled) : s)
        .toList();
    chatProvider.setGlobalRegexScripts(updated);
  }

  // ---------------------------------------------------------------------------
  // Edit dialog
  // ---------------------------------------------------------------------------

  void _openEditDialog(RegexScript script) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // Local mutable copy for the dialog.
    RegexScript editing = script.copyWith();

    final nameCtrl = TextEditingController(text: editing.scriptName);
    final findCtrl = TextEditingController(text: editing.findRegex);
    final replaceCtrl = TextEditingController(text: editing.replaceString);

    // Test panel controllers.
    final testInputCtrl = TextEditingController();
    String testOutput = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final labelStyle = TextStyle(
              color: themeProvider.subtitleColor,
              fontSize: scaleProvider.systemFontSize * 0.8,
            );

            InputDecoration monoInputDeco(String label) => InputDecoration(
                  labelText: label,
                  labelStyle: labelStyle,
                  filled: true,
                  fillColor: themeProvider.containerFillDarkColor,
                  isDense: true,
                  border: const OutlineInputBorder(),
                );

            final monoStyle = TextStyle(
              fontFamily: 'monospace',
              color: themeProvider.textColor,
              fontSize: scaleProvider.systemFontSize * 0.85,
            );

            Future<void> runTest() async {
              final input = testInputCtrl.text;
              if (input.isEmpty) return;
              try {
                final result = await RegexService.apply(
                  text: input,
                  scripts: [
                    editing.copyWith(
                      findRegex: findCtrl.text,
                      replaceString: replaceCtrl.text,
                    )
                  ],
                  target: RegexTarget.aiOutput,
                  macroContext: chatProvider.macroContext,
                );
                setDialogState(() => testOutput = result);
              } catch (e) {
                setDialogState(() => testOutput = 'Error: $e');
              }
            }

            return AlertDialog(
              backgroundColor: themeProvider.dropdownColor,
              title: Text('Edit Regex Script',
                  style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: scaleProvider.systemFontSize)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Name ---
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(
                          color: themeProvider.textColor,
                          fontSize: scaleProvider.systemFontSize * 0.85,
                        ),
                        decoration: monoInputDeco('Script Name'),
                        onChanged: (v) => editing.scriptName = v,
                      ),
                      const SizedBox(height: 10),

                      // --- Find ---
                      TextField(
                        controller: findCtrl,
                        style: monoStyle,
                        decoration: monoInputDeco('Find (regex)'),
                        maxLines: 2,
                        minLines: 1,
                      ),
                      const SizedBox(height: 10),

                      // --- Replace ---
                      TextField(
                        controller: replaceCtrl,
                        style: monoStyle,
                        decoration: monoInputDeco('Replace with'),
                        maxLines: 2,
                        minLines: 1,
                      ),
                      const SizedBox(height: 14),

                      // --- Affects ---
                      Text('Affects', style: labelStyle),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          _dialogCheck(
                              'User Input',
                              editing.affectsUserInput,
                              (v) => setDialogState(
                                  () => editing.affectsUserInput = v ?? false),
                              scaleProvider,
                              themeProvider),
                          _dialogCheck(
                              'AI Output',
                              editing.affectsAiOutput,
                              (v) => setDialogState(
                                  () => editing.affectsAiOutput = v ?? false),
                              scaleProvider,
                              themeProvider),
                          _dialogCheck(
                              'World Info',
                              editing.affectsWorldInfo,
                              (v) => setDialogState(
                                  () => editing.affectsWorldInfo = v ?? false),
                              scaleProvider,
                              themeProvider),
                          _dialogCheck(
                              'Reasoning',
                              editing.affectsReasoning,
                              (v) => setDialogState(
                                  () => editing.affectsReasoning = v ?? false),
                              scaleProvider,
                              themeProvider),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // --- Ephemerality ---
                      Text('Ephemerality', style: labelStyle),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: [
                          _dialogCheck(
                              'Display only',
                              editing.displayOnly,
                              (v) => setDialogState(() {
                                    editing.displayOnly = v ?? false;
                                    if (editing.displayOnly) {
                                      editing.promptOnly = false;
                                    }
                                  }),
                              scaleProvider,
                              themeProvider),
                          _dialogCheck(
                              'Prompt only',
                              editing.promptOnly,
                              (v) => setDialogState(() {
                                    editing.promptOnly = v ?? false;
                                    if (editing.promptOnly) {
                                      editing.displayOnly = false;
                                    }
                                  }),
                              scaleProvider,
                              themeProvider),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // --- Regex Flags ---
                      Text('Regex Flags', style: labelStyle),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          _flagChip(
                              'i',
                              editing.caseInsensitive,
                              (v) => setDialogState(
                                  () => editing.caseInsensitive = v),
                              themeProvider,
                              scaleProvider),
                          _flagChip(
                              's',
                              editing.dotAll,
                              (v) =>
                                  setDialogState(() => editing.dotAll = v),
                              themeProvider,
                              scaleProvider),
                          _flagChip(
                              'm',
                              editing.multiLine,
                              (v) => setDialogState(
                                  () => editing.multiLine = v),
                              themeProvider,
                              scaleProvider),
                          _flagChip(
                              'u',
                              editing.unicode,
                              (v) =>
                                  setDialogState(() => editing.unicode = v),
                              themeProvider,
                              scaleProvider),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // --- Macro mode + Scope ---
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Macro Mode', style: labelStyle),
                                const SizedBox(height: 4),
                                _dropdownField<RegexMacroMode>(
                                  value: editing.macroMode,
                                  items: RegexMacroMode.values,
                                  labelOf: (m) => m.name,
                                  onChanged: (v) => setDialogState(() =>
                                      editing.macroMode =
                                          v ?? RegexMacroMode.none),
                                  themeProvider: themeProvider,
                                  scaleProvider: scaleProvider,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scope', style: labelStyle),
                                const SizedBox(height: 4),
                                _dropdownField<RegexScope>(
                                  value: editing.scope,
                                  items: RegexScope.values,
                                  labelOf: (s) => s.name,
                                  onChanged: (v) => setDialogState(() =>
                                      editing.scope =
                                          v ?? RegexScope.scoped),
                                  themeProvider: themeProvider,
                                  scaleProvider: scaleProvider,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // --- Depth Range ---
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              style: monoStyle,
                              decoration: monoInputDeco('Min Depth'),
                              controller: TextEditingController(
                                  text: editing.minDepth.toString()),
                              onChanged: (v) =>
                                  editing.minDepth = int.tryParse(v) ?? 0,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              style: monoStyle,
                              decoration: monoInputDeco('Max Depth'),
                              controller: TextEditingController(
                                  text: editing.maxDepth.toString()),
                              onChanged: (v) =>
                                  editing.maxDepth =
                                      int.tryParse(v) ?? -1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // --- Trim Strings ---
                      Text('Trim Strings', style: labelStyle),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ...editing.trimStrings.asMap().entries.map((e) {
                            return InputChip(
                              label: Text(e.value,
                                  style: TextStyle(
                                      fontSize:
                                          scaleProvider.systemFontSize * 0.7,
                                      color: themeProvider.textColor)),
                              backgroundColor:
                                  themeProvider.containerFillColor,
                              deleteIconColor: Colors.redAccent,
                              onDeleted: () {
                                setDialogState(() {
                                  editing.trimStrings.removeAt(e.key);
                                });
                              },
                            );
                          }),
                          ActionChip(
                            label: Icon(Icons.add,
                                size: 14, color: themeProvider.textColor),
                            backgroundColor:
                                themeProvider.containerFillColor,
                            onPressed: () => _addTrimString(
                                setDialogState,
                                editing,
                                themeProvider,
                                scaleProvider),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Divider(color: themeProvider.borderColor),

                      // --- Test Panel ---
                      Text('Test', style: labelStyle),
                      const SizedBox(height: 6),
                      TextField(
                        controller: testInputCtrl,
                        style: monoStyle,
                        maxLines: 2,
                        minLines: 1,
                        decoration: monoInputDeco('Sample input'),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: Text('Run',
                              style: TextStyle(
                                  fontSize:
                                      scaleProvider.systemFontSize * 0.8)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          onPressed: runTest,
                        ),
                      ),
                      if (testOutput.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeProvider.containerFillDarkColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            testOutput,
                            style: monoStyle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel',
                      style: TextStyle(
                          fontSize: scaleProvider.systemFontSize * 0.8)),
                  onPressed: () => Navigator.pop(ctx),
                ),
                TextButton(
                  child: Text('Save',
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: scaleProvider.systemFontSize * 0.8)),
                  onPressed: () {
                    editing.scriptName = nameCtrl.text.trim();
                    editing.findRegex = findCtrl.text;
                    editing.replaceString = replaceCtrl.text;
                    final updated = chatProvider.globalRegexScripts
                        .map((s) => s.id == editing.id ? editing : s)
                        .toList();
                    chatProvider.setGlobalRegexScripts(updated);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Small add-trim-string dialog within the edit dialog.
  void _addTrimString(
    StateSetter setDialogState,
    RegexScript editing,
    ThemeProvider themeProvider,
    ScaleProvider scaleProvider,
  ) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text('Add Trim String',
            style: TextStyle(
                color: themeProvider.textColor,
                fontSize: scaleProvider.systemFontSize)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
              color: themeProvider.textColor,
              fontSize: scaleProvider.systemFontSize * 0.85),
          decoration: InputDecoration(
            hintText: 'String to trim before matching',
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
          ),
        ),
        actions: [
          TextButton(
              child: Text('Cancel',
                  style: TextStyle(
                      fontSize: scaleProvider.systemFontSize * 0.8)),
              onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: Text('Add',
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: scaleProvider.systemFontSize * 0.8)),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setDialogState(() => editing.trimStrings.add(val));
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Import / Export
  // ---------------------------------------------------------------------------

  Future<void> _handleImport() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      List<RegexScript> imported = [];
      if (decoded is List) {
        imported = decoded
            .map((e) => RegexScript.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else if (decoded is Map) {
        imported = [
          RegexScript.fromJson(Map<String, dynamic>.from(decoded))
        ];
      }

      if (imported.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid regex scripts found.')),
          );
        }
        return;
      }

      // Assign unique IDs to avoid collisions.
      final base = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < imported.length; i++) {
        imported[i] = imported[i].copyWith(id: base + i);
      }

      final merged = [...chatProvider.globalRegexScripts, ...imported];
      chatProvider.setGlobalRegexScripts(merged);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Imported ${imported.length} regex script(s).')),
        );
      }
    } catch (e) {
      debugPrint('Regex import failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final scripts = chatProvider.globalRegexScripts;
    if (scripts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No scripts to export.')),
        );
      }
      return;
    }

    try {
      final jsonStr = const JsonEncoder.withIndent('  ')
          .convert(scripts.map((s) => s.toJson()).toList());
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Regex Scripts',
        fileName: 'regex_scripts.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: bytes,
      );

      if (outputFile != null) {
        await File(outputFile).writeAsString(jsonStr);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to $outputFile')),
          );
        }
      }
    } catch (e) {
      debugPrint('Regex export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Reusable dialog widgets
  // ---------------------------------------------------------------------------

  Widget _dialogCheck(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
    ScaleProvider scaleProvider,
    ThemeProvider themeProvider,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          width: 24,
          child: Checkbox(
            value: value,
            activeColor: Colors.blueAccent,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        Text(label,
            style: TextStyle(
                color: themeProvider.textColor,
                fontSize: scaleProvider.systemFontSize * 0.75)),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _flagChip(
    String label,
    bool selected,
    ValueChanged<bool> onSelected,
    ThemeProvider themeProvider,
    ScaleProvider scaleProvider,
  ) {
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: scaleProvider.systemFontSize * 0.8,
              color:
                  selected ? Colors.white : themeProvider.subtitleColor)),
      selected: selected,
      selectedColor: Colors.blueAccent,
      backgroundColor: themeProvider.containerFillColor,
      checkmarkColor: Colors.white,
      onSelected: onSelected,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _dropdownField<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
    required ThemeProvider themeProvider,
    required ScaleProvider scaleProvider,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: themeProvider.containerFillDarkColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: themeProvider.dropdownColor,
        underline: const SizedBox(),
        style: TextStyle(
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize * 0.8),
        items: items.map((i) {
          return DropdownMenuItem<T>(
            value: i,
            child: Text(labelOf(i)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    final globalScripts = chatProvider.globalRegexScripts;
    final charScripts = chatProvider.characterRegexScripts;
    final enabled = chatProvider.enableRegex;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: Container(
          decoration: BoxDecoration(
            color: themeProvider.containerFillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeProvider.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Import / Export / Add ---
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleImport,
                        icon: const Icon(Icons.arrow_downward, size: 14),
                        label: Text('Import',
                            style: TextStyle(
                                fontSize:
                                    scaleProvider.systemFontSize * 0.8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleExport,
                        icon: const Icon(Icons.arrow_upward, size: 14),
                        label: Text('Export',
                            style: TextStyle(
                                fontSize:
                                    scaleProvider.systemFontSize * 0.8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: Colors.greenAccent, size: 22),
                      tooltip: 'Add Script',
                      onPressed: _addScript,
                    ),
                  ],
                ),
              ),

              Divider(color: themeProvider.borderColor, height: 1),

              // --- Global Scripts List ---
              if (globalScripts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.find_replace,
                          size: 48, color: themeProvider.faintColor),
                      const SizedBox(height: 12),
                      Text('No global regex scripts defined.',
                          style: TextStyle(
                              color: themeProvider.faintColor,
                              fontSize:
                                  scaleProvider.systemFontSize * 0.9),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(
                        'Tap + to add one, or import from a JSON file.',
                        style: TextStyle(
                            color: themeProvider.faintestColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.7),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              if (globalScripts.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: globalScripts.length,
                  onReorder: (oldIdx, newIdx) => _onReorder(
                      oldIdx, newIdx, List.from(globalScripts)),
                  itemBuilder: (ctx, index) {
                    final script = globalScripts[index];
                    return ListTile(
                      key: ValueKey(script.id),
                      dense: true,
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Icon(Icons.drag_handle,
                            color: themeProvider.faintColor, size: 18),
                      ),
                      title: Text(
                        script.scriptName.isNotEmpty
                            ? script.scriptName
                            : 'Unnamed Script',
                        style: TextStyle(
                            color: themeProvider.subtitleColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.8),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_affectsSummary(script)}${_ephemeralBadge(script)}',
                        style: TextStyle(
                            color: themeProvider.faintColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.65),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.close,
                                color: themeProvider.faintestColor,
                                size: 16),
                            onPressed: () => _deleteScript(script),
                          ),
                          Switch(
                            value: script.enabled,
                            activeThumbColor: Colors.blueAccent,
                            onChanged: (v) =>
                                _toggleScript(script, v),
                          ),
                        ],
                      ),
                      onTap: () => _openEditDialog(script),
                    );
                  },
                ),

              // --- Character-Scoped Scripts (read-only) ---
              if (charScripts.isNotEmpty) ...[
                Divider(color: themeProvider.borderColor, height: 1),
                ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(
                    'Character Scripts (${charScripts.length})',
                    style: TextStyle(
                      color: themeProvider.subtitleColor,
                      fontSize: scaleProvider.systemFontSize * 0.8,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  collapsedIconColor: themeProvider.faintColor,
                  iconColor: themeProvider.faintColor,
                  children: charScripts.map((s) {
                    return ListTile(
                      dense: true,
                      enabled: false,
                      title: Text(
                        s.scriptName.isNotEmpty
                            ? s.scriptName
                            : 'Unnamed',
                        style: TextStyle(
                            color: themeProvider.faintColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.75),
                      ),
                      subtitle: Text(
                        'From character card \u00b7 ${_affectsSummary(s)}',
                        style: TextStyle(
                            color: themeProvider.faintestColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.6),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
