import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/preset_model.dart';
import '../../services/library_service.dart';

/// A panel for managing custom rules and importable presets.
///
/// Custom rules are toggle-able text directives that are concatenated into the
/// "advanced prompt" and injected alongside the main system prompt. Presets
/// bundle a system prompt, advanced prompt, generation settings, and custom
/// rules into a single importable/exportable JSON file.
class PresetPanel extends StatefulWidget {
  /// Controller for the main system prompt text (read by presets on apply).
  final TextEditingController mainPromptController;

  /// Controller for the compiled advanced prompt output.
  final TextEditingController advancedPromptController;

  /// Controller for the title of the current prompt preset.
  final TextEditingController promptTitleController;

  /// Callback triggered when prompt content changes.
  final VoidCallback onPromptChanged;

  const PresetPanel({
    super.key,
    required this.mainPromptController,
    required this.advancedPromptController,
    required this.promptTitleController,
    required this.onPromptChanged,
  });

  @override
  State<PresetPanel> createState() => _PresetPanelState();
}

class _PresetPanelState extends State<PresetPanel> {
  late TextEditingController _ruleLabelController;
  late TextEditingController _newRuleContentController;

  /// The list of custom rules managed in this panel.
  List<Map<String, dynamic>> _customRules = [];

  /// SharedPreferences key for custom rules (normalised to airp_ prefix).
  static const String kCustomRulesKey = 'airp_custom_rules';

  /// Legacy key — used for one-time migration on first load.
  static const String _kLegacyCustomRulesKey = 'custom_sys_prompt_rules';

  @override
  void initState() {
    super.initState();
    _ruleLabelController = TextEditingController();
    _newRuleContentController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomRules();
    });
  }

  @override
  void dispose() {
    _ruleLabelController.dispose();
    _newRuleContentController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Loads custom rules from SharedPreferences, migrating from the legacy key
  /// if needed.
  Future<void> _loadCustomRules() async {
    final prefs = await SharedPreferences.getInstance();

    // Try the new key first.
    String? jsonString = prefs.getString(kCustomRulesKey);

    // One-time migration from legacy key.
    if (jsonString == null) {
      jsonString = prefs.getString(_kLegacyCustomRulesKey);
      if (jsonString != null) {
        await prefs.setString(kCustomRulesKey, jsonString);
        await prefs.remove(_kLegacyCustomRulesKey);
      }
    }

    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _customRules =
            decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint("Error loading custom rules: $e");
      }
    }

    if (mounted) {
      setState(() {
        _rebuildAdvancedPrompt();
      });
    }
  }

  Future<void> _saveCustomRulesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_customRules);
    await prefs.setString(kCustomRulesKey, encoded);
  }

  /// Rebuilds the advanced prompt controller text from active rules.
  void _rebuildAdvancedPrompt() {
    final List<String> activePrompts = [];
    for (final rule in _customRules) {
      if (rule['active'] == true) {
        activePrompts.add((rule['content'] as String).trim());
      }
    }
    widget.advancedPromptController.text = activePrompts.join('\n\n');
    widget.onPromptChanged();
  }

  // ---------------------------------------------------------------------------
  // Import / Export
  // ---------------------------------------------------------------------------

  Future<void> _handleImportPreset() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final jsonMap = jsonDecode(content);
        final preset = SystemPreset.fromJson(jsonMap);

        widget.promptTitleController.text = preset.name;
        widget.mainPromptController.text = preset.systemPrompt;

        // Merge rules — add any new rules from the preset.
        final List<Map<String, dynamic>> currentRules = [..._customRules];
        final existingLabels = currentRules.map((r) => r['label']).toSet();

        for (final rule in preset.customRules) {
          if (!existingLabels.contains(rule['label'])) {
            currentRules.add(rule);
            existingLabels.add(rule['label']);
          }
        }

        setState(() {
          _customRules = currentRules;
          _saveCustomRulesToPrefs();
          _rebuildAdvancedPrompt();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Imported preset '${preset.name}'!")),
          );
        }
      }
    } catch (e) {
      debugPrint("Import preset failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import failed: $e")),
        );
      }
    }
  }

  /// Exports the current system prompt + rules as a preset JSON file.
  ///
  /// FIX: Previously called LibraryService.exportPreset twice. Now serialises
  /// once and reuses the result for both FilePicker and manual file write.
  Future<void> _handleExportPreset() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final preset = SystemPreset(
      name: widget.promptTitleController.text.isNotEmpty
          ? widget.promptTitleController.text
          : "Untitled Preset",
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

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Preset',
        fileName:
            '${preset.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: bytes,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonStr);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Exported to $outputFile")),
          );
        }
      }
    } catch (e) {
      debugPrint("Export failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Rule CRUD
  // ---------------------------------------------------------------------------

  void _addRuleFromInput() {
    final text = _newRuleContentController.text.trim();
    if (text.isEmpty) return;

    final String label = _ruleLabelController.text.trim().isNotEmpty
        ? _ruleLabelController.text.trim()
        : (text.length > 25 ? "${text.substring(0, 25)}..." : text);

    setState(() {
      _customRules.add({'content': text, 'active': true, 'label': label});
      _newRuleContentController.clear();
      _ruleLabelController.clear();
      _saveCustomRulesToPrefs();
      _rebuildAdvancedPrompt();
    });
  }

  void _editCustomRule(int index) {
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final rule = _customRules[index];
    final labelController = TextEditingController(text: rule['label']);
    final contentController = TextEditingController(text: rule['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text("Edit Rule",
            style: TextStyle(
                color: themeProvider.textColor,
                fontSize: scaleProvider.systemFontSize)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: InputDecoration(
                labelText: "Rule Name",
                filled: true,
                fillColor: themeProvider.containerFillDarkColor,
              ),
              style: TextStyle(
                  color: themeProvider.textColor,
                  fontSize: scaleProvider.systemFontSize * 0.8),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Rule Content",
                filled: true,
                fillColor: themeProvider.containerFillDarkColor,
              ),
              style: TextStyle(
                  color: themeProvider.textColor,
                  fontSize: scaleProvider.systemFontSize * 0.8),
            ),
          ],
        ),
        actions: [
          TextButton(
              child: Text("Cancel",
                  style: TextStyle(
                      fontSize: scaleProvider.systemFontSize * 0.8)),
              onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text("Save",
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: scaleProvider.systemFontSize * 0.8)),
            onPressed: () {
              setState(() {
                _customRules[index]['label'] = labelController.text.trim();
                _customRules[index]['content'] =
                    contentController.text.trim();
                _saveCustomRulesToPrefs();
                if (_customRules[index]['active'] == true) {
                  _rebuildAdvancedPrompt();
                }
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomRule(int index) {
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final rule = _customRules[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text("Delete Rule?",
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: scaleProvider.systemFontSize)),
        content: Text(
          "Are you sure you want to delete '${rule['label']}'?\n\nThis cannot be undone.",
          style: TextStyle(
              color: themeProvider.subtitleColor,
              fontSize: scaleProvider.systemFontSize * 0.8),
        ),
        actions: [
          TextButton(
              child: Text("Cancel",
                  style: TextStyle(
                      fontSize: scaleProvider.systemFontSize * 0.8)),
              onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text("DELETE",
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: scaleProvider.systemFontSize * 0.8)),
            onPressed: () {
              _deleteCustomRuleForever(index);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _deleteCustomRuleForever(int index) {
    setState(() {
      bool wasActive = _customRules[index]['active'] == true;
      _customRules.removeAt(index);
      _saveCustomRulesToPrefs();
      if (wasActive) _rebuildAdvancedPrompt();
    });
  }

  // ---------------------------------------------------------------------------
  // Clipboard helpers
  // ---------------------------------------------------------------------------

  void _copyRuleContentToClipboard() {
    final text = _newRuleContentController.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Copied rule to Clipboard!"),
          duration: Duration(milliseconds: 600),
        ),
      );
    }
  }

  Future<void> _pasteRuleContentFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _newRuleContentController.text = data!.text!;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Opacity(
      opacity: chatProvider.enableAdvancedSystemPrompt ? 1.0 : 0.5,
      child: AbsorbPointer(
        absorbing: !chatProvider.enableAdvancedSystemPrompt,
        child: Container(
          decoration: BoxDecoration(
            color: themeProvider.containerFillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeProvider.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Import / Export Buttons ---
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleImportPreset,
                        icon: const Icon(Icons.arrow_downward, size: 14),
                        label: Text("Import",
                            style: TextStyle(
                                fontSize:
                                    scaleProvider.systemFontSize * 0.8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleExportPreset,
                        icon: const Icon(Icons.arrow_upward, size: 14),
                        label: Text("Export",
                            style: TextStyle(
                                fontSize:
                                    scaleProvider.systemFontSize * 0.8)),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: themeProvider.borderColor, height: 1),

              // --- Rule list ---
              if (_customRules.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No custom rules defined.",
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center),
                ),

              ..._customRules.asMap().entries.map((entry) {
                final int index = entry.key;
                final Map<String, dynamic> rule = entry.value;

                return ListTile(
                  dense: true,
                  title: Text(
                    rule['label'],
                    style: TextStyle(
                        color: themeProvider.subtitleColor,
                        fontSize: scaleProvider.systemFontSize * 0.8),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    (rule['content'] as String).replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: themeProvider.faintColor, fontSize: 10),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.edit,
                        color: Colors.blueAccent, size: 16),
                    onPressed: () => _editCustomRule(index),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close,
                            color: themeProvider.faintestColor, size: 16),
                        onPressed: () => _confirmDeleteCustomRule(index),
                      ),
                      Switch(
                        value: rule['active'] == true,
                        activeThumbColor: Colors.blueAccent,
                        onChanged: (val) {
                          setState(() {
                            rule['active'] = val;
                            _rebuildAdvancedPrompt();
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),

              Divider(color: themeProvider.borderColor),

              // --- Add New Rule ---
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _ruleLabelController,
                      decoration: InputDecoration(
                        labelText: "Rule Name",
                        hintText: "Name",
                        isDense: true,
                        filled: true,
                        fillColor: themeProvider.containerFillDarkColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newRuleContentController,
                      maxLines: 8,
                      minLines: 3,
                      decoration: InputDecoration(
                        labelText: "New Rule Content",
                        hintText: "Enter custom rule content...",
                        hintStyle: TextStyle(
                            fontSize: scaleProvider.systemFontSize * 0.8),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: themeProvider.containerFillColor,
                      ),
                      style: TextStyle(fontSize: scaleProvider.systemFontSize),
                      onSubmitted: (_) => _addRuleFromInput(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.copy_rounded,
                              size: 18, color: themeProvider.textColor),
                          onPressed: _copyRuleContentToClipboard,
                          tooltip: 'Copy Rule Content',
                          padding: const EdgeInsets.all(8),
                        ),
                        IconButton(
                          icon: const Icon(Icons.paste,
                              size: 18, color: Colors.greenAccent),
                          onPressed: _pasteRuleContentFromClipboard,
                          tooltip: 'Paste Rule Content',
                          padding: const EdgeInsets.all(8),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              size: 20, color: Colors.greenAccent),
                          onPressed: _addRuleFromInput,
                          tooltip: 'Add Rule',
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- Preview ---
              ExpansionTile(
                title: const Text("View Generated Advanced Prompt",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: widget.advancedPromptController,
                      readOnly: true,
                      maxLines: 5,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: themeProvider.containerFillDarkColor,
                        border: const OutlineInputBorder(),
                      ),
                      style: TextStyle(
                          fontSize: 12,
                          color: themeProvider.subtitleColor),
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
}
