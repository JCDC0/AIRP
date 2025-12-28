import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';
import '../widgets/message_bubble.dart';
import '../services/chat_api_service.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/effects_overlay.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// ----------------------------------------------------------------------
// CONFIGURATION
// ----------------------------------------------------------------------
class _ChatScreenState extends State<ChatScreen> {
  static const _defaultApiKey = ''; // hardcode a default key if desired

  // LOADING STATES
  bool _isLoading = false;
  bool _isCancelled = false;
  StreamSubscription? _geminiSubscription; 


   // 1. DYNAMIC MODEL LISTS
  List<String> _geminiModelsList = [];     
  List<String> _openRouterModelsList = []; 
  List<String> _arliAiModelsList = []; 
  List<String> _nanoGptModelsList = [];
  
  // 2. LOADING STATES
  bool _isLoadingGeminiModels = false;
  bool _isLoadingOpenRouterModels = false;
  bool _isLoadingArliAiModels = false;
  bool _isLoadingNanoGptModels = false;

  AiProvider _currentProvider = AiProvider.gemini;

  String _geminiKey = '';
  String _openRouterKey = '';
  String _openAiKey = ''; 
  String _arliAiKey = '';
  String _nanoGptKey = '';

  final TextEditingController _localIpController = TextEditingController();
  String _localModelName = 'local-model';

  String _selectedGeminiModel = 'models/gemini-flash-lite-latest'; 
  String _openRouterModel = 'z-ai/glm-4.5-air:free'; 
  String _arliAiModel = 'Mistral-Nemo-12B-Instruct-v1';
  String _nanoGptModel = 'gpt-4o';

  String _selectedModel = 'models/gemini-flash-lite-latest';
  double _temperature = 1; 
  bool _enableGrounding = false;
  bool _disableSafety = true;
  
  late GenerativeModel _model;
  late ChatSession _chat;
  final TextEditingController _openRouterModelController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _systemInstructionController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController(); 
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _promptTitleController = TextEditingController(); 
  List<SystemPromptData> _savedSystemPrompts = [];
  final List<String> _pendingImages = [];
  List<ChatMessage> _messages = []; 
  List<ChatSessionData> _savedSessions = []; 

  // ----------------------------------------------------------------------
  // NEW SETTINGS VARIABLES
  // ----------------------------------------------------------------------
  double _topP = 0.95;       // Nucleus Sampling (0.0 - 1.0)
  int _topK = 40;            // Top-K Sampling (1 - 100)
  int _maxOutputTokens = 32768; // How much the AI writes back
  int _historyLimit = 500;    // How many past messages to remember (Truncation)
  bool _hasUnsavedChanges = false;
  String? _currentSessionId;
  int _tokenCount = 0;


  @override
  void initState() {
    super.initState();
    _loadSessions();
    _loadSettings(); 
    _loadSystemPrompts();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('airp_sessions');
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        setState(() {
          _savedSessions = jsonList.map((j) => ChatSessionData.fromJson(j)).toList();
        });
      } catch (e) {
        debugPrint("Error loading sessions: $e");
      }
    }
  }

  // _loadSettings (Loads Saved Lists)
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load Keys
      _geminiKey = prefs.getString('airp_key_gemini') ?? '';
      _openRouterKey = prefs.getString('airp_key_openrouter') ?? '';
      _openAiKey = prefs.getString('airp_key_openai') ?? '';

      // Load Local IP
      _localIpController.text = prefs.getString('airp_local_ip') ?? 'http://192.168.1.15:1234/v1';

      // Load Provider
      final providerString = prefs.getString('airp_provider') ?? 'gemini';
      if (providerString == 'openRouter') {
        _currentProvider = AiProvider.openRouter;
      } else if (providerString == 'openAi') {
        _currentProvider = AiProvider.openAi;
      } else if (providerString == 'local') {
        _currentProvider = AiProvider.local;
      } else if (providerString == 'arliAi') {
        _currentProvider = AiProvider.arliAi;
      } else if (providerString == 'nanoGpt') {
        _currentProvider = AiProvider.nanoGpt;
      } else {
        _currentProvider = AiProvider.gemini;
      }

      // LOAD PERSISTED MODEL LISTS
      _geminiModelsList = prefs.getStringList('airp_list_gemini') ?? [];
      _openRouterModelsList = prefs.getStringList('airp_list_openrouter') ?? [];
      _arliAiModelsList = prefs.getStringList('airp_list_arliai') ?? [];
      _nanoGptModelsList = prefs.getStringList('airp_list_nanogpt') ?? [];

      // Load Selected Models
      _selectedGeminiModel = prefs.getString('airp_model_gemini') ?? 'models/gemini-flash-lite-latest';
      _openRouterModel = prefs.getString('airp_model_openrouter') ?? 'z-ai/glm-4.5-air:free';
      _openRouterModelController.text = _openRouterModel;
      _arliAiModel = prefs.getString('airp_model_arliai') ?? 'Mistral-Nemo-12B-Instruct-v1';
      _nanoGptModel = prefs.getString('airp_model_nanogpt') ?? 'gpt-4o';

      // Load Other Settings
      _topP = prefs.getDouble('airp_top_p') ?? 0.95;
      _topK = prefs.getInt('airp_top_k') ?? 40;
      _maxOutputTokens = prefs.getInt('airp_max_output') ?? 32768;
      _historyLimit = prefs.getInt('airp_history_limit') ?? 500;
      
      _updateApiKeyTextField();
    });

    if (_currentProvider == AiProvider.gemini) {
      await _initializeModel(); 
    }
  }

  // HELPER TO SYNC UI TEXT FIELD
  void _updateApiKeyTextField() {
    switch (_currentProvider) {
      case AiProvider.gemini: _apiKeyController.text = _geminiKey; break;
      case AiProvider.openRouter: _apiKeyController.text = _openRouterKey; break;
      case AiProvider.openAi: _apiKeyController.text = _openAiKey; break;
      case AiProvider.local: _apiKeyController.text = "No Key Needed"; break;
      case AiProvider.arliAi: _apiKeyController.text = _arliAiKey; break;
      case AiProvider.nanoGpt: _apiKeyController.text = _nanoGptKey; break;
    }
  }

  Future<void> _saveSettings() async {
    final cleanKey = _apiKeyController.text.trim();
    final cleanModel = _openRouterModelController.text.trim();
    final cleanIp = _localIpController.text.trim();

    setState(() {
      _hasUnsavedChanges = false;
      switch (_currentProvider) {
        case AiProvider.gemini: _geminiKey = cleanKey; break;
        case AiProvider.openRouter: _openRouterKey = cleanKey; break;
        case AiProvider.openAi: _openAiKey = cleanKey; break;
        case AiProvider.arliAi: _arliAiKey = cleanKey; break;
        case AiProvider.nanoGpt: _nanoGptKey = cleanKey; break;
        case AiProvider.local: break;
      }
      _openRouterModel = cleanModel;
      _openRouterModelController.text = cleanModel;

      // Update selected model based on provider
      if (_currentProvider == AiProvider.openRouter) {
        _selectedModel = cleanModel;
      } else if (_currentProvider == AiProvider.gemini) {
         _selectedModel = _selectedGeminiModel;
      } else if (_currentProvider == AiProvider.arliAi) {
         _selectedModel = _arliAiModel;
      } else if (_currentProvider == AiProvider.nanoGpt) {
         _selectedModel = _nanoGptModel;
      } else if (_currentProvider == AiProvider.local) {
         _selectedModel = "Local Network AI"; 
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('airp_key_gemini', _geminiKey);
    await prefs.setString('airp_key_openrouter', _openRouterKey);
    await prefs.setString('airp_key_openai', _openAiKey);
    await prefs.setString('airp_local_ip', cleanIp); 
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

    if (_currentSessionId != null) {
      _autoSaveCurrentSession(); 
    }

    if (_currentProvider == AiProvider.gemini) {
      await _initializeModel();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Settings Saved & Model Updated"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.lightBlue,
        duration: Duration(milliseconds: 1500),
      )
    );
  }

  Future<void> _autoSaveCurrentSession() async {
    if (_messages.isEmpty  && _titleController.text.isEmpty) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    String title = _titleController.text;
    if (title.isEmpty && _messages.isNotEmpty) {
      title = _messages.first.text;
      if (title.length > 25) title = "${title.substring(0, 25)}..."; 
      _titleController.text = title; 
    } 
    if (title.isEmpty) title = "New Conversation";

    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

    // Determine correct provider string
    String providerStr = 'gemini';
    if (_currentProvider == AiProvider.openRouter) {
      providerStr = 'openRouter';
    } else if (_currentProvider == AiProvider.local) providerStr = 'local';
    else if (_currentProvider == AiProvider.openAi) providerStr = 'openAi';

    // FIX: Using ChatSessionData from imports
    final sessionData = ChatSessionData(
      id: _currentSessionId!,
      title: title,
      messages: List.from(_messages), 
      modelName: _selectedModel,
      tokenCount: _tokenCount,
      systemInstruction: _systemInstructionController.text,
      backgroundImage: themeProvider.backgroundImagePath,
      provider: providerStr,
    );

    setState(() {
      _savedSessions.removeWhere((s) => s.id == _currentSessionId);
      _savedSessions.insert(0, sessionData);
    });

    final String data = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
    await prefs.setString('airp_sessions', data);
  }

  void _createNewSession() {
    setState(() {
      _messages.clear();
      _tokenCount = 0;
      _currentSessionId = null; 
      _systemInstructionController.clear();
      _titleController.clear();
    });
    _initializeModel();
  }

    void _cancelGeneration() async {
    setState(() {
      _isLoading = false;
      _isCancelled = true; 
    });

    // 1. Kill Gemini Stream (if active)
    if (_geminiSubscription != null) {
      await _geminiSubscription?.cancel();
      _geminiSubscription = null;
    }

    // 2. UI Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Generation Stopped (Stream Cancelled)"), 
          duration: Duration(milliseconds: 500),
          backgroundColor: Colors.redAccent,
        )
      );
    }
  }

  Future<void> _initializeModel() async {
    String activeKey = '';
    // Select Key
    if (_currentProvider == AiProvider.gemini) {
      activeKey = _geminiKey.isNotEmpty ? _geminiKey : _defaultApiKey;
    } else if (_currentProvider == AiProvider.openRouter) {
      activeKey = _openRouterKey;
    } else if (_currentProvider == AiProvider.openAi) {
      activeKey = _openAiKey;
    }

    if (activeKey.isEmpty) {
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

      _model = GenerativeModel(
        model: _selectedModel,
        apiKey: activeKey, // The SDK handles empty keys by throwing errors later usually
        systemInstruction: _systemInstructionController.text.isNotEmpty
            ? Content.system(_systemInstructionController.text)
            : null,
          generationConfig: GenerationConfig(
            temperature: _temperature,
            topP: _topP,
            topK: _topK,
            maxOutputTokens: _maxOutputTokens,
          ),
          safetySettings: safetySettings,
        );
      
      List<Content> history = [];
      // TRUNCATE MESSAGE HISTORY
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
  // ======================================================================
  // SEND MESSAGE LOGIC
  // ======================================================================
  Future<void> _sendMessage() async {
    final messageText = _textController.text;
    if (messageText.isEmpty && _pendingImages.isEmpty) return;

    final List<String> imagesToSend = List.from(_pendingImages);
    
    // 1. Update UI (Optimistic Update)
    setState(() {
      _messages.add(ChatMessage(text: messageText, isUser: true, imagePaths: imagesToSend));
      _isLoading = true;
      _isCancelled = false;
      _pendingImages.clear();
      _textController.clear();
    });
    _scrollToBottom();
    _autoSaveCurrentSession();

    // 2. Handle Grounding (Gemini Special Case)
    if (_enableGrounding && _currentProvider == AiProvider.gemini && imagesToSend.isEmpty) {
       try {
         final activeKey = _geminiKey.isNotEmpty ? _geminiKey : _defaultApiKey;
         // CALL SERVICE
         final groundedText = await ChatApiService.performGeminiGrounding(
            apiKey: activeKey, 
            model: _selectedModel, 
            history: _messages.sublist(0, _messages.length - 1), 
            userMessage: messageText, 
            systemInstruction: _systemInstructionController.text,
            disableSafety: _disableSafety
         );
         
         if (_isCancelled) return; 
         
         setState(() {
           _messages.add(ChatMessage(text: groundedText ?? "Error", isUser: false, modelName: _selectedModel));
           _isLoading = false;
         });
         return; 
       } catch (e) {
         debugPrint("Grounding failed: $e");
       }
    }

    // 3. Prepare AI Response Placeholder
    setState(() {
      _messages.add(ChatMessage(
        text: "",
        isUser: false, 
        modelName: _selectedModel
      ));
    });

    Stream<String>? responseStream;

    try {
      // 4. Select Provider and Get Stream from Service
      if (_currentProvider == AiProvider.gemini) {
        responseStream = ChatApiService.streamGeminiResponse(
          chatSession: _chat, 
          message: messageText,
          imagePaths: imagesToSend,
          modelName: _selectedModel,
        );
      } 
      else {
        // Prepare common variables for OpenAI-style APIs
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
          baseUrl = _localIpController.text.trim();
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
          systemInstruction: _systemInstructionController.text,
          userMessage: messageText,
          imagePaths: imagesToSend,
          temperature: _temperature,
          topP: _topP,
          topK: _topK,
          maxTokens: _maxOutputTokens,
          enableGrounding: _enableGrounding && _currentProvider == AiProvider.openRouter,
          extraHeaders: headers,
        );
      }

      // 5. Listen to the Stream
      String fullText = "";
      _geminiSubscription = responseStream.listen(
        (chunk) {
          if (_isCancelled) return;
          fullText += chunk;
          setState(() {
            _messages.last = ChatMessage(
              text: fullText,
              isUser: false,
              modelName: _selectedModel
            );
          });
           // Auto-scroll logic
          if (_scrollController.hasClients && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
             _scrollToBottom();
          }
        },
        onError: (e) {
          if (!_isCancelled) {
            setState(() {
              _messages.last = ChatMessage(
                text: "${_messages.last.text}\n\n**Error:** $e",
                isUser: false,
                modelName: "System Alert"
              );
              _isLoading = false;
            });
          }
        },
        onDone: () async {
          if (!_isCancelled) {
            setState(() => _isLoading = false);
            _autoSaveCurrentSession();
            if (_currentProvider == AiProvider.gemini) {
              await _initializeModel(); 
              if (!_enableGrounding) _updateTokenCount();
            }
          }
        },
      );
    
    } catch (e) {
      if (!_isCancelled) {
        setState(() {
          _messages.add(ChatMessage(
            text: "**System Error**\n\n```\n$e\n```",
            isUser: false,
            modelName: "System Alert",
          ));
          _isLoading = false;
        });
        _autoSaveCurrentSession();
      }
    }
  }

  // ----------------------------------------------------------------------
  // FETCH GOOGLE GEMINI MODELS
  // ----------------------------------------------------------------------
  Future<void> _fetchGeminiModels() async {
    if (_geminiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Need API Key first!")));
      return;
    }

    setState(() => _isLoadingGeminiModels = true);

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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('airp_list_gemini', fetchedIds);

        setState(() {
          _geminiModelsList = fetchedIds;
          _isLoadingGeminiModels = false;
          if (!_geminiModelsList.contains(_selectedGeminiModel) && _geminiModelsList.isNotEmpty) {
             _selectedGeminiModel = _geminiModelsList.first;
          }
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Found ${_geminiModelsList.length} Gemini models!")));
      } else {
        throw Exception("Google API Error: ${response.body}");
      }
    } catch (e) {
      setState(() => _isLoadingGeminiModels = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fetch Error: $e"), backgroundColor: Colors.red));
    }
  }

  // ----------------------------------------------------------------------
  // FETCH OPENROUTER MODELS
  // ----------------------------------------------------------------------
  Future<void> _fetchOpenRouterModels() async {
    setState(() => _isLoadingOpenRouterModels = true);

    try {
      final response = await http.get(
        Uri.parse("https://openrouter.ai/api/v1/models"),
        headers: {"HTTP-Referer": "https://airp-chat.com", "X-Title": "AIRP Chat"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> dataList = data['data'];

        final List<String> fetchedIds = dataList
            .map<String>((e) => e['id'].toString())
            .toList();
        
        fetchedIds.sort();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('airp_list_openrouter', fetchedIds);

        setState(() {
          _openRouterModelsList = fetchedIds;
          _isLoadingOpenRouterModels = false;
        });
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Found ${_openRouterModelsList.length} OpenRouter models!")));
      } else {
        throw Exception("Status ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoadingOpenRouterModels = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fetch Error: $e"), backgroundColor: Colors.red));
    }
  }

  // ----------------------------------------------------------------------
  // FETCH ARLI AI MODELS 
  // ----------------------------------------------------------------------
  Future<void> _fetchArliAiModels() async {
    if (_arliAiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Need ArliAI API Key first!")));
      return;
    }

    setState(() => _isLoadingArliAiModels = true);

    try {
      // 1. Try to fetch from API
      final response = await http.get(
        Uri.parse("https://api.arliai.com/v1/models"),
        headers: {"Authorization": "Bearer ${_arliAiKey.trim()}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> dataList = data['data'];

        final List<String> fetchedIds = dataList
            .map<String>((e) => e['id'].toString())
            .toList();
        
        fetchedIds.sort();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('airp_list_arliai', fetchedIds);

        setState(() {
          _arliAiModelsList = fetchedIds;
          _isLoadingArliAiModels = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Found ${_arliAiModelsList.length} ArliAI models!")));
      
      } else {
        // If 401 or other error, throw to trigger fallback
        throw Exception("Status ${response.statusCode}");
      }

    } catch (e) {
      // 2. FALLBACK: Use known models if API fails (e.g. 401 on Free Tier)
      debugPrint("ArliAI Fetch failed ($e), using fallback list.");

      setState(() {
        _isLoadingArliAiModels = false;
        // Auto-select first if current is invalid
        if (!_arliAiModelsList.contains(_arliAiModel)) {
          _arliAiModel = _arliAiModelsList.first;
          if (_currentProvider == AiProvider.arliAi) _selectedModel = _arliAiModel;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("API Fetch Failed ($e)."), 
            backgroundColor: Colors.orange
          )
        );
      }
    }
  }

  // ----------------------------------------------------------------------
  // FETCH NANOGPT MODELS
  // ----------------------------------------------------------------------
  Future<void> _fetchNanoGptModels() async {
    if (_nanoGptKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Need NanoGPT API Key first!")));
      return;
    }

    setState(() => _isLoadingNanoGptModels = true);

    try {
      final response = await http.get(
        Uri.parse("https://nano-gpt.com/api/v1/models"),
        headers: {"Authorization": "Bearer ${_nanoGptKey.trim()}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> dataList = data['data'] ?? []; 

        final List<String> fetchedIds = dataList
            .map<String>((e) => e['id'].toString())
            .toList();
        
        fetchedIds.sort();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('airp_list_nanogpt', fetchedIds);

        setState(() {
          _nanoGptModelsList = fetchedIds;
          _isLoadingNanoGptModels = false;
           // Auto-select first if current is invalid
          if (!_nanoGptModelsList.contains(_nanoGptModel) && _nanoGptModelsList.isNotEmpty) {
            _nanoGptModel = _nanoGptModelsList.first;
            if (_currentProvider == AiProvider.nanoGpt) _selectedModel = _nanoGptModel;
          }
        });
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Found ${_nanoGptModelsList.length} NanoGPT models!")));
      } else {
        throw Exception("Status ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoadingNanoGptModels = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fetch Error: $e"), backgroundColor: Colors.red));
    }
  }

// TOKEN COUNTING LOGIC ==================================
  Future<void> _updateTokenCount() async {
    if (_messages.isEmpty) {
      setState(() => _tokenCount = 0);
      return;
    }
    final contents = _messages.map((m) => m.isUser ? Content.text(m.text) : Content.model([TextPart(m.text)])).toList();
    try {
      final response = await _model.countTokens(contents);
      if (mounted) setState(() => _tokenCount = response.totalTokens);
    } catch (e) {
      debugPrint('Token count error: $e');
    }
  }

    Future<void> _pickImage() async { 
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _pendingImages.add(image.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

    Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'txt', 'md', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() {
          _pendingImages.add(path);
        });
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking file: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

    void _showAttachmentMenu() {
    // Get ThemeProvider to style the bottom sheet if needed
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                // Use theme color for attachment icons
                leading: Icon(Icons.photo_library, color: themeProvider.appThemeColor),
                title: const Text('Image from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),

              ListTile(
                leading: const Icon(Icons.description, color: Colors.orangeAccent),
                title: const Text('Document / File'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // LOAD LIBRARY
  Future<void> _loadSystemPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('airp_system_prompts');
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        setState(() {
          _savedSystemPrompts = jsonList.map((j) => SystemPromptData.fromJson(j)).toList();
        });
      } catch (e) {
        debugPrint("Error loading prompts: $e");
      }
    }
  }

  // SAVE TO LIBRARY LOGIC =================================
  Future<void> _savePromptToLibrary() async {
    if (_promptTitleController.text.isEmpty || _systemInstructionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Content cannot be empty")));
      return;
    }

    final newPrompt = SystemPromptData(
      title: _promptTitleController.text, 
      content: _systemInstructionController.text
    );

    setState(() {
      // Check if title exists, if so, update it. If not, add new.
      final index = _savedSystemPrompts.indexWhere((p) => p.title == newPrompt.title);
      if (index != -1) {
        _savedSystemPrompts[index] = newPrompt; 
      } else {
        _savedSystemPrompts.add(newPrompt); 
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_savedSystemPrompts.map((s) => s.toJson()).toList());
    await prefs.setString('airp_system_prompts', data);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved '${newPrompt.title}' to Library!")));
  }
  
  // DELETE FROM LIBRARY LOGIC =================================
  Future<void> _deletePromptFromLibrary() async {
    final title = _promptTitleController.text;
    if (title.isEmpty) return;

    setState(() {
      _savedSystemPrompts.removeWhere((p) => p.title == title);
      _promptTitleController.clear();
    });

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_savedSystemPrompts.map((s) => s.toJson()).toList());
    await prefs.setString('airp_system_prompts', data);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deleted '$title'")));
  }

  // SCROLL TO BOTTOM LOGIC =================================
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ----------------------------------------------------------------------
  // REGENERATE FUNCTION
  // ----------------------------------------------------------------------
  void _regenerateResponse(int index) {
    // Logic:
    // 1. If it's an AI message, delete it, then find the user message before it, and re-send.
    // 2. If it's a User message, delete everything after it, and re-send that user message.

    final msg = _messages[index];
    
    // Case A: User wants to retry the AI's last response
    if (!msg.isUser) {
      setState(() {
        _messages.removeAt(index); 
        _isLoading = true; 
      });
      
      if (_messages.isNotEmpty && _messages.last.isUser) {
        final lastUserMsg = _messages.last;
        _messages.removeLast(); 
        
        _textController.text = lastUserMsg.text;
        _pendingImages.addAll(lastUserMsg.imagePaths);
        _sendMessage(); 
      }
    }
    // Case B: User wants to retry their message
    else if (msg.isUser) {
       // Only allow if it's the very last message
       if (index == _messages.length - 1) {
         setState(() {
           _messages.removeAt(index);
           _isLoading = true;
         });
         _textController.text = msg.text;
         _pendingImages.addAll(msg.imagePaths);
         _sendMessage();
       } else {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Can only regenerate the latest exchange"))
         );
       }
    }
  }
  
    void _showMessageOptions(BuildContext context, int index) {
    final msg = _messages[index];
    final bool isLastMessage = index == _messages.length - 1;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Little handle bar
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
                ),
                
                // THE ICON ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. COPY
                    _buildMenuIcon(
                      icon: Icons.copy, 
                      label: "Copy", 
                      color: themeProvider.appThemeColor, // Changed to Theme Color
                      onTap: () {
                        Navigator.pop(context);
                        Clipboard.setData(ClipboardData(text: msg.text));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!"), duration: Duration(milliseconds: 800)));
                      }
                    ),

                    // 2. EDIT (Only for user messages usually, but allowed for both here)

                    _buildMenuIcon(
                      icon: Icons.edit, 
                      label: "Edit", 
                      color: Colors.orangeAccent, 
                      onTap: () {
                        Navigator.pop(context);
                        _showEditDialog(index);
                      }
                    ),

                    // 3. REGENERATE (Only if it's the last message exchange)
                    Opacity(
                      opacity: isLastMessage ? 1.0 : 0.3,
                      child: _buildMenuIcon(
                        icon: Icons.refresh, 
                        label: "Retry", 
                        color: Colors.greenAccent, 
                        onTap: isLastMessage ? () {
                          Navigator.pop(context);
                          _regenerateResponse(index);
                        } : null
                      ),
                    ),

                    // 4. DELETE (With Confirmation)
                    _buildMenuIcon(
                      icon: Icons.delete, 
                      label: "Delete", 
                      color: Colors.redAccent, 
                      onTap: () {
                        Navigator.pop(context); 
                        _confirmDeleteMessage(index); 
                      }
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuIcon({required IconData icon, required String label, required Color color, VoidCallback? onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(16),
          ),
          icon: Icon(icon, color: color, size: 28),
          onPressed: onTap,
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }

void _showEditDialog(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final TextEditingController editController = TextEditingController(text: _messages[index].text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Edit Message", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController, maxLines: null,
          style: const TextStyle(color: Colors.white70),
          decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.black26,),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() {
                _messages[index] = ChatMessage(text: editController.text, isUser: _messages[index].isUser);
              });
              _autoSaveCurrentSession(); 
              _initializeModel();
              
              Navigator.pop(context);
            },
            child: Text("Save", style: TextStyle(color: themeProvider.appThemeColor)),
          ),
        ],
      ),
    );
  }


  // ----------------------------------------------------------------------
  // DELETE WITH CONFIRMATION
  // ----------------------------------------------------------------------
  void _confirmDeleteMessage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Message?", style: TextStyle(color: Colors.white)),
        content: const Text("This cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(index); 
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // DELETE LOGIC
  void _deleteMessage(int index) {
    setState(() {
      _messages.removeAt(index);
    });
    _autoSaveCurrentSession();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Message deleted"),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1000),
      )
    );
  }

    // ----------------------------------------------------------------------
  // UI BUILDERS
  // ----------------------------------------------------------------------

  Widget _buildLeftDrawer() {
    return ConversationDrawer(
      savedSessions: _savedSessions,
      currentSessionId: _currentSessionId,
      tokenCount: _tokenCount,
      onNewSession: _createNewSession,
      onLoadSession: (session) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        setState(() {
          _messages = List.from(session.messages);
          _currentSessionId = session.id;
          _tokenCount = session.tokenCount;
          _systemInstructionController.text = session.systemInstruction;
          _titleController.text = session.title;

          if (session.backgroundImage != null) {
            themeProvider.setBackgroundImage(session.backgroundImage!);
          }

          if (session.provider == 'openRouter') {
            _currentProvider = AiProvider.openRouter;
            _openRouterModel = session.modelName;
            _openRouterModelController.text = session.modelName;
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
          _updateApiKeyTextField();
          _initializeModel();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      },
      onDeleteSession: (id) {
        setState(() {
          _savedSessions.removeWhere((s) => s.id == id);
          if (id == _currentSessionId) {
            _createNewSession();
          }
        });
        _autoSaveCurrentSession();
      },
    );
  }

  Widget _buildSettingsDrawer() {
    return SettingsDrawer(
      currentProvider: _currentProvider,
      apiKey: _apiKeyController.text,
      localIp: _localIpController.text,
      title: _titleController.text,
      geminiModelsList: _geminiModelsList,
      openRouterModelsList: _openRouterModelsList,
      arliAiModelsList: _arliAiModelsList,
      nanoGptModelsList: _nanoGptModelsList,
      selectedGeminiModel: _selectedGeminiModel,
      openRouterModel: _openRouterModel,
      arliAiModel: _arliAiModel,
      nanoGptModel: _nanoGptModel,
      localModelName: _localModelName,
      isLoadingGeminiModels: _isLoadingGeminiModels,
      isLoadingOpenRouterModels: _isLoadingOpenRouterModels,
      isLoadingArliAiModels: _isLoadingArliAiModels,
      isLoadingNanoGptModels: _isLoadingNanoGptModels,
      temperature: _temperature,
      topP: _topP,
      topK: _topK,
      maxOutputTokens: _maxOutputTokens,
      historyLimit: _historyLimit,
      enableGrounding: _enableGrounding,
      disableSafety: _disableSafety,
      hasUnsavedChanges: _hasUnsavedChanges,
      savedSystemPrompts: _savedSystemPrompts,
      promptTitle: _promptTitleController.text,
      systemInstruction: _systemInstructionController.text,
      onApiKeyChanged: (val) {
        setState(() {
          switch (_currentProvider) {
            case AiProvider.gemini: _geminiKey = val; break;
            case AiProvider.openRouter: _openRouterKey = val; break;
            case AiProvider.openAi: _openAiKey = val; break;
            case AiProvider.arliAi: _arliAiKey = val; break;
            case AiProvider.nanoGpt: _nanoGptKey = val; break;
            case AiProvider.local: break;
          }
          _apiKeyController.text = val;
          _hasUnsavedChanges = true;
        });
      },
      onLocalIpChanged: (val) {
        setState(() {
          _localIpController.text = val;
          _hasUnsavedChanges = true;
        });
      },
      onTitleChanged: (val) {
        setState(() {
          _titleController.text = val;
          _hasUnsavedChanges = true;
        });
      },
      onModelSelected: (val) {
        setState(() {
          if (_currentProvider == AiProvider.gemini) {
            _selectedGeminiModel = val;
            _selectedModel = val;
          } else if (_currentProvider == AiProvider.openRouter) {
            _openRouterModel = val;
            _openRouterModelController.text = val;
            _selectedModel = val;
          } else if (_currentProvider == AiProvider.arliAi) {
            _arliAiModel = val;
            _selectedModel = val;
          } else if (_currentProvider == AiProvider.nanoGpt) {
            _nanoGptModel = val;
            _selectedModel = val;
          }
          _hasUnsavedChanges = true;
        });
      },
      onLocalModelNameChanged: (val) {
        setState(() {
          _localModelName = val;
          _hasUnsavedChanges = true;
        });
      },
      onFetchGeminiModels: _fetchGeminiModels,
      onFetchOpenRouterModels: _fetchOpenRouterModels,
      onFetchArliAiModels: _fetchArliAiModels,
      onFetchNanoGptModels: _fetchNanoGptModels,
      onTemperatureChanged: (val) => setState(() { _temperature = val; _hasUnsavedChanges = true; }),
      onTopPChanged: (val) => setState(() { _topP = val; _hasUnsavedChanges = true; }),
      onTopKChanged: (val) => setState(() { _topK = val; _hasUnsavedChanges = true; }),
      onMaxOutputTokensChanged: (val) => setState(() { _maxOutputTokens = val; _hasUnsavedChanges = true; }),
      onHistoryLimitChanged: (val) => setState(() { _historyLimit = val; _hasUnsavedChanges = true; }),
      onEnableGroundingChanged: (val) => setState(() { _enableGrounding = val; _hasUnsavedChanges = true; }),
      onDisableSafetyChanged: (val) => setState(() { _disableSafety = val; _hasUnsavedChanges = true; }),
      onPromptTitleChanged: (val) {
        setState(() {
          _promptTitleController.text = val;
          _hasUnsavedChanges = true;
        });
      },
      onSystemInstructionChanged: (val) {
        setState(() {
          _systemInstructionController.text = val;
          _hasUnsavedChanges = true;
        });
      },
      onSavePrompt: _savePromptToLibrary,
      onDeletePrompt: _deletePromptFromLibrary,
      onLoadPrompt: (title, content) {
        setState(() {
          _promptTitleController.text = title;
          _systemInstructionController.text = content;
          _hasUnsavedChanges = true;
        });
      },
      onSaveSettings: _saveSettings,
    );
  }

@override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      resizeToAvoidBottomInset: true, 
      drawer: _buildLeftDrawer(),
      endDrawer: _buildSettingsDrawer(),
      appBar: AppBar(
        backgroundColor: themeProvider.backgroundImagePath != null
          ? const Color(0xFFFFFFFF).withAlpha((0 * 255).round())
          : const Color.fromARGB(255, 0, 0, 0),
        leading: Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(c).openDrawer())),
        
                title: PopupMenuButton<AiProvider>(
          initialValue: _currentProvider,
          color: const Color(0xFF2C2C2C),
          // MODIFIED: Use theme color for shadow/bloom
          shadowColor: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : null,
          elevation: themeProvider.enableBloom ? 12 : 8,
          onSelected: (AiProvider result) {
            setState(() {
              _currentProvider = result;
              _updateApiKeyTextField(); 
              if (result == AiProvider.gemini) _initializeModel();
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to ${result.name.toUpperCase()}")));
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<AiProvider>>[
            PopupMenuItem<AiProvider>(
              value: AiProvider.gemini,
              child: Row(children: [Icon(Icons.auto_awesome, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - Gemini')]),
            ),
            PopupMenuItem<AiProvider>(
              value: AiProvider.openRouter,
              child: Row(children: [Icon(Icons.router, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - OpenRouter')]),
            ),
                        PopupMenuItem<AiProvider>(
              value: AiProvider.arliAi,
              child: Row(children: [Icon(Icons.alternate_email, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - ArliAI')]),
            ),
            PopupMenuItem<AiProvider>(
              value: AiProvider.nanoGpt,
              child: Row(children: [Icon(Icons.bolt, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - NanoGPT')]),
            ),
            PopupMenuItem<AiProvider>(
              value: AiProvider.local,
              child: Row(children: [Icon(Icons.laptop_mac, color: themeProvider.appThemeColor), const SizedBox(width: 8), const Text('AIRP - Local')]),
            ),
            const PopupMenuItem<AiProvider>(
              value: AiProvider.openAi,
              enabled: false,
              child: Row(children: [Icon(Icons.lock, color: Colors.grey), SizedBox(width: 8), Text('AIRP - OpenAI (Soon)')]),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'AIRP - ${_currentProvider == AiProvider.gemini ? "Gemini" 
                      : _currentProvider == AiProvider.openRouter ? "OpenRouter" 
                      : _currentProvider == AiProvider.arliAi ? "ArliAI"
                      : _currentProvider == AiProvider.nanoGpt ? "NanoGPT"
                      : _currentProvider == AiProvider.local ? "Local" 
                      : "OpenAI"}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: themeProvider.appThemeColor,
                    fontWeight: FontWeight.bold,
                    shadows: themeProvider.enableBloom ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 8)] : [],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: themeProvider.appThemeColor),
            ],
          ),
        ),

        actions: [
          Builder(builder: (c) => IconButton(icon: const Icon(Icons.settings), onPressed: () => Scaffold.of(c).openEndDrawer())),
        ],
      ),
            body: Stack(
        children: [
          if (themeProvider.backgroundImagePath != null)
                        Positioned.fill(
              child: Image(
                image: themeProvider.currentImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          if (themeProvider.backgroundImagePath != null)
            Positioned.fill(
              child: Container(
                  color: Colors.black
                      .withAlpha((themeProvider.backgroundOpacity * 255).round())),
            ),
            Positioned.fill(
              child: EffectsOverlay(
                showMotes: themeProvider.enableMotes,
                showRain: themeProvider.enableRain,
                showFireflies: themeProvider.enableFireflies,
                effectColor: themeProvider.appThemeColor,
                motesDensity: themeProvider.motesDensity.toDouble(),
                rainIntensity: themeProvider.rainIntensity.toDouble(),
                firefliesCount: themeProvider.firefliesCount.toDouble(),              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(
                        msg: _messages[index],
                        themeProvider: themeProvider,
                        onLongPress: () => _showMessageOptions(context, index),
                      );
                    },
                  ),
                ),
              if (_isLoading)
                LinearProgressIndicator(color: themeProvider.appThemeColor, minHeight: 2),
              
              Container(
                padding: const EdgeInsets.all(8.0),
                color: const Color(0xFFFFFFFF).withAlpha((0.1 * 255).round()),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pendingImages.isNotEmpty)
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _pendingImages.length,
                          itemBuilder: (context, index) {
                            final path = _pendingImages[index];
                            final filename = path.split('/').last;
                            final ext = path.split('.').last.toLowerCase();
                            final isImage = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);

                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                              child: Stack(
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: isImage
                                            ? Image.file(File(path),
                                                width: 60, height: 60, fit: BoxFit.cover)
                                            : Container(
                                                width: 60,
                                                height: 60,
                                                color: Colors.white12,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  ext == 'pdf'
                                                      ? Icons.picture_as_pdf
                                                      : Icons.insert_drive_file,
                                                  color: Colors.white70,
                                                  size: 28,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          filename,
                                          style: const TextStyle(
                                              color: Colors.white70, fontSize: 9),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Delete button (X)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: InkWell(
                                      onTap: () => setState(
                                          () => _pendingImages.removeAt(index)),
                                      child: const CircleAvatar(
                                          radius: 10,
                                          backgroundColor: Colors.red,
                                          child: Icon(Icons.close,
                                              size: 12, color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.attach_file, color: themeProvider.appThemeColor),
                          tooltip: "Add Attachment",
                          onPressed: _isLoading ? null : _showAttachmentMenu,
                        ),

                        Expanded(
                          child: TextField(
                            controller: _textController,
                            minLines: 1,
                            maxLines: 6,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: _pendingImages.isNotEmpty
                                  ? 'Add a caption...'
                                  : (_enableGrounding
                                      ? 'Search & Chat...'
                                      : 'Ready to chat...'),
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none),
                              filled: true,
                              fillColor: const Color.fromARGB(255, 0, 0, 0), 
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            // Allow Enter to send ONLY if not loading
                            onSubmitted: _isLoading ? null : (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 3. DYNAMIC SEND / STOP BUTTON
                        // MODIFIED: Uses appThemeColor for button background/icon details
                        IconButton.filled(
                          style: IconButton.styleFrom(
                              backgroundColor: _isLoading
                                 ? themeProvider.appThemeColor.withOpacity(0.2) 
                                 : (_enableGrounding ? Colors.green : themeProvider.appThemeColor)
                          ),
                          // Toggle Function: Send if idle, Stop if loading
                          onPressed: _isLoading ? _cancelGeneration : _sendMessage,
                          // Toggle Icon: Stop Square if loading, Send Plane if idle
                          icon: Icon(
                            _isLoading ? Icons.stop_circle_outlined : Icons.send,
                             color: _isLoading ? themeProvider.appThemeColor : Colors.black
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),

        ],
      ),
    );
  }
}