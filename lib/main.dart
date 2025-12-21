import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const GeminiChatApp(),
    ),
  );
}

class GeminiChatApp extends StatelessWidget {
  const GeminiChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'AIRP - Gemini Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: themeProvider.currentTextTheme,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

// ----------------------------------------------------------------------
// DATA CLASS
// ----------------------------------------------------------------------
enum AiProvider { gemini, openRouter, openAi }

class ChatSessionData {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final String modelName;
  final int tokenCount;
  final String systemInstruction;
  final String? backgroundImage;
  final String provider;

  ChatSessionData({
    required this.id,
    required this.title, 
    required this.messages, 
    required this.modelName,
    required this.tokenCount,
    required this.systemInstruction,
    this.backgroundImage,
    this.provider = 'gemini', 
  });

// Compact JSON conversion
Map<String, dynamic> toJson() => {
  'id': id, 'title': title, 'modelName': modelName, 'tokenCount': tokenCount,
  'systemInstruction': systemInstruction, 'backgroundImage': backgroundImage,
  'provider': provider,
  'messages': messages.map((m) => m.toJson()).toList(),
};

factory ChatSessionData.fromJson(Map<String, dynamic> json) => ChatSessionData(
  id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
  title: json['title'] ?? "Untitled",
  messages: (json['messages'] as List?)?.map((m) => ChatMessage.fromJson(m)).toList() ?? [],
  modelName: json['modelName'] ?? 'models/gemini-flash-lite-latest',
  tokenCount: json['tokenCount'] ?? 0,
  systemInstruction: json['systemInstruction'] ?? "",
  backgroundImage: json['backgroundImage'],
  provider: json['provider'] ?? 'gemini',
);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ----------------------------------------------------------------------
  // CONFIGURATION
  // ----------------------------------------------------------------------
  static const _defaultApiKey = '';

  String _drawerSearchQuery = '';
  
  final List<String> _models = [
    'models/gemini-3-pro-preview',
    'models/gemini-3-flash-preview',
    'models/gemini-2.5-pro',
    'models/gemini-flash-latest',
    'models/gemini-flash-lite-latest', 
    'models/gemini-2.0-flash',
    'models/gemini-2.0-flash-lite',
    'models/gemma-3-27b-it',
    'models/gemma-3-12b-it',
    'models/gemma-3-4b-it',
    'models/gemma-3-2b-it',
    'models/gemma-3-1b-it',
  ];

  final Map<String, String> _modelDisplayNames = {
    // Gemini 3 Series
    'models/gemini-3-pro-preview': 'Gemini 3 Pro Preview (Expensive)',
    'models/gemini-3-flash-preview': 'Gemini 3 Flash Preview (Fast)',
    // Gemini 2.5 Series
    'models/gemini-2.5-pro': 'Gemini 2.5 Pro (Middle ground)',
    'models/gemini-flash-latest': 'Gemini 2.5 Flash Latest (Cheap)',
    'models/gemini-flash-lite-latest': 'Gemini 2.5 Flash Latest Lite (Cheaper)',
    // Gemini 2.0 Series
    'models/gemini-2.0-flash': 'Gemini 2.0 Flash',
    'models/gemini-2.0-flash-lite': 'Gemini 2.0 Flash Lite',
    // Gemma 3 Series
    'models/gemma-3-27b-it': 'Gemma 3 27B (Desktop Class)',
    'models/gemma-3-12b-it': 'Gemma 3 12B (Efficient)',
    'models/gemma-3-4b-it': 'Gemma 3 4B (Lightweight)',
    'models/gemma-3-2b-it': 'Gemma 3 2B (Small)',
    'models/gemma-3-1b-it': 'Gemma 3 1B (Tiny)',
  };

  AiProvider _currentProvider = AiProvider.gemini;

  String _geminiKey = '';
  String _openRouterKey = '';
  String _openAiKey = ''; // Placeholder for possible OpenAI support

  String _selectedGeminiModel = 'models/gemini-flash-lite-latest'; // Default Gemini model
  String _openRouterModel = 'z-ai/glm-4.5-air:free'; // Default OR model

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
  String? _currentSessionId;
  int _tokenCount = 0;
  static const int _tokenLimitWarning = 190000;
  List<String> _openRouterModelsList = [];
  bool _isLoadingModels = false;
  bool _isLoading = false;

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

  // UPDATED SETTINGS LOADER
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load Keys
      _geminiKey = prefs.getString('airp_key_gemini') ?? '';
      _openRouterKey = prefs.getString('airp_key_openrouter') ?? '';
      _openAiKey = prefs.getString('airp_key_openai') ?? '';

      // Load Provider State
      final providerString = prefs.getString('airp_provider') ?? 'gemini';
      if (providerString == 'openRouter') {
        _currentProvider = AiProvider.openRouter;
      } else if (providerString == 'openAi') {
        _currentProvider = AiProvider.openAi;
      } else {
        _currentProvider = AiProvider.gemini;
      }

      // Load Models
      _openRouterModel = prefs.getString('airp_model_openrouter') ?? 'google/gemini-2.0-flash-lite-preview-02-05:free';
      _openRouterModelController.text = _openRouterModel;
      
      // Update the visible API key box based on current provider
      _updateApiKeyTextField();
    });

    // Only init Google Model if we are in Gemini mode
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
    }
  }

  // ----------------------------------------------------------------------
  // OPTIMIZED _saveSettings
  // ----------------------------------------------------------------------

  Future<void> _saveSettings() async {
    // Trim inputs
    final cleanKey = _apiKeyController.text.trim();
    final cleanModel = _openRouterModelController.text.trim();

    setState(() {
      switch (_currentProvider) {
        case AiProvider.gemini: _geminiKey = cleanKey; break;
        case AiProvider.openRouter: _openRouterKey = cleanKey; break;
        case AiProvider.openAi: _openAiKey = cleanKey; break;
      }
      _openRouterModel = cleanModel;
      _openRouterModelController.text = cleanModel;

      // Update selected model based on provider
      if (_currentProvider == AiProvider.openRouter) {
        _selectedModel = cleanModel;
      } else if (_currentProvider == AiProvider.gemini) {
         _selectedModel = _selectedGeminiModel;
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('airp_key_gemini', _geminiKey);
    await prefs.setString('airp_key_openrouter', _openRouterKey);
    await prefs.setString('airp_key_openai', _openAiKey);
    await prefs.setString('airp_provider', _currentProvider.name);
    await prefs.setString('airp_model_openrouter', _openRouterModel);

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

    final sessionData = ChatSessionData(
      id: _currentSessionId!,
      title: title,
      messages: List.from(_messages), 
      modelName: _selectedModel,
      tokenCount: _tokenCount,
      systemInstruction: _systemInstructionController.text,
      backgroundImage: themeProvider.backgroundImagePath,
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

  // ----------------------------------------------------------------------
  // FIXED _initializeModel
  // ----------------------------------------------------------------------
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
      return; 
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
        apiKey: activeKey,
        systemInstruction: _systemInstructionController.text.isNotEmpty
            ? Content.system(_systemInstructionController.text)
            : null,
        generationConfig: GenerationConfig(temperature: _temperature),
        safetySettings: safetySettings,
      );
      
      List<Content> history = [];
      for (var msg in _messages) {
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

Future<void> _sendMessage() async {
    final messageText = _textController.text;
    if (messageText.isEmpty && _pendingImages.isEmpty) return;
    
    // 1. UI UPDATES (Same as before)
    final List<String> imagesToSend = List.from(_pendingImages);
    setState(() {
      _messages.add(ChatMessage(text: messageText, isUser: true, imagePaths: imagesToSend));
      _isLoading = true;
      _pendingImages.clear();
      _textController.clear();
    });
    _scrollToBottom();
    _autoSaveCurrentSession();

    // 2. BRANCHING LOGIC
    try {
      if (_currentProvider == AiProvider.gemini) {
        // --- GEMINI LOGIC ---
        await _sendGeminiMessage(messageText, imagesToSend);
      } else if (_currentProvider == AiProvider.openRouter) {
        // --- OPENROUTER LOGIC ---
        await _sendOpenRouterMessage(messageText, imagesToSend);
      } else {
        // OpenAI Placeholder
        setState(() => _isLoading = false);
      }
    } catch (e) {
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

  Future<void> _sendGeminiMessage(String text, List<String> images) async {
    Content userContent;
    if (images.isNotEmpty) {
      final List<Part> parts = [];
      if (text.isNotEmpty) parts.add(TextPart(text));
      for (String path in images) {
        final bytes = await File(path).readAsBytes();
        final mimeType = path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        parts.add(DataPart(mimeType, bytes));
      }
      userContent = Content.multi(parts);
    } else {
      userContent = Content.text(text);
    }
    
    if (_enableGrounding && images.isEmpty) {
      final groundedText = await _performGroundedGeneration(text);
      setState(() {
        _messages.add(ChatMessage(text: groundedText ?? "Error", isUser: false, modelName: _selectedModel));
        _isLoading = false;
      });
    } else {
      final response = await _chat.sendMessage(userContent);
      
      String fullText = "";
      String? aiImageBase64;

      if (response.candidates.isNotEmpty) {
        final parts = response.candidates.first.content.parts;
        for (var part in parts) {
          if (part is TextPart) {
            fullText += part.text;
          } else if (part is DataPart) {
            aiImageBase64 = base64Encode(part.bytes);
          }
        }
      }

      setState(() {
        _messages.add(ChatMessage(
          text: fullText,
          isUser: false,
          aiImage: aiImageBase64,
          modelName: _selectedModel, // stamp model used
        ));
        _isLoading = false;
      });
    }

    await _initializeModel();
    _scrollToBottom();
    if (!_enableGrounding) _updateTokenCount();
    _autoSaveCurrentSession();
  }

  Future<void> _sendOpenRouterMessage(String text, List<String> images) async {
    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");

    // Safety Check: Trim the key again just to be sure
    final cleanKey = _openRouterKey.trim();
    if (cleanKey.isEmpty) {
      throw Exception("OpenRouter Key is empty! Check settings.");
    }

    // 1. Build Messages JSON (simpler history)
    List<Map<String, dynamic>> messagesPayload = [];
    if (_systemInstructionController.text.isNotEmpty) {
      messagesPayload.add({"role": "system", "content": _systemInstructionController.text});
    }

    for (var msg in _messages) {
      if (msg == _messages.last) continue;
      messagesPayload.add({
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.text
      });
    }

    if (images.isEmpty) {
      messagesPayload.add({"role": "user", "content": text});
    } else {
      List<Map<String, dynamic>> contentParts = [];
      if (text.isNotEmpty) contentParts.add({"type": "text", "text": text});
      for (String path in images) {
        final bytes = await File(path).readAsBytes();
        final base64Img = base64Encode(bytes);
        contentParts.add({
          "type": "image_url",
          "image_url": {"url": "data:image/jpeg;base64,$base64Img"}
        });
      }
      messagesPayload.add({"role": "user", "content": contentParts});
    }

    // 2. Send Request
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $cleanKey",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://airp-chat.com",
        "X-Title": "AIRP Chat",
      },
      body: jsonEncode({
        "model": _openRouterModel.trim(),
        "messages": messagesPayload,
        "temperature": _temperature,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['choices'] != null && data['choices'].isNotEmpty) {
        final String aiText = data['choices'][0]['message']['content'];
        setState(() {
          _messages.add(ChatMessage(text: aiText, isUser: false, modelName: _openRouterModel));
          _isLoading = false;
        });
        _autoSaveCurrentSession();
      }
    } else {
      debugPrint("OpenRouter Error Body: ${response.body}");
      throw Exception("OpenRouter Error: ${response.statusCode} - ${response.body}");
    }
  }

  // ----------------------------------------------------------------------
  // FETCH OPENROUTER MODELS
  // ----------------------------------------------------------------------
  Future<void> _fetchOpenRouterModels() async {
    setState(() => _isLoadingModels = true);

    try {
      // 1. We don't strictly need a key for this public endpoint, 
      // but it's good practice to send it if we have it.
      final response = await http.get(
        Uri.parse("https://openrouter.ai/api/v1/models"),
        headers: {
          "HTTP-Referer": "https://airp-chat.com",
          "X-Title": "AIRP Chat",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> dataList = data['data'];

        // 2. Extract IDs and Sort Alphabetically
        final List<String> fetchedIds = dataList
            .map<String>((e) => e['id'].toString())
            .toList();
        
        fetchedIds.sort(); // A-Z sort

        setState(() {
          _openRouterModelsList = fetchedIds;
          _isLoadingModels = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Fetched ${_openRouterModelsList.length} models! OwO"))
          );
        }
      } else {
        throw Exception("Status ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoadingModels = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch models: $e"), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  Future<String?> _performGroundedGeneration(String userMessage) async {
    final activeKey = _geminiKey.isNotEmpty ? _geminiKey : _defaultApiKey;
    final modelId = _selectedModel.replaceAll('models/', '');
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$activeKey');

    final List<Map<String, dynamic>> contents = [];
    for (var msg in _messages) {
      if (msg == _messages.last) continue; 
      contents.add({
        "role": msg.isUser ? "user" : "model",
        "parts": [{"text": msg.text}]
      });
    }
    contents.add({"role": "user", "parts": [{"text": userMessage}]});

    final toolsPayload = [ { "google_search": {} } ];
    final body = jsonEncode({
      "contents": contents,
      "tools": toolsPayload,
      "system_instruction": _systemInstructionController.text.isNotEmpty ? {
        "parts": [{"text": _systemInstructionController.text}]
      } : null,
      "generationConfig": {"temperature": _temperature},
      "safetySettings": _disableSafety ? [
          {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
      ] : []
    });

    final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] != null && (data['candidates'] as List).isNotEmpty) {
        final candidate = data['candidates'][0];
        final parts = candidate['content']['parts'] as List;
        String fullText = "";
        for (var part in parts) { if (part['text'] != null) fullText += part['text']; }
        if (candidate['groundingMetadata'] != null) {
            fullText += "\n\n--- \n**Sources Found:**\n";
            final metadata = candidate['groundingMetadata'];
            if (metadata['groundingChunks'] != null) {
              for (var chunk in metadata['groundingChunks']) {
                if (chunk['web'] != null) fullText += "- [${chunk['web']['title']}](${chunk['web']['uri']})\n";
              }
            }
        }
        return fullText;
      }
    } 
    return null;
  }

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

  // SAVE TO LIBRARY
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
        _savedSystemPrompts[index] = newPrompt; // Update existing
      } else {
        _savedSystemPrompts.add(newPrompt); // Add new
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_savedSystemPrompts.map((s) => s.toJson()).toList());
    await prefs.setString('airp_system_prompts', data);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved '${newPrompt.title}' to Library!")));
  }
  
  // DELETE FROM LIBRARY
  Future<void> _deletePromptFromLibrary() async {
    final title = _promptTitleController.text;
    if (title.isEmpty) return;

    setState(() {
      _savedSystemPrompts.removeWhere((p) => p.title == title);
      _promptTitleController.clear();
      // Don't clear system instruction, user might want to keep the text
    });

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_savedSystemPrompts.map((s) => s.toJson()).toList());
    await prefs.setString('airp_system_prompts', data);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deleted '$title'")));
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
    
    // For simplicity/safety, let's only allow regenerating the LAST AI message for now.
    // Or if the user clicks their own last message.
    
    final msg = _messages[index];
    
    // Case A: User wants to retry the AI's last response
    if (!msg.isUser) {
      setState(() {
        _messages.removeAt(index); // Remove "bad" AI response
        _isLoading = true; // Start loading
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
                      color: Colors.cyanAccent, 
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
            child: const Text("Save", style: TextStyle(color: Colors.cyanAccent)),
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
    final tokenColor = _tokenCount > _tokenLimitWarning ? Colors.redAccent : Colors.greenAccent;
    
    final filteredSessions = _savedSessions.where((session) {
      final titleLower = session.title.toLowerCase();
      final queryLower = _drawerSearchQuery.toLowerCase();
      return titleLower.contains(queryLower);
    }).toList();

    return Drawer(
      width: 280,
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            color: Colors.black26,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Conversations List", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.token, color: tokenColor, size: 16),
                    const SizedBox(width: 8),
                    Text("$_tokenCount / 1M \n Limit: ~190k", style: TextStyle(color: tokenColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
            title: const Text("New Conversation", style: TextStyle(color: Colors.green)),
            subtitle: const Text("Hold Chat to delete", style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
            onTap: () {
              _createNewSession();
              Navigator.pop(context);
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: "Find conversation...",
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Colors.cyanAccent, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
                onChanged: (val) {
                  setState(() {
                    _drawerSearchQuery = val;
                  });
                },
              ),
            ),
          ),
          
          const Divider(color: Colors.grey),
          
          Expanded(
            child: filteredSessions.isEmpty 
            ? const Center(child: Text("No chats found", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
              itemCount: filteredSessions.length,
              itemBuilder: (context, index) {
                final session = filteredSessions[index];
                final bool isActive = session.id == _currentSessionId;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.cyanAccent.withAlpha((0.05 * 255).round()) : Colors.transparent,
                    border: isActive ? Border.all(color: Colors.cyanAccent, width: 1.5) : null, 
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    splashColor: Colors.red.withAlpha((0.95 * 255).round()),
                    leading: Icon(
                      isActive ? Icons.check_circle : Icons.history, 
                      color: isActive ? Colors.cyanAccent : Colors.grey[600]
                    ),
                    title: Text(
                      session.title, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis, 
                      style: TextStyle(
                        color: isActive ? Colors.cyanAccent : Colors.grey[300], 
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal
                      )
                    ),
                    subtitle: Text(
                      _modelDisplayNames[session.modelName] ?? session.modelName, 
                      style: TextStyle(fontSize: 10, color: Colors.grey[600])
                    ),
                    onTap: () {
                      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                      
                      setState(() {
                        // 1. Load Messages & Basic Data
                        _messages = List.from(session.messages);
                        _currentSessionId = session.id;
                        _tokenCount = session.tokenCount;
                        _systemInstructionController.text = session.systemInstruction;
                        _titleController.text = session.title;

                        // 2. Restore Visuals
                        if (session.backgroundImage != null) {
                          themeProvider.setBackgroundImage(session.backgroundImage!);
                        }

                        // 3. Restore Provider & Model UI State 
                        // This ensures the Settings Drawer shows the correct model/provider
                        if (session.provider == 'openRouter') {
                          _currentProvider = AiProvider.openRouter;
                          _openRouterModel = session.modelName;
                          _openRouterModelController.text = session.modelName; 
                          _selectedModel = session.modelName;
                        } 
                        else if (session.provider == 'openAi') {
                          _currentProvider = AiProvider.openAi;
                          // Handle OpenAI specific UI sync if added later
                          _selectedModel = session.modelName;
                        } 
                        else {
                          // Default to Gemini
                          _currentProvider = AiProvider.gemini;
                          _selectedGeminiModel = session.modelName; 
                          _selectedModel = session.modelName;
                        }

                        // 4. Update the API Key text box to match the restored provider
                        _updateApiKeyTextField();

                        // 5. Re-initialize the chat engine
                        _initializeModel();
                      });

                      Navigator.pop(context); // Close Drawer
                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    },
                    
                    onLongPress: () {
                      HapticFeedback.heavyImpact();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF2C2C2C),
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                              SizedBox(width: 10),
                              Text("Delete?", style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                          content: Text("Permanently deletes ${session.title}", style: const TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                              icon: const Icon(Icons.delete_forever, color: Colors.white),
                              label: const Text("DELETE"),
                              onPressed: () {
                                setState(() {
                                  _savedSessions.removeWhere((s) => s.id == session.id);
                                  if (session.id == _currentSessionId) {
                                    _createNewSession();
                                  }
                                });
                                _autoSaveCurrentSession();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Conversation Deleted"), backgroundColor: Colors.redAccent)
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      width: 320,
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text("Main Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(),

            const Text("Conversation Title", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            const SizedBox(height: 5),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: "Type a title...",
                  hintStyle: TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  suffixIcon: Icon(Icons.edit, size: 16, color: Colors.cyanAccent),
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty) {
                    _autoSaveCurrentSession();}
                },
              ),
            ),
            const SizedBox(height: 20),
            
            const Text("API Key (BYOK)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            const SizedBox(height: 5),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Paste AI Studio Key...",
                border: OutlineInputBorder(),
                filled: true, isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 20),

            const Text("Model Selection", style: TextStyle(fontWeight: FontWeight.bold)),
            
            // DYNAMIC SELECTOR
            if (_currentProvider == AiProvider.gemini) 
              DropdownButton<String>(
                isExpanded: true,
                dropdownColor: Colors.grey[900],
                value: _models.contains(_selectedGeminiModel) ? _selectedGeminiModel : _models.first,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() { _selectedGeminiModel = newValue; _selectedModel = newValue; _initializeModel(); });
                  }
                },
                items: _models.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(_modelDisplayNames[value] ?? value, style: const TextStyle(fontSize: 13, color: Colors.white)),
                  );
                }).toList(),
              )
            else if (_currentProvider == AiProvider.openRouter)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  
                  if (_openRouterModelsList.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _openRouterModelsList.contains(_openRouterModel) 
                              ? _openRouterModel 
                              : null, // Handle case where current text isn't in list
                          hint: Text(_openRouterModel, style: const TextStyle(color: Colors.white70)),
                          dropdownColor: const Color(0xFF2C2C2C),
                          items: _openRouterModelsList.map((String id) {
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                id, 
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _openRouterModel = newValue;
                                _openRouterModelController.text = newValue; 
                              });
                            }
                          },
                        ),
                      ),
                    )
                  else
                    // Fallback to Manual Entry if list isn't loaded
                    TextField(
                      controller: _openRouterModelController,
                      decoration: const InputDecoration(
                        hintText: "vendor/model-name",
                        hintStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(),
                        filled: true,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (val) { _openRouterModel = val.trim(); },
                    ),

                  const SizedBox(height: 8),

                  if (_openRouterModelsList.isEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: _isLoadingModels 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.cloud_download, size: 16),
                        label: Text(_isLoadingModels ? "Loading..." : "Load Model List"),
                        onPressed: _isLoadingModels ? null : _fetchOpenRouterModels,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purpleAccent,
                          side: const BorderSide(color: Colors.purpleAccent),
                        ),
                      ),
                    ),
                    
                  if (_openRouterModelsList.isNotEmpty)
                     Align(
                       alignment: Alignment.centerRight,
                       child: TextButton(
                         onPressed: () {
                           // Option to switch back to manual entry
                           setState(() => _openRouterModelsList = []);
                         },
                         child: const Text("Switch to Manual Input", style: TextStyle(fontSize: 10, color: Colors.grey)),
                       ),
                     ),

                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text("Check openrouter.ai/models for details", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  )
                ],
              ),
            const SizedBox(height: 30),

            const Text("System Prompt", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            
            // 1. THE DROPDOWN & ACTIONS ROW
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text("Select from Library...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  dropdownColor: const Color(0xFF2C2C2C),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
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
                    ..._savedSystemPrompts.map((prompt) {
                      return DropdownMenuItem<String>(
                        value: prompt.title,
                        child: Text(prompt.title, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue == "CREATE_NEW") {
                      setState(() {
                        _promptTitleController.clear();
                        _systemInstructionController.clear();
                      });
                    } else if (newValue != null) {
                      final prompt = _savedSystemPrompts.firstWhere((p) => p.title == newValue);
                      setState(() {
                        _promptTitleController.text = prompt.title;
                        _systemInstructionController.text = prompt.content;
                      });
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 10),

            // 2. PROMPT TITLE FIELD
            TextField(
              controller: _promptTitleController,
              decoration: const InputDecoration(
                labelText: "Prompt Title (e.g., 'World of Japan')",
                labelStyle: TextStyle(color: Colors.cyanAccent, fontSize: 12),
                border: OutlineInputBorder(),
                filled: true, fillColor: Colors.black12,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            // 3. PROMPT CONTENT FIELD
            TextField(
              controller: _systemInstructionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "Enter the roleplay rules here...",
                border: OutlineInputBorder(),
                filled: true, fillColor: Colors.black26,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyanAccent, 
                      side: const BorderSide(color: Colors.cyanAccent),
                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    ),
                    onPressed: _savePromptToLibrary,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text("Save Preset"),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.redAccent.withAlpha((0.2 * 255).round())),
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  tooltip: "Delete Preset",
                  onPressed: _deletePromptFromLibrary,
                ),
              ],
            ),

            const SizedBox(height: 20),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40), 
                backgroundColor: Colors.lightBlueAccent, 
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _saveSettings();
              },
              child: const Text("APPLY & SAVE"),
            ),
            const SizedBox(height: 20),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Temperature\nHigher is Creative"), subtitle: Text(_temperature.toStringAsFixed(1)), value: true, onChanged: (val) {},),
            Slider(value: _temperature, min: 0.0, max: 2.0, divisions: 20, activeColor: Colors.redAccent, onChanged: (val) => setState(() => _temperature = val),),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Grounding (Google Search)"), value: _enableGrounding, activeThumbColor: Colors.greenAccent, onChanged: (val) { setState(() => _enableGrounding = val); },),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Disable Safety Filters"), value: _disableSafety, activeThumbColor: Colors.redAccent, onChanged: (val) { setState(() => _disableSafety = val); },),
            
            const SizedBox(height: 50),
            const Divider(height: 30),
            
            const Text("Global Interface Font", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            Consumer<ThemeProvider>(
              builder: (context, provider, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12),),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true, value: provider.fontStyle, dropdownColor: const Color(0xFF2C2C2C), icon: const Icon(Icons.text_fields, color: Colors.cyanAccent),
                      items: const [
                        DropdownMenuItem(value: 'Default', child: Text("Default (System)")),
                        DropdownMenuItem(value: 'Google', child: Text("Google Sans (Open Sans)")),
                        DropdownMenuItem(value: 'Apple', child: Text("Apple SF (Inter)")),
                        DropdownMenuItem(value: 'Roleplay', child: Text("Storybook (Lora)")),
                        DropdownMenuItem(value: 'Terminal', child: Text("Hacker (Space Mono)")),
                      ],
                      onChanged: (String? newValue) { if (newValue != null) provider.setFont(newValue); },
                    ),
                  ),
                );
              },
            ),

            const Divider(),
            const Text("Chat Customization", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            Consumer<ThemeProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
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
                          Text("${(provider.userBubbleColor.a * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
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
                  ],
                );
              },
            ),
            const SizedBox(height: 10),

            const SizedBox(height: 20),
            const Divider(),
            const Text("Visuals & Atmosphere", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            Consumer<ThemeProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
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
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,),
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
                                  color: Colors.cyanAccent.withAlpha((0.1 * 255).round()),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.cyanAccent.withAlpha((0.5 * 255).round())),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center, 
                                  children: [Icon(Icons.add_photo_alternate, color: Colors.cyanAccent), Text("Add", style: TextStyle(fontSize: 10, color: Colors.cyanAccent))],
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
                                    decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent, width: 3), borderRadius: BorderRadius.circular(8), color: Colors.black26), 
                                    child: const Center(child: Icon(Icons.check_circle, color: Colors.cyanAccent)),
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
                      Slider(value: provider.backgroundOpacity, min: 0.0, max: 0.95, activeColor: Colors.cyanAccent, inactiveColor: Colors.grey[800], onChanged: (val) => provider.setBackgroundOpacity(val),),
                    ]
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      resizeToAvoidBottomInset: true, 
      drawer: _buildLeftDrawer(),
      endDrawer: _buildSettingsDrawer(),
      appBar: AppBar(
        backgroundColor: themeProvider.backgroundImagePath != null
          ? const Color(0xFFFFFFFF).withAlpha((0 * 255).round())
          : const Color(0xFF2C2C2C),
        leading: Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(c).openDrawer())),
        
        title: PopupMenuButton<AiProvider>(
          initialValue: _currentProvider,
          onSelected: (AiProvider result) {
            setState(() {
              _currentProvider = result;
              _updateApiKeyTextField(); 
              if (result == AiProvider.gemini) _initializeModel();
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to ${result.name.toUpperCase()}")));
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<AiProvider>>[
            const PopupMenuItem<AiProvider>(
              value: AiProvider.gemini,
              child: Row(children: [Icon(Icons.auto_awesome, color: Colors.blueAccent), SizedBox(width: 8), Text('AIRP - Gemini')]),
            ),
            const PopupMenuItem<AiProvider>(
              value: AiProvider.openRouter,
              child: Row(children: [Icon(Icons.router, color: Colors.purpleAccent), SizedBox(width: 8), Text('AIRP - OpenRouter')]),
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
                  'AIRP - ${_currentProvider == AiProvider.gemini ? "Gemini" : _currentProvider == AiProvider.openRouter ? "OpenRouter" : "OpenAI"}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down),
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
                const LinearProgressIndicator(color: Colors.cyanAccent, minHeight: 2),
              
              Container(
                padding: const EdgeInsets.all(8.0),
                color: const Color(0xFFFFFFFF).withAlpha((0.1 * 255).round()),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pendingImages.isNotEmpty)
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _pendingImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(File(_pendingImages[index]),
                                        width: 60, height: 60, fit: BoxFit.cover),
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
                          icon: const Icon(Icons.image, color: Colors.cyanAccent),
                          onPressed: _pickImage,
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
                              hintStyle: TextStyle(color: Colors.white),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none),
                              filled: true,
                              fillColor: const Color.fromARGB(255, 28, 57, 102),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                              backgroundColor: _enableGrounding
                                  ? Colors.green
                                  : Colors.cyanAccent),
                          onPressed: _isLoading ? null : _sendMessage,
                          icon: const Icon(Icons.send, color: Colors.black),
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

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> imagePaths; 
  final String? aiImage;
  final String? modelName;
  ChatMessage({
    required this.text, 
    required this.isUser,
    this.imagePaths = const [],
    this.aiImage,
    this.modelName,
    });

  Map<String, dynamic> toJson() => {
    'text': text, 
    'isUser': isUser,
    'imagePaths': imagePaths, 
    'aiImage': aiImage,
    'modelName': modelName,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'], 
    isUser: json['isUser'],
    imagePaths: List<String>.from(json['imagePaths'] ?? []), 
    aiImage: json['aiImage'],
    modelName: json['modelName'],
  );}


// ----------------------------------------------------------------------
// SYSTEM PROMPT DATA CLASS
// ----------------------------------------------------------------------
class SystemPromptData {
  final String title;
  final String content;

  SystemPromptData({required this.title, required this.content});

  Map<String, dynamic> toJson() => {'title': title, 'content': content};

  factory SystemPromptData.fromJson(Map<String, dynamic> json) {
    return SystemPromptData(
      title: json['title'] ?? "Untitled",
      content: json['content'] ?? "",
    );
  }
}


// ----------------------------------------------------------------------
// THEME PROVIDER
// ----------------------------------------------------------------------
class ThemeProvider extends ChangeNotifier {
  String _fontStyle = 'Default';
  String? _backgroundImagePath; 
  double _backgroundOpacity = 0.7;
  
  Color _userBubbleColor = Colors.cyanAccent.withAlpha((0.2 * 255).round());
  Color _userTextColor = Colors.white;
  Color _aiBubbleColor = const Color(0xFF2C2C2C).withAlpha((0.8 * 255).round());
  Color _aiTextColor = Colors.white;

  List<String> _customImagePaths = []; 

  String get fontStyle => _fontStyle;
  String? get backgroundImagePath => _backgroundImagePath;
  double get backgroundOpacity => _backgroundOpacity;
  List<String> get customImagePaths => _customImagePaths;
  
  Color get userBubbleColor => _userBubbleColor;
  Color get userTextColor => _userTextColor;
  Color get aiBubbleColor => _aiBubbleColor;
  Color get aiTextColor => _aiTextColor;

  ThemeProvider() {
    _loadPreferences();
  }

  ImageProvider get currentImageProvider {
    if (_backgroundImagePath == null) return const AssetImage(kDefaultBackground);
    if (_backgroundImagePath!.startsWith('assets/')) {
      return AssetImage(_backgroundImagePath!);
    } else {
      return FileImage(File(_backgroundImagePath!));
    }
  }

  TextTheme get currentTextTheme {
    const baseColor = Colors.white;
    final baseTheme = ThemeData.dark().textTheme.apply(bodyColor: baseColor, displayColor: baseColor);
    switch (_fontStyle) {
      case 'Google': return GoogleFonts.openSansTextTheme(baseTheme);
      case 'Apple': return GoogleFonts.interTextTheme(baseTheme);
      case 'Roleplay': return GoogleFonts.loraTextTheme(baseTheme);
      case 'Terminal': return GoogleFonts.spaceMonoTextTheme(baseTheme);
      default: return baseTheme;
    }
  }

  // --- Background Logic ---
  Future<void> setBackgroundImage(String? path) async { 
    _backgroundImagePath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('app_bg_path', path);
    } else {
      await prefs.remove('app_bg_path');
    }
  }

  Future<void> setBackgroundOpacity(double value) async {
    _backgroundOpacity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_bg_opacity', value);
  }

  Future<void> updateColor(String type, Color color) async {
    switch (type) {
      case 'userBubble': _userBubbleColor = color; break;
      case 'userText': _userTextColor = color; break;
      case 'aiBubble': _aiBubbleColor = color; break;
      case 'aiText': _aiTextColor = color; break;
    }
    notifyListeners();
    _saveColors();
  }

  Future<void> _saveColors() async {
    final prefs = await SharedPreferences.getInstance();
    final int ub = (((_userBubbleColor.a * 255.0).round() & 0xff) << 24) |
      (((_userBubbleColor.r * 255.0).round() & 0xff) << 16) |
      (((_userBubbleColor.g * 255.0).round() & 0xff) << 8) |
      ((_userBubbleColor.b * 255.0).round() & 0xff);
    await prefs.setInt('color_user_bubble', ub);

    final int ut = (((_userTextColor.a * 255.0).round() & 0xff) << 24) |
      (((_userTextColor.r * 255.0).round() & 0xff) << 16) |
      (((_userTextColor.g * 255.0).round() & 0xff) << 8) |
      ((_userTextColor.b * 255.0).round() & 0xff);
    await prefs.setInt('color_user_text', ut);

    final int ab = (((_aiBubbleColor.a * 255.0).round() & 0xff) << 24) |
      (((_aiBubbleColor.r * 255.0).round() & 0xff) << 16) |
      (((_aiBubbleColor.g * 255.0).round() & 0xff) << 8) |
      ((_aiBubbleColor.b * 255.0).round() & 0xff);
    await prefs.setInt('color_ai_bubble', ab);

    final int at = (((_aiTextColor.a * 255.0).round() & 0xff) << 24) |
      (((_aiTextColor.r * 255.0).round() & 0xff) << 16) |
      (((_aiTextColor.g * 255.0).round() & 0xff) << 8) |
      ((_aiTextColor.b * 255.0).round() & 0xff);
    await prefs.setInt('color_ai_text', at);
  }

  Future<void> addCustomImage(String path) async {
    if (!_customImagePaths.contains(path)) {
      _customImagePaths.add(path);
      notifyListeners();
      _saveCustomPaths();
    }
    setBackgroundImage(path);
  }

  Future<void> removeCustomImage(String path) async {
    if (_customImagePaths.contains(path)) {
      _customImagePaths.remove(path);
      if (_backgroundImagePath == path) _backgroundImagePath = null;
      notifyListeners();
      _saveCustomPaths();
    }
  }

  Future<void> _saveCustomPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('app_custom_bg_list', _customImagePaths);
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _fontStyle = prefs.getString('app_font_style') ?? 'Default';
    _backgroundImagePath = prefs.getString('app_bg_path');
    _backgroundOpacity = prefs.getDouble('app_bg_opacity') ?? 0.7;
    _customImagePaths = prefs.getStringList('app_custom_bg_list') ?? [];
    
    final int? userBubbleInt = prefs.getInt('color_user_bubble');
    if (userBubbleInt != null) {
      _userBubbleColor = Color(userBubbleInt);
    } else {
      _userBubbleColor = Colors.cyanAccent.withAlpha((0.2 * 255).round());
    }

    final int? userTextInt = prefs.getInt('color_user_text');
    _userTextColor = userTextInt != null ? Color(userTextInt) : Colors.white;

    final int? aiBubbleInt = prefs.getInt('color_ai_bubble');
    if (aiBubbleInt != null) {
      _aiBubbleColor = Color(aiBubbleInt);
    } else {
      _aiBubbleColor = const Color(0xFF2C2C2C).withAlpha((0.8 * 255).round());
    }

    final int? aiTextInt = prefs.getInt('color_ai_text');
    _aiTextColor = aiTextInt != null ? Color(aiTextInt) : Colors.white;
    
    notifyListeners();
  }

  Future<void> setFont(String fontName) async {
    _fontStyle = fontName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font_style', fontName);
  }
}

// ----------------------------------------------------------------------
// ASSET CONSTANTS
// ----------------------------------------------------------------------
const String kDefaultBackground = 'assets/default.jpg';

const List<String> kAssetBackgrounds = [
  'assets/bebe.jpg', 
  'assets/67_horror.jpg',
  'assets/Backrooms_2.jpg',
  'assets/beach_morning.jpg',
  'assets/beach_night.jpg',
  'assets/building.jpg',
  'assets/cafe.jpg',
  'assets/city.jpg',
  'assets/classroom_afternoon.jpg',
  'assets/classroom_morning.jpg',
  'assets/classroom_night.png',
  'assets/dark_hallway.jpg',
  'assets/default.jpg',
  'assets/du_street.jpg',
  'assets/gym_pool.jpg',
  'assets/halls.jpg',
  'assets/horror_dark.jpg',
  'assets/hoshinoBG.jpg',
  'assets/japan_river.jpg',
  'assets/judgement_hall.jpg',
  'assets/kivotos.png',
  'assets/military_park.jpg',
  'assets/minecraft_lake.jpg',
  'assets/sekiro.jpg',
  'assets/still_waters.jpg',
  'assets/trainer_office.jpg',
  'assets/turf.jpeg',
];

class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final ThemeProvider themeProvider;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.themeProvider,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = msg.isUser ? themeProvider.userBubbleColor : themeProvider.aiBubbleColor;
    final textColor = msg.isUser ? themeProvider.userTextColor : themeProvider.aiTextColor;
    final borderColor = msg.isUser ? themeProvider.userBubbleColor.withAlpha(128) : Colors.white10;

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- MODEL NAME DISPLAY ADDED HERE ---
              if (!msg.isUser && msg.modelName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      msg.modelName!,
                      style: TextStyle(
                        fontSize: 10, 
                        color: textColor.withOpacity(0.7), 
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace'
                      ),
                    ),
                  ),
                ),
              // --------------------------------------
              if (msg.imagePaths.isNotEmpty)
                _buildImageGrid(msg.imagePaths),
              if (msg.aiImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(base64Decode(msg.aiImage!), width: 250, fit: BoxFit.contain),
                  ),
                ),
              if (msg.text.isNotEmpty)
                MarkdownBody(
                  data: msg.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: textColor),
                    a: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline),
                    code: TextStyle(color: textColor, backgroundColor: Colors.black26),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> paths) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: paths.map((path) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(path), width: 150, height: 150, fit: BoxFit.cover),
        )).toList(),
      ),
    );
  }
}