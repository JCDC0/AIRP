import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';
import '../providers/chat_provider.dart';
import 'settings_panels/settings_header.dart';
import 'settings_panels/api_settings_panel.dart';
import 'settings_panels/model_settings_panel.dart';
import 'settings_panels/system_prompt_panel.dart';
import 'settings_panels/generation_settings_panel.dart';
import 'settings_panels/visual_settings_panel.dart';

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

  bool _hasUnsavedChanges = false;

  // Track last synced values to avoid overwriting user input
  String? _lastSyncedApiKey;
  String? _lastSyncedLocalIp;
  String? _lastSyncedTitle;
  String? _lastSyncedOpenRouterModel;
  
  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    _apiKeyController = TextEditingController(text: _getApiKey(chatProvider));
    _localIpController = TextEditingController(text: chatProvider.localIp);
    _titleController = TextEditingController(text: chatProvider.currentTitle);
    _promptTitleController = TextEditingController();
    _openRouterModelController = TextEditingController(text: chatProvider.openRouterModel);
    
    _advancedPromptController = TextEditingController();
    _mainPromptController = TextEditingController();

    // Initialize last synced values
    _lastSyncedApiKey = _apiKeyController.text;
    _lastSyncedLocalIp = _localIpController.text;
    _lastSyncedTitle = _titleController.text;
    _lastSyncedOpenRouterModel = _openRouterModelController.text;

    // Add listeners to detect changes
    _apiKeyController.addListener(_checkForChanges);
    _localIpController.addListener(_checkForChanges);
    _titleController.addListener(_checkForChanges);
    _openRouterModelController.addListener(_checkForChanges);
    _mainPromptController.addListener(_checkForChanges);
    _advancedPromptController.addListener(_checkForChanges);
    
    // Note: SystemPromptPanel handles loading custom rules and populating the prompt controllers
  }

  String _getApiKey(ChatProvider provider) {
    switch (provider.currentProvider) {
      case AiProvider.gemini: return provider.geminiKey;
      case AiProvider.openRouter: return provider.openRouterKey;
      case AiProvider.openAi: return provider.openAiKey;
      case AiProvider.arliAi: return provider.arliAiKey;
      case AiProvider.nanoGpt: return provider.nanoGptKey;
      case AiProvider.huggingFace: return provider.huggingFaceKey;
      case AiProvider.local: return "";
    }
  }
  
  void _handleSaveSettings() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 1. Construct System Prompt
    String finalPrompt;
    String advanced = _advancedPromptController.text.trim();
    String main = _mainPromptController.text.trim();
    
    if (advanced.isNotEmpty && main.isNotEmpty) {
      finalPrompt = "$advanced\n\n$main";
    } else {
      finalPrompt = advanced + main;
    }
    
    // 2. Save All Values to Provider
    chatProvider.setSystemInstruction(finalPrompt);
    chatProvider.setApiKey(_apiKeyController.text.trim());
    chatProvider.setLocalIp(_localIpController.text.trim());
    chatProvider.setTitle(_titleController.text.trim());
    
    if (chatProvider.currentProvider == AiProvider.openRouter) {
      chatProvider.setModel(_openRouterModelController.text.trim());
    }

    // 3. Persist to Disk
    chatProvider.saveSettings();
    
    // 4. Update Sync State
    _lastSyncedApiKey = _apiKeyController.text;
    _lastSyncedLocalIp = _localIpController.text;
    _lastSyncedTitle = _titleController.text;
    _lastSyncedOpenRouterModel = _openRouterModelController.text;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Settings Saved & Model Updated"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.lightBlue,
        duration: Duration(milliseconds: 1500),
      )
    );
    
    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  void _checkForChanges() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    bool hasChanges = false;

    // 1. Check API Key
    if (_apiKeyController.text != _getApiKey(chatProvider)) hasChanges = true;

    // 2. Check Local IP
    if (_localIpController.text != chatProvider.localIp) hasChanges = true;

    // 3. Check Title
    if (_titleController.text != chatProvider.currentTitle) hasChanges = true;

    // 4. Check OpenRouter Model
    if (chatProvider.currentProvider == AiProvider.openRouter) {
      if (_openRouterModelController.text != chatProvider.openRouterModel) hasChanges = true;
    }

    // 5. Check System Prompt
    String advanced = _advancedPromptController.text.trim();
    String main = _mainPromptController.text.trim(); // Use trim for comparison consistency
    String finalPrompt = (advanced.isNotEmpty && main.isNotEmpty) ? "$advanced\n\n$main" : advanced + main;
    
    if (finalPrompt != chatProvider.systemInstruction) hasChanges = true;

    if (_hasUnsavedChanges != hasChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
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
    super.dispose();
  }

  void _syncControllers(ChatProvider chatProvider) {
    // 1. Sync API Key
    final correctKey = _getApiKey(chatProvider);
    if (correctKey != _lastSyncedApiKey) {
      if (_apiKeyController.text != correctKey) {
        _apiKeyController.text = correctKey;
      }
      _lastSyncedApiKey = correctKey;
    }

    // 2. Sync Local IP
    if (chatProvider.localIp != _lastSyncedLocalIp) {
      if (_localIpController.text != chatProvider.localIp) {
        _localIpController.text = chatProvider.localIp;
      }
      _lastSyncedLocalIp = chatProvider.localIp;
    }

    // 3. Sync Title
    if (chatProvider.currentTitle != _lastSyncedTitle) {
      if (_titleController.text != chatProvider.currentTitle) {
        _titleController.text = chatProvider.currentTitle;
      }
      _lastSyncedTitle = chatProvider.currentTitle;
    }

    // 4. Sync OpenRouter Model
    if (chatProvider.currentProvider == AiProvider.openRouter) {
      if (chatProvider.openRouterModel != _lastSyncedOpenRouterModel) {
        if (_openRouterModelController.text != chatProvider.openRouterModel) {
          _openRouterModelController.text = chatProvider.openRouterModel;
        }
        _lastSyncedOpenRouterModel = chatProvider.openRouterModel;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    
    _syncControllers(chatProvider);

    return Material(
      elevation: themeProvider.enableBloom ? 30 : 16,
      shadowColor: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.9) : null,
      color: const Color.fromARGB(255, 0, 0, 0),
      child: SizedBox(
        width: 340,
        height: double.infinity,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsHeader(),
                  
                  ApiSettingsPanel(
                    apiKeyController: _apiKeyController,
                    localIpController: _localIpController,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  ModelSettingsPanel(
                    titleController: _titleController,
                    openRouterModelController: _openRouterModelController,
                  ),
                  
                  const SizedBox(height: 30),
                  
                  SystemPromptPanel(
                    mainPromptController: _mainPromptController,
                    advancedPromptController: _advancedPromptController,
                    promptTitleController: _promptTitleController,
                    onPromptChanged: _checkForChanges,
                  ),
                  
                  const SizedBox(height: 10),
                  const Divider(),
                  
                  const GenerationSettingsPanel(),
                  
                  const VisualSettingsPanel(),
                  
                  // Extra space for FAB
                  const SizedBox(height: 80),
                ],
              ),
            ),
            
            AnimatedPositioned(
              duration: const Duration(milliseconds: 800),
              curve: _hasUnsavedChanges ? Curves.bounceOut : Curves.easeInBack,
              bottom: _hasUnsavedChanges ? 30 : MediaQuery.of(context).size.height + 200,
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
      ),
    );
  }
}
