import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';
import '../../models/character_card.dart';
import '../../models/preset_model.dart';
import '../../services/character_card_service.dart';
import '../../services/library_service.dart';

/// A panel for configuring the AI's system instruction and advanced prompts.
///
/// This panel supports preset library selection, custom behavioral tweaks,
/// and kaomoji emotion filters.
class SystemPromptPanel extends StatefulWidget {
  /// Controller for the main system instruction text.
  final TextEditingController mainPromptController;

  /// Controller for advanced behavioral instructions.
  final TextEditingController advancedPromptController;

  /// Controller for the title of the current prompt preset.
  final TextEditingController promptTitleController;

  /// Callback triggered when any prompt content changes.
  final VoidCallback onPromptChanged;

  const SystemPromptPanel({
    super.key,
    required this.mainPromptController,
    required this.advancedPromptController,
    required this.promptTitleController,
    required this.onPromptChanged,
  });

  @override
  State<SystemPromptPanel> createState() => _SystemPromptPanelState();
}

class _SystemPromptPanelState extends State<SystemPromptPanel> {
  late TextEditingController _ruleLabelController;
  late TextEditingController _newRuleContentController;
  
  // Character Card Controllers
  late TextEditingController _cardNameController;
  late TextEditingController _cardDescriptionController;
  late TextEditingController _cardPersonalityController;
  late TextEditingController _cardScenarioController;
  late TextEditingController _cardFirstMesController;
  late TextEditingController _cardMesExampleController;
  late TextEditingController _cardSystemPromptController;

  List<Map<String, dynamic>> _customRules = [];

  // _isKaomojiFixEnabled removed - migrated to custom rules

  static const String kDefaultKaomojiFix =
      "Use kaomoji for spoken character (e.g. OwO, ^_^) frequently in character dialogue to convey emotion for spoken characters only. (Except if the character is only you)";
  static const String kCustomRulesKey = "custom_sys_prompt_rules";
  static const String kKaomojiMigratedKey = "kaomoji_migrated_v2";


  Timer? _cardSaveTimer; 

  @override
  void initState() {
    super.initState();
    _ruleLabelController = TextEditingController();
    _newRuleContentController = TextEditingController();
    
    _cardNameController = TextEditingController();
    _cardDescriptionController = TextEditingController();
    _cardPersonalityController = TextEditingController();
    _cardScenarioController = TextEditingController();
    _cardFirstMesController = TextEditingController();
    _cardMesExampleController = TextEditingController();
    _cardSystemPromptController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      _updateCardControllers(chatProvider.characterCard);
      
      String fullPrompt = chatProvider.systemInstruction;
      if (chatProvider.advancedSystemInstruction.isNotEmpty) {
        if (fullPrompt.isNotEmpty) fullPrompt += "\n\n";
        fullPrompt += chatProvider.advancedSystemInstruction;
      }
      _loadCustomRulesAndParse(fullPrompt);
      _migrateKaomoji();
    });
  }

  void _updateCardControllers(CharacterCard card) {
    _cardNameController.text = card.name;
    _cardDescriptionController.text = card.description;
    _cardPersonalityController.text = card.personality;
    _cardScenarioController.text = card.scenario;
    _cardFirstMesController.text = card.firstMessage;
    _cardMesExampleController.text = card.mesExample;
    _cardSystemPromptController.text = card.systemPrompt;
  }
  

  
  Future<void> _migrateKaomoji() async {
    final prefs = await SharedPreferences.getInstance();
    final bool migrated = prefs.getBool(kKaomojiMigratedKey) ?? false;
    
    if (!migrated) {
      // Ensure legacy kaomoji settings are migrated to the new rules system.
      
      await prefs.setBool(kKaomojiMigratedKey, true);
    }
  }

  @override
  void dispose() {
    _ruleLabelController.dispose();
    _newRuleContentController.dispose();
    _cardNameController.dispose();
    _cardDescriptionController.dispose();
    _cardPersonalityController.dispose();
    _cardScenarioController.dispose();
    _cardFirstMesController.dispose();
    _cardMesExampleController.dispose();
    _cardSystemPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomRulesAndParse(String systemInstruction) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(kCustomRulesKey);

    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _customRules = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (e) {
        debugPrint("Error loading custom rules: $e");
      }
    }

    if (mounted) {
      setState(() {
        _parseSystemInstruction(systemInstruction);
      });
    }
  }

  Future<void> _saveCustomRulesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_customRules);
    await prefs.setString(kCustomRulesKey, encoded);
  }

  void _parseSystemInstruction(String fullPrompt, {bool updateMain = true, bool updateRules = true}) {
    String workingText = fullPrompt;
    String advancedVisualText = "";

    // Check for Kaomoji text and migrate if needed
    if (workingText.contains(kDefaultKaomojiFix.trim())) {
      // Check if we already have a rule for this
      bool hasKaomojiRule = _customRules.any((r) => r['content'] == kDefaultKaomojiFix.trim());
      
      if (!hasKaomojiRule) {
        // Auto-create the rule
        _customRules.add({
          'label': 'Kaomoji Mode (Legacy)',
          'content': kDefaultKaomojiFix.trim(),
          'active': true
        });
        _saveCustomRulesToPrefs();
      }
      
      workingText = workingText.replaceFirst(kDefaultKaomojiFix.trim(), "");
    }

    for (var rule in _customRules) {
      final content = rule['content'] as String;
      if (workingText.contains(content.trim())) {
        if (updateRules) rule['active'] = true;
        workingText = workingText.replaceFirst(content.trim(), "");
        advancedVisualText += "${content.trim()}\n\n";
      } else {
        if (updateRules) rule['active'] = false;
      }
    }

    workingText = workingText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    advancedVisualText = advancedVisualText.trim();

    if (updateMain) {
      widget.mainPromptController.text = workingText;
    }
    
    if (updateRules) {
      widget.advancedPromptController.text = advancedVisualText;
    }
  }

  void _onAdvancedSwitchChanged() {
    final List<String> activePrompts = [];

    for (final rule in _customRules) {
      if (rule['active'] == true) {
        activePrompts.add((rule['content'] as String).trim());
      }
    }

    widget.advancedPromptController.text = activePrompts.join('\n\n');

    widget.onPromptChanged();
  }

  Future<void> _handleImportCharacterCard() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final card = await CharacterCardService.parseFile(file);

        if (card != null) {
           final warnings = CharacterCardService.validate(card);
           if (warnings.isNotEmpty) {
             // Show warnings but allow proceeding
             if (!mounted) return;
             await showDialog(
               context: context, 
               builder: (ctx) => AlertDialog(
                 title: const Text("Import Warnings", style: TextStyle(color: Colors.orangeAccent)),
                 content: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: warnings.map((w) => Text("• $w", style: const TextStyle(color: Colors.white70))).toList(),
                 ),
                 actions: [
                   TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
                 ],
                 backgroundColor: const Color(0xFF2C2C2C),
               )
             );
           }
        
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          chatProvider.setCharacterCard(card);
          _updateCardControllers(card);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Imported '${card.name}' successfully!")),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Import failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import failed: $e")),
        );
      }
    }
  }

  Future<void> _handleExportCharacterCard() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final card = chatProvider.characterCard;
    
    if (card.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Character card is empty. Add a name first.")),
      );
      return;
    }

    try {
      final jsonStr = await LibraryService.exportCharacterCard(card);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Character Card',
        fileName: '${card.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: bytes,
      );

      if (outputFile != null) {
        final jsonStr = await LibraryService.exportCharacterCard(card);
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

        // Apply preset
        // We merge custom rules, replace description/system prompt
        widget.promptTitleController.text = preset.name;
        widget.mainPromptController.text = preset.systemPrompt;
        
        // Merge rules
        final prefs = await SharedPreferences.getInstance();
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
          _saveCustomRulesToPrefs(); // Persist merged rules
          _onAdvancedSwitchChanged(); // Update visual text
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

  Future<void> _handleExportPreset() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Construct preset from current state
    final preset = SystemPreset(
      name: widget.promptTitleController.text.isNotEmpty ? widget.promptTitleController.text : "Untitled Preset",
      systemPrompt: widget.mainPromptController.text,
      advancedPrompt: widget.advancedPromptController.text,
      customRules: _customRules,
      generationSettings: {
        'temperature': chatProvider.temperature,
        'top_p': chatProvider.topP,
        'top_k': chatProvider.topK,
      }
    );

    try {
      final jsonStr = await LibraryService.exportPreset(preset);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Preset',
        fileName: '${preset.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: bytes,
      );

      if (outputFile != null) {
        final jsonStr = await LibraryService.exportPreset(preset);
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

  void _clearCharacterCard() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final emptyCard = CharacterCard();
    chatProvider.setCharacterCard(emptyCard);
    _updateCardControllers(emptyCard);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Character card cleared.")),
    );
  }

  void _confirmDeletePromptFromLibrary(String title) {
    if (title.isEmpty) return;
    
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text("Delete '$title'?", style: TextStyle(color: Colors.redAccent, fontSize: scaleProvider.systemFontSize)),
        content: Text("Are you sure you want to remove this preset from your library?", style: TextStyle(color: Colors.white70, fontSize: scaleProvider.systemFontSize * 0.8)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              chatProvider.deletePromptFromLibrary(title);
              widget.promptTitleController.clear();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Deleted from Library")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

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
      _onAdvancedSwitchChanged();
    });
  }

  void _editCustomRule(int index) {
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final rule = _customRules[index];
    final labelController = TextEditingController(text: rule['label']);
    final contentController = TextEditingController(text: rule['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text(
          "Edit Rule",
          style: TextStyle(
            color: Colors.white,
            fontSize: scaleProvider.systemFontSize,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: "Rule Name",
                filled: true,
                fillColor: Colors.black12,
              ),
              style: TextStyle(
                color: Colors.white,
                fontSize: scaleProvider.systemFontSize * 0.8,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Rule Content",
                filled: true,
                fillColor: Colors.black12,
              ),
              style: TextStyle(
                color: Colors.white,
                fontSize: scaleProvider.systemFontSize * 0.8,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              "Cancel",
              style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              "Save",
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: scaleProvider.systemFontSize * 0.8,
              ),
            ),
            onPressed: () {
              setState(() {
                _customRules[index]['label'] = labelController.text.trim();
                _customRules[index]['content'] = contentController.text.trim();

                _saveCustomRulesToPrefs();
                if (_customRules[index]['active'] == true) {
                  _onAdvancedSwitchChanged();
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
    final rule = _customRules[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text(
          "Delete Rule?",
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: scaleProvider.systemFontSize,
          ),
        ),
        content: Text(
          "Are you sure you want to delete '${rule['label']}'?\n\nThis cannot be undone.",
          style: TextStyle(
            color: Colors.white70,
            fontSize: scaleProvider.systemFontSize * 0.8,
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              "Cancel",
              style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              "DELETE",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: scaleProvider.systemFontSize * 0.8,
              ),
            ),
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
      if (wasActive) _onAdvancedSwitchChanged();
    });
  }

  void _copyToClipboard() {
    final text = widget.mainPromptController.text;
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

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        widget.mainPromptController.text = data!.text!;
      });
      widget.onPromptChanged();
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

  void _handleSavePreset() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.setSystemInstruction(widget.mainPromptController.text);
    chatProvider.savePromptToLibrary(
      widget.promptTitleController.text,
      widget.mainPromptController.text,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Saved '${widget.promptTitleController.text}' to Library!",
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);



    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 1. Main System Prompt ---
        ExpansionTile(
          title: Text(
            "Main System Prompt",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              fontWeight: FontWeight.bold,
              shadows: themeProvider.enableBloom
                  ? [const Shadow(color: Colors.white, blurRadius: 10)]
                  : [],
            ),
          ),
          trailing: Switch(
            value: chatProvider.enableSystemPrompt,
            activeColor: themeProvider.appThemeColor,
            onChanged: (val) {
              chatProvider.setEnableSystemPrompt(val);
              chatProvider.saveSettings();
            },
          ),
          children: [
            Opacity(
              opacity: chatProvider.enableSystemPrompt ? 1.0 : 0.5,
              child: AbsorbPointer(
                absorbing: !chatProvider.enableSystemPrompt,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Library / Preset Section ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: themeProvider.enableBloom
                                ? themeProvider.appThemeColor.withOpacity(0.5)
                                : Colors.white12,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text(
                              "Load Main Prompt...",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: scaleProvider.systemFontSize * 0.8,
                              ),
                            ),
                            dropdownColor: const Color(0xFF2C2C2C),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: themeProvider.appThemeColor,
                            ),
                            value: null,
                            items: [
                              DropdownMenuItem<String>(
                                value: "CREATE_NEW",
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.add,
                                      color: Colors.greenAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Create New",
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: scaleProvider.systemFontSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...chatProvider.savedSystemPrompts.map((prompt) {
                                return DropdownMenuItem<String>(
                                  value: prompt.title,
                                  child: Text(
                                    prompt.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: scaleProvider.systemFontSize,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue == "CREATE_NEW") {
                                widget.promptTitleController.clear();
                                widget.mainPromptController.clear();
                                widget.onPromptChanged();
                              } else if (newValue != null) {
                                final prompt = chatProvider.savedSystemPrompts
                                    .firstWhere((p) => p.title == newValue);
                                // Only update main prompt (keep rules intact)
                                _parseSystemInstruction(prompt.content, updateMain: true, updateRules: false);
                                widget.onPromptChanged();
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      
                      // Helper Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // SAVE TO LIBRARY
                            Center(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: themeProvider.appThemeColor,
                                  side: BorderSide(color: themeProvider.appThemeColor),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                onPressed: _handleSavePreset,
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text("Save to Library"),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // DELETE, EXPORT, IMPORT
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.redAccent.withAlpha(50),
                                  ),
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  tooltip: "Delete from Library",
                                  onPressed: () => _confirmDeletePromptFromLibrary(
                                    widget.promptTitleController.text,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward, color: Colors.blueAccent),
                                  tooltip: "Export Preset to File",
                                  onPressed: _handleExportPreset,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward, color: Colors.greenAccent),
                                  tooltip: "Import Preset from File",
                                  onPressed: _handleImportPreset,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: widget.promptTitleController,
                        decoration: InputDecoration(
                          labelText: "Prompt Title",
                          labelStyle: TextStyle(
                            color: themeProvider.appThemeColor,
                            fontSize: scaleProvider.systemFontSize * 0.8,
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.black12,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        style: TextStyle(
                          fontSize: scaleProvider.systemFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      // Main Prompt Input
                      TextField(
                        controller: widget.mainPromptController,
                        onChanged: (_) => widget.onPromptChanged(),
                        maxLines: 8,
                        minLines: 3,
                        decoration: InputDecoration(
                          labelText: "Main System Prompt (Base Rules)",
                          hintText: "Enter the core roleplay rules here...",
                          hintStyle: TextStyle(
                            fontSize: scaleProvider.systemFontSize * 0.8,
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.black26,
                        ),
                        style: TextStyle(
                           fontSize: scaleProvider.systemFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),                
                const SizedBox(height: 20),
                
        // --- 2. Character Card Section ---
        ExpansionTile(
          initiallyExpanded: chatProvider.characterCard.name.isNotEmpty,
          title: Text(
            "Character Card",
            style: TextStyle(
              fontSize: scaleProvider.systemFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
            ),
          ),
          subtitle: Text(
            chatProvider.characterCard.name.isNotEmpty 
              ? "Active: ${chatProvider.characterCard.name}"
              : "Import V1/V2 PNG or JSON cards",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: Switch(
            value: chatProvider.enableCharacterCard,
            activeColor: Colors.orangeAccent,
            onChanged: (val) {
              chatProvider.setEnableCharacterCard(val);
              chatProvider.saveSettings();
            },
          ),
          children: [
             Opacity(
               opacity: chatProvider.enableCharacterCard ? 1.0 : 0.5,
               child: AbsorbPointer(
                 absorbing: !chatProvider.enableCharacterCard,
                 child: Padding(
                   padding: const EdgeInsets.all(12.0),
                   child: Column(
                     children: [
                       // Import/Export/Clear Column
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.stretch,
                         children: [
                               ElevatedButton.icon(
                                 onPressed: _handleImportCharacterCard,
                                 icon: const Icon(Icons.file_open, size: 16),
                                 label: const Text("Import Card"),
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                               ),
                               const SizedBox(height: 8),
                               OutlinedButton.icon(
                                 onPressed: _handleExportCharacterCard,
                                 icon: const Icon(Icons.save_alt, size: 16),
                                 label: const Text("Export JSON"),
                               ),
                               TextButton(
                                 onPressed: _clearCharacterCard,
                                 child: const Text("Clear Card", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                               )
                         ],
                       ),
                       const Divider(color: Colors.white12),
                       _buildCardField("Name", _cardNameController),
                       const SizedBox(height: 8),
                       _buildCardField("Description / Persona", _cardDescriptionController, maxLines: 3),
                       const SizedBox(height: 8),
                       _buildCardField("First Message", _cardFirstMesController, maxLines: 3),
                       const SizedBox(height: 8),
                       ExpansionTile(
                         title: const Text("More Fields (Scenario, Examples, etc.)", style: TextStyle(fontSize: 14)),
                         dense: true,
                         children: [
                            _buildCardField("Scenario", _cardScenarioController, maxLines: 2),
                            const SizedBox(height: 8),
                            _buildCardField("Personality", _cardPersonalityController, maxLines: 2),
                            const SizedBox(height: 8),
                            _buildCardField("Example Dialogue (Mes Example)", _cardMesExampleController, maxLines: 4),
                            const SizedBox(height: 8),
                            _buildCardField("Character System Prompt", _cardSystemPromptController, maxLines: 2),
                         ],
                       )
                     ],
                   ),
                 ),
               ),
             )
          ],
        ),

                const SizedBox(height: 20),

                // --- Custom Rules & Advanced Prompt ---
        // --- 3. Custom Rules & Presets ---
        ExpansionTile(
          title: Text(
            "Custom Rules & Presets",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: scaleProvider.systemFontSize,
              color: themeProvider.appThemeColor,
              shadows: themeProvider.enableBloom
                  ? [const Shadow(color: Colors.white, blurRadius: 10)]
                  : [],
            ),
          ),
          trailing: Switch(
            value: chatProvider.enableAdvancedSystemPrompt,
            activeColor: themeProvider.appThemeColor,
            onChanged: (val) {
              chatProvider.setEnableAdvancedSystemPrompt(val);
              chatProvider.saveSettings();
            },
          ),
          children: [
             Opacity(
               opacity: chatProvider.enableAdvancedSystemPrompt ? 1.0 : 0.5,
               child: AbsorbPointer(
                 absorbing: !chatProvider.enableAdvancedSystemPrompt,
                 child: Container(
                   decoration: BoxDecoration(
                     color: Colors.black26,
                     borderRadius: BorderRadius.circular(8),
                     border: Border.all(color: Colors.white12),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                        // --- Rules Preset Dropdown ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeProvider.enableBloom
                                  ? themeProvider.appThemeColor.withOpacity(0.5)
                                  : Colors.white12,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Text(
                                "Load Rules Preset...",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: scaleProvider.systemFontSize * 0.8,
                                ),
                              ),
                              dropdownColor: const Color(0xFF2C2C2C),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: themeProvider.appThemeColor,
                              ),
                              value: null,
                              items: chatProvider.savedSystemPrompts.map((prompt) {
                                  return DropdownMenuItem<String>(
                                    value: prompt.title,
                                    child: Text(
                                      prompt.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: scaleProvider.systemFontSize,
                                      ),
                                    ),
                                  );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  final prompt = chatProvider.savedSystemPrompts
                                      .firstWhere((p) => p.title == newValue);
                                  // Only update rules (keep main prompt intact)
                                  _parseSystemInstruction(prompt.content, updateMain: false, updateRules: true);
                                  widget.onPromptChanged();
                                }
                              },
                            ),
                          ),
                        ),

                        // List of Rules
                        if (_customRules.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text("No custom rules defined.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                          ),
                          
                        ..._customRules.asMap().entries.map((entry) {
                           final int index = entry.key;
                           final Map<String, dynamic> rule = entry.value;

                           return ListTile(
                             dense: true,
                             title: Text(
                               rule['label'],
                               style: TextStyle(
                                 color: Colors.white70,
                                 fontSize: scaleProvider.systemFontSize * 0.8,
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                             subtitle: Text(
                               (rule['content'] as String).replaceAll('\n', ' '),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                               style: const TextStyle(color: Colors.white30, fontSize: 10),
                             ),
                             leading: IconButton(
                               icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 16),
                               onPressed: () => _editCustomRule(index),
                             ),
                             trailing: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 IconButton(
                                   icon: const Icon(Icons.close, color: Colors.white24, size: 16),
                                   onPressed: () => _confirmDeleteCustomRule(index),
                                 ),
                                 Switch(
                                   value: rule['active'] == true,
                                   activeThumbColor: Colors.blueAccent,
                                   onChanged: (val) {
                                     setState(() {
                                       rule['active'] = val;
                                       _onAdvancedSwitchChanged();
                                     });
                                   },
                                 ),
                               ],
                             ),
                           );
                       }),
                       
                       const Divider(color: Colors.white12),
                       
                       // Add New Rule
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _ruleLabelController,
                                decoration: const InputDecoration(
                                  labelText: "Rule Name",
                                  hintText: "Name",
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.black12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _newRuleContentController,
                                      decoration: const InputDecoration(
                                        labelText: "New Rule Content",
                                        hintText: "Content to append...",
                                        isDense: true,
                                        filled: true,
                                        fillColor: Colors.black12,
                                      ),
                                      onSubmitted: (_) => _addRuleFromInput(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
                                    onPressed: _addRuleFromInput,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Preview of compiled Advanced Prompt
                        ExpansionTile(
                          title: const Text("View Generated Advanced Prompt", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                controller: widget.advancedPromptController,
                                readOnly: true, // It is generated from rules
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  filled: true, 
                                  fillColor: Colors.black12,
                                  border: OutlineInputBorder(),
                                ),
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            )
                          ],
                        )
                     ],
                   ),
                 ),
               ),
             )
          ],
        ),

        
        const Divider(),
      ],
    );
  }

  void _syncCardFromControllers() {
    _cardSaveTimer?.cancel();
    _cardSaveTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Create updated card from controllers
      // Note: We deliberately do NOT update 'creator' or 'spec_version' here as UI doesn't edit them yet
      final updatedCard = chatProvider.characterCard.copyWith(
        name: _cardNameController.text,
        description: _cardDescriptionController.text,
        firstMessage: _cardFirstMesController.text,
        scenario: _cardScenarioController.text,
        personality: _cardPersonalityController.text,
        mesExample: _cardMesExampleController.text,
        systemPrompt: _cardSystemPromptController.text,
      );
      
      chatProvider.setCharacterCard(updatedCard);
    });
  }

  Widget _buildCardField(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: (_) => _syncCardFromControllers(),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.black12,
        border: const OutlineInputBorder(),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}
