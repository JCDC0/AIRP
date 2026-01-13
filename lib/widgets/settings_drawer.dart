import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class SettingsDrawer extends StatefulWidget {
  final AiProvider currentProvider;
  final String apiKey;
  final String localIp;
  final String title;
  
  // Model Lists
  final List<String> geminiModelsList;
  final List<String> openRouterModelsList;
  final List<String> arliAiModelsList;
  final List<String> nanoGptModelsList;
  
  // Selected Models
  final String selectedGeminiModel;
  final String openRouterModel;
  final String arliAiModel;
  final String nanoGptModel;
  final String localModelName;

  // Loading States
  final bool isLoadingGeminiModels;
  final bool isLoadingOpenRouterModels;
  final bool isLoadingArliAiModels;
  final bool isLoadingNanoGptModels;

  // Settings
  final double temperature;
  final double topP;
  final int topK;
  final int maxOutputTokens;
  final int historyLimit;
  final bool enableGrounding;
  final bool disableSafety;
  final bool hasUnsavedChanges;
  final String reasoningEffort;

  // Prompt System
  final List<SystemPromptData> savedSystemPrompts;
  final String promptTitle;
  final String systemInstruction;

  // Callbacks
  final Function(String) onApiKeyChanged;
  final Function(String) onLocalIpChanged;
  final Function(String) onTitleChanged;
  final Function(String) onModelSelected;
  final Function(String) onLocalModelNameChanged;
  
  final VoidCallback onFetchGeminiModels;
  final VoidCallback onFetchOpenRouterModels;
  final VoidCallback onFetchArliAiModels;
  final VoidCallback onFetchNanoGptModels;

  final Function(double) onTemperatureChanged;
  final Function(double) onTopPChanged;
  final Function(int) onTopKChanged;
  final Function(int) onMaxOutputTokensChanged;
  final Function(int) onHistoryLimitChanged;
  final Function(bool) onEnableGroundingChanged;
  final Function(bool) onDisableSafetyChanged;
  final Function(String) onReasoningEffortChanged;
  
  final Function(String) onPromptTitleChanged;
  final Function(String) onSystemInstructionChanged;
  final VoidCallback onSavePrompt;
  final VoidCallback onDeletePrompt;
  final Function(String, String) onLoadPrompt;
  
  final VoidCallback onSaveSettings;

  const SettingsDrawer({
    super.key,
    required this.currentProvider,
    required this.apiKey,
    required this.localIp,
    required this.title,
    required this.geminiModelsList,
    required this.openRouterModelsList,
    required this.arliAiModelsList,
    required this.nanoGptModelsList,
    required this.selectedGeminiModel,
    required this.openRouterModel,
    required this.arliAiModel,
    required this.nanoGptModel,
    required this.localModelName,
    required this.isLoadingGeminiModels,
    required this.isLoadingOpenRouterModels,
    required this.isLoadingArliAiModels,
    required this.isLoadingNanoGptModels,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.maxOutputTokens,
    required this.historyLimit,
    required this.enableGrounding,
    required this.disableSafety,
    required this.hasUnsavedChanges,
    required this.reasoningEffort,
    required this.savedSystemPrompts,
    required this.promptTitle,
    required this.systemInstruction,
    required this.onApiKeyChanged,
    required this.onLocalIpChanged,
    required this.onTitleChanged,
    required this.onModelSelected,
    required this.onLocalModelNameChanged,
    required this.onFetchGeminiModels,
    required this.onFetchOpenRouterModels,
    required this.onFetchArliAiModels,
    required this.onFetchNanoGptModels,
    required this.onTemperatureChanged,
    required this.onTopPChanged,
    required this.onTopKChanged,
    required this.onMaxOutputTokensChanged,
    required this.onHistoryLimitChanged,
    required this.onEnableGroundingChanged,
    required this.onDisableSafetyChanged,
    required this.onReasoningEffortChanged,
    required this.onPromptTitleChanged,
    required this.onSystemInstructionChanged,
    required this.onSavePrompt,
    required this.onDeletePrompt,
    required this.onLoadPrompt,
    required this.onSaveSettings,
  });

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  late TextEditingController _apiKeyController;
  late TextEditingController _localIpController;
    late TextEditingController _titleController;
  late TextEditingController _promptTitleController;
  late TextEditingController _mainPromptController;
  late TextEditingController _openRouterModelController; 
        late TextEditingController _advancedPromptController;

  late TextEditingController _ruleLabelController;
  late TextEditingController _newRuleContentController;

  bool _isProgrammaticUpdate = false; 

  
      Set<String> _bookmarkedModels = {};
  
  // Custom Rules storage
  List<Map<String, dynamic>> _customRules = [];

  static const String kDefaultKaomojiFix = "Use kaomoji for spoken character (e.g. OwO, ^_^) frequently in character dialogue to convey emotion for spoken characters only. (Except if the character is only you)";
  static const String kCustomRulesKey = "custom_sys_prompt_rules";

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.apiKey);
    _localIpController = TextEditingController(text: widget.localIp);
    _titleController = TextEditingController(text: widget.title);
    _promptTitleController = TextEditingController(text: widget.promptTitle);
    _openRouterModelController = TextEditingController(text: widget.openRouterModel);
    _ruleLabelController = TextEditingController();
    _newRuleContentController = TextEditingController();
    
    _advancedPromptController = TextEditingController();
    _mainPromptController = TextEditingController();

    // Load bookmarks and then Load Rules & Parse
    _loadBookmarks();
    _loadCustomRulesAndParse();
  }

  /// Loads custom rules from SharedPreferences, then parses the incoming systemInstruction
  /// to see which rules are currently active in the text.
  Future<void> _loadCustomRulesAndParse() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(kCustomRulesKey);
    
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _customRules = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint("Error loading custom rules: $e");
      }
    }

    if (mounted) {
      setState(() {
        _parseSystemInstruction(widget.systemInstruction);
      });
    }
  }

  Future<void> _saveCustomRulesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_customRules);
    await prefs.setString(kCustomRulesKey, encoded);
  }

    /// Parses the full instruction string to separate "Main" from "Advanced" components
  void _parseSystemInstruction(String fullPrompt) {
    String workingText = fullPrompt;
    String advancedVisualText = "";

    // 2. Detect Kaomoji
    if (workingText.contains(kDefaultKaomojiFix.trim())) {
       _isKaomojiFixEnabled = true;
       workingText = workingText.replaceFirst(kDefaultKaomojiFix.trim(), "");
       advancedVisualText += "${kDefaultKaomojiFix.trim()}\n\n";
    } else {
       _isKaomojiFixEnabled = false;
    }

        // 3. Detect Custom Rules
    for (var rule in _customRules) {
      final content = rule['content'] as String;
      if (workingText.contains(content.trim())) {
        rule['active'] = true;
        workingText = workingText.replaceFirst(content.trim(), "");
        advancedVisualText += "${content.trim()}\n\n";
      } else {
        rule['active'] = false;
      }
    }

    // 4. Cleanup
    workingText = workingText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    advancedVisualText = advancedVisualText.trim();

    _mainPromptController.text = workingText;
    _advancedPromptController.text = advancedVisualText;
  }
  
  // Track switches
  bool _isKaomojiFixEnabled = false;
  
  void _handleSaveSettings() {
    String finalPrompt;
    String advanced = _advancedPromptController.text.trim();
    String main = _mainPromptController.text.trim(); // Ensure main is trimmed
    
    if (advanced.isNotEmpty && main.isNotEmpty) {
      finalPrompt = "$advanced\n\n$main";
    } else {
      finalPrompt = advanced + main;
    }
    
    widget.onSystemInstructionChanged(finalPrompt);
    widget.onSaveSettings();
  }
  
    void _handleSavePreset() {
    setState(() {
      _isProgrammaticUpdate = true;
    });
    
    widget.onSystemInstructionChanged(_mainPromptController.text);
    widget.onSavePrompt();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isProgrammaticUpdate = false;
        });
      }
    });
  }

  void _notifyChangeIfNeeded() {
    if (!widget.hasUnsavedChanges) {
        // Construct what the prompt currently looks like to satisfy the callback signature
        // We match the logic in didUpdateWidget to avoid re-parsing and cursor jumps
        String advanced = _advancedPromptController.text.trim();
        String main = _mainPromptController.text; // Don't trim while typing
        String finalPrompt = (advanced.isNotEmpty && main.isNotEmpty) ? "$advanced\n\n$main" : advanced + main;
        
        widget.onSystemInstructionChanged(finalPrompt);
    }
  }

  
        void _onAdvancedSwitchChanged() {
    final List<String> activePrompts = [];

    if (_isKaomojiFixEnabled) {
      activePrompts.add(kDefaultKaomojiFix.trim());
    }

    for (final rule in _customRules) {
      if (rule['active'] == true) {
        activePrompts.add((rule['content'] as String).trim());
      }
    }
    
    _advancedPromptController.text = activePrompts.join('\n\n');
    
    // Notify parent immediately so the FAB drops down
    // We construct what the final prompt WOULD be
    String advanced = _advancedPromptController.text.trim();
    String main = _mainPromptController.text.trim();
    String finalPrompt = (advanced.isNotEmpty && main.isNotEmpty) ? "$advanced\n\n$main" : advanced + main;
    
    widget.onSystemInstructionChanged(finalPrompt);
  }


    void _addRuleFromInput() {
    final text = _newRuleContentController.text.trim();
    if (text.isEmpty) return;

    final String label = _ruleLabelController.text.trim().isNotEmpty 
        ? _ruleLabelController.text.trim() 
        : (text.length > 25 ? "${text.substring(0, 25)}..." : text);

    setState(() {
      _customRules.add({
        'content': text,
        'active': true,
        'label': label,
      });
      
      _newRuleContentController.clear();
      _ruleLabelController.clear();
      
      _saveCustomRulesToPrefs();
      _onAdvancedSwitchChanged();
    });
  }

  void _editCustomRule(int index) {
    final rule = _customRules[index];
    final labelController = TextEditingController(text: rule['label']);
    final contentController = TextEditingController(text: rule['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Edit Rule", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: "Rule Name", filled: true, fillColor: Colors.black12),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "Rule Content", filled: true, fillColor: Colors.black12),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Save", style: TextStyle(color: Colors.blueAccent)),
            onPressed: () {
              setState(() {
                // If the rule was active, we need to handle the content change carefully
                // But _onAdvancedSwitchChanged rebuilds the whole prompt from active rules, 
                // so we just need to update the definition and trigger a rebuild.
                
                _customRules[index]['label'] = labelController.text.trim();
                _customRules[index]['content'] = contentController.text.trim();
                
                _saveCustomRulesToPrefs();
                // Re-evaluate the prompt with the new content (if it was active)
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
    final rule = _customRules[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Delete Rule?", style: TextStyle(color: Colors.redAccent)),
        content: Text(
          "Are you sure you want to delete '${rule['label']}'?\n\nThis cannot be undone.",
          style: const TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () {
              _deleteCustomRuleForever(index);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _copyToClipboard() {
    final text = _mainPromptController.text;

    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Copied rule to Clipboard!"), duration: Duration(milliseconds: 600)),
      );
    }
  }

  void _copyRuleContentToClipboard() {
    final text = _newRuleContentController.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Copied rule to Clipboard!"), duration: Duration(milliseconds: 600)),
      );
    }
  }

            Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _mainPromptController.text = data!.text!;
      });
      _notifyChangeIfNeeded();
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



      void _deleteCustomRuleForever(int index) {
      setState(() {
        bool wasActive = _customRules[index]['active'] == true;
        _customRules.removeAt(index);
        _saveCustomRulesToPrefs();
        if (wasActive) _onAdvancedSwitchChanged();
      });
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookmarkedModels = prefs.getStringList('bookmarked_models')?.toSet() ?? {};
    });
  }

  Future<void> _toggleBookmark(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_bookmarkedModels.contains(modelId)) {
        _bookmarkedModels.remove(modelId);
      } else {
        _bookmarkedModels.add(modelId);
      }
    });
    await prefs.setStringList('bookmarked_models', _bookmarkedModels.toList());
  }


  @override
  void didUpdateWidget(SettingsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apiKey != oldWidget.apiKey && widget.apiKey != _apiKeyController.text) {
      _apiKeyController.text = widget.apiKey;
    }
    if (widget.localIp != oldWidget.localIp && widget.localIp != _localIpController.text) {
      _localIpController.text = widget.localIp;
    }
    if (widget.title != oldWidget.title && widget.title != _titleController.text) {
      _titleController.text = widget.title;
    }
        if (widget.promptTitle != oldWidget.promptTitle && widget.promptTitle != _promptTitleController.text) {
      _promptTitleController.text = widget.promptTitle;
    }
    if (widget.systemInstruction != oldWidget.systemInstruction) {
        // If we triggered this update ourselves just to save, don't re-parse everything.
        if (_isProgrammaticUpdate) return;
        
        String advanced = _advancedPromptController.text.trim();
        String main = _mainPromptController.text;
        String currentCombined = (advanced.isNotEmpty && main.isNotEmpty) ? "$advanced\n\n$main" : advanced + main;

        if (widget.systemInstruction != currentCombined) {
             // External update -> Re-parse using the centralized logic
             // This keeps our custom rules aware of what's in the text
             setState(() {
               _parseSystemInstruction(widget.systemInstruction);
             });
        }
    }

    if (widget.openRouterModel != oldWidget.openRouterModel && widget.openRouterModel != _openRouterModelController.text) {
      _openRouterModelController.text = widget.openRouterModel;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _localIpController.dispose();
        _titleController.dispose();
    _promptTitleController.dispose();
    _mainPromptController.dispose();
    _openRouterModelController.dispose();

        _advancedPromptController.dispose();
    _ruleLabelController.dispose();
    _newRuleContentController.dispose();
    super.dispose();
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required Color activeColor,
    required Function(double) onChanged,
    bool isInt = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(
              width: 60,
              height: 30,
              child: TextField(
                controller: TextEditingController(
                    text: isInt ? value.toInt().toString() : value.toStringAsFixed(2)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 12, color: Colors.white),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                ),
                onSubmitted: (val) {
                  double? parsed = double.tryParse(val);
                  if (parsed != null) {
                    if (parsed < min) parsed = min;
                    if (parsed > max) parsed = max;
                    onChanged(parsed);
                  }
                },
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildColorCircle(String label, Color color, Function(Color) onSave) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showColorPickerDialog(color, onSave), 
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  void _showColorPickerDialog(Color initialColor, Function(Color) onSave) {
    Color tempColor = initialColor;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: const Text("Pick a Color", style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: tempColor,
                onColorChanged: (c) => setDialogState(() => tempColor = c),
                pickerAreaHeightPercent: 0.7,
                enableAlpha: false,
                displayThumbColor: true,
                paletteType: PaletteType.hsvWithHue,
              ),
            ),
            actions: [
              TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context)),
              TextButton(
                child: const Text("Done", style: TextStyle(color: Colors.cyanAccent)),
                onPressed: () {
                  onSave(tempColor);
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showModelPickerDialog({
    required BuildContext context,
    required List<String> models,
    required String currentModel,
    required Function(String) onSelected,
    required ThemeProvider themeProvider,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter and Sort
            final filteredModels = models.where((m) {
              final name = cleanModelName(m).toLowerCase();
              final id = m.toLowerCase();
              final query = searchQuery.toLowerCase();
              return name.contains(query) || id.contains(query);
            }).toList();

            filteredModels.sort((a, b) {
              // 1. Bookmarks first
              final bool aBookmarked = _bookmarkedModels.contains(a);
              final bool bBookmarked = _bookmarkedModels.contains(b);
              if (aBookmarked && !bBookmarked) return -1;
              if (!aBookmarked && bBookmarked) return 1;

              // 2. Constants (Starred) second
              final bool aInConstants = kModelDisplayNames.containsKey(a);
              final bool bInConstants = kModelDisplayNames.containsKey(b);
              if (aInConstants && !bInConstants) return -1;
              if (!aInConstants && bInConstants) return 1;

              // 3. Alphabetical
              return cleanModelName(a).compareTo(cleanModelName(b));
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text("Select Model", style: TextStyle(color: themeProvider.appThemeColor)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search models...",
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredModels.isEmpty
                          ? const Center(child: Text("No models found", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: filteredModels.length,
                              itemBuilder: (context, index) {
                                final modelId = filteredModels[index];
                                final isSelected = modelId == currentModel;
                                final isBookmarked = _bookmarkedModels.contains(modelId);
                                final isFeatured = kModelDisplayNames.containsKey(modelId);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? themeProvider.appThemeColor.withOpacity(0.2) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: themeProvider.appThemeColor.withOpacity(0.5)) : null,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    title: Text(
                                      cleanModelName(modelId),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isBookmarked ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text(modelId, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    leading: isBookmarked
                                        ? const Icon(Icons.bookmark, color: Colors.amber, size: 20)
                                        : (isFeatured ? const Icon(Icons.star, color: Colors.yellowAccent, size: 16) : const Icon(Icons.circle_outlined, color: Colors.grey, size: 12)),
                                    trailing: IconButton(
                                      icon: Icon(
                                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                        color: isBookmarked ? Colors.amber : Colors.grey,
                                      ),
                                      onPressed: () async {
                                        await _toggleBookmark(modelId);
                                        setDialogState(() {}); // Refresh dialog
                                        setState(() {}); // Refresh parent drawer to update if needed
                                      },
                                    ),
                                    onTap: () {
                                      onSelected(modelId);
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Close"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModelSelectorTrigger({
    required String selectedModel,
    required List<String> modelsList,
    required Function(String) onSelected,
    required ThemeProvider themeProvider,
    required String placeholder,
  }) {
    return GestureDetector(
      onTap: () {
        if (modelsList.isNotEmpty) {
          _showModelPickerDialog(
            context: context,
            models: modelsList,
            currentModel: selectedModel,
            onSelected: onSelected,
            themeProvider: themeProvider,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
          boxShadow: themeProvider.enableBloom ? [BoxShadow(color: themeProvider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                modelsList.contains(selectedModel) ? cleanModelName(selectedModel) : (selectedModel.isNotEmpty ? cleanModelName(selectedModel) : placeholder),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

      return Drawer(
      width: 370, 
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      shadowColor: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.9) : null,
      elevation: themeProvider.enableBloom ? 30 : 16,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text("Main Settings", 
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: themeProvider.appThemeColor,
                shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [],
              )
            ),
            const Text("v0.1.16.10", 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: Colors.grey
                )),
            const Divider(),
            const SizedBox(height: 10),
            

            Text("API Key (BYOK)", 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: themeProvider.appThemeColor,
                shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [],
              )
            ),
            const SizedBox(height: 5),
            
            if (widget.currentProvider != AiProvider.local) ...[
              TextField(
                controller: _apiKeyController,
                onChanged: widget.onApiKeyChanged,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "Paste AI Studio Key...",
                  border: OutlineInputBorder(
                    borderSide: themeProvider.enableBloom ? BorderSide(color: themeProvider.appThemeColor) : const BorderSide(),
                  ),
                  enabledBorder: themeProvider.enableBloom 
                    ? OutlineInputBorder(borderSide: BorderSide(color: themeProvider.appThemeColor.withOpacity(0.5)))
                    : const OutlineInputBorder(),
                  filled: true, isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),
            ] else ...[
              TextField(
                controller: _localIpController,
                onChanged: widget.onLocalIpChanged,
                decoration: const InputDecoration(
                  hintText: "http://192.168.1.X:1234/v1",
                  labelText: "Local Server Address",
                  labelStyle: TextStyle(color: Colors.greenAccent),
                  border: OutlineInputBorder(),
                  filled: true, isDense: true
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Text("Ensure your local AI is listening on Network (0.0.0.0)", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
              const SizedBox(height: 20),
            ],

            Text("Conversation Title", 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: themeProvider.appThemeColor,
                shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [],
              )
            ),
            const SizedBox(height: 5),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
                boxShadow: themeProvider.enableBloom ? [BoxShadow(color: themeProvider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : [],
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Type a title...",
                  hintStyle: const TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  suffixIcon: Icon(Icons.edit, size: 16, color: themeProvider.appThemeColor),
                ),
                onChanged: widget.onTitleChanged,
              ),
            ),
            const SizedBox(height: 20),

            Text("Model Selection", style: TextStyle(fontWeight: FontWeight.bold, shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.white, blurRadius: 10)] : [])),
            const SizedBox(height: 5),

            // ============================================
            // GEMINI UI
            // ============================================
            if (widget.currentProvider == AiProvider.gemini) ...[
              if (widget.geminiModelsList.isNotEmpty)
                _buildModelSelectorTrigger(
                  selectedModel: widget.selectedGeminiModel,
                  modelsList: widget.geminiModelsList,
                  onSelected: widget.onModelSelected,
                  themeProvider: themeProvider,
                  placeholder: "Select Gemini Model",
                )
              else
                TextField(
                  decoration: const InputDecoration(hintText: "models/gemini-flash-lite-latest", border: OutlineInputBorder(), isDense: true),
                  onChanged: widget.onModelSelected,
                  controller: TextEditingController(text: widget.selectedGeminiModel),
                ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: widget.isLoadingGeminiModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(widget.isLoadingGeminiModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: widget.isLoadingGeminiModels ? null : widget.onFetchGeminiModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
                ),
              ),
            ]

            // ============================================
            // OPENROUTER UI
            // ============================================
            else if (widget.currentProvider == AiProvider.openRouter) ...[
              if (widget.openRouterModelsList.isNotEmpty)
                _buildModelSelectorTrigger(
                  selectedModel: widget.openRouterModel,
                  modelsList: widget.openRouterModelsList,
                  onSelected: (val) {
                    widget.onModelSelected(val);
                    _openRouterModelController.text = val;
                  },
                  themeProvider: themeProvider,
                  placeholder: "Select OpenRouter Model",
                )
              else
                TextField(
                  controller: _openRouterModelController,
                  decoration: const InputDecoration(hintText: "vendor/model-name", border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) { widget.onModelSelected(val.trim()); },
                ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: widget.isLoadingOpenRouterModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(widget.isLoadingOpenRouterModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: widget.isLoadingOpenRouterModels ? null : widget.onFetchOpenRouterModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.purpleAccent),
                ),
              ),
            ],
            // -------------------------------------------
            // LOCAL UI
            // -------------------------------------------
            if (widget.currentProvider == AiProvider.local) ...[
               const SizedBox(height: 5),
               TextField(
                 onChanged: widget.onLocalModelNameChanged,
                 controller: TextEditingController(text: widget.localModelName),
                 decoration: const InputDecoration(
                   hintText: "local-model",
                   labelText: "Target Model ID (Optional)",
                   border: OutlineInputBorder(), 
                   isDense: true
                 ),
                 style: const TextStyle(fontSize: 13),
               ),
            ],

            // ============================================
            // ARLI AI UI
            // ============================================
            if (widget.currentProvider == AiProvider.arliAi) ...[
              if (widget.arliAiModelsList.isNotEmpty)
                _buildModelSelectorTrigger(
                  selectedModel: widget.arliAiModel,
                  modelsList: widget.arliAiModelsList,
                  onSelected: widget.onModelSelected,
                  themeProvider: themeProvider,
                  placeholder: "Select ArliAI Model",
                )
              else
                TextField(
                  controller: TextEditingController(text: widget.arliAiModel),
                  decoration: const InputDecoration(hintText: "Gemma-3-27B-Big-Tiger-v3", border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) { widget.onModelSelected(val.trim()); },
                ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: widget.isLoadingArliAiModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(widget.isLoadingArliAiModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: widget.isLoadingArliAiModels ? null : widget.onFetchArliAiModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent),
                ),
              ),
            ],

            // ============================================
            // NANOGPT UI
            // ============================================
            if (widget.currentProvider == AiProvider.nanoGpt) ...[
              if (widget.nanoGptModelsList.isNotEmpty)
                _buildModelSelectorTrigger(
                  selectedModel: widget.nanoGptModel,
                  modelsList: widget.nanoGptModelsList,
                  onSelected: widget.onModelSelected,
                  themeProvider: themeProvider,
                  placeholder: "Select NanoGPT Model",
                )
              else
                TextField(
                  controller: TextEditingController(text: widget.nanoGptModel),
                  decoration: const InputDecoration(hintText: "aion-labs/aion-rp-llama-3.1-8b", border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) { widget.onModelSelected(val.trim()); },
                ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: widget.isLoadingNanoGptModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(widget.isLoadingNanoGptModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: widget.isLoadingNanoGptModels ? null : widget.onFetchNanoGptModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.yellowAccent),
                ),
              ),
            ],

            const SizedBox(height: 30),

            Text("System Prompt", style: 
            TextStyle(
              fontWeight: FontWeight.bold, 
              shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.white, blurRadius: 10)] : [])),
            const SizedBox(height: 5),
            
            // 1. THE DROPDOWN & ACTIONS ROW
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
                boxShadow: themeProvider.enableBloom ? [BoxShadow(color: themeProvider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : [],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text("Select from Library...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  dropdownColor: const Color(0xFF2C2C2C),
                  icon: Icon(Icons.arrow_drop_down, color: themeProvider.appThemeColor),
                  value: null, 
                  items: [
                    const DropdownMenuItem<String>(
                      value: "CREATE_NEW",
                      child: Row(children: [
                        Icon(Icons.add, color: Colors.greenAccent, size: 16),
                        SizedBox(width: 8),
                        Text("Create New", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    ...widget.savedSystemPrompts.map((prompt) {
                      return DropdownMenuItem<String>(
                        value: prompt.title,
                        child: Text(prompt.title, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue == "CREATE_NEW") {
                      widget.onPromptTitleChanged("");
                      widget.onSystemInstructionChanged("");
                    } else if (newValue != null) {
                      final prompt = widget.savedSystemPrompts.firstWhere((p) => p.title == newValue);
                      widget.onLoadPrompt(prompt.title, prompt.content);
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 10),

            // 2. PROMPT TITLE FIELD
            TextField(
              controller: _promptTitleController,
              onChanged: widget.onPromptTitleChanged,
              decoration: InputDecoration(
                labelText: "Prompt Title (e.g., 'World of mana and mechs')",
                labelStyle: TextStyle(color: themeProvider.appThemeColor, fontSize: 12),
                border: OutlineInputBorder(borderSide: themeProvider.enableBloom ? BorderSide(color: themeProvider.appThemeColor) : const BorderSide()),
                enabledBorder: themeProvider.enableBloom ? OutlineInputBorder(borderSide: BorderSide(color: themeProvider.appThemeColor.withOpacity(0.5))) : const OutlineInputBorder(),
                filled: true, fillColor: Colors.black12,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),

                        const SizedBox(height: 5),

            // 3. MAIN PROMPT CONTENT FIELD
            Focus(
              onFocusChange: (hasFocus) {
                 setState(() {}); 
              },
              child: Builder(
                builder: (context) {
                  final hasFocus = Focus.of(context).hasFocus;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    height: hasFocus ? 300 : null,
                    child: TextField(
                      controller: _mainPromptController,
                      onChanged: (_) => _notifyChangeIfNeeded(),
                      maxLines: hasFocus ? null : 5,
                      expands: hasFocus,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: "Enter the roleplay rules here...",
                        border: OutlineInputBorder(borderSide: themeProvider.enableBloom ? BorderSide(color: themeProvider.appThemeColor) : const BorderSide()),
                        enabledBorder: themeProvider.enableBloom ? OutlineInputBorder(borderSide: BorderSide(color: themeProvider.appThemeColor.withOpacity(0.5))) : const OutlineInputBorder(),
                        filled: true, fillColor: Colors.black26,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }
              ),
            ),
            
            const SizedBox(height: 8),

                        Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.blueAccent),
                    tooltip: "Copy Text",
                    onPressed: _copyToClipboard,
                  ),
                  Container(width: 1, height: 20, color: Colors.white12),
                  IconButton(
                    icon: const Icon(Icons.paste, color: Colors.orangeAccent),
                    tooltip: "Paste Text",
                    onPressed: _pasteFromClipboard,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                                            foregroundColor: themeProvider.appThemeColor, 
                      side: BorderSide(color: themeProvider.appThemeColor),
                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    ),
                    onPressed: _handleSavePreset,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text("Save Preset"),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.redAccent.withAlpha((0.2 * 255).round())),
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  tooltip: "Delete Preset",
                  onPressed: widget.onDeletePrompt,
                ),
              ],
            ),

            const Divider(),

            // --- ADVANCED SYSTEM PROMPT SECTION ---
            Text("Advanced System Prompt", style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.appThemeColor, shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.white, blurRadius: 10)] : [])),
            const SizedBox(height: 5),

            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
              ),
              child: ExpansionTile(
                title: const Text("Tweaks & Overrides", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(
                  _isKaomojiFixEnabled ? "Active: Kaomoji" : "Configure hidden behavior...",
                  style: const TextStyle(fontSize: 10, color: Colors.grey)
                ),
                collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                children: [
                   ListTile(
                     dense: true,
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                     title: Text("Kaomoji Mode", style: TextStyle(color: themeProvider.appThemeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                     trailing: Switch(
                       value: _isKaomojiFixEnabled,
                       activeThumbColor: themeProvider.appThemeColor,
                       onChanged: (val) {
                         setState(() => _isKaomojiFixEnabled = val);
                         _onAdvancedSwitchChanged();
                       },
                     ),
                     onTap: () {
                        _advancedPromptController.text = kDefaultKaomojiFix;
                     },
                   ),
                   
                   // Dynamic Rules List
                   if (_customRules.isNotEmpty)
                     const Padding(
                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                       child: Divider(color: Colors.white10),
                     ),
                                                         ..._customRules.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final Map<String, dynamic> rule = entry.value;
                      
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(rule['label'], style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        leading: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 16),
                          tooltip: "Edit Rule",
                          onPressed: () => _editCustomRule(index),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white24, size: 16),
                              onPressed: () => _confirmDeleteCustomRule(index),
                              tooltip: "Delete Rule",
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
                        onTap: () {
                           _advancedPromptController.text = rule['content'];
                        },
                      );
                   }),
                  // EDITABLE RAW PROMPT
                   const Divider(),
                   Padding(
                     padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                                                  const Text("Raw Advanced Instructions:", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 4),
                         Focus(
                            onFocusChange: (hasFocus) => setState((){}),
                            child: Builder(builder: (context) {
                              final hasFocus = Focus.of(context).hasFocus;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: hasFocus ? 200 : null,
                                child: TextField(
                                 controller: _advancedPromptController,
                                 maxLines: hasFocus ? null : 4,
                                 expands: hasFocus,
                                 textAlignVertical: TextAlignVertical.top,
                                 style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70),
                                 decoration: InputDecoration(
                                   filled: true, 
                                   fillColor: Colors.black45,
                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                   contentPadding: const EdgeInsets.all(8),
                                 ),
                                 onChanged: (val) {
                                   // Sync switches to text presence
                                   setState(() {
                                     _isKaomojiFixEnabled = val.contains(kDefaultKaomojiFix);
                                   });
                                   _notifyChangeIfNeeded();
                                 },
                               ),
                              );
                            }),
                         ),
                         
                        
                       ],
                     ),
                   ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            const Divider(),

            // --- NEW RULE CREATION SECTION ---
            const Text("Add a New Tweak/Rule", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            Focus(
                onFocusChange: (hasFocus) {
                  setState(() {});
                },
                child: Builder(
                  builder: (context) {
                     final hasFocus = Focus.of(context).hasFocus;
                     return AnimatedContainer(
                       duration: const Duration(milliseconds: 300),
                       curve: Curves.easeOut,
                       height: hasFocus ? 250 : null,
                       child: TextField(
                        controller: _newRuleContentController,
                        maxLines: hasFocus ? null : 4, 
                        expands: hasFocus,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: "Enter new rule content here...\n(e.g., 'You are a pirate.')",
                          border: OutlineInputBorder(borderSide: themeProvider.enableBloom ? BorderSide(color: themeProvider.appThemeColor) : const BorderSide()),
                          enabledBorder: themeProvider.enableBloom ? OutlineInputBorder(borderSide: BorderSide(color: themeProvider.appThemeColor.withOpacity(0.5))) : const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.black26,
                          contentPadding: const EdgeInsets.all(8),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                     );
                  }
                ),
              ),
            const SizedBox(height: 8),

            // 2. Button bar for new rule content (Copy/Paste)
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.blueAccent),
                    tooltip: "Copy Rule Content",
                    onPressed: _copyRuleContentToClipboard,
                  ),
                  Container(width: 1, height: 20, color: Colors.white12),
                  IconButton(
                    icon: const Icon(Icons.paste, color: Colors.orangeAccent),
                    tooltip: "Paste Rule Content",
                    onPressed: _pasteRuleContentFromClipboard,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 3. Rule Name and Add Button Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ruleLabelController,
                    decoration: InputDecoration(
                      hintText: "Name your new rule...",
                      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: Colors.black12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.greenAccent.withAlpha(40)),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                  tooltip: "Add as new Tweak/Rule",
                  onPressed: _addRuleFromInput,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            
            _buildSliderSetting(


              title: "(Msg History) Limit",
              value: widget.historyLimit.toDouble(),
              min: 2,
              max: 2000,
              divisions: 499,
              activeColor: Colors.greenAccent,
              isInt: true,
              onChanged: (val) => widget.onHistoryLimitChanged(val.toInt()),
            ),
            const Text(
              "Note: Lower this if you get 'Context Window Exceeded' errors.",
              style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const Divider(),

            // --- GROUNDING SWITCH ---
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Grounding / Web Search", style: TextStyle(shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
              subtitle: Text(
                widget.currentProvider == AiProvider.gemini ? "Uses Google Search (Native)" 
                : widget.currentProvider == AiProvider.openRouter ? "Uses OpenRouter Web Plugin"
                : "Not available on this provider",
                style: const TextStyle(fontSize: 10, color: Colors.grey)
              ),
              value: widget.enableGrounding,
              activeThumbColor: Colors.greenAccent,
              onChanged: (widget.currentProvider == AiProvider.gemini || widget.currentProvider == AiProvider.openRouter || widget.currentProvider == AiProvider.arliAi || widget.currentProvider == AiProvider.nanoGpt)
                  ? widget.onEnableGroundingChanged
                  : null, 
            ),

            // --- REASONING MODE ---
            const SizedBox(height: 10),
             Text("Reasoning / Thinking Effort", style: TextStyle(fontWeight: FontWeight.bold, shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.white, blurRadius: 10)] : [])),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
                boxShadow: themeProvider.enableBloom ? [BoxShadow(color: themeProvider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : [],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: widget.reasoningEffort,
                  dropdownColor: const Color(0xFF2C2C2C),
                  icon: Icon(Icons.psychology, color: themeProvider.appThemeColor),
                  items: const [
                    DropdownMenuItem(value: "none", child: Text("Disabled (None)")),
                    DropdownMenuItem(value: "low", child: Text("Low / Minimal")),
                    DropdownMenuItem(value: "medium", child: Text("Medium")),
                    DropdownMenuItem(value: "high", child: Text("High / Deep Think")),
                  ],
                  onChanged: (val) {
                     if (val != null) widget.onReasoningEffortChanged(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Controls the depth of thought (Thinking Models Only).",
              style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const Divider(),
            const SizedBox(height: 20),
            
            // --- TEMPERATURE ---
            _buildSliderSetting(
              title: "Temperature (Creativity)",
              value: widget.temperature,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              activeColor: Colors.redAccent,
              onChanged: widget.onTemperatureChanged,
            ),

            // --- TOP P ---
            _buildSliderSetting(
              title: "Top P (Nucleus Sampling)",
              value: widget.topP,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              activeColor: Colors.purpleAccent,
              onChanged: widget.onTopPChanged,
            ),

            // --- TOP K ---
            _buildSliderSetting(
              title: "Top K (Vocabulary Size)",
              value: widget.topK.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              activeColor: Colors.orangeAccent,
              isInt: true,
              onChanged: (val) => widget.onTopKChanged(val.toInt()),
            ),

            // --- MAX OUTPUT TOKENS ---
            _buildSliderSetting(
              title: "Max Output Tokens",
              value: widget.maxOutputTokens.toDouble(),
              min: 256,
              max: 32768,
              activeColor: Colors.blueAccent,
              isInt: true,
              onChanged: (val) => widget.onMaxOutputTokensChanged(val.toInt()),
            ),

            // --- SAFETY FILTERS (Conditional Visibility) ---
            if (widget.currentProvider == AiProvider.gemini)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Disable Safety Filters", style: TextStyle(shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])), 
                subtitle: const Text("Applies to Gemini Only", style: TextStyle(fontSize: 10, color: Colors.grey)),
                value: widget.disableSafety, 
                activeThumbColor: Colors.redAccent, 
                onChanged: widget.onDisableSafetyChanged,
              ),
            const Divider(height: 5),
            const SizedBox(height: 30),
            Text("Visuals & Atmosphere", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeProvider.appThemeColor, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [])),
            const Divider(height: 10),
            
            Text("Global Interface Font", style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.appThemeColor, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [])),
            Consumer<ThemeProvider>(
              builder: (context, provider, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: provider.enableBloom ? provider.appThemeColor.withOpacity(0.5) : Colors.white12), boxShadow: provider.enableBloom ? [BoxShadow(color: provider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : []),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true, value: provider.fontStyle, dropdownColor: const Color(0xFF2C2C2C), icon: Icon(Icons.text_fields, color: provider.appThemeColor),
                      items: const [
                        DropdownMenuItem(value: 'Default', child: Text("Default (System)")),
                        DropdownMenuItem(value: 'Google', child: Text("Google Sans (Open Sans)")),
                        DropdownMenuItem(value: 'Apple', child: Text("Apple SF (Inter)")),
                        DropdownMenuItem(value: 'Claude', child: Text("Assistant (Source Serif 4)")),
                        DropdownMenuItem(value: 'Roleplay', child: Text("Storybook (Lora)")),
                        DropdownMenuItem(value: 'Terminal', child: Text("Hacker (Space Mono)")),
                        DropdownMenuItem(value: 'Manuscript', child: Text("Ancient Tome (EB Garamond)")),
                        DropdownMenuItem(value: 'Cyber', child: Text("Neon HUD (Orbitron)")),
                        DropdownMenuItem(value: 'ModernAnime', child: Text("Light Novel (Quicksand)")),
                        DropdownMenuItem(value: 'AnimeSub', child: Text("Subtitles (Kosugi Maru)")),
                        DropdownMenuItem(value: 'Gothic', child: Text("Victorian (Crimson Text)")),
                        DropdownMenuItem(value: 'Journal', child: Text("Handwritten (Caveat)")),
                        DropdownMenuItem(value: 'CleanThin', child: Text("Minimalist (Raleway)")),
                        DropdownMenuItem(value: 'Stylized', child: Text("Vogue (Playfair Display)")),
                        DropdownMenuItem(value: 'Fantasy', child: Text("MMORPG (Cinzel)")),
                        DropdownMenuItem(value: 'Typewriter', child: Text("Detective (Special Elite)")),
                        DropdownMenuItem(value: 'AnimeAce', child: Text("Manga (Anime Ace)")),
                        DropdownMenuItem(value: 'Acme', child: Text("Agent (Acme Secret Agent)")),
                        DropdownMenuItem(value: 'Smack', child: Text("Action (Smack Attack)")),
                      ],
                      onChanged: (String? newValue) { if (newValue != null) provider.setFont(newValue); },
                    ),
                  ),
                );
              },
            ),

            const Divider(),
            Text("Chat Customization", style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.appThemeColor, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [])),
            Consumer<ThemeProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    const SizedBox(height: 15),
                    _buildColorCircle("App Theme", provider.appThemeColor, (c) => provider.updateColor('appTheme', c)),
                    const SizedBox(height: 15),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildColorCircle("User BG", provider.userBubbleColor, (c) => provider.updateColor('userBubble', c.withAlpha(((provider.userBubbleColor.a * 255.0).round() & 0xff)))),
                        _buildColorCircle("User Text", provider.userTextColor, (c) => provider.updateColor('userText', c)),
                        _buildColorCircle("AI BG", provider.aiBubbleColor, (c) => provider.updateColor('aiBubble', c.withAlpha(((provider.aiBubbleColor.a * 255.0).round() & 0xff)))),
                        _buildColorCircle("AI Text", provider.aiTextColor, (c) => provider.updateColor('aiText', c)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          const Text("User Opacity:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const Spacer(),
                          Text("${(provider.userBubbleColor.a * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.bold, color: provider.appThemeColor)),
                        ],
                      ),
                    ),
                    Slider(
                      value: provider.userBubbleColor.a,
                      min: 0.0, max: 1.0,
                      activeColor: provider.userBubbleColor.withAlpha(255), 
                      inactiveColor: Colors.grey[800],
                      onChanged: (val) {
                        provider.updateColor('userBubble', provider.userBubbleColor.withAlpha((val * 255).round()));
                      },
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          const Text("AI Opacity:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const Spacer(),
                          Text("${(provider.aiBubbleColor.a * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                    Slider(
                      value: provider.aiBubbleColor.a,
                      min: 0.0, max: 1.0,
                      activeColor: provider.aiBubbleColor.withAlpha(255),
                      inactiveColor: Colors.grey[800],
                      onChanged: (val) {
                        provider.updateColor('aiBubble', provider.aiBubbleColor.withAlpha((val * 255).round()));
                      },
                    ),
                    
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text("Reset to Defaults", style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF2C2C2C),
                              title: const Text("Reset Theme?", style: TextStyle(color: Colors.white)),
                              content: const Text("This will revert all colors and visual settings.", style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                                  onPressed: () {
                                    provider.resetToDefaults();
                                    Navigator.pop(ctx);
                                  },
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Consumer<ThemeProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Enable Bloom (Glow)", style: TextStyle(fontSize: 14, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                      subtitle: const Text("Adds a dreamy glow effect", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      value: provider.enableBloom,
                      activeThumbColor: provider.appThemeColor,
                      onChanged: (val) => provider.toggleBloom(val),
                    ),
                    const Divider(),
                    Text("Environmental Effects", style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.appThemeColor.withOpacity(0.8), shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Floating Dust Motes", style: TextStyle(fontSize: 14, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                      subtitle: const Text("Subtle, glowing particles", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      value: provider.enableMotes,
                      activeThumbColor: themeProvider.appThemeColor,
                      onChanged: (val) => provider.toggleMotes(val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Gentle Rain", style: TextStyle(fontSize: 14, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                      subtitle: const Text("A calming, rainy mood", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      value: provider.enableRain,
                      activeThumbColor: themeProvider.appThemeColor,
                      onChanged: (val) => provider.toggleRain(val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Glowing Fireflies", style: TextStyle(fontSize: 14, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                      subtitle: const Text("Blinking lights for a cozy vibe", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      value: provider.enableFireflies,
                      activeThumbColor: themeProvider.appThemeColor,
                      onChanged: (val) => provider.toggleFireflies(val),
                    ),
                    const Divider(),
                    // Sliders for VFX
                    if (provider.enableMotes)
                      _buildSliderSetting(
                          title: "Motes Density",
                          value: provider.motesDensity.toDouble(),
                          min: 1,
                          max: 150,
                          isInt: true,
                          activeColor: themeProvider.appThemeColor,
                          onChanged: (val) => provider.setMotesDensity(val.toInt())),
                    if (provider.enableRain)
                      _buildSliderSetting(
                          title: "Rainfall Intensity",
                          value: provider.rainIntensity.toDouble(),
                          min: 1,
                          max: 200,
                          isInt: true,
                          activeColor: themeProvider.appThemeColor,
                          onChanged: (val) => provider.setRainIntensity(val.toInt())),
                    if (provider.enableFireflies)
                      _buildSliderSetting(
                          title: "Fireflies Count",
                          value: provider.firefliesCount.toDouble(),
                          min: 1,
                          max: 100,
                          isInt: true,
                          activeColor: themeProvider.appThemeColor,
                          onChanged: (val) => provider.setFirefliesCount(val.toInt())),

                    const SizedBox(height: 10),
                    if (provider.backgroundImagePath != null) ...[
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          InkWell(onTap: () => provider.setBackgroundImage("assets/default.jpg"), child: const Text("CLEAR BACKGROUND", style: TextStyle(fontSize: 15, color: Colors.redAccent)),)
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      height: 250, 
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10),),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8,),
                        itemCount: 1 + provider.customImagePaths.length + kAssetBackgrounds.length,
                       itemBuilder: (context, index) {
                          if (index == 0) {
                            return GestureDetector(
                              onTap: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                if (image != null) provider.addCustomImage(image.path);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: provider.appThemeColor.withAlpha((0.1 * 255).round()),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: provider.appThemeColor.withAlpha((0.5 * 255).round())),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center, 
                                  children: [Icon(Icons.add_photo_alternate, color: provider.appThemeColor), Text("Add", style: TextStyle(fontSize: 10, color: provider.appThemeColor))],
                                ),
                              ),
                            );
                          }

                          final int adjustedIndex = index - 1;
                          final int customCount = provider.customImagePaths.length;
                          String path;
                          bool isCustom;

                          if (adjustedIndex < customCount) {
                            path = provider.customImagePaths[adjustedIndex];
                            isCustom = true;
                          } else {
                            path = kAssetBackgrounds[adjustedIndex - customCount];
                            isCustom = false;
                          }

                          final bool isSelected = provider.backgroundImagePath == path;

                          return InkWell(
                            onTap: () => provider.setBackgroundImage(path),
                            // Long Press triggers "Red Delete"
                            onLongPress: isCustom ? () {
                              HapticFeedback.mediumImpact(); 
                              provider.removeCustomImage(path);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Image Deleted"), backgroundColor: Colors.redAccent, duration: Duration(milliseconds: 500)),
                              );
                            } : null,
                            splashColor: Colors.redAccent.withAlpha((0.8 * 255).round()), // The Red Blur Effect on hold
                            highlightColor: Colors.redAccent.withAlpha((0.4 * 255).round()),
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isCustom
                                    ? Image.file(File(path), fit: BoxFit.cover)
                                    : Image.asset(path, fit: BoxFit.cover),
                                ),
                                if (isSelected) 
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: provider.appThemeColor, width: 2), 
                                      borderRadius: BorderRadius.circular(8), 
                                    ), 
                                    child: Center(child: Icon(Icons.check_circle, color: provider.appThemeColor)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (provider.backgroundImagePath != null) ...[
                      const SizedBox(height: 5),
                      Text("Dimmer: ${(provider.backgroundOpacity * 100).toInt()}%", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Slider(value: provider.backgroundOpacity, min: 0.0, max: 0.95, activeColor: provider.appThemeColor, inactiveColor: Colors.grey[800], onChanged: (val) => provider.setBackgroundOpacity(val),),
                    ]
                  ],
                );
              },
            ),
          ],
        ),
      ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: widget.hasUnsavedChanges ? Curves.bounceOut : Curves.easeInBack,
            bottom: widget.hasUnsavedChanges ? 30 : MediaQuery.of(context).size.height + 200,
            right: 20,
            child: FloatingActionButton(
                            backgroundColor: themeProvider.appThemeColor,
              foregroundColor: Colors.black,
              onPressed: _handleSaveSettings,
              elevation: 10,
              child: const Icon(Icons.save),
            ),

          ),
        ],
      ),
    );
  }
}
