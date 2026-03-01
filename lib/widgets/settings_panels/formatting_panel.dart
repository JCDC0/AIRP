import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/formatting_models.dart';
import '../../services/formatting_service.dart';

/// Panel for managing the active [FormattingTemplate] and its rules.
///
/// Provides template-level controls (load default, clear, import/export)
/// and a per-rule editor for label, type, pattern, and template strings.
/// Reads and writes state via [ChatProvider.formattingTemplate] and
/// [ChatProvider.setFormattingTemplate].
class FormattingPanel extends StatefulWidget {
  const FormattingPanel({super.key});

  @override
  State<FormattingPanel> createState() => _FormattingPanelState();
}

class _FormattingPanelState extends State<FormattingPanel> {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns an icon for each rule type.
  IconData _typeIcon(FormattingRuleType type) {
    switch (type) {
      case FormattingRuleType.dialogue:
        return Icons.format_quote;
      case FormattingRuleType.thought:
        return Icons.psychology;
      case FormattingRuleType.narration:
        return Icons.menu_book;
      case FormattingRuleType.characterName:
        return Icons.person;
      case FormattingRuleType.custom:
        return Icons.tune;
    }
  }

  // ---------------------------------------------------------------------------
  // Template-level actions
  // ---------------------------------------------------------------------------

  void _loadDefault() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider
        .setFormattingTemplate(FormattingService.defaultTemplate().copyWith(enabled: true));
  }

  void _clearTemplate() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text('Clear Template?',
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: scaleProvider.systemFontSize)),
        content: Text(
          'This will remove all formatting rules.\n\nThis cannot be undone.',
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
            child: Text('CLEAR',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: scaleProvider.systemFontSize * 0.8)),
            onPressed: () {
              chatProvider.setFormattingTemplate(null);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rule CRUD
  // ---------------------------------------------------------------------------

  void _addRule() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    var template = chatProvider.formattingTemplate ??
        FormattingTemplate(name: 'Custom', enabled: true);

    final newRule = FormattingRule(
      id: DateTime.now().millisecondsSinceEpoch,
      label: 'New Rule',
      type: FormattingRuleType.custom,
      template: '{{match}}',
      sortOrder: template.rules.length,
    );
    template = template.copyWith(rules: [...template.rules, newRule]);
    chatProvider.setFormattingTemplate(template);
    _openRuleEditDialog(newRule);
  }

  void _deleteRule(FormattingRule rule) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final template = chatProvider.formattingTemplate;
    if (template == null) return;

    final updated = template.copyWith(
      rules: template.rules.where((r) => r.id != rule.id).toList(),
    );
    chatProvider.setFormattingTemplate(updated);
  }

  void _toggleRule(FormattingRule rule, bool enabled) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final template = chatProvider.formattingTemplate;
    if (template == null) return;

    final updated = template.copyWith(
      rules: template.rules
          .map((r) => r.id == rule.id ? r.copyWith(enabled: enabled) : r)
          .toList(),
    );
    chatProvider.setFormattingTemplate(updated);
  }

  void _onReorderRules(int oldIndex, int newIndex) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final template = chatProvider.formattingTemplate;
    if (template == null) return;

    if (newIndex > oldIndex) newIndex--;
    final rules = List<FormattingRule>.from(template.rules);
    final moved = rules.removeAt(oldIndex);
    rules.insert(newIndex, moved);
    for (int i = 0; i < rules.length; i++) {
      rules[i] = rules[i].copyWith(sortOrder: i);
    }
    chatProvider.setFormattingTemplate(template.copyWith(rules: rules));
  }

  // ---------------------------------------------------------------------------
  // Rule edit dialog
  // ---------------------------------------------------------------------------

  void _openRuleEditDialog(FormattingRule rule) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    FormattingRule editing = rule.copyWith();
    final labelCtrl = TextEditingController(text: editing.label);
    final patternCtrl = TextEditingController(text: editing.pattern);
    final templateCtrl = TextEditingController(text: editing.template);

    // Preview controllers
    final previewInputCtrl = TextEditingController();
    String previewOutput = '';

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

            Future<void> runPreview() async {
              final input = previewInputCtrl.text;
              if (input.isEmpty) return;
              try {
                final testRule = editing.copyWith(
                  pattern: patternCtrl.text,
                  template: templateCtrl.text,
                );
                final result = await FormattingService.applySingleRule(
                  input,
                  testRule,
                  macroContext: chatProvider.macroContext,
                );
                setDialogState(() => previewOutput = result);
              } catch (e) {
                setDialogState(() => previewOutput = 'Error: $e');
              }
            }

            return AlertDialog(
              backgroundColor: themeProvider.dropdownColor,
              title: Text('Edit Formatting Rule',
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
                      // --- Label ---
                      TextField(
                        controller: labelCtrl,
                        style: TextStyle(
                          color: themeProvider.textColor,
                          fontSize: scaleProvider.systemFontSize * 0.85,
                        ),
                        decoration: monoInputDeco('Rule Label'),
                      ),
                      const SizedBox(height: 10),

                      // --- Type dropdown ---
                      Text('Type', style: labelStyle),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: themeProvider.containerFillDarkColor,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: themeProvider.borderColor),
                        ),
                        child: DropdownButton<FormattingRuleType>(
                          value: editing.type,
                          isExpanded: true,
                          dropdownColor: themeProvider.dropdownColor,
                          underline: const SizedBox(),
                          style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize:
                                  scaleProvider.systemFontSize * 0.8),
                          items: FormattingRuleType.values.map((t) {
                            return DropdownMenuItem<FormattingRuleType>(
                              value: t,
                              child: Row(
                                children: [
                                  Icon(_typeIcon(t),
                                      size: 16,
                                      color: themeProvider.subtitleColor),
                                  const SizedBox(width: 8),
                                  Text(t.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setDialogState(
                              () => editing.type = v ?? editing.type),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // --- Pattern ---
                      TextField(
                        controller: patternCtrl,
                        style: monoStyle,
                        decoration: monoInputDeco('Pattern (regex)'),
                        maxLines: 2,
                        minLines: 1,
                      ),
                      const SizedBox(height: 10),

                      // --- Template ---
                      TextField(
                        controller: templateCtrl,
                        style: monoStyle,
                        decoration:
                            monoInputDeco('Template (use {{match}})'),
                        maxLines: 2,
                        minLines: 1,
                      ),

                      const SizedBox(height: 16),
                      Divider(color: themeProvider.borderColor),

                      // --- Preview Panel ---
                      Text('Preview', style: labelStyle),
                      const SizedBox(height: 6),
                      TextField(
                        controller: previewInputCtrl,
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
                          onPressed: runPreview,
                        ),
                      ),
                      if (previewOutput.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeProvider.containerFillDarkColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            previewOutput,
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
                    editing.label = labelCtrl.text.trim();
                    editing.pattern = patternCtrl.text;
                    editing.template = templateCtrl.text;

                    final template = chatProvider.formattingTemplate;
                    if (template != null) {
                      final updated = template.copyWith(
                        rules: template.rules
                            .map(
                                (r) => r.id == editing.id ? editing : r)
                            .toList(),
                      );
                      chatProvider.setFormattingTemplate(updated);
                    }
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

      if (decoded is! Map) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid formatting template file.')),
          );
        }
        return;
      }

      final imported =
          FormattingTemplate.fromJson(Map<String, dynamic>.from(decoded));
      imported.enabled = true;
      chatProvider.setFormattingTemplate(imported);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Imported template '${imported.name}' (${imported.rules.length} rules).")),
        );
      }
    } catch (e) {
      debugPrint('Template import failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final template = chatProvider.formattingTemplate;
    if (template == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No template to export.')),
        );
      }
      return;
    }

    try {
      final jsonStr = const JsonEncoder.withIndent('  ')
          .convert(template.toJson());
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Formatting Template',
        fileName: '${template.name.isNotEmpty ? template.name : "template"}.json',
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
      debugPrint('Template export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    final template = chatProvider.formattingTemplate;
    final enabled = chatProvider.enableFormatting;
    final rules = template?.rules ?? [];

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
              // --- Template Controls ---
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Template name
                    if (template != null && template.name.isNotEmpty)
                      Text(
                        template.name,
                        style: TextStyle(
                          color: themeProvider.textColor,
                          fontSize: scaleProvider.systemFontSize * 0.9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (template != null && template.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          template.description,
                          style: TextStyle(
                            color: themeProvider.faintColor,
                            fontSize: scaleProvider.systemFontSize * 0.7,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Action buttons row 1
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loadDefault,
                            icon: const Icon(Icons.restore, size: 14),
                            label: Text('Default',
                                style: TextStyle(
                                    fontSize:
                                        scaleProvider.systemFontSize * 0.8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearTemplate,
                            icon: Icon(Icons.clear, size: 14,
                                color: template != null
                                    ? Colors.redAccent
                                    : null),
                            label: Text('Clear',
                                style: TextStyle(
                                    fontSize:
                                        scaleProvider.systemFontSize * 0.8,
                                    color: template != null
                                        ? Colors.redAccent
                                        : null)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Action buttons row 2
                    Row(
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
                          tooltip: 'Add Rule',
                          onPressed: _addRule,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Divider(color: themeProvider.borderColor, height: 1),

              // --- Rules List ---
              if (rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.text_format,
                          size: 48, color: themeProvider.faintColor),
                      const SizedBox(height: 12),
                      Text('No formatting rules defined.',
                          style: TextStyle(
                              color: themeProvider.faintColor,
                              fontSize:
                                  scaleProvider.systemFontSize * 0.9),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(
                        'Load the default template or add rules manually.',
                        style: TextStyle(
                            color: themeProvider.faintestColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.7),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              if (rules.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: rules.length,
                  onReorder: _onReorderRules,
                  itemBuilder: (ctx, index) {
                    final rule = rules[index];
                    return ListTile(
                      key: ValueKey(rule.id),
                      dense: true,
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Icon(Icons.drag_handle,
                            color: themeProvider.faintColor, size: 18),
                      ),
                      title: Row(
                        children: [
                          Icon(_typeIcon(rule.type),
                              size: 14,
                              color: themeProvider.subtitleColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rule.label.isNotEmpty
                                  ? rule.label
                                  : 'Unnamed Rule',
                              style: TextStyle(
                                  color: themeProvider.subtitleColor,
                                  fontSize:
                                      scaleProvider.systemFontSize * 0.8),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        rule.type.name,
                        style: TextStyle(
                            color: themeProvider.faintColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.65),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.close,
                                color: themeProvider.faintestColor,
                                size: 16),
                            onPressed: () => _deleteRule(rule),
                          ),
                          Switch(
                            value: rule.enabled,
                            activeThumbColor: Colors.blueAccent,
                            onChanged: (v) => _toggleRule(rule, v),
                          ),
                        ],
                      ),
                      onTap: () => _openRuleEditDialog(rule),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
