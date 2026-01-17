import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/constants.dart';
import 'settings_slider.dart';
import 'settings_color_picker.dart';
import 'model_selector.dart';

class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key});

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
  bool _systemPromptChanged = false; 
  
  // Custom Rules storage
  List<Map<String, dynamic>> _customRules = [];

  static const String kDefaultKaomojiFix = "Use kaomoji for spoken character (e.g. OwO, ^_^) frequently in character dialogue to convey emotion for spoken characters only. (Except if the character is only you)";
  static const String kCustomRulesKey = "custom_sys_prompt_rules";
  
  bool _isKaomojiFixEnabled = false;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    _apiKeyController = TextEditingController(text: _getApiKey(chatProvider));
    _localIpController = TextEditingController(text: chatProvider.localIp);
    _titleController = TextEditingController(text: chatProvider.currentTitle);
    _promptTitleController = TextEditingController(); // We don't persist prompt title in provider currently, just the list
    _openRouterModelController = TextEditingController(text: chatProvider.openRouterModel);
    _ruleLabelController = TextEditingController();
    _newRuleContentController = TextEditingController();
    
    _advancedPromptController = TextEditingController();
    _mainPromptController = TextEditingController();

    _loadCustomRulesAndParse(chatProvider.systemInstruction);
  }

  String _getApiKey(ChatProvider provider) {
    switch (provider.currentProvider) {
      case AiProvider.gemini: return provider.geminiKey;
      case AiProvider.openRouter: return provider.openRouterKey;
      case AiProvider.openAi: return provider.openAiKey;
      case AiProvider.arliAi: return provider.arliAiKey;
      case AiProvider.nanoGpt: return provider.nanoGptKey;
      case AiProvider.local: return "";
    }
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

    _mainPromptController.text = workingText;
    _advancedPromptController.text = advancedVisualText;
  }
  
  void _handleSaveSettings() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    String finalPrompt;
    String advanced = _advancedPromptController.text.trim();
    String main = _mainPromptController.text.trim(); 
    
    if (advanced.isNotEmpty && main.isNotEmpty) {
      finalPrompt = "$advanced\n\n$main";
    } else {
      finalPrompt = advanced + main;
    }
    
    chatProvider.setSystemInstruction(finalPrompt);
    chatProvider.saveSettings();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Settings Saved & Model Updated"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.lightBlue,
        duration: Duration(milliseconds: 1500),
      )
    );
    
    _systemPromptChanged = false; 
  }
  
  void _handleSavePreset() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    setState(() {
      _isProgrammaticUpdate = true;
    });
    
    chatProvider.setSystemInstruction(_mainPromptController.text);
    chatProvider.savePromptToLibrary(_promptTitleController.text, _mainPromptController.text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isProgrammaticUpdate = false;
          _systemPromptChanged = false; 
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved '${_promptTitleController.text}' to Library!")));
      }
    });
  }

  void _notifyChangeIfNeeded() {
    if (!_systemPromptChanged) {
        String advanced = _advancedPromptController.text.trim();
        String main = _mainPromptController.text; 
        String finalPrompt = (advanced.isNotEmpty && main.isNotEmpty) ? "$advanced\n\n$main" : advanced + main; 
        
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        if (finalPrompt != chatProvider.systemInstruction) {
            _systemPromptChanged = true; 
            chatProvider.setSystemInstruction(finalPrompt);
        }
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
    
    String advanced = _advancedPromptController.text.trim();
    String main = _mainPromptController.text.trim();
    String finalPrompt = (advanced.isNotEmpty && main.isNotEmpty) ? "$advanced\n\n$main" : advanced + main;
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.setSystemInstruction(finalPrompt);
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

  void _deleteCustomRuleForever(int index) {
      setState(() {
        bool wasActive = _customRules[index]['active'] == true;
        _customRules.removeAt(index);
        _saveCustomRulesToPrefs();
        if (wasActive) _onAdvancedSwitchChanged();
      });
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

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
            const Text("v0.2", 
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
            
            if (chatProvider.currentProvider != AiProvider.local) ...[
              TextField(
                controller: _apiKeyController,
                onChanged: chatProvider.setApiKey,
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
                onChanged: chatProvider.setLocalIp,
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
                onChanged: chatProvider.setTitle,
              ),
            ),
            const SizedBox(height: 20),

            Text("Model Selection", style: TextStyle(fontWeight: FontWeight.bold, shadows: themeProvider.enableBloom ? [const Shadow(color: Colors.white, blurRadius: 10)] : [])),
            const SizedBox(height: 5),

            // ============================================
            // GEMINI UI
            // ============================================
            if (chatProvider.currentProvider == AiProvider.gemini) ...[
              if (chatProvider.geminiModelsList.isNotEmpty)
                ModelSelector(
                  modelsList: chatProvider.geminiModelsList,
                  selectedModel: chatProvider.selectedGeminiModel,
                  onSelected: chatProvider.setModel,
                  placeholder: "Select Gemini Model",
                )
              else
                TextField(
                  decoration: const InputDecoration(hintText: "models/gemini-flash-lite-latest", border: OutlineInputBorder(), isDense: true),
                  onChanged: chatProvider.setModel,
                  controller: TextEditingController(text: chatProvider.selectedGeminiModel),
                ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: chatProvider.isLoadingGeminiModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(chatProvider.isLoadingGeminiModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: chatProvider.isLoadingGeminiModels ? null : chatProvider.fetchGeminiModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
                ),
              ),
            ]

            // ============================================
            // OPENROUTER UI
            // ============================================
            else if (chatProvider.currentProvider == AiProvider.openRouter) ...[
              if (chatProvider.openRouterModelsList.isNotEmpty)
                ModelSelector(
                  modelsList: chatProvider.openRouterModelsList,
                  selectedModel: chatProvider.openRouterModel,
                  onSelected: (val) {
                    chatProvider.setModel(val);
                    _openRouterModelController.text = val;
                  },
                  placeholder: "Select OpenRouter Model",
                )
              else
                TextField(
                  controller: _openRouterModelController,
                  decoration: const InputDecoration(hintText: "vendor/model-name", border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) { chatProvider.setModel(val.trim()); },
                ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: chatProvider.isLoadingOpenRouterModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(chatProvider.isLoadingOpenRouterModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: chatProvider.isLoadingOpenRouterModels ? null : chatProvider.fetchOpenRouterModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.purpleAccent),
                ),
              ),
            ],
            // -------------------------------------------
            // LOCAL UI
            // -------------------------------------------
            if (chatProvider.currentProvider == AiProvider.local) ...[
               const SizedBox(height: 5),
               TextField(
                 onChanged: chatProvider.setLocalModelName,
                 controller: TextEditingController(text: chatProvider.localModelName),
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
            if (chatProvider.currentProvider == AiProvider.arliAi) ...[
              if (chatProvider.arliAiModelsList.isNotEmpty)
                ModelSelector(
                  modelsList: chatProvider.arliAiModelsList,
                  selectedModel: chatProvider.arliAiModel,
                  onSelected: chatProvider.setModel,
                  placeholder: "Select ArliAI Model",
                )
              else
                TextField(
                  controller: TextEditingController(text: chatProvider.arliAiModel),
                  decoration: const InputDecoration(hintText: "Gemma-3-27B-Big-Tiger-v3", border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) { chatProvider.setModel(val.trim()); },
                ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: chatProvider.isLoadingArliAiModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(chatProvider.isLoadingArliAiModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: chatProvider.isLoadingArliAiModels ? null : chatProvider.fetchArliAiModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent),
                ),
              ),
            ],

            // ============================================
            // NANOGPT UI
            // ============================================
            if (chatProvider.currentProvider == AiProvider.nanoGpt) ...[
              if (chatProvider.nanoGptModelsList.isNotEmpty)
                ModelSelector(
                  modelsList: chatProvider.nanoGptModelsList,
                  selectedModel: chatProvider.nanoGptModel,
                  onSelected: chatProvider.setModel,
                  placeholder: "Select NanoGPT Model",
                )
              else
                TextField(
                  controller: TextEditingController(text: chatProvider.nanoGptModel),
                  decoration: const InputDecoration(hintText: "aion-labs/aion-rp-llama-3.1-8b", border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) { chatProvider.setModel(val.trim()); },
                ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: chatProvider.isLoadingNanoGptModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(chatProvider.isLoadingNanoGptModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: chatProvider.isLoadingNanoGptModels ? null : chatProvider.fetchNanoGptModels,
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
                    ...chatProvider.savedSystemPrompts.map((prompt) {
                      return DropdownMenuItem<String>(
                        value: prompt.title,
                        child: Text(prompt.title, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue == "CREATE_NEW") {
                      _promptTitleController.clear();
                      _mainPromptController.clear();
                      _notifyChangeIfNeeded();
                    } else if (newValue != null) {
                      final prompt = chatProvider.savedSystemPrompts.firstWhere((p) => p.title == newValue);
                      _promptTitleController.text = prompt.title;
                      _parseSystemInstruction(prompt.content);
                      _notifyChangeIfNeeded();
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 10),

            // 2. PROMPT TITLE FIELD
            TextField(
              controller: _promptTitleController,
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
                  onPressed: () {
                    chatProvider.deletePromptFromLibrary(_promptTitleController.text);
                    _promptTitleController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted Preset")));
                  },
                ),
              ],
            ),
            // --- GROUNDING SWITCH ---
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Grounding / Web Search", style: TextStyle(shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
              subtitle: Text(
                chatProvider.currentProvider == AiProvider.gemini ? "Uses Google Search (Native)" 
                : chatProvider.currentProvider == AiProvider.openRouter ? "Uses OpenRouter Web Plugin"
                : "Not available on this provider",
                style: const TextStyle(fontSize: 10, color: Colors.grey)
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
                title: Text("Disable Safety Filters", style: TextStyle(shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])), 
                subtitle: const Text("Applies to Gemini Only", style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                title: Text("Request Usage Stats", style: TextStyle(shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                subtitle: const Text("Appends token usage info to response", style: TextStyle(fontSize: 10, color: Colors.grey)),
                value: chatProvider.enableUsage,
                activeThumbColor: Colors.tealAccent,
                onChanged: (val) {
                  chatProvider.setEnableUsage(val);
                  chatProvider.saveSettings();
                },
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
                         _handleSaveSettings();
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
                                _handleSaveSettings();
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
            
            SettingsSlider(
              title: "(Msg History) Limit",
              value: chatProvider.historyLimit.toDouble(),
              min: 2,
              max: 2000,
              divisions: 499,
              activeColor: Colors.greenAccent,
              isInt: true,
              onChanged: (val) {
                chatProvider.setHistoryLimit(val.toInt());
                chatProvider.saveSettings();
              },
            ),
            const Text(
              "Note: Lower this if you get 'Context Window Exceeded' errors.",
              style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const Divider(),

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
                  value: chatProvider.reasoningEffort,
                  dropdownColor: const Color(0xFF2C2C2C),
                  icon: Icon(Icons.psychology, color: themeProvider.appThemeColor),
                  items: const [
                    DropdownMenuItem(value: "none", child: Text("Disabled (None)")),
                    DropdownMenuItem(value: "low", child: Text("Low / Minimal")),
                    DropdownMenuItem(value: "medium", child: Text("Medium")),
                    DropdownMenuItem(value: "high", child: Text("High / Deep Think")),
                  ],
                  onChanged: (val) {
                     if (val != null) {
                       chatProvider.setReasoningEffort(val);
                       chatProvider.saveSettings();
                     }
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
            
            // --- TEMPERATURE ---
            SettingsSlider(
              title: "Temperature (Creativity)",
              value: chatProvider.temperature,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              activeColor: Colors.redAccent,
              onChanged: (val) {
                chatProvider.setTemperature(val);
                chatProvider.saveSettings();
              },
            ),

            // --- TOP P ---
            SettingsSlider(
              title: "Top P (Nucleus Sampling)",
              value: chatProvider.topP,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              activeColor: Colors.purpleAccent,
              onChanged: (val) {
                chatProvider.setTopP(val);
                chatProvider.saveSettings();
              },
            ),

            // --- TOP K ---
            SettingsSlider(
              title: "Top K (Vocabulary Size)",
              value: chatProvider.topK.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              activeColor: Colors.orangeAccent,
              isInt: true,
              onChanged: (val) {
                chatProvider.setTopK(val.toInt());
                chatProvider.saveSettings();
              },
            ),

            // --- MAX OUTPUT TOKENS ---
            SettingsSlider(
              title: "Max Output Tokens",
              value: chatProvider.maxOutputTokens.toDouble(),
              min: 256,
              max: 32768,
              activeColor: Colors.blueAccent,
              isInt: true,
              onChanged: (val) {
                chatProvider.setMaxOutputTokens(val.toInt());
                chatProvider.saveSettings();
              },
            ),
            const Divider(height: 5),
            const SizedBox(height: 30),
            Text("Visuals & Atmosphere", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeProvider.appThemeColor, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [])),
            const Divider(height: 10),
            
            Text("Global Interface Font", style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.appThemeColor, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12), boxShadow: themeProvider.enableBloom ? [BoxShadow(color: themeProvider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : []),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true, value: themeProvider.fontStyle, dropdownColor: const Color(0xFF2C2C2C), icon: Icon(Icons.text_fields, color: themeProvider.appThemeColor),
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
                  onChanged: (String? newValue) { if (newValue != null) themeProvider.setFont(newValue); },
                ),
              ),
            ),

            const Divider(),
            Text("Chat Customization", style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.appThemeColor, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 10)] : [])),
            Column(
              children: [
                const SizedBox(height: 15),
                SettingsColorPicker(label: "App Theme", color: themeProvider.appThemeColor, onSave: (c) => themeProvider.updateColor('appTheme', c)),
                const SizedBox(height: 15),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SettingsColorPicker(label: "User BG", color: themeProvider.userBubbleColor, onSave: (c) => themeProvider.updateColor('userBubble', c.withAlpha(((themeProvider.userBubbleColor.a * 255.0).round() & 0xff)))),
                    SettingsColorPicker(label: "User Text", color: themeProvider.userTextColor, onSave: (c) => themeProvider.updateColor('userText', c)),
                    SettingsColorPicker(label: "AI BG", color: themeProvider.aiBubbleColor, onSave: (c) => themeProvider.updateColor('aiBubble', c.withAlpha(((themeProvider.aiBubbleColor.a * 255.0).round() & 0xff)))),
                    SettingsColorPicker(label: "AI Text", color: themeProvider.aiTextColor, onSave: (c) => themeProvider.updateColor('aiText', c)),
                  ],
                ),
                const SizedBox(height: 20),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text("User Opacity:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const Spacer(),
                      Text("${(themeProvider.userBubbleColor.a * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.appThemeColor)),
                    ],
                  ),
                ),
                Slider(
                  value: themeProvider.userBubbleColor.a,
                  min: 0.0, max: 1.0,
                  activeColor: themeProvider.userBubbleColor.withAlpha(255), 
                  inactiveColor: Colors.grey[800],
                  onChanged: (val) {
                    themeProvider.updateColor('userBubble', themeProvider.userBubbleColor.withAlpha((val * 255).round()));
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text("AI Opacity:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const Spacer(),
                      Text("${(themeProvider.aiBubbleColor.a * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                Slider(
                  value: themeProvider.aiBubbleColor.a,
                  min: 0.0, max: 1.0,
                  activeColor: themeProvider.aiBubbleColor.withAlpha(255),
                  inactiveColor: Colors.grey[800],
                  onChanged: (val) {
                    themeProvider.updateColor('aiBubble', themeProvider.aiBubbleColor.withAlpha((val * 255).round()));
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
                                themeProvider.resetToDefaults();
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
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Enable Bloom (Glow)", style: TextStyle(fontSize: 14, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                  subtitle: const Text("Adds a dreamy glow effect", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  value: themeProvider.enableBloom,
                  activeThumbColor: themeProvider.appThemeColor,
                  onChanged: (val) => themeProvider.toggleBloom(val),
                ),
                const Divider(),
                Text("Environmental Effects", style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.appThemeColor.withOpacity(0.8), shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Floating Dust Motes", style: TextStyle(fontSize: 14, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                  subtitle: const Text("Subtle, glowing particles", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  value: themeProvider.enableMotes,
                  activeThumbColor: themeProvider.appThemeColor,
                  onChanged: (val) => themeProvider.toggleMotes(val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Gentle Rain", style: TextStyle(fontSize: 14, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                  subtitle: const Text("A calming, rainy mood", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  value: themeProvider.enableRain,
                  activeThumbColor: themeProvider.appThemeColor,
                  onChanged: (val) => themeProvider.toggleRain(val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Glowing Fireflies", style: TextStyle(fontSize: 14, shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor.withOpacity(0.9), blurRadius: 20)] : [])),
                  subtitle: const Text("Blinking lights for a cozy vibe", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  value: themeProvider.enableFireflies,
                  activeThumbColor: themeProvider.appThemeColor,
                  onChanged: (val) => themeProvider.toggleFireflies(val),
                ),
                const Divider(),
                // Sliders for VFX
                if (themeProvider.enableMotes)
                  SettingsSlider(
                      title: "Motes Density",
                      value: themeProvider.motesDensity.toDouble(),
                      min: 1,
                      max: 150,
                      isInt: true,
                      activeColor: themeProvider.appThemeColor,
                      onChanged: (val) => themeProvider.setMotesDensity(val.toInt())),
                if (themeProvider.enableRain)
                  SettingsSlider(
                      title: "Rainfall Intensity",
                      value: themeProvider.rainIntensity.toDouble(),
                      min: 1,
                      max: 200,
                      isInt: true,
                      activeColor: themeProvider.appThemeColor,
                      onChanged: (val) => themeProvider.setRainIntensity(val.toInt())),
                if (themeProvider.enableFireflies)
                  SettingsSlider(
                      title: "Fireflies Count",
                      value: themeProvider.firefliesCount.toDouble(),
                      min: 1,
                      max: 100,
                      isInt: true,
                      activeColor: themeProvider.appThemeColor,
                      onChanged: (val) => themeProvider.setFirefliesCount(val.toInt())),

                const SizedBox(height: 10),
                if (themeProvider.backgroundImagePath != null) ...[
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      InkWell(onTap: () => themeProvider.setBackgroundImage("assets/default.jpg"), child: const Text("CLEAR BACKGROUND", style: TextStyle(fontSize: 15, color: Colors.redAccent)),)
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
                    itemCount: 1 + themeProvider.customImagePaths.length + kAssetBackgrounds.length,
                   itemBuilder: (context, index) {
                      if (index == 0) {
                        return GestureDetector(
                          onTap: () async {
                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) themeProvider.addCustomImage(image.path);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: themeProvider.appThemeColor.withAlpha((0.1 * 255).round()),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: themeProvider.appThemeColor.withAlpha((0.5 * 255).round())),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center, 
                              children: [Icon(Icons.add_photo_alternate, color: themeProvider.appThemeColor), Text("Add", style: TextStyle(fontSize: 10, color: themeProvider.appThemeColor))],
                            ),
                          ),
                        );
                      }

                      final int adjustedIndex = index - 1;
                      final int customCount = themeProvider.customImagePaths.length;
                      String path;
                      bool isCustom;

                      if (adjustedIndex < customCount) {
                        path = themeProvider.customImagePaths[adjustedIndex];
                        isCustom = true;
                      } else {
                        path = kAssetBackgrounds[adjustedIndex - customCount];
                        isCustom = false;
                      }

                      final bool isSelected = themeProvider.backgroundImagePath == path;

                      return InkWell(
                        onTap: () => themeProvider.setBackgroundImage(path),
                        // Long Press triggers "Red Delete"
                        onLongPress: isCustom ? () {
                          HapticFeedback.mediumImpact(); 
                          themeProvider.removeCustomImage(path);
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
                                  border: Border.all(color: themeProvider.appThemeColor, width: 2), 
                                  borderRadius: BorderRadius.circular(8), 
                                ), 
                                child: Center(child: Icon(Icons.check_circle, color: themeProvider.appThemeColor)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (themeProvider.backgroundImagePath != null) ...[
                  const SizedBox(height: 5),
                  Text("Dimmer: ${(themeProvider.backgroundOpacity * 100).toInt()}%", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Slider(value: themeProvider.backgroundOpacity, min: 0.0, max: 0.95, activeColor: themeProvider.appThemeColor, inactiveColor: Colors.grey[800], onChanged: (val) => themeProvider.setBackgroundOpacity(val),),
                ]
              ],
            ),
          ],
        ),
      ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: _systemPromptChanged ? Curves.bounceOut : Curves.easeInBack,
            bottom: _systemPromptChanged ? 30 : MediaQuery.of(context).size.height + 200,
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
