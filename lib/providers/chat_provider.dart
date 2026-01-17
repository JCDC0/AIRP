import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import '../services/chat_api_service.dart';

class ChatProvider extends ChangeNotifier {
  // ----------------------------------------------------------------------
  // STATE VARIABLES
  // ----------------------------------------------------------------------
  
  // Loading & Status
  bool _isLoading = false;
  bool _isCancelled = false;
  StreamSubscription? _geminiSubscription;
  
  bool get isLoading => _isLoading;
  bool get isCancelled => _isCancelled;

  // Model Lists
  List<String> _geminiModelsList = [];
  List<String> _openRouterModelsList = [];
  List<String> _arliAiModelsList = [];
  List<String> _nanoGptModelsList = [];

  List<String> get geminiModelsList => _geminiModelsList;
  List<String> get openRouterModelsList => _openRouterModelsList;
  List<String> get arliAiModelsList => _arliAiModelsList;
  List<String> get nanoGptModelsList => _nanoGptModelsList;

  // Loading States for Models
  bool _isLoadingGeminiModels = false;
  bool _isLoadingOpenRouterModels = false;
  bool _isLoadingArliAiModels = false;
  bool _isLoadingNanoGptModels = false;

  bool get isLoadingGeminiModels => _isLoadingGeminiModels;
  bool get isLoadingOpenRouterModels => _isLoadingOpenRouterModels;
  bool get isLoadingArliAiModels => _isLoadingArliAiModels;
  bool get isLoadingNanoGptModels => _isLoadingNanoGptModels;

  // Keys & Config
  AiProvider _currentProvider = AiProvider.gemini;
  String _geminiKey = '';
  String _openRouterKey = '';
  String _openAiKey = '';
  String _arliAiKey = '';
  String _nanoGptKey = '';
  String _localIp = 'http://192.168.1.15:1234/v1';
  String _localModelName = 'local-model';

  AiProvider get currentProvider => _currentProvider;
  String get geminiKey => _geminiKey;
  String get openRouterKey => _openRouterKey;
  String get openAiKey => _openAiKey;
  String get arliAiKey => _arliAiKey;
  String get nanoGptKey => _nanoGptKey;
  String get localIp => _localIp;
  String get localModelName => _localModelName;

  // Selected Models
  String _selectedGeminiModel = 'models/gemini-flash-lite-latest';
  String _openRouterModel = 'z-ai/glm-4.5-air:free';
  String _arliAiModel = 'Mistral-Nemo-12B-Instruct-v1';
  String _nanoGptModel = 'gpt-4o';
  String _selectedModel = 'models/gemini-flash-lite-latest';

  String get selectedGeminiModel => _selectedGeminiModel;
  String get openRouterModel => _openRouterModel;
  String get arliAiModel => _arliAiModel;
  String get nanoGptModel => _nanoGptModel;
  String get selectedModel => _selectedModel;

  // Generation Settings
  double _temperature = 1.0;
  double _topP = 0.95;
  int _topK = 40;
  int _maxOutputTokens = 32768;
  int _historyLimit = 500;
  bool _enableGrounding = false;
  bool _enableImageGen = false;
  bool _enableUsage = false;
  bool _disableSafety = true;
  String _reasoningEffort = "none";

  double get temperature => _temperature;
  double get topP => _topP;
  int get topK => _topK;
  int get maxOutputTokens => _maxOutputTokens;
  int get historyLimit => _historyLimit;
  bool get enableGrounding => _enableGrounding;
  bool get enableImageGen => _enableImageGen;
  bool get enableUsage => _enableUsage;
  bool get disableSafety => _disableSafety;
  String get reasoningEffort => _reasoningEffort;

  // Session Data
  List<ChatMessage> _messages = [];
  List<ChatSessionData> _savedSessions = [];
  String? _currentSessionId;
  int _tokenCount = 0;
  String _currentTitle = "";
  String _systemInstruction = "";

  List<ChatMessage> get messages => _messages;
  List<ChatSessionData> get savedSessions => _savedSessions;
  String? get currentSessionId => _currentSessionId;
  int get tokenCount => _tokenCount;
  String get currentTitle => _currentTitle;
  String get systemInstruction => _systemInstruction;

  // System Prompts Library
  List<SystemPromptData> _savedSystemPrompts = [];
  List<SystemPromptData> get savedSystemPrompts => _savedSystemPrompts;

  // Model Bookmarks
  Set<String> _bookmarkedModels = {};
  Set<String> get bookmarkedModels => _bookmarkedModels;

  // Internal
  late GenerativeModel _model;
  late ChatSession _chat;
  static const _defaultApiKey = ''; 

  // ----------------------------------------------------------------------
  // INITIALIZATION
  // ----------------------------------------------------------------------

  ChatProvider() {
    _loadSettings();
    _loadSessions();
    _loadSystemPrompts();
    _loadModelBookmarks();
  }

  Future<void> _loadModelBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    _bookmarkedModels = prefs.getStringList('bookmarked_models')?.toSet() ?? {};
    notifyListeners();
  }

  Future<void> toggleModelBookmark(String modelId) async {
    if (_bookmarkedModels.contains(modelId)) {
      _bookmarkedModels.remove(modelId);
    } else {
      _bookmarkedModels.add(modelId);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarked_models', _bookmarkedModels.toList());
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('airp_sessions');
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        _savedSessions = jsonList.map((j) => ChatSessionData.fromJson(j)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint("Error loading sessions: $e");
      }
    }
  }

  Future<void> _loadSystemPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('airp_system_prompts');
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        _savedSystemPrompts = jsonList.map((j) => SystemPromptData.fromJson(j)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint("Error loading prompts: $e");
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Keys
    _geminiKey = prefs.getString('airp_key_gemini') ?? '';
    _openRouterKey = prefs.getString('airp_key_openrouter') ?? '';
    _openAiKey = prefs.getString('airp_key_openai') ?? '';
    _arliAiKey = prefs.getString('airp_key_arliai') ?? '';
    _nanoGptKey = prefs.getString('airp_key_nanogpt') ?? '';
    _localIp = prefs.getString('airp_local_ip') ?? 'http://192.168.1.15:1234/v1';

    // Load Provider
    final providerString = prefs.getString('airp_provider') ?? 'gemini';
    if (providerString == 'openRouter') _currentProvider = AiProvider.openRouter;
    else if (providerString == 'openAi') _currentProvider = AiProvider.openAi;
    else if (providerString == 'local') _currentProvider = AiProvider.local;
    else if (providerString == 'arliAi') _currentProvider = AiProvider.arliAi;
    else if (providerString == 'nanoGpt') _currentProvider = AiProvider.nanoGpt;
    else _currentProvider = AiProvider.gemini;

    // Load Lists
    _geminiModelsList = prefs.getStringList('airp_list_gemini') ?? [];
    _openRouterModelsList = prefs.getStringList('airp_list_openrouter') ?? [];
    _arliAiModelsList = prefs.getStringList('airp_list_arliai') ?? [];
    _nanoGptModelsList = prefs.getStringList('airp_list_nanogpt') ?? [];

    // Load Selected Models
    _selectedGeminiModel = prefs.getString('airp_model_gemini') ?? 'models/gemini-flash-lite-latest';
    _openRouterModel = prefs.getString('airp_model_openrouter') ?? 'z-ai/glm-4.5-air:free';
    _arliAiModel = prefs.getString('airp_model_arliai') ?? 'Mistral-Nemo-12B-Instruct-v1';
    _nanoGptModel = prefs.getString('airp_model_nanogpt') ?? 'gpt-4o';

    // Determine current selected model
    if (_currentProvider == AiProvider.openRouter) _selectedModel = _openRouterModel;
    else if (_currentProvider == AiProvider.gemini) _selectedModel = _selectedGeminiModel;
    else if (_currentProvider == AiProvider.arliAi) _selectedModel = _arliAiModel;
    else if (_currentProvider == AiProvider.nanoGpt) _selectedModel = _nanoGptModel;
    else if (_currentProvider == AiProvider.local) _selectedModel = "Local Network AI";

    // Load Other Settings
    _topP = prefs.getDouble('airp_top_p') ?? 0.95;
    _topK = prefs.getInt('airp_top_k') ?? 40;
    _maxOutputTokens = prefs.getInt('airp_max_output') ?? 32768;
    _historyLimit = prefs.getInt('airp_history_limit') ?? 500;
    _temperature = prefs.getDouble('airp_temperature') ?? 1.0;
    _enableUsage = prefs.getBool('airp_enable_usage') ?? false;
    _reasoningEffort = prefs.getString('airp_reasoning_effort') ?? 'none';
    _systemInstruction = prefs.getString('airp_default_system_instruction') ?? '';

    notifyListeners();

    if (_currentProvider == AiProvider.gemini) {
      await initializeModel();
    }
  }

  // ----------------------------------------------------------------------
  // SETTERS & UPDATERS
  // ----------------------------------------------------------------------

  void setProvider(AiProvider provider) {
    _currentProvider = provider;
    if (provider == AiProvider.gemini) _selectedModel = _selectedGeminiModel;
    else if (provider == AiProvider.openRouter) _selectedModel = _openRouterModel;
    else if (provider == AiProvider.arliAi) _selectedModel = _arliAiModel;
    else if (provider == AiProvider.nanoGpt) _selectedModel = _nanoGptModel;
    else if (provider == AiProvider.local) _selectedModel = "Local Network AI";
    
    notifyListeners();
    saveSettings(showConfirmation: false);
    if (provider == AiProvider.gemini) initializeModel();
  }

  void setApiKey(String key) {
    switch (_currentProvider) {
      case AiProvider.gemini: _geminiKey = key; break;
      case AiProvider.openRouter: _openRouterKey = key; break;
      case AiProvider.openAi: _openAiKey = key; break;
      case AiProvider.arliAi: _arliAiKey = key; break;
      case AiProvider.nanoGpt: _nanoGptKey = key; break;
      case AiProvider.local: break;
    }
    notifyListeners();
  }

  void setLocalIp(String ip) {
    _localIp = ip;
    notifyListeners();
  }

  void setLocalModelName(String name) {
    _localModelName = name;
    notifyListeners();
  }

  void setTitle(String title) {
    _currentTitle = title;
    notifyListeners();
  }

  void setSystemInstruction(String instruction) {
    _systemInstruction = instruction;
    notifyListeners();
  }

  void setModel(String model) {
    if (_currentProvider == AiProvider.gemini) {
      _selectedGeminiModel = model;
      _selectedModel = model;
    } else if (_currentProvider == AiProvider.openRouter) {
      _openRouterModel = model;
      _selectedModel = model;
    } else if (_currentProvider == AiProvider.arliAi) {
      _arliAiModel = model;
      _selectedModel = model;
    } else if (_currentProvider == AiProvider.nanoGpt) {
      _nanoGptModel = model;
      _selectedModel = model;
    }
    notifyListeners();
  }

  void setTemperature(double val) { _temperature = val; notifyListeners(); }
  void setTopP(double val) { _topP = val; notifyListeners(); }
  void setTopK(int val) { _topK = val; notifyListeners(); }
  void setMaxOutputTokens(int val) { _maxOutputTokens = val; notifyListeners(); }
  void setHistoryLimit(int val) { _historyLimit = val; notifyListeners(); }
  void setEnableGrounding(bool val) { 
    _enableGrounding = val; 
    if (val) _enableImageGen = false;
    notifyListeners(); 
  }
  void setEnableImageGen(bool val) {
    _enableImageGen = val;
    if (val) _enableGrounding = false;
    notifyListeners();
  }
  void setDisableSafety(bool val) { _disableSafety = val; notifyListeners(); }
  void setEnableUsage(bool val) { _enableUsage = val; notifyListeners(); }
  void setReasoningEffort(String val) { _reasoningEffort = val; notifyListeners(); }

  Future<void> saveSettings({bool showConfirmation = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('airp_key_gemini', _geminiKey);
    await prefs.setString('airp_key_openrouter', _openRouterKey);
    await prefs.setString('airp_key_openai', _openAiKey);
    await prefs.setString('airp_local_ip', _localIp);
    await prefs.setString('airp_provider', _currentProvider.name);
    await prefs.setString('airp_model_gemini', _selectedGeminiModel);
    await prefs.setString('airp_model_openrouter', _openRouterModel);
    await prefs.setString('airp_key_arliai', _arliAiKey);
    await prefs.setString('airp_key_nanogpt', _nanoGptKey);
    await prefs.setString('airp_model_arliai', _arliAiModel);
    await prefs.setString('airp_model_nanogpt', _nanoGptModel);
    await prefs.setDouble('airp_top_p', _topP);
    await prefs.setInt('airp_top_k', _topK);
    await prefs.setInt('airp_max_output', _maxOutputTokens);
    await prefs.setInt('airp_history_limit', _historyLimit);
    await prefs.setDouble('airp_temperature', _temperature);
    await prefs.setBool('airp_enable_usage', _enableUsage);
    await prefs.setString('airp_reasoning_effort', _reasoningEffort);
    await prefs.setString('airp_default_system_instruction', _systemInstruction);

    if (_currentSessionId != null) {
      autoSaveCurrentSession();
    }

    if (_currentProvider == AiProvider.gemini) {
      await initializeModel();
    }
  }

  // ----------------------------------------------------------------------
  // LOGIC: MODEL INITIALIZATION
  // ----------------------------------------------------------------------

  Future<void> initializeModel() async {
    String activeKey = '';
    if (_currentProvider == AiProvider.gemini) {
      activeKey = _geminiKey.isNotEmpty ? _geminiKey : _defaultApiKey;
    } else if (_currentProvider == AiProvider.openRouter) {
      activeKey = _openRouterKey;
    } else if (_currentProvider == AiProvider.openAi) {
      activeKey = _openAiKey;
    }

    if (activeKey.isEmpty && _currentProvider != AiProvider.local) {
      debugPrint("Warning: No API Key found for ${_currentProvider.name}");
    }

    try {
      final List<SafetySetting> safetySettings = _disableSafety
          ? [
              SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
              SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
              SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
              SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
            ]
          : [];

      String finalSystemInstruction = _systemInstruction;
      if (_currentProvider == AiProvider.gemini && (_reasoningEffort != "none" || _selectedModel.contains("thinking"))) {
         finalSystemInstruction += "\n\n[SYSTEM: You are a reasoning model. You MUST enclose your internal thought process in <think> and </think> tags before your final response.";
         if (_reasoningEffort != "none") {
            finalSystemInstruction += " Reasoning Effort: $_reasoningEffort.";
         }
         finalSystemInstruction += "]";
      }

      _model = GenerativeModel(
        model: _selectedModel,
        apiKey: activeKey,
        systemInstruction: finalSystemInstruction.isNotEmpty
            ? Content.system(finalSystemInstruction)
            : null,
          generationConfig: GenerationConfig(
            temperature: _temperature,
            topP: _topP,
            topK: _topK,
            maxOutputTokens: _maxOutputTokens,
          ),
          safetySettings: safetySettings,
        );
      
      // Rebuild history for Gemini Chat Session
      List<Content> history = [];
      int startIndex = _messages.length - _historyLimit;
      if (startIndex < 0) startIndex = 0;
      final limitedMessages = _messages.sublist(startIndex);

      for (var msg in limitedMessages) {
          final String role = msg.isUser ? 'user' : 'model';
          if (msg.isUser && msg.imagePaths.isNotEmpty) {
              List<Part> parts = [];
              if (msg.text.isNotEmpty) parts.add(TextPart(msg.text));
              for (String path in msg.imagePaths) {
                  if (await File(path).exists()) {
                      final bytes = await File(path).readAsBytes();
                      final mimeType = path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
                      parts.add(DataPart(mimeType, bytes));
                  }
              }
              history.add(Content(role, parts));
          } else if (history.isNotEmpty && history.last.role == role) {
              final List<Part> existingParts = history.last.parts.toList();
              existingParts.add(TextPart("\n\n${msg.text}"));
              history[history.length - 1] = Content(role, existingParts);
          } else {
              history.add(msg.isUser ? Content.text(msg.text) : Content.model([TextPart(msg.text)]));
          }
      }

      _chat = _model.startChat(history: history);
    } catch (e) {
      debugPrint("Model Init Error: $e");
    }
  }

  // ----------------------------------------------------------------------
  // LOGIC: SEND MESSAGE
  // ----------------------------------------------------------------------

  Future<void> sendMessage(String messageText, List<String> imagesToSend) async {
    if (messageText.isEmpty && imagesToSend.isEmpty) return;

    // 1. Optimistic Update
    _messages.add(ChatMessage(text: messageText, isUser: true, imagePaths: imagesToSend));
    _isLoading = true;
    _isCancelled = false;
    notifyListeners();
    
    autoSaveCurrentSession();

    // 2. Grounding (Gemini)
    if (_enableGrounding && _currentProvider == AiProvider.gemini && imagesToSend.isEmpty) {
       try {
         final activeKey = _geminiKey.isNotEmpty ? _geminiKey : _defaultApiKey;
         final groundedText = await ChatApiService.performGeminiGrounding(
            apiKey: activeKey, 
            model: _selectedModel, 
            history: _messages.sublist(0, _messages.length - 1), 
            userMessage: messageText, 
            systemInstruction: _systemInstruction,
            disableSafety: _disableSafety
         );
         
         if (_isCancelled) return; 
         
         _messages.add(ChatMessage(text: groundedText ?? "Error", isUser: false, modelName: _selectedModel));
         _isLoading = false;
         notifyListeners();
         return; 
       } catch (e) {
         debugPrint("Grounding failed: $e");
       }
    }

    // 3. Image Generation
    if (_enableImageGen) {
      try {
        String activeKey = '';
        String provider = 'openai';
        
        if (_currentProvider == AiProvider.openRouter) {
          activeKey = _openRouterKey;
          provider = 'openrouter';
        } else if (_currentProvider == AiProvider.openAi) {
          activeKey = _openAiKey;
          provider = 'openai';
        } else {
           _messages.add(ChatMessage(text: "Image Gen currently only supported for OpenRouter/OpenAI in this mode.", isUser: false, modelName: "System"));
           _isLoading = false;
           notifyListeners();
           return;
        }

        final imageUrl = await ChatApiService.generateImage(
          apiKey: activeKey,
          prompt: messageText,
          provider: provider,
        );

        if (_isCancelled) return;

        if (imageUrl != null && imageUrl.startsWith('http')) {
            _messages.add(ChatMessage(text: imageUrl, isUser: false, modelName: "Image Gen"));
        } else {
            _messages.add(ChatMessage(text: "Image Gen Failed: $imageUrl", isUser: false, modelName: "System"));
        }
        _isLoading = false;
        notifyListeners();
        return;
      } catch (e) {
         _messages.add(ChatMessage(text: "Error generating image: $e", isUser: false, modelName: "System"));
         _isLoading = false;
         notifyListeners();
         return;
      }
    }

    // 4. Standard Chat Response
    _messages.add(ChatMessage(text: "", isUser: false, modelName: _selectedModel));
    notifyListeners();

    Stream<String>? responseStream;

    try {
      if (_currentProvider == AiProvider.gemini) {
        responseStream = ChatApiService.streamGeminiResponse(
          chatSession: _chat, 
          message: messageText,
          imagePaths: imagesToSend,
          modelName: _selectedModel,
        );
      } else {
        String baseUrl = "";
        String apiKey = "";
        Map<String, String>? headers;

        final contextMessages = _messages.sublist(0, _messages.length - 2); 
        int startIndex = contextMessages.length - _historyLimit;
        if (startIndex < 0) startIndex = 0;
        final limitedHistory = contextMessages.sublist(startIndex);

        if (_currentProvider == AiProvider.openRouter) {
          baseUrl = "https://openrouter.ai/api/v1/chat/completions";
          apiKey = _openRouterKey;
          headers = {
            "HTTP-Referer": "https://airp-chat.com",
            "X-Title": "AIRP Chat",
          };
        } else if (_currentProvider == AiProvider.arliAi) {
          baseUrl = "https://api.arliai.com/v1/chat/completions";
          apiKey = _arliAiKey;
        } else if (_currentProvider == AiProvider.nanoGpt) {
          baseUrl = "https://nano-gpt.com/api/v1/chat/completions";
          apiKey = _nanoGptKey;
        } else if (_currentProvider == AiProvider.local) {
          baseUrl = _localIp.trim();
          if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
          if (!baseUrl.endsWith('/chat/completions')) {
             baseUrl += baseUrl.endsWith('/v1') ? "/chat/completions" : "/v1/chat/completions";
          }
          apiKey = "local-key";
        }

        responseStream = ChatApiService.streamOpenAiCompatible(
          apiKey: apiKey,
          baseUrl: baseUrl,
          model: _currentProvider == AiProvider.local ? _localModelName : _selectedModel,
          history: limitedHistory,
          systemInstruction: _systemInstruction,
          userMessage: messageText,
          imagePaths: imagesToSend,
          temperature: _temperature,
          topP: _topP,
          topK: _topK,
          maxTokens: _maxOutputTokens,
          enableGrounding: _enableGrounding,
          reasoningEffort: _reasoningEffort,
          extraHeaders: headers,
          includeUsage: _enableUsage,
        );
      }

      String fullText = "";
      _geminiSubscription = responseStream.listen(
        (chunk) {
          if (_isCancelled) return;
          if (chunk.startsWith('[[USAGE:')) {
            final usageStr = chunk.substring(8, chunk.length - 2);
            final usage = jsonDecode(usageStr) as Map<String, dynamic>;
            _messages.last = _messages.last.copyWith(usage: usage);
            notifyListeners();
          } else {
            fullText += chunk;
            _messages.last = ChatMessage(
              text: fullText,
              isUser: false,
              modelName: _selectedModel,
              usage: _messages.last.usage
            );
            notifyListeners();
          }
        },
        onError: (e) {
          if (!_isCancelled) {
            _messages.last = ChatMessage(
              text: "${_messages.last.text}\n\n**Error:** $e",
              isUser: false,
              modelName: "System Alert"
            );
            _isLoading = false;
            notifyListeners();
          }
        },
        onDone: () async {
          if (!_isCancelled) {
            _isLoading = false;
            notifyListeners();
            autoSaveCurrentSession();
            
            if (_currentProvider == AiProvider.gemini) {
              await initializeModel(); 
            }
            
            if (!_enableGrounding) updateTokenCount();
          }
        },
      );
    
    } catch (e) {
      if (!_isCancelled) {
        _messages.add(ChatMessage(
          text: "**System Error**\n\n```\n$e\n```",
          isUser: false,
          modelName: "System Alert",
        ));
        _isLoading = false;
        notifyListeners();
        autoSaveCurrentSession();
      }
    }
  }

  void cancelGeneration() async {
    _isLoading = false;
    _isCancelled = true;
    notifyListeners();

    if (_geminiSubscription != null) {
      await _geminiSubscription?.cancel();
      _geminiSubscription = null;
    }
  }

  Future<void> regenerateResponse(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final msg = _messages[index];

    String textToResend = "";
    List<String> imagesToResend = [];

    if (!msg.isUser) {
      // If AI message, rewind to the User message that triggered it
      int userMsgIndex = index - 1;
      if (userMsgIndex >= 0 && _messages[userMsgIndex].isUser) {
        final userMsg = _messages[userMsgIndex];
        _messages.removeRange(userMsgIndex, _messages.length);
        textToResend = userMsg.text;
        imagesToResend = userMsg.imagePaths;
      } else {
        _messages.removeAt(index);
        return; // Cannot regenerate without user context
      }
    } else {
      // If User message, rewind to this message
      final userMsg = _messages[index];
      _messages.removeRange(index, _messages.length);
      textToResend = userMsg.text;
      imagesToResend = userMsg.imagePaths;
    }

    notifyListeners();
    await initializeModel();
    sendMessage(textToResend, imagesToResend);
  }

  // ----------------------------------------------------------------------
  // LOGIC: SESSION MANAGEMENT
  // ----------------------------------------------------------------------

  Future<void> autoSaveCurrentSession({String? backgroundImagePath}) async {
    if (_messages.isEmpty && _currentTitle.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    String title = _currentTitle;
    if (title.isEmpty && _messages.isNotEmpty) {
      title = _messages.first.text;
      if (title.length > 25) title = "${title.substring(0, 25)}...";
      _currentTitle = title;
    }
    if (title.isEmpty) title = "New Conversation";

    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

    String providerStr = 'gemini';
    if (_currentProvider == AiProvider.openRouter) providerStr = 'openRouter';
    else if (_currentProvider == AiProvider.local) providerStr = 'local';
    else if (_currentProvider == AiProvider.openAi) providerStr = 'openAi';

    final sessionData = ChatSessionData(
      id: _currentSessionId!,
      title: title,
      messages: List.from(_messages),
      modelName: _selectedModel,
      tokenCount: _tokenCount,
      systemInstruction: _systemInstruction,
      backgroundImage: backgroundImagePath,
      provider: providerStr,
    );

    _savedSessions.removeWhere((s) => s.id == _currentSessionId);
    _savedSessions.insert(0, sessionData);
    notifyListeners();

    final String data = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
    await prefs.setString('airp_sessions', data);
  }

  Future<void> bookmarkSession(String sessionId, bool isBookmarked) async {
    final index = _savedSessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;

    final session = _savedSessions[index];
    final updatedSession = ChatSessionData(
      id: session.id,
      title: session.title,
      messages: session.messages,
      modelName: session.modelName,
      tokenCount: session.tokenCount,
      systemInstruction: session.systemInstruction,
      backgroundImage: session.backgroundImage,
      provider: session.provider,
      isBookmarked: isBookmarked,
    );

    _savedSessions[index] = updatedSession;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
    await prefs.setString('airp_sessions', data);
  }

  void createNewSession() {
    _messages.clear();
    _tokenCount = 0;
    _currentSessionId = null;
    _currentTitle = "";
    notifyListeners();
    initializeModel();
  }

  void loadSession(ChatSessionData session) {
    _messages = List.from(session.messages);
    _currentSessionId = session.id;
    _tokenCount = session.tokenCount;
    _systemInstruction = session.systemInstruction;
    _currentTitle = session.title;

    if (session.provider == 'openRouter') {
      _currentProvider = AiProvider.openRouter;
      _openRouterModel = session.modelName;
      _selectedModel = session.modelName;
    } else if (session.provider == 'local') {
      _currentProvider = AiProvider.local;
      _selectedModel = "Local Network AI";
    } else if (session.provider == 'openAi') {
      _currentProvider = AiProvider.openAi;
      _selectedModel = session.modelName;
    } else {
      _currentProvider = AiProvider.gemini;
      _selectedGeminiModel = session.modelName;
      _selectedModel = session.modelName;
    }
    
    notifyListeners();
    initializeModel();
  }

  void deleteSession(String id) async {
    _savedSessions.removeWhere((s) => s.id == id);
    if (id == _currentSessionId) {
      createNewSession();
    } else {
      notifyListeners();
    }
    
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
    await prefs.setString('airp_sessions', data);
  }

  void deleteMessage(int index) {
    _messages.removeAt(index);
    notifyListeners();
    autoSaveCurrentSession();
    initializeModel();
  }

  void editMessage(int index, String newText) {
    _messages[index] = ChatMessage(text: newText, isUser: _messages[index].isUser);
    notifyListeners();
    autoSaveCurrentSession();
    initializeModel();
  }

  // ----------------------------------------------------------------------
  // LOGIC: MODEL FETCHING
  // ----------------------------------------------------------------------

  Future<void> fetchGeminiModels() async {
    if (_geminiKey.isEmpty) return;
    _isLoadingGeminiModels = true;
    notifyListeners();

    try {
      final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models?key=$_geminiKey");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models = data['models'];

        final List<String> fetchedIds = models
            .where((m) {
              final methods = List<String>.from(m['supportedGenerationMethods'] ?? []);
              return methods.contains('generateContent');
            })
            .map<String>((m) => m['name'].toString()) 
            .toList();

        fetchedIds.sort(); 
        _geminiModelsList = fetchedIds;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('airp_list_gemini', fetchedIds);
        
        if (!_geminiModelsList.contains(_selectedGeminiModel) && _geminiModelsList.isNotEmpty) {
             _selectedGeminiModel = _geminiModelsList.first;
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      _isLoadingGeminiModels = false;
      notifyListeners();
    }
  }

  Future<void> fetchOpenRouterModels() async {
    _isLoadingOpenRouterModels = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse("https://openrouter.ai/api/v1/models"),
        headers: {"HTTP-Referer": "https://airp-chat.com", "X-Title": "AIRP Chat"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> dataList = data['data'];
        final List<String> fetchedIds = dataList.map<String>((e) => e['id'].toString()).toList();
        fetchedIds.sort();

        _openRouterModelsList = fetchedIds;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('airp_list_openrouter', fetchedIds);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      _isLoadingOpenRouterModels = false;
      notifyListeners();
    }
  }

  Future<void> fetchArliAiModels() async {
    if (_arliAiKey.isEmpty) return;
    _isLoadingArliAiModels = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse("https://api.arliai.com/v1/models"),
        headers: {"Authorization": "Bearer ${_arliAiKey.trim()}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> dataList = data['data'];
        final List<String> fetchedIds = dataList.map<String>((e) => e['id'].toString()).toList();
        fetchedIds.sort();

        _arliAiModelsList = fetchedIds;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('airp_list_arliai', fetchedIds);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      _isLoadingArliAiModels = false;
      notifyListeners();
    }
  }

  Future<void> fetchNanoGptModels() async {
    if (_nanoGptKey.isEmpty) return;
    _isLoadingNanoGptModels = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse("https://nano-gpt.com/api/v1/models"),
        headers: {"Authorization": "Bearer ${_nanoGptKey.trim()}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> dataList = data['data'] ?? [];
        final List<String> fetchedIds = dataList.map<String>((e) => e['id'].toString()).toList();
        fetchedIds.sort();

        _nanoGptModelsList = fetchedIds;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('airp_list_nanogpt', fetchedIds);
        
        if (!_nanoGptModelsList.contains(_nanoGptModel) && _nanoGptModelsList.isNotEmpty) {
            _nanoGptModel = _nanoGptModelsList.first;
            if (_currentProvider == AiProvider.nanoGpt) _selectedModel = _nanoGptModel;
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      _isLoadingNanoGptModels = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------------
  // LOGIC: PROMPT LIBRARY
  // ----------------------------------------------------------------------

  Future<void> savePromptToLibrary(String title, String content) async {
    if (title.isEmpty || content.isEmpty) return;

    final newPrompt = SystemPromptData(title: title, content: content);
    final index = _savedSystemPrompts.indexWhere((p) => p.title == newPrompt.title);
    
    if (index != -1) {
      _savedSystemPrompts[index] = newPrompt;
    } else {
      _savedSystemPrompts.add(newPrompt);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_savedSystemPrompts.map((s) => s.toJson()).toList());
    await prefs.setString('airp_system_prompts', data);
  }

  Future<void> deletePromptFromLibrary(String title) async {
    _savedSystemPrompts.removeWhere((p) => p.title == title);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_savedSystemPrompts.map((s) => s.toJson()).toList());
    await prefs.setString('airp_system_prompts', data);
  }

  // ----------------------------------------------------------------------
  // UTILS
  // ----------------------------------------------------------------------

  Future<void> updateTokenCount() async {
    if (_messages.isEmpty) {
      _tokenCount = 0;
      notifyListeners();
      return;
    }

    if (_currentProvider == AiProvider.gemini) {
      try {
        final contents = _messages.map((m) => m.isUser ? Content.text(m.text) : Content.model([TextPart(m.text)])).toList();
        final response = await _model.countTokens(contents);
        _tokenCount = response.totalTokens;
        notifyListeners();
      } catch (e) {
        debugPrint('Token count error: $e');
      }
    } else {
      int totalChars = 0;
      int imgCount = 0;
      for (var msg in _messages) {
        totalChars += msg.text.length;
        imgCount += msg.imagePaths.length;
      }
      _tokenCount = (totalChars / 3.5).ceil() + (imgCount * 200);
      notifyListeners();
    }
  }
}
