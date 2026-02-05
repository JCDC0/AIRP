import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';

class SystemPromptPanel extends StatefulWidget {
  final TextEditingController mainPromptController;
  final TextEditingController advancedPromptController;
  final TextEditingController promptTitleController;
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

  // Custom Rules storage
  List<Map<String, dynamic>> _customRules = [];
  bool _isKaomojiFixEnabled = false;

  static const String kDefaultKaomojiFix = "Use kaomoji for spoken character (e.g. OwO, ^_^) frequently in character dialogue to convey emotion for spoken characters only. (Except if the character is only you)";
  static const String kCustomRulesKey = "custom_sys_prompt_rules";

  @override
  void initState() {
    super.initState();
    _ruleLabelController = TextEditingController();
    _newRuleContentController = TextEditingController();
    
    // Load rules after build to ensure provider is available or use listen:false
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      String fullPrompt = chatProvider.systemInstruction;
      if (chatProvider.advancedSystemInstruction.isNotEmpty) {
         if (fullPrompt.isNotEmpty) fullPrompt += "\n\n";
         fullPrompt += chatProvider.advancedSystemInstruction;
      }
      _loadCustomRulesAndParse(fullPrompt);
    });
  }

  @override
  void dispose() {
    _ruleLabelController.dispose();
    _newRuleContentController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomRulesAndParse(String systemInstruction) async {
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
        _parseSystemInstruction(systemInstruction);
      });
    }
  }

  Future<void> _saveCustomRulesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_customRules);
    await prefs.setString(kCustomRulesKey, encoded);
  }

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

    widget.mainPromptController.text = workingText;
    widget.advancedPromptController.text = advancedVisualText;
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
    
    widget.advancedPromptController.text = activePrompts.join('\n\n');
    
    // String advanced = widget.advancedPromptController.text.trim();
    // String main = widget.mainPromptController.text.trim();
    // String finalPrompt = (advanced.isNotEmpty && main.isNotEmpty) ? "$advanced\n\n$main" : advanced + main;
    
    // final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // chatProvider.setSystemInstruction(finalPrompt); // Removed to allow Save button logic
    widget.onPromptChanged();
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
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final rule = _customRules[index];
    final labelController = TextEditingController(text: rule['label']);
    final contentController = TextEditingController(text: rule['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text("Edit Rule", style: TextStyle(color: Colors.white, fontSize: scaleProvider.systemFontSize)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: "Rule Name", filled: true, fillColor: Colors.black12),
              style: TextStyle(color: Colors.white, fontSize: scaleProvider.systemFontSize * 0.8),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "Rule Content", filled: true, fillColor: Colors.black12),
              style: TextStyle(color: Colors.white, fontSize: scaleProvider.systemFontSize * 0.8),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Save", style: TextStyle(color: Colors.blueAccent, fontSize: scaleProvider.systemFontSize * 0.8)),
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
        title: Text("Delete Rule?", style: TextStyle(color: Colors.redAccent, fontSize: scaleProvider.systemFontSize)),
        content: Text(
          "Are you sure you want to delete '${rule['label']}'?\n\nThis cannot be undone.",
          style: TextStyle(color: Colors.white70, fontSize: scaleProvider.systemFontSize * 0.8)
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("DELETE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: scaleProvider.systemFontSize * 0.8)),
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
    chatProvider.savePromptToLibrary(widget.promptTitleController.text, widget.mainPromptController.text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved '${widget.promptTitleController.text}' to Library!")));
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
        const SizedBox(height: 30),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("System Prompt", style:
            TextStyle(
              fontSize: scaleProvider.systemFontSize,
              fontWeight: FontWeight.bold,
              shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.white, blurRadius: 10)] : [])),
          value: chatProvider.enableSystemPrompt,
          activeThumbColor: themeProvider.appThemeColor,
          onChanged: (val) {
            chatProvider.setEnableSystemPrompt(val);
            chatProvider.saveSettings();
          },
        ),
        
        // 1. THE DROPDOWN & ACTIONS ROW
        Opacity(
          opacity: chatProvider.enableSystemPrompt ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !chatProvider.enableSystemPrompt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              hint: Text("Select from Library...", style: TextStyle(color: Colors.grey, fontSize: scaleProvider.systemFontSize * 0.8)),
              dropdownColor: const Color(0xFF2C2C2C),
              icon: Icon(Icons.arrow_drop_down, color: themeProvider.appThemeColor),
              value: null, 
              items: [
                DropdownMenuItem<String>(
                  value: "CREATE_NEW",
                  child: Row(children: [
                    Icon(Icons.add, color: Colors.greenAccent, size: 16),
                    SizedBox(width: 8),
                    Text("Create New", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: scaleProvider.systemFontSize)),
                  ]),
                ),
                ...chatProvider.savedSystemPrompts.map((prompt) {
                  return DropdownMenuItem<String>(
                    value: prompt.title,
                    child: Text(prompt.title, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: scaleProvider.systemFontSize)),
                  );
                }),
              ],
              onChanged: (String? newValue) {
                if (newValue == "CREATE_NEW") {
                  widget.promptTitleController.clear();
                  widget.mainPromptController.clear();
                  widget.onPromptChanged();
                } else if (newValue != null) {
                  final prompt = chatProvider.savedSystemPrompts.firstWhere((p) => p.title == newValue);
                  widget.promptTitleController.text = prompt.title;
                  _parseSystemInstruction(prompt.content);
                  widget.onPromptChanged();
                }
              },
            ),
          ),
        ),
        
        const SizedBox(height: 10),

        // 2. PROMPT TITLE FIELD
        TextField(
          controller: widget.promptTitleController,
          decoration: InputDecoration(
            labelText: "Prompt Title (e.g., 'World of mana and mechs')",
            labelStyle: TextStyle(color: themeProvider.appThemeColor, fontSize: scaleProvider.systemFontSize * 0.8),
            border: OutlineInputBorder(borderSide: themeProvider.enableBloom ? BorderSide(color: themeProvider.appThemeColor) : const BorderSide()),
            enabledBorder: themeProvider.enableBloom ? OutlineInputBorder(borderSide: BorderSide(color: themeProvider.appThemeColor.withOpacity(0.5))) : const OutlineInputBorder(),
            filled: true, fillColor: Colors.black12,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
          style: TextStyle(fontSize: scaleProvider.systemFontSize, fontWeight: FontWeight.bold),
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
                  controller: widget.mainPromptController,
                  onChanged: (_) => widget.onPromptChanged(),
                  maxLines: hasFocus ? null : scaleProvider.inputAreaScale.toInt(),
                  expands: hasFocus,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: "Enter the roleplay rules here...",
                    hintStyle: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
                    border: OutlineInputBorder(borderSide: themeProvider.enableBloom ? BorderSide(color: themeProvider.appThemeColor) : const BorderSide()),
                    enabledBorder: themeProvider.enableBloom ? OutlineInputBorder(borderSide: BorderSide(color: themeProvider.appThemeColor.withOpacity(0.5))) : const OutlineInputBorder(),
                    filled: true, fillColor: Colors.black26,
                  ),
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
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
                icon: Icon(Icons.copy, color: Colors.blueAccent, size: scaleProvider.systemFontSize * 1.5),
                tooltip: "Copy Text",
                onPressed: _copyToClipboard,
              ),
              Container(width: 1, height: 20, color: Colors.white12),
              IconButton(
                icon: Icon(Icons.paste, color: Colors.orangeAccent, size: scaleProvider.systemFontSize * 1.5),
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
                  textStyle: TextStyle(fontSize: scaleProvider.systemFontSize * 1),
                ),
                onPressed: _handleSavePreset,
                icon: Icon(Icons.save, size: scaleProvider.systemFontSize * 1.25),
                label: Text("Save Preset"),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.redAccent.withAlpha((0.2 * 255).round())),
              icon: Icon(Icons.delete, color: Colors.redAccent, size: scaleProvider.systemFontSize * 1.2),
              tooltip: "Delete Preset",
              onPressed: () {
                chatProvider.deletePromptFromLibrary(widget.promptTitleController.text);
                widget.promptTitleController.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted Preset")));
              },
            ),
          ],
        ),
              ],
            ),
          ),
        ),
        // --- GROUNDING SWITCH ---
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("Grounding / Web Search", style: TextStyle(fontSize: scaleProvider.systemFontSize, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
          subtitle: Text(
            chatProvider.currentProvider == AiProvider.gemini ? "Uses Google Search (Native)" 
            : chatProvider.currentProvider == AiProvider.openRouter ? "Uses OpenRouter Web Plugin"
            : "Not available on this provider",
            style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8, color: Colors.grey)
          ),
          value: chatProvider.enableGrounding,
          activeThumbColor: Colors.greenAccent,
          onChanged: (chatProvider.currentProvider == AiProvider.gemini || chatProvider.currentProvider == AiProvider.openRouter || chatProvider.currentProvider == AiProvider.arliAi || chatProvider.currentProvider == AiProvider.nanoGpt)
              ? (val) {
                  chatProvider.setEnableGrounding(val);
                  chatProvider.saveSettings();
                }
              : null,
        ),

        // --- SAFETY FILTERS (Conditional Visibility) ---
        if (chatProvider.currentProvider == AiProvider.gemini)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Disable Safety Filters", style: TextStyle(fontSize: scaleProvider.systemFontSize, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])), 
            subtitle: Text("Applies to Gemini Only", style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8, color: Colors.grey)),
            value: chatProvider.disableSafety, 
            activeThumbColor: Colors.redAccent, 
            onChanged: (val) {
              chatProvider.setDisableSafety(val);
              chatProvider.saveSettings();
            },
          ),

        // --- USAGE STATS (OpenRouter Only) ---
        if (chatProvider.currentProvider == AiProvider.openRouter)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Request Usage Stats", style: TextStyle(fontSize: scaleProvider.systemFontSize, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
            subtitle: Text("Appends token usage info to response", style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8, color: Colors.grey)),
            value: chatProvider.enableUsage,
            activeThumbColor: Colors.tealAccent,
            onChanged: (val) {
              chatProvider.setEnableUsage(val);
              chatProvider.saveSettings();
            },
          ),
        const Divider(),

        // --- ADVANCED SYSTEM PROMPT SECTION ---
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("Advanced System Prompt", style: TextStyle(fontWeight: FontWeight.bold, fontSize: scaleProvider.systemFontSize, color: themeProvider.appThemeColor, shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.white, blurRadius: 10)] : [])),
          value: chatProvider.enableAdvancedSystemPrompt,
          activeThumbColor: themeProvider.appThemeColor,
          onChanged: (val) {
            chatProvider.setEnableAdvancedSystemPrompt(val);
            chatProvider.saveSettings();
          },
        ),
        
        Opacity(
          opacity: chatProvider.enableAdvancedSystemPrompt ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !chatProvider.enableAdvancedSystemPrompt,
            child: Column(
              children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
          ),
          child: ExpansionTile(
            title: Text("Tweaks & Overrides", style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8, fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text(
              _isKaomojiFixEnabled ? "Active: Kaomoji" : "Configure hidden behavior...",
              style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.6, color: Colors.grey)
            ),
            collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            children: [
               ListTile(
                 dense: true,
                 contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                 title: Text("Kaomoji Mode", style: TextStyle(color: themeProvider.appThemeColor, fontWeight: FontWeight.bold, fontSize: scaleProvider.systemFontSize * 0.8)),
                 trailing: Switch(
                   value: _isKaomojiFixEnabled,
                   activeThumbColor: themeProvider.appThemeColor,
                   onChanged: (val) {
                     setState(() => _isKaomojiFixEnabled = val);
                     _onAdvancedSwitchChanged();
                     widget.onPromptChanged();
                   },
                 ),
                 onTap: () {
                    widget.advancedPromptController.text = kDefaultKaomojiFix;
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
                    title: Text(rule['label'], style: TextStyle(color: Colors.white70, fontSize: scaleProvider.systemFontSize * 0.8), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                            widget.onPromptChanged();
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                       widget.advancedPromptController.text = rule['content'];
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
                    Text("Raw Advanced Instructions:", style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.7, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                     Focus(
                        onFocusChange: (hasFocus) => setState((){}),
                        child: Builder(builder: (context) {
                          final hasFocus = Focus.of(context).hasFocus;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: hasFocus ? 200 : null,
                            child: TextField(
                             controller: widget.advancedPromptController,
                             maxLines: hasFocus ? null : 4,
                             expands: hasFocus,
                             textAlignVertical: TextAlignVertical.top,
                             style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8, fontFamily: 'monospace', color: Colors.white70),
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
                               widget.onPromptChanged();
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
        Text("Add a New Tweak/Rule", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: scaleProvider.systemFontSize)),
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
                    style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
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
                icon: Icon(Icons.copy, color: Colors.blueAccent, size: scaleProvider.systemFontSize * 1.5),
                tooltip: "Copy Rule Content",
                onPressed: _copyRuleContentToClipboard,
              ),
              Container(width: 1, height: 20, color: Colors.white12),
              IconButton(
                icon: Icon(Icons.paste, color: Colors.orangeAccent, size: scaleProvider.systemFontSize * 1.5),
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
                  hintStyle: TextStyle(fontSize: scaleProvider.systemFontSize * 0.7, color: Colors.grey),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: Colors.black12,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.greenAccent.withAlpha(40)),
              icon: Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: scaleProvider.systemFontSize * 0.8),
              tooltip: "Add as new Tweak/Rule",
              onPressed: _addRuleFromInput,
            ),
          ],
        ),
        const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
