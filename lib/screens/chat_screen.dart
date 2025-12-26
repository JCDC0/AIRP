import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/constants.dart';
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';
import '../widgets/message_bubble.dart';

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

  String _drawerSearchQuery = '';

  // LOADING STATES
  bool _isLoading = false;
  http.Client? _httpClient; 
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
  static const int _tokenLimitWarning = 190000;


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

    // 1. Kill HTTP Client (For Local, OpenRouter, Arli, Nano)
    try {
      _httpClient?.close();
      _httpClient = null;
    } catch (e) {
      debugPrint("Error closing client: $e");
    }

    // 2. Kill Gemini Stream
    if (_geminiSubscription != null) {
      await _geminiSubscription?.cancel();
      _geminiSubscription = null;
    }

    // 3. UI Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Generation Stopped & Saved (Connection Cut)"), 
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
      // Don't error out immediately, just warn
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
      // We slice the list to only take the last N messages
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
              // Merge Logic for Gemini SDK
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

// SEND BUTTON LOGIC ==================================================
  Future<void> _sendMessage() async {
    final messageText = _textController.text;
    if (messageText.isEmpty && _pendingImages.isEmpty) return;

    // 1. UI UPDATES
    final List<String> imagesToSend = List.from(_pendingImages);
    setState(() {
      _messages.add(ChatMessage(text: messageText, isUser: true, imagePaths: imagesToSend));
      _isLoading = true;
      _isCancelled = false;
      _httpClient = http.Client(); // New Client for this request
      _pendingImages.clear();
      _textController.clear();
    });
    _scrollToBottom();
    _autoSaveCurrentSession();

    // GROUNDING CHECK for GEMINI ONLY
    // We only hijack for Gemini because its streaming SDK doesn't handle grounding easily yet.
    // For OpenRouter, we use the integrated streaming + plugin approach.
    if (_enableGrounding && _currentProvider == AiProvider.gemini && imagesToSend.isEmpty) {
       try {
         final groundedText = await _performGroundedGeneration(messageText);
         if (_isCancelled) return; 
         setState(() {
           _messages.add(ChatMessage(text: groundedText ?? "Error", isUser: false, modelName: _selectedModel));
           _isLoading = false;
         });
         return; 
       } catch (e) {
         // Fallback if grounding fails
         debugPrint("Grounding failed, falling back to standard chat: $e");
       }
    }

    try {
      if (_currentProvider == AiProvider.gemini) {
        await _sendGeminiMessage(messageText, imagesToSend);
      } else if (_currentProvider == AiProvider.openRouter) {
        await _sendOpenRouterMessage(messageText, imagesToSend);
      } else if (_currentProvider == AiProvider.local) {
        await _sendLocalMessage(messageText, imagesToSend);
      } else if (_currentProvider == AiProvider.arliAi) {
        await _sendArliAiMessage(messageText, imagesToSend);
      } else if (_currentProvider == AiProvider.nanoGpt) {
        await _sendNanoGptMessage(messageText, imagesToSend);
      } else {
        setState(() => _isLoading = false);
      }
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

// GEMINI (Uses google_generative_ai package) ==================================
  // GEMINI (Streaming Implementation) ==================================
  Future<void> _sendGeminiMessage(String text, List<String> images) async {
    Content userContent;
    final List<Part> parts = [];
    String accumulatedText = text;

    // --- 1. PREPARE CONTENT (Same as before) ---
    if (images.isNotEmpty) {
      for (String path in images) {
        final String ext = path.split('.').last.toLowerCase();
        // Text Files
        if (['txt', 'md', 'json', 'dart', 'js', 'py', 'html', 'css', 'csv', 'c', 'cpp', 'java'].contains(ext)) {
          try {
            final String fileContent = await File(path).readAsString();
            accumulatedText += "\n\n--- Attached File: ${path.split('/').last} ---\n$fileContent\n--- End File ---\n";
          } catch (e) { debugPrint("Error reading text file: $e"); }
        } 
        // Binary Files
        else {
          final bytes = await File(path).readAsBytes();
          String? mimeType;
          if (['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'].contains(ext)) {
            mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
          } else if (ext == 'pdf') mimeType = 'application/pdf';
          if (mimeType != null) parts.add(DataPart(mimeType, bytes));
        }
      }
    }

    if (accumulatedText.isNotEmpty) parts.insert(0, TextPart(accumulatedText));
    userContent = parts.isNotEmpty ? Content.multi(parts) : Content.text(accumulatedText);

    // --- 3. STREAMING LOGIC ---
    try {
      // A. Create a placeholder message for the AI response
      setState(() {
        _messages.add(ChatMessage(
          text: "", // Start empty
          isUser: false, 
          modelName: _selectedModel,
          aiImage: null 
        ));
      });

      // B. Start the stream
      final stream = _chat.sendMessageStream(userContent);
      
      String fullResponseText = "";

      _geminiSubscription = stream.listen(
        (response) {
          // This runs every time a chunk of text arrives
          final textChunk = response.text;
          if (textChunk != null) {
            fullResponseText += textChunk;
            setState(() {
              // Update the LAST message (the placeholder we made)
              _messages.last = ChatMessage(
                text: fullResponseText,
                isUser: false,
                modelName: _selectedModel,
              );
            });
            // Auto-scroll slightly to keep up
            if (_scrollController.hasClients && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
               _scrollToBottom();
            }
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
          // Stream finished successfully
          if (!_isCancelled) {
             setState(() => _isLoading = false);
             _geminiSubscription = null;
             await _initializeModel(); // Refresh context
             _autoSaveCurrentSession();
             if (!_enableGrounding) _updateTokenCount();
          }
        },
      );

    } catch (e) {
      if (!_isCancelled) {
         setState(() {
          _messages.add(ChatMessage(text: "System Error: $e", isUser: false, modelName: "System"));
          _isLoading = false;
        });
      }
    }
  }

  // ----------------------------------------------------------------------
  // OPENROUTER (STREAMING & GROUNDING)
  // ----------------------------------------------------------------------
  Future<void> _sendOpenRouterMessage(String text, List<String> images) async {
    final cleanKey = _openRouterKey.trim();
    if (cleanKey.isEmpty) throw Exception("OpenRouter Key is empty!");

    // 1. Setup Placeholder Message for Streaming
    setState(() {
      _messages.add(ChatMessage(
        text: "", // Start empty
        isUser: false, 
        modelName: _openRouterModel
      ));
    });

    // 2. Build Payload
    List<Map<String, dynamic>> messagesPayload = [];
    if (_systemInstructionController.text.isNotEmpty) {
      messagesPayload.add({"role": "system", "content": _systemInstructionController.text});
    }
    
    final validHistory = _messages.take(_messages.length - 2).toList();
    
    int skipCount = validHistory.length - _historyLimit;
    if (skipCount < 0) skipCount = 0;
    
    final truncatedHistory = validHistory.skip(skipCount).toList();
    // History
    for (var msg in truncatedHistory) {
      messagesPayload.add({
        "role": msg.isUser ? "user" : "assistant", 
        "content": msg.text
      });
    }
    // Current User Message (Text + Image)
    if (images.isEmpty) {
      messagesPayload.add({"role": "user", "content": text});
    } else {
      List<Map<String, dynamic>> contentParts = [];
      if (text.isNotEmpty) contentParts.add({"type": "text", "text": text});
      for (String path in images) {
        final bytes = await File(path).readAsBytes();
        final base64Img = base64Encode(bytes);
        // Note: OpenRouter supports standard openai image_url format
        contentParts.add({
          "type": "image_url", 
          "image_url": {"url": "data:image/jpeg;base64,$base64Img"}
        });
      }
      messagesPayload.add({"role": "user", "content": contentParts});
    }

    // 3. Prepare Request (Use http.Request for streaming)
    final request = http.Request('POST', Uri.parse("https://openrouter.ai/api/v1/chat/completions"));
    
    request.headers.addAll({
      "Authorization": "Bearer $cleanKey",
      "Content-Type": "application/json",
      "HTTP-Referer": "https://airp-chat.com",
      "X-Title": "AIRP Chat",
    });

    final bodyMap = {
      "model": _openRouterModel.trim(),
      "messages": messagesPayload,
      "temperature": _temperature,
      "stream": true,
      "top_p": _topP,
      "top_k": _topK,
      "max_tokens": _maxOutputTokens, 
    };

    // --- GROUNDING LOGIC FOR OPENROUTER ---
    if (_enableGrounding) {
      bodyMap["plugins"] = ["web_search"]; 
    }

    request.body = jsonEncode(bodyMap);

    try {
      // 4. Send & Listen
      _httpClient ??= http.Client();
      final streamedResponse = await _httpClient!.send(request);

      if (streamedResponse.statusCode != 200) {
        // Read error from stream
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception("Error ${streamedResponse.statusCode}: $errorBody");
      }

      // 5. Process Stream
      String fullResponseText = "";
      
      // Listen to the byte stream, decode to UTF8, split by lines
      await streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
            
        if (_isCancelled) return; // Stop processing if cancelled

        // OpenAI Stream format: "data: {JSON}"
        if (line.startsWith("data: ")) {
          final dataStr = line.substring(6).trim(); // Remove "data: "
          if (dataStr == "[DONE]") return; // End of stream

          try {
            final json = jsonDecode(dataStr);
            final choices = json['choices'] as List;
            if (choices.isNotEmpty) {
              final delta = choices[0]['delta'];
              if (delta != null && delta['content'] != null) {
                final contentChunk = delta['content'].toString();
                
                fullResponseText += contentChunk;

                // Update UI incrementally
                setState(() {
                  _messages.last = ChatMessage(
                    text: fullResponseText, 
                    isUser: false, 
                    modelName: _openRouterModel
                  );
                });

                // Auto Scroll
                if (_scrollController.hasClients && 
                    _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
                   _scrollToBottom();
                }
              }
            }
          } catch (e) {
            // Ignore parse errors for partial chunks
          }
        }
      }).asFuture();

      // Done
      if (!_isCancelled) {
        setState(() => _isLoading = false);
        _autoSaveCurrentSession();
      }

    } catch (e) {
      if (!_isCancelled) {
        setState(() {
          _messages.last = ChatMessage(
            text: "**Stream Error**\n$e",
            isUser: false,
            modelName: "System Alert"
          );
          _isLoading = false;
        });
      }
    }
  }

  // ----------------------------------------------------------------------
  // ARLI AI IMPLEMENTATION
  // ----------------------------------------------------------------------
  Future<void> _sendArliAiMessage(String text, List<String> images) async {
    final cleanKey = _arliAiKey.trim();
    if (cleanKey.isEmpty) throw Exception("ArliAI Key is empty!");
    
    // (You can implement similar streaming logic here as OpenRouter if desired, 
    // for now sticking to the original blocking post for Arli/Nano unless you request it).

    List<Map<String, dynamic>> messagesPayload = [];
    if (_systemInstructionController.text.isNotEmpty) {
      messagesPayload.add({"role": "system", "content": _systemInstructionController.text});
    }

    // 1. Calculate History (No placeholder exists yet, so we just remove the last one which is the User Message)
    final validHistory = _messages.take(_messages.length - 1).toList(); 
    
    int skipCount = validHistory.length - _historyLimit;
    if (skipCount < 0) skipCount = 0;
    
    final truncatedHistory = validHistory.skip(skipCount).toList();

    for (var msg in truncatedHistory) {
      messagesPayload.add({"role": msg.isUser ? "user" : "assistant", "content": msg.text});
    }
    
    messagesPayload.add({"role": "user", "content": text});

    final response = await _httpClient!.post(
      Uri.parse("https://api.arliai.com/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer $cleanKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": _arliAiModel,
        "messages": messagesPayload,
        "temperature": _temperature,
        "top_p": _topP,
        "top_k": _topK,
        "max_tokens": _maxOutputTokens,
        "stream": false, 
      }),
    );

    if (_isCancelled) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final String aiText = data['choices'][0]['message']['content'];
      setState(() {
        _messages.add(ChatMessage(text: aiText, isUser: false, modelName: _arliAiModel));
        _isLoading = false;
      });
      _autoSaveCurrentSession();
    } else {
      throw Exception("ArliAI Error: ${response.statusCode} - ${response.body}");
    }
  }

  // ----------------------------------------------------------------------
  // NANOGPT IMPLEMENTATION
  // ----------------------------------------------------------------------
  Future<void> _sendNanoGptMessage(String text, List<String> images) async {
    final cleanKey = _nanoGptKey.trim();
    if (cleanKey.isEmpty) throw Exception("NanoGPT Key is empty!");

    List<Map<String, dynamic>> messagesPayload = [];
    if (_systemInstructionController.text.isNotEmpty) {
      messagesPayload.add({"role": "system", "content": _systemInstructionController.text});
    }

    // 1. Calculate History (No placeholder exists yet, so we just remove the last one which is the User Message)
    final validHistory = _messages.take(_messages.length - 1).toList(); 
    
    int skipCount = validHistory.length - _historyLimit;
    if (skipCount < 0) skipCount = 0;
    
    final truncatedHistory = validHistory.skip(skipCount).toList();

    for (var msg in truncatedHistory) {
      messagesPayload.add({"role": msg.isUser ? "user" : "assistant", "content": msg.text});
    }

    final response = await _httpClient!.post(
      Uri.parse("https://nano-gpt.com/api/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer $cleanKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": _nanoGptModel,
        "messages": messagesPayload,
        "temperature": _temperature,
        "top_p": _topP,
        "top_k": _topK,
        "max_tokens": _maxOutputTokens, 
      }),
    );

    if (_isCancelled) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final String aiText = data['choices'][0]['message']['content'];
      setState(() {
        _messages.add(ChatMessage(text: aiText, isUser: false, modelName: _nanoGptModel));
        _isLoading = false;
      });
      _autoSaveCurrentSession();
    } else {
      throw Exception("NanoGPT Error: ${response.statusCode} - ${response.body}");
    }
  }

  // UPDATED LOCAL MESSAGE (Uses _httpClient) 
  Future<void> _sendLocalMessage(String text, List<String> images) async {
    String baseUrl = _localIpController.text.trim();
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);

    if (!baseUrl.endsWith('/chat/completions')) {
      if (baseUrl.endsWith('/v1')) {
        baseUrl += "/chat/completions";
      } else {
        baseUrl += "/v1/chat/completions";
      }
    }

    List<Map<String, dynamic>> messagesPayload = [];
    if (_systemInstructionController.text.isNotEmpty) {
      messagesPayload.add({"role": "system", "content": _systemInstructionController.text});
    }
    // 1. Calculate History (No placeholder exists yet, so we just remove the last one which is the User Message)
    final validHistory = _messages.take(_messages.length - 1).toList(); 
    
    int skipCount = validHistory.length - _historyLimit;
    if (skipCount < 0) skipCount = 0;
    
    final truncatedHistory = validHistory.skip(skipCount).toList();

    for (var msg in truncatedHistory) {
      messagesPayload.add({"role": msg.isUser ? "user" : "assistant", "content": msg.text});
    }
    
    if (images.isEmpty) {
      messagesPayload.add({"role": "user", "content": text});
    } else {
      List<Map<String, dynamic>> contentParts = [];
      if (text.isNotEmpty) contentParts.add({"type": "text", "text": text});
      for (String path in images) {
        final bytes = await File(path).readAsBytes();
        final base64Img = base64Encode(bytes);
        contentParts.add({"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,$base64Img"}});
      }
      messagesPayload.add({"role": "user", "content": contentParts});
    }
    final response = await _httpClient!.post(
      Uri.parse(baseUrl),
      headers: { "Content-Type": "application/json", "Authorization": "Bearer local-key" },
      body: jsonEncode({
        "model": _localModelName,
        "messages": messagesPayload,
        "temperature": _temperature,
        "top_p": _topP,
        "top_k": _topK,
        "max_tokens": _maxOutputTokens, 
        "stream": false,
      }),
    );

    if (_isCancelled) return; 

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      String aiText = '';
      if (data['choices'] != null && data['choices'] is List && data['choices'].isNotEmpty) {
        final choice = data['choices'][0];
        if (choice['message'] != null && choice['message']['content'] != null) {
          aiText = choice['message']['content'].toString();
        } else if (choice['text'] != null) {
          aiText = choice['text'].toString();
        }
      } else if (data['message'] != null) {
        aiText = data['message'].toString();
      }
      setState(() {
        _messages.add(ChatMessage(text: aiText, isUser: false, modelName: "Local AI"));
        _isLoading = false;
      });
      _autoSaveCurrentSession();
    } else {
      throw Exception("Local AI Error: ${response.statusCode} - ${response.body}");
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
        headers: {"Authorization": "Bearer ${_arliAiKey.trim()}"}, // Fixed: Trim key
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.cyanAccent),
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

  // COLOR PICKER WIDGET =================================
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

  // COLOR PICKER DIALOG =================================
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
    
    // For simplicity/safety, let's only allow regenerating the LAST AI message for now.
    // Or if the user clicks their own last message.
    
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
                      cleanModelName(session.modelName), 
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
                        else if (session.provider == 'local') {
                          _currentProvider = AiProvider.local;
                          _selectedModel = "Local Network AI";
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

                      Navigator.pop(context);
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

  Widget _buildSettingsDrawer() {
    return Drawer(
      width: 320,
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
            child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text("Main Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text("v0.1.9.1", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const Divider(),
            const SizedBox(height: 10),

            const Text("API Key (BYOK)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            const SizedBox(height: 5),
            // --- UPDATED API KEY / IP FIELD SECTION ---
                        if (_currentProvider != AiProvider.local) ...[
              TextField(
                controller: _apiKeyController,
                onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: "Paste AI Studio Key...",
                  border: OutlineInputBorder(),
                  filled: true, isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),
            ] else ...[
                            // LOCAL IP INPUT
              TextField(
                controller: _localIpController,
                onChanged: (_) => setState(() => _hasUnsavedChanges = true),
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
                                onChanged: (val) => setState(() => _hasUnsavedChanges = true),
              ),
            ),
            const SizedBox(height: 20),

            const Text("Model Selection", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),

            // ============================================
            // GEMINI UI
            // ============================================
            if (_currentProvider == AiProvider.gemini) ...[
              if (_geminiModelsList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C2C2C),
                      value: _geminiModelsList.contains(_selectedGeminiModel) ? _selectedGeminiModel : null,
                      hint: Text(cleanModelName(_selectedGeminiModel), style: const TextStyle(color: Colors.white)),
                      items: _geminiModelsList.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(cleanModelName(value), style: const TextStyle(fontSize: 13, color: Colors.white)),
                        );
                      }).toList(),
                                            onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() { 
                            _selectedGeminiModel = newValue; 
                            _selectedModel = newValue; 
                            _hasUnsavedChanges = true;
                          });
                        }
                      },
                    ),
                  ),
                )
              else
              // Fallback Text Field if list is empty/error
                                TextField(
                  decoration: const InputDecoration(hintText: "models/gemini-flash-lite-latest", border: OutlineInputBorder(), isDense: true),
                  onChanged: (val) => setState(() { _selectedGeminiModel = val; _hasUnsavedChanges = true; }),
                  controller: TextEditingController(text: _selectedGeminiModel),
                ),

              const SizedBox(height: 8),
              // REFRESH BUTTON
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _isLoadingGeminiModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(_isLoadingGeminiModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: _isLoadingGeminiModels ? null : _fetchGeminiModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
                ),
              ),
            ]

            // ============================================
            // OPENROUTER UI
            // ============================================
            else if (_currentProvider == AiProvider.openRouter) ...[
              if (_openRouterModelsList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C2C2C),
                      value: _openRouterModelsList.contains(_openRouterModel) ? _openRouterModel : null,
                      hint: Text(cleanModelName(_openRouterModel), style: const TextStyle(color: Colors.white)),
                      items: _openRouterModelsList.map((String id) {
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(cleanModelName(id), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.white)),
                        );
                      }).toList(),
                                            onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _openRouterModel = newValue;
                            _openRouterModelController.text = newValue;
                            _hasUnsavedChanges = true;
                          });
                        }
                      },
                    ),
                  ),
                )
              else
                                TextField(
                  controller: _openRouterModelController,
                  decoration: const InputDecoration(hintText: "vendor/model-name", border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) { setState(() { _openRouterModel = val.trim(); _hasUnsavedChanges = true; }); },
                ),

              const SizedBox(height: 8),
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _isLoadingOpenRouterModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(_isLoadingOpenRouterModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: _isLoadingOpenRouterModels ? null : _fetchOpenRouterModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.purpleAccent),
                ),
              ),
            ],
            // -------------------------------------------
            // LOCAL UI
            // -------------------------------------------
                        if (_currentProvider == AiProvider.local) ...[
               const SizedBox(height: 5),
               TextField(
                 onChanged: (val) => setState(() { _localModelName = val; _hasUnsavedChanges = true; }),
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
            if (_currentProvider == AiProvider.arliAi) ...[
              if (_arliAiModelsList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C2C2C),
                      value: _arliAiModelsList.contains(_arliAiModel) ? _arliAiModel : null,
                      hint: Text(cleanModelName(_arliAiModel), style: const TextStyle(color: Colors.white)),
                      items: _arliAiModelsList.map((String id) {
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(cleanModelName(id), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.white)),
                        );
                      }).toList(),
                                            onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _arliAiModel = newValue;
                            _selectedModel = newValue;
                            _hasUnsavedChanges = true;
                          });
                        }
                      },
                    ),
                  ),
                )
              else
                // Fallback TextField if list is empty
                                TextField(
                  controller: TextEditingController(text: _arliAiModel),
                  decoration: const InputDecoration(hintText: "Gemma-3-27B-Big-Tiger-v3", border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) { setState(() { _arliAiModel = val.trim(); _hasUnsavedChanges = true; }); },
                ),

              const SizedBox(height: 8),
              
              // REFRESH BUTTON
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _isLoadingArliAiModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(_isLoadingArliAiModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: _isLoadingArliAiModels ? null : _fetchArliAiModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent),
                ),
              ),
            ],

            // ============================================
            // NANOGPT UI
            // ============================================
            if (_currentProvider == AiProvider.nanoGpt) ...[
              if (_nanoGptModelsList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C2C2C),
                      value: _nanoGptModelsList.contains(_nanoGptModel) ? _nanoGptModel : null,
                      hint: Text(cleanModelName(_nanoGptModel), style: const TextStyle(color: Colors.white)),
                      items: _nanoGptModelsList.map((String id) {
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(cleanModelName(id), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.white)),
                        );
                      }).toList(),
                                            onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _nanoGptModel = newValue;
                            _selectedModel = newValue;
                            _hasUnsavedChanges = true;
                          });
                        }
                      },
                    ),
                  ),
                )
              else
                // Fallback TextField
                                TextField(
                  controller: TextEditingController(text: _nanoGptModel),
                  decoration: const InputDecoration(hintText: "aion-labs/aion-rp-llama-3.1-8b", border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) { setState(() { _nanoGptModel = val.trim(); _hasUnsavedChanges = true; }); },
                ),

              const SizedBox(height: 8),
              
              // REFRESH BUTTON
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _isLoadingNanoGptModels 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.cloud_sync, size: 16),
                  label: Text(_isLoadingNanoGptModels ? "Fetching..." : "Refresh Model List"),
                  onPressed: _isLoadingNanoGptModels ? null : _fetchNanoGptModels,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.yellowAccent),
                ),
              ),
            ],

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
                        _hasUnsavedChanges = true;
                      });
                    } else if (newValue != null) {
                      final prompt = _savedSystemPrompts.firstWhere((p) => p.title == newValue);
                      setState(() {
                        _promptTitleController.text = prompt.title;
                        _systemInstructionController.text = prompt.content;
                        _hasUnsavedChanges = true;
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
              onChanged: (_) => setState(() => _hasUnsavedChanges = true),
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
              onChanged: (_) => setState(() => _hasUnsavedChanges = true),
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
            
            // --- TEMPERATURE ---
            _buildSliderSetting(
              title: "Temperature (Creativity)",
              value: _temperature,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              activeColor: Colors.redAccent,
              onChanged: (val) => setState(() { _temperature = val; _hasUnsavedChanges = true; }),
            ),

            // --- TOP P ---
            _buildSliderSetting(
              title: "Top P (Nucleus Sampling)",
              value: _topP,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              activeColor: Colors.purpleAccent,
              onChanged: (val) => setState(() { _topP = val; _hasUnsavedChanges = true; }),
            ),

            // --- TOP K ---
            _buildSliderSetting(
              title: "Top K (Vocabulary Size)",
              value: _topK.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              activeColor: Colors.orangeAccent,
              isInt: true,
              onChanged: (val) => setState(() { _topK = val.toInt(); _hasUnsavedChanges = true; }),
            ),

            // --- MAX OUTPUT TOKENS ---
            _buildSliderSetting(
              title: "Max Output Tokens",
              value: _maxOutputTokens.toDouble(),
              min: 256,
              max: 32768, // User defined limit
              // Removed divisions for smoother sliding on large range
              activeColor: Colors.blueAccent,
              isInt: true,
              onChanged: (val) => setState(() { _maxOutputTokens = val.toInt(); _hasUnsavedChanges = true; }),
            ),

            // --- CONTEXT HISTORY LIMIT ---
            const Divider(),
            _buildSliderSetting(
              title: "(Msg History) Limit",
              value: _historyLimit.toDouble(),
              min: 2,
              max: 1000,
              divisions: 499,
              activeColor: Colors.greenAccent,
              isInt: true,
              onChanged: (val) => setState(() { _historyLimit = val.toInt(); _hasUnsavedChanges = true; }),
            ),
            const Text(
              "Note: Lower this if you get 'Context Window Exceeded' errors.",
              style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const Divider(),

            // --- GROUNDING SWITCH ---
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Grounding / Web Search"),
              subtitle: Text(
                _currentProvider == AiProvider.gemini ? "Uses Google Search (Native)" 
                : _currentProvider == AiProvider.openRouter ? "Try OpenRouter Web Plugin"
                : "Not available on this provider",
                style: const TextStyle(fontSize: 10, color: Colors.grey)
              ),
              value: _enableGrounding,
              activeThumbColor: Colors.greenAccent,
              // Disable if not Gemini OR OpenRouter
                            onChanged: (_currentProvider == AiProvider.gemini || _currentProvider == AiProvider.openRouter)
                  ? (val) { setState(() { _enableGrounding = val; _hasUnsavedChanges = true; }); }
                  : null, 
            ),

            // --- SAFETY FILTERS (Conditional Visibility) ---
            // Only show for Gemini, as it's the only one with explicit client-side safety toggles
            if (_currentProvider == AiProvider.gemini)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Disable Safety Filters"), 
                subtitle: const Text("Applies to Gemini Only", style: TextStyle(fontSize: 10, color: Colors.grey)),
                value: _disableSafety, 
                activeThumbColor: Colors.redAccent, 
                onChanged: (val) { setState(() { _disableSafety = val; _hasUnsavedChanges = true; }); },
              ),
            
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
          if (_hasUnsavedChanges)
            Positioned(
              bottom: 30,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                onPressed: _saveSettings,
                child: const Icon(Icons.save),
              ),
            ),
        ],
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
          : const Color.fromARGB(255, 0, 0, 0),
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
              value: AiProvider.arliAi,
              child: Row(children: [Icon(Icons.alternate_email, color: Colors.orangeAccent), SizedBox(width: 8), Text('AIRP - ArliAI')]),
            ),
            const PopupMenuItem<AiProvider>(
              value: AiProvider.nanoGpt,
              child: Row(children: [Icon(Icons.bolt, color: Colors.yellowAccent), SizedBox(width: 8), Text('AIRP - NanoGPT')]),
            ),
            const PopupMenuItem<AiProvider>(
              value: AiProvider.local,
              child: Row(children: [Icon(Icons.laptop_mac, color: Colors.greenAccent), SizedBox(width: 8), Text('AIRP - Local')]),
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
                  // FIXED: Added checks for ArliAI and NanoGPT
                  'AIRP - ${_currentProvider == AiProvider.gemini ? "Gemini" 
                      : _currentProvider == AiProvider.openRouter ? "OpenRouter" 
                      : _currentProvider == AiProvider.arliAi ? "ArliAI"
                      : _currentProvider == AiProvider.nanoGpt ? "NanoGPT"
                      : _currentProvider == AiProvider.local ? "Local" 
                      : "OpenAI"}',
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
                        // MERGED ATTACHMENT BUTTON
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.cyanAccent),
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
                        IconButton.filled(
                          style: IconButton.styleFrom(
                              backgroundColor: _isLoading
                                 ? Colors.cyanAccent.withOpacity(0.2) 
                                 : (_enableGrounding ? Colors.green : Colors.cyanAccent)
                          ),
                          // Toggle Function: Send if idle, Stop if loading
                          onPressed: _isLoading ? _cancelGeneration : _sendMessage,
                          // Toggle Icon: Stop Square if loading, Send Plane if idle
                          icon: Icon(
                            _isLoading ? Icons.stop_circle_outlined : Icons.send,
                             color: _isLoading ? Colors.cyanAccent : Colors.black
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