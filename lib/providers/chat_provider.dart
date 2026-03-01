import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../models/character_card.dart';
import '../models/formatting_models.dart';
import '../models/lorebook_models.dart';
import '../models/regex_models.dart';
import '../services/chat_api_service.dart';
import '../services/lorebook_service.dart';
import '../services/macro_service.dart';
import '../services/prompt_pipeline_service.dart';
import '../services/regex_service.dart';
import '../services/secure_storage_service.dart';
import '../services/web_search_service.dart';
import '../utils/constants.dart';

/// Central provider for managing chat state, API communication, and settings.
///
/// This class handles session persistence, model configuration for multiple
/// AI providers (Gemini, OpenRouter, OpenAI, etc.), and coordinates the
/// streaming of chat responses.
class ChatProvider extends ChangeNotifier {
  // --- Background stream infrastructure ---
  final Map<String, StreamSubscription> _activeStreams = {};
  final Map<String, ValueNotifier<String>> _activeNotifiers = {};
  final Map<String, String> _activeStreamTexts = {};
  final Map<String, String> _activeStreamModels = {};
  final Set<String> _cancelledSessions = {};
  bool _nonStreamingLoading = false;
  Timer? _autoSaveTimer;

  /// Stores regenerated versions to attach to the next generated message.
  List<String> _pendingRegenerationVersions = [];

  bool get isLoading =>
      _activeStreams.containsKey(_currentSessionId) || _nonStreamingLoading;
  bool get isCancelled => _cancelledSessions.contains(_currentSessionId);

  /// Set of session IDs that currently have an active background stream.
  Set<String> get streamingSessionIds => _activeStreams.keys.toSet();

  /// Pending background notifications for completed responses.
  final List<BackgroundNotification> _pendingNotifications = [];
  List<BackgroundNotification> get pendingNotifications =>
      _pendingNotifications;

  void removeNotification(int index) {
    if (index >= 0 && index < _pendingNotifications.length) {
      _pendingNotifications.removeAt(index);
      notifyListeners();
    }
  }

  List<ModelInfo> _geminiModelsList = [];
  List<ModelInfo> _openRouterModelsList = [];
  List<ModelInfo> _arliAiModelsList = [];
  List<ModelInfo> _nanoGptModelsList = [];
  List<ModelInfo> _openAiModelsList = [];
  List<ModelInfo> _huggingFaceModelsList = [];
  List<ModelInfo> _groqModelsList = [];

  List<ModelInfo> get geminiModelsList => _geminiModelsList;
  List<ModelInfo> get openRouterModelsList => _openRouterModelsList;
  List<ModelInfo> get arliAiModelsList => _arliAiModelsList;
  List<ModelInfo> get nanoGptModelsList => _nanoGptModelsList;
  List<ModelInfo> get openAiModelsList => _openAiModelsList;
  List<ModelInfo> get huggingFaceModelsList => _huggingFaceModelsList;
  List<ModelInfo> get groqModelsList => _groqModelsList;

  bool _isLoadingGeminiModels = false;
  bool _isLoadingOpenRouterModels = false;
  bool _isLoadingArliAiModels = false;
  bool _isLoadingNanoGptModels = false;
  bool _isLoadingOpenAiModels = false;
  bool _isLoadingHuggingFaceModels = false;
  bool _isLoadingGroqModels = false;

  bool get isLoadingGeminiModels => _isLoadingGeminiModels;
  bool get isLoadingOpenRouterModels => _isLoadingOpenRouterModels;
  bool get isLoadingArliAiModels => _isLoadingArliAiModels;
  bool get isLoadingNanoGptModels => _isLoadingNanoGptModels;
  bool get isLoadingOpenAiModels => _isLoadingOpenAiModels;
  bool get isLoadingHuggingFaceModels => _isLoadingHuggingFaceModels;
  bool get isLoadingGroqModels => _isLoadingGroqModels;

  bool get isRefreshingModels =>
      _isLoadingGeminiModels ||
      _isLoadingOpenRouterModels ||
      _isLoadingArliAiModels ||
      _isLoadingNanoGptModels ||
      _isLoadingOpenAiModels ||
      _isLoadingHuggingFaceModels ||
      _isLoadingGroqModels;

  AiProvider _currentProvider = AiProvider.gemini;
  String _geminiKey = '';
  String _openRouterKey = '';
  String _openAiKey = '';
  String _arliAiKey = '';
  String _nanoGptKey = '';
  String _huggingFaceKey = '';
  String _groqKey = '';
  String _localIp = ChatDefaults.localIp;
  String _localModelName = 'local-model';

  AiProvider get currentProvider => _currentProvider;
  String get geminiKey => _geminiKey;
  String get openRouterKey => _openRouterKey;
  String get openAiKey => _openAiKey;
  String get arliAiKey => _arliAiKey;
  String get nanoGptKey => _nanoGptKey;
  String get huggingFaceKey => _huggingFaceKey;
  String get groqKey => _groqKey;
  String get localIp => _localIp;
  String get localModelName => _localModelName;

  String _selectedGeminiModel = 'models/gemini-3-flash-preview';
  String _openRouterModel = 'z-ai/glm-4.5-air:free';
  String _arliAiModel = 'Mistral-Nemo-12B-Instruct-v1';
  String _nanoGptModel = 'gpt-4o';
  String _openAiModel = 'gpt-4o';
  String _huggingFaceModel = 'meta-llama/Meta-Llama-3-8B-Instruct';
  String _groqModel = 'llama3-8b-8192';
  String _selectedModel = 'models/gemini-3-flash-preview';

  String get selectedGeminiModel => _selectedGeminiModel;
  String get openRouterModel => _openRouterModel;
  String get arliAiModel => _arliAiModel;
  String get nanoGptModel => _nanoGptModel;
  String get openAiModel => _openAiModel;
  String get huggingFaceModel => _huggingFaceModel;
  String get groqModel => _groqModel;
  String get selectedModel => _selectedModel;

  /// Returns the maximum context length for the currently selected model.
  int getMaxContext() {
    List<ModelInfo> currentList = [];
    String currentId = "";

    switch (_currentProvider) {
      case AiProvider.gemini:
        currentList = _geminiModelsList;
        currentId = _selectedGeminiModel;
        break;
      case AiProvider.openRouter:
        currentList = _openRouterModelsList;
        currentId = _openRouterModel;
        break;
      case AiProvider.arliAi:
        currentList = _arliAiModelsList;
        currentId = _arliAiModel;
        break;
      case AiProvider.nanoGpt:
        currentList = _nanoGptModelsList;
        currentId = _nanoGptModel;
        break;
      case AiProvider.openAi:
        currentList = _openAiModelsList;
        currentId = _openAiModel;
        break;
      case AiProvider.huggingFace:
        currentList = _huggingFaceModelsList;
        currentId = _huggingFaceModel;
        break;
      case AiProvider.groq:
        currentList = _groqModelsList;
        currentId = _groqModel;
        break;
      case AiProvider.local:
        return 32768; // Default for local
    }

    try {
      final model = currentList.firstWhere((m) => m.id == currentId);
      return int.tryParse(model.contextLength.replaceAll(',', '')) ?? 1048576;
    } catch (_) {
      return 1048576; // Default fallback
    }
  }

  /// Formats a string with commas for readability (e.g., 1000000 -> 1,000,000).
  String formatNumber(String s) {
    int? n = int.tryParse(s.replaceAll(',', ''));
    if (n == null) return s;
    String str = n.toString();
    String res = "";
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      res = str[i] + res;
      count++;
      if (count % 3 == 0 && i != 0) {
        res = ",$res";
      }
    }
    return res;
  }

  double _temperature = ChatDefaults.temperature;
  double _topP = ChatDefaults.topP;
  int _topK = ChatDefaults.topK;
  int _maxOutputTokens = ChatDefaults.maxOutputTokens;
  int _historyLimit = ChatDefaults.historyLimit;
  bool _enableGrounding = false;
  bool _enableImageGen = false;
  bool _enableUsage = false;
  bool _disableSafety = true;
  String _reasoningEffort = "none";

  // Web Search (BYOK)
  SearchProvider _searchProvider = SearchProvider.provider;
  String _braveApiKey = '';
  String _tavilyApiKey = '';
  String _serperApiKey = '';
  String _searxngUrl = '';
  int _searchResultCount = 5;

  bool _enableSystemPrompt = true;
  bool _enableAdvancedSystemPrompt = true;
  bool _enableCharacterCard = true;
  bool _enableMsgHistory = true;
  bool _enableReasoning = false;
  bool _enableGenerationSettings = true;
  bool _enableMaxOutputTokens = true;

  // --- Lorebook / Regex / Formatting state ---
  Lorebook _globalLorebook = Lorebook(name: 'Global');
  List<RegexScript> _globalRegexScripts = [];
  FormattingTemplate? _formattingTemplate;
  bool _enableLorebook = true;
  bool _enableRegex = true;
  bool _enableFormatting = false;

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

  // Web Search (BYOK)
  SearchProvider get searchProvider => _searchProvider;
  String get braveApiKey => _braveApiKey;
  String get tavilyApiKey => _tavilyApiKey;
  String get serperApiKey => _serperApiKey;
  String get searxngUrl => _searxngUrl;
  int get searchResultCount => _searchResultCount;

  bool get enableSystemPrompt => _enableSystemPrompt;
  bool get enableAdvancedSystemPrompt => _enableAdvancedSystemPrompt;
  bool get enableCharacterCard => _enableCharacterCard;
  bool get enableMsgHistory => _enableMsgHistory;
  bool get enableReasoning => _enableReasoning;
  bool get enableGenerationSettings => _enableGenerationSettings;
  bool get enableMaxOutputTokens => _enableMaxOutputTokens;

  // --- Lorebook / Regex / Formatting getters ---
  Lorebook get globalLorebook => _globalLorebook;
  List<RegexScript> get globalRegexScripts => _globalRegexScripts;
  FormattingTemplate? get formattingTemplate => _formattingTemplate;
  bool get enableLorebook => _enableLorebook;
  bool get enableRegex => _enableRegex;
  bool get enableFormatting => _enableFormatting;

  /// Returns the character-scoped lorebook (from the active character card),
  /// or `null` if no card is loaded or the card has no embedded lorebook.
  Lorebook? get characterLorebook => _characterCard.characterBook;

  /// Returns the character-scoped regex scripts (from the active character card).
  List<RegexScript> get characterRegexScripts => _characterCard.regexScripts;

  /// All currently active regex scripts (global + character-scoped).
  List<RegexScript> get activeRegexScripts {
    if (!_enableRegex) return [];
    return [
      ..._globalRegexScripts,
      if (_enableCharacterCard) ..._characterCard.regexScripts,
    ];
  }

  List<ChatMessage> _messages = [];
  List<ChatSessionData> _savedSessions = [];
  String? _currentSessionId;
  int _tokenCount = 0;
  String _currentTitle = "";
  String _systemInstruction = "";
  String _advancedSystemInstruction = "";
  CharacterCard _characterCard = CharacterCard();

  List<ChatMessage> get messages => _messages;
  List<ChatSessionData> get savedSessions => _savedSessions;
  String? get currentSessionId => _currentSessionId;
  int get tokenCount => _tokenCount;
  String get currentTitle => _currentTitle;
  String get systemInstruction => _systemInstruction;
  String get advancedSystemInstruction => _advancedSystemInstruction;
  CharacterCard get characterCard => _characterCard;

  List<SystemPromptData> _savedSystemPrompts = [];
  List<SystemPromptData> get savedSystemPrompts => _savedSystemPrompts;

  Set<String> _bookmarkedModels = {};
  Set<String> get bookmarkedModels => _bookmarkedModels;

  late GenerativeModel _model;
  late ChatSession _chat;
  static const _defaultApiKey = '';

  ChatProvider() {
    _loadSettings();
    _loadSessions();
    _loadSystemPrompts();
    _loadModelBookmarks();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final sub in _activeStreams.values) {
      sub.cancel();
    }
    _activeStreams.clear();
    _activeNotifiers.clear();
    _activeStreamTexts.clear();
    _activeStreamModels.clear();
    _safeDisposeMessageNotifiers(_messages);
    super.dispose();
  }

  Future<void> _loadModelBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    // Migration: rename legacy key to airp_ prefixed key
    if (prefs.containsKey('bookmarked_models') && !prefs.containsKey('airp_bookmarked_models')) {
      final legacy = prefs.getStringList('bookmarked_models')!;
      await prefs.setStringList('airp_bookmarked_models', legacy);
      await prefs.remove('bookmarked_models');
    }
    _bookmarkedModels = prefs.getStringList('airp_bookmarked_models')?.toSet() ?? {};
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
    await prefs.setStringList('airp_bookmarked_models', _bookmarkedModels.toList());
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('airp_sessions');
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        _savedSessions = jsonList
            .map((j) => ChatSessionData.fromJson(j))
            .toList();
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
        _savedSystemPrompts = jsonList
            .map((j) => SystemPromptData.fromJson(j))
            .toList();
        notifyListeners();
      } catch (e) {
        debugPrint("Error loading prompts: $e");
      }
    }
  }

  Future<void> _loadCharacterCard() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('airp_character_card');
    if (data != null) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(data);
        _characterCard = CharacterCard.fromJson(jsonMap);
        notifyListeners();
      } catch (e) {
        debugPrint("Error loading character card: $e");
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _geminiKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyGemini,
      prefsKey: ApiConstants.prefKeyGemini,
    );
    _openRouterKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyOpenRouter,
      prefsKey: ApiConstants.prefKeyOpenRouter,
    );
    _openAiKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyOpenAi,
      prefsKey: ApiConstants.prefKeyOpenAi,
    );
    _arliAiKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyArliAi,
      prefsKey: ApiConstants.prefKeyArliAi,
    );
    _nanoGptKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyNanoGpt,
      prefsKey: ApiConstants.prefKeyNanoGpt,
    );
    _huggingFaceKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyHuggingFace,
      prefsKey: ApiConstants.prefKeyHuggingFace,
    );
    _groqKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyGroq,
      prefsKey: ApiConstants.prefKeyGroq,
    );
    _localIp =
        prefs.getString(ApiConstants.prefLocalIp) ?? ChatDefaults.localIp;
    _localModelName =
        prefs.getString(ApiConstants.prefLocalModelName) ?? _localModelName;

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
    } else if (providerString == 'huggingFace') {
      _currentProvider = AiProvider.huggingFace;
    } else if (providerString == 'groq') {
      _currentProvider = AiProvider.groq;
    } else {
      _currentProvider = AiProvider.gemini;
    }

    _geminiModelsList = _deserializeModels(
      prefs.getStringList(ApiConstants.prefListGemini),
    );
    _openRouterModelsList = _deserializeModels(
      prefs.getStringList(ApiConstants.prefListOpenRouter),
    );
    _arliAiModelsList = _deserializeModels(
      prefs.getStringList(ApiConstants.prefListArliAi),
    );
    _nanoGptModelsList = _deserializeModels(
      prefs.getStringList(ApiConstants.prefListNanoGpt),
    );
    _openAiModelsList = _deserializeModels(
      prefs.getStringList(ApiConstants.prefListOpenAi),
    );
    _huggingFaceModelsList = _deserializeModels(
      prefs.getStringList(ApiConstants.prefListHuggingFace),
    );
    _groqModelsList = _deserializeModels(
      prefs.getStringList(ApiConstants.prefListGroq),
    );

    _selectedGeminiModel =
        prefs.getString(ApiConstants.prefModelGemini) ??
        'models/gemini-3-flash-preview';
    _openRouterModel =
        prefs.getString(ApiConstants.prefModelOpenRouter) ??
        'z-ai/glm-4.5-air:free';
    _arliAiModel =
        prefs.getString(ApiConstants.prefModelArliAi) ??
        'Mistral-Nemo-12B-Instruct-v1';
    _nanoGptModel = prefs.getString(ApiConstants.prefModelNanoGpt) ?? 'gpt-4o';
    _openAiModel = prefs.getString(ApiConstants.prefModelOpenAi) ?? 'gpt-4o';
    _huggingFaceModel =
        prefs.getString(ApiConstants.prefModelHuggingFace) ??
        'meta-llama/Meta-Llama-3-8B-Instruct';
    _groqModel =
        prefs.getString(ApiConstants.prefModelGroq) ?? 'llama3-8b-8192';

    _selectedModel = _getProviderModel(_currentProvider);

    _topP = prefs.getDouble('airp_top_p') ?? ChatDefaults.topP;
    _topK = prefs.getInt('airp_top_k') ?? ChatDefaults.topK;
    _maxOutputTokens =
        prefs.getInt('airp_max_output') ?? ChatDefaults.maxOutputTokens;
    _historyLimit =
        prefs.getInt('airp_history_limit') ?? ChatDefaults.historyLimit;
    _temperature =
        prefs.getDouble('airp_temperature') ?? ChatDefaults.temperature;
    _enableUsage = prefs.getBool('airp_enable_usage') ?? false;
    _reasoningEffort = prefs.getString('airp_reasoning_effort') ?? 'none';
    _enableGrounding = prefs.getBool(ApiConstants.prefEnableGrounding) ?? false;
    _enableImageGen = prefs.getBool(ApiConstants.prefEnableImageGen) ?? false;
    _disableSafety = prefs.getBool(ApiConstants.prefDisableSafety) ?? true;

    if (_enableGrounding && _enableImageGen) {
      _enableImageGen = false;
    }

    // Web Search (BYOK)
    final providerName =
        prefs.getString(ApiConstants.prefKeySearchProvider) ?? 'provider';
    _searchProvider = SearchProvider.values.firstWhere(
      (e) => e.name == providerName,
      orElse: () => SearchProvider.provider,
    );
    _braveApiKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyBraveApiKey,
      prefsKey: ApiConstants.prefKeyBraveApiKey,
    );
    _tavilyApiKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyTavilyApiKey,
      prefsKey: ApiConstants.prefKeyTavilyApiKey,
    );
    _serperApiKey = await _loadApiKeyFromStorage(
      prefs: prefs,
      secureKey: ApiConstants.secureKeySerperApiKey,
      prefsKey: ApiConstants.prefKeySerperApiKey,
    );
    _searxngUrl = prefs.getString(ApiConstants.prefKeySearXNGUrl) ?? '';
    _searchResultCount = prefs.getInt(ApiConstants.prefSearchResultCount) ?? 5;
    _systemInstruction =
        prefs.getString('airp_default_system_instruction') ?? '';
    _advancedSystemInstruction =
        prefs.getString('airp_advanced_system_instruction') ?? '';

    _enableSystemPrompt = prefs.getBool('airp_enable_system_prompt') ?? true;
    _enableAdvancedSystemPrompt =
        prefs.getBool('airp_enable_advanced_system_prompt') ?? true;
    // Migration: rename legacy key to airp_ prefixed key
    if (prefs.containsKey('enable_character_card')) {
      final legacy = prefs.getBool('enable_character_card')!;
      await prefs.setBool('airp_enable_character_card', legacy);
      await prefs.remove('enable_character_card');
    }
    _enableCharacterCard = prefs.getBool('airp_enable_character_card') ?? true;
    _enableMsgHistory = prefs.getBool('airp_enable_msg_history') ?? true;
    _enableReasoning = prefs.getBool('airp_enable_reasoning') ?? false;
    _enableGenerationSettings =
        prefs.getBool('airp_enable_generation_settings') ?? true;
    _enableMaxOutputTokens =
        prefs.getBool('airp_enable_max_output_tokens') ?? true;

    await _loadCharacterCard();
    await _loadSillyTavernState();

    notifyListeners();

    if (_currentProvider == AiProvider.gemini) {
      await initializeModel();
    }
  }

  void setProvider(AiProvider provider) {
    _currentProvider = provider;
    _selectedModel = _getProviderModel(provider);

    notifyListeners();
    saveSettings(showConfirmation: false);
    if (provider == AiProvider.gemini) initializeModel();
  }

  void setApiKey(String key) {
    _setProviderKey(_currentProvider, key);
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

  void setAdvancedSystemInstruction(String instruction) {
    _advancedSystemInstruction = instruction;
    notifyListeners();
  }

  // --- Lorebook / Regex / Formatting setters ---

  void setGlobalLorebook(Lorebook lorebook) {
    _globalLorebook = lorebook;
    notifyListeners();
    _saveSillyTavernState();
  }

  void setGlobalRegexScripts(List<RegexScript> scripts) {
    _globalRegexScripts = scripts;
    notifyListeners();
    _saveSillyTavernState();
  }

  void setFormattingTemplate(FormattingTemplate? template) {
    _formattingTemplate = template;
    notifyListeners();
    _saveSillyTavernState();
  }

  void setEnableLorebook(bool enable) {
    _enableLorebook = enable;
    notifyListeners();
    _saveSillyTavernState();
  }

  void setEnableRegex(bool enable) {
    _enableRegex = enable;
    notifyListeners();
    _saveSillyTavernState();
  }

  void setEnableFormatting(bool enable) {
    _enableFormatting = enable;
    notifyListeners();
    _saveSillyTavernState();
  }

  void setEnableCharacterCard(bool enable) {
    _enableCharacterCard = enable;
    notifyListeners();
    _saveEnableCharacterCard();
    if (_currentProvider == AiProvider.gemini) {
      initializeModel();
    }
  }

  Future<void> _saveEnableCharacterCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('airp_enable_character_card', _enableCharacterCard);
  }

  /// Persists lorebook, regex, formatting state to SharedPreferences.
  Future<void> _saveSillyTavernState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'airp_global_lorebook',
      jsonEncode(_globalLorebook.toJson()),
    );
    await prefs.setString(
      'airp_global_regex_scripts',
      jsonEncode(_globalRegexScripts.map((s) => s.toJson()).toList()),
    );
    if (_formattingTemplate != null) {
      await prefs.setString(
        'airp_formatting_template',
        jsonEncode(_formattingTemplate!.toJson()),
      );
    } else {
      await prefs.remove('airp_formatting_template');
    }
    await prefs.setBool('airp_enable_lorebook', _enableLorebook);
    await prefs.setBool('airp_enable_regex', _enableRegex);
    await prefs.setBool('airp_enable_formatting', _enableFormatting);
  }

  /// Loads lorebook, regex, formatting state from SharedPreferences.
  Future<void> _loadSillyTavernState() async {
    final prefs = await SharedPreferences.getInstance();

    final lorebookData = prefs.getString('airp_global_lorebook');
    if (lorebookData != null) {
      try {
        _globalLorebook = Lorebook.fromJson(jsonDecode(lorebookData));
      } catch (e) {
        debugPrint('Error loading global lorebook: $e');
      }
    }

    final regexData = prefs.getString('airp_global_regex_scripts');
    if (regexData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(regexData);
        _globalRegexScripts = jsonList
            .map((j) => RegexScript.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      } catch (e) {
        debugPrint('Error loading global regex scripts: $e');
      }
    }

    final formattingData = prefs.getString('airp_formatting_template');
    if (formattingData != null) {
      try {
        _formattingTemplate =
            FormattingTemplate.fromJson(jsonDecode(formattingData));
      } catch (e) {
        debugPrint('Error loading formatting template: $e');
      }
    }

    _enableLorebook = prefs.getBool('airp_enable_lorebook') ?? true;
    _enableRegex = prefs.getBool('airp_enable_regex') ?? true;
    _enableFormatting = prefs.getBool('airp_enable_formatting') ?? false;
  }

  void setCharacterCard(CharacterCard card) {
    _characterCard = card;

    // Auto-load embedded character book and regex scripts.
    // The characterBook and regexScripts are stored on the card itself and
    // accessed via getters (characterLorebook, characterRegexScripts), so
    // no additional state assignment is needed — they become active
    // automatically when _enableCharacterCard and _enableLorebook/_enableRegex
    // are true.

    notifyListeners();
    _saveCharacterCard();
    if (_currentProvider == AiProvider.gemini) {
      initializeModel();
    }
  }

  Future<void> _saveCharacterCard() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_characterCard.toJson());
    await prefs.setString('airp_character_card', data);
  }

  void setModel(String model) {
    _setProviderModel(_currentProvider, model);
    _selectedModel = model;
    notifyListeners();
  }

  String _getProviderModel(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini:
        return _selectedGeminiModel;
      case AiProvider.openRouter:
        return _openRouterModel;
      case AiProvider.arliAi:
        return _arliAiModel;
      case AiProvider.nanoGpt:
        return _nanoGptModel;
      case AiProvider.openAi:
        return _openAiModel;
      case AiProvider.huggingFace:
        return _huggingFaceModel;
      case AiProvider.groq:
        return _groqModel;
      case AiProvider.local:
        return "Local Network AI";
    }
  }

  void _setProviderModel(AiProvider provider, String model) {
    switch (provider) {
      case AiProvider.gemini:
        _selectedGeminiModel = model;
        break;
      case AiProvider.openRouter:
        _openRouterModel = model;
        break;
      case AiProvider.arliAi:
        _arliAiModel = model;
        break;
      case AiProvider.nanoGpt:
        _nanoGptModel = model;
        break;
      case AiProvider.openAi:
        _openAiModel = model;
        break;
      case AiProvider.huggingFace:
        _huggingFaceModel = model;
        break;
      case AiProvider.groq:
        _groqModel = model;
        break;
      case AiProvider.local:
        break;
    }
  }

  String _getProviderKey(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini:
        return _geminiKey;
      case AiProvider.openRouter:
        return _openRouterKey;
      case AiProvider.openAi:
        return _openAiKey;
      case AiProvider.arliAi:
        return _arliAiKey;
      case AiProvider.nanoGpt:
        return _nanoGptKey;
      case AiProvider.huggingFace:
        return _huggingFaceKey;
      case AiProvider.groq:
        return _groqKey;
      case AiProvider.local:
        return "local-key";
    }
  }

  void _setProviderKey(AiProvider provider, String key) {
    switch (provider) {
      case AiProvider.gemini:
        _geminiKey = key;
        break;
      case AiProvider.openRouter:
        _openRouterKey = key;
        break;
      case AiProvider.openAi:
        _openAiKey = key;
        break;
      case AiProvider.arliAi:
        _arliAiKey = key;
        break;
      case AiProvider.nanoGpt:
        _nanoGptKey = key;
        break;
      case AiProvider.huggingFace:
        _huggingFaceKey = key;
        break;
      case AiProvider.groq:
        _groqKey = key;
        break;
      case AiProvider.local:
        break;
    }
  }

  void setTemperature(double val) {
    _temperature = val;
    notifyListeners();
  }

  void setTopP(double val) {
    _topP = val;
    notifyListeners();
  }

  void setTopK(int val) {
    _topK = val;
    notifyListeners();
  }

  void setMaxOutputTokens(int val) {
    _maxOutputTokens = val;
    notifyListeners();
  }

  void setHistoryLimit(int val) {
    _historyLimit = val;
    notifyListeners();
  }

  void setEnableGrounding(bool val) {
    _enableGrounding = val;
    if (val) _enableImageGen = false;
    notifyListeners();
  }

  void setSearchProvider(SearchProvider val) {
    _searchProvider = val;
    notifyListeners();
  }

  void setBraveApiKey(String val) {
    _braveApiKey = val;
    notifyListeners();
  }

  void setTavilyApiKey(String val) {
    _tavilyApiKey = val;
    notifyListeners();
  }

  void setSerperApiKey(String val) {
    _serperApiKey = val;
    notifyListeners();
  }

  void setSearxngUrl(String val) {
    _searxngUrl = val;
    notifyListeners();
  }

  void setSearchResultCount(int val) {
    _searchResultCount = val;
    notifyListeners();
  }

  void setEnableImageGen(bool val) {
    _enableImageGen = val;
    if (val) _enableGrounding = false;
    notifyListeners();
  }

  void setDisableSafety(bool val) {
    _disableSafety = val;
    notifyListeners();
  }

  void setEnableUsage(bool val) {
    _enableUsage = val;
    notifyListeners();
  }

  void setReasoningEffort(String val) {
    _reasoningEffort = val;
    notifyListeners();
  }

  void setEnableSystemPrompt(bool val) {
    _enableSystemPrompt = val;
    notifyListeners();
  }

  void setEnableAdvancedSystemPrompt(bool val) {
    _enableAdvancedSystemPrompt = val;
    notifyListeners();
  }

  void setEnableMsgHistory(bool val) {
    _enableMsgHistory = val;
    notifyListeners();
  }

  void setEnableReasoning(bool val) {
    _enableReasoning = val;
    notifyListeners();
  }

  void setEnableGenerationSettings(bool val) {
    _enableGenerationSettings = val;
    notifyListeners();
  }

  void setEnableMaxOutputTokens(bool val) {
    _enableMaxOutputTokens = val;
    notifyListeners();
  }

  Future<void> saveSettings({bool showConfirmation = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyGemini,
      prefsKey: ApiConstants.prefKeyGemini,
      value: _geminiKey,
    );
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyOpenRouter,
      prefsKey: ApiConstants.prefKeyOpenRouter,
      value: _openRouterKey,
    );
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyOpenAi,
      prefsKey: ApiConstants.prefKeyOpenAi,
      value: _openAiKey,
    );
    await prefs.setString(ApiConstants.prefLocalIp, _localIp);
    await prefs.setString(ApiConstants.prefLocalModelName, _localModelName);
    await prefs.setString('airp_provider', _currentProvider.name);
    await prefs.setString(ApiConstants.prefModelGemini, _selectedGeminiModel);
    await prefs.setString(ApiConstants.prefModelOpenRouter, _openRouterModel);
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyArliAi,
      prefsKey: ApiConstants.prefKeyArliAi,
      value: _arliAiKey,
    );
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyNanoGpt,
      prefsKey: ApiConstants.prefKeyNanoGpt,
      value: _nanoGptKey,
    );
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyHuggingFace,
      prefsKey: ApiConstants.prefKeyHuggingFace,
      value: _huggingFaceKey,
    );
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyGroq,
      prefsKey: ApiConstants.prefKeyGroq,
      value: _groqKey,
    );
    await prefs.setString(ApiConstants.prefModelArliAi, _arliAiModel);
    await prefs.setString(ApiConstants.prefModelNanoGpt, _nanoGptModel);
    await prefs.setString(ApiConstants.prefModelOpenAi, _openAiModel);
    await prefs.setString(ApiConstants.prefModelHuggingFace, _huggingFaceModel);
    await prefs.setString(ApiConstants.prefModelGroq, _groqModel);
    await prefs.setDouble('airp_top_p', _topP);
    await prefs.setInt('airp_top_k', _topK);
    await prefs.setInt('airp_max_output', _maxOutputTokens);
    await prefs.setInt('airp_history_limit', _historyLimit);
    await prefs.setDouble('airp_temperature', _temperature);
    await prefs.setBool('airp_enable_usage', _enableUsage);
    await prefs.setString('airp_reasoning_effort', _reasoningEffort);
    await prefs.setBool(ApiConstants.prefEnableGrounding, _enableGrounding);
    await prefs.setBool(ApiConstants.prefEnableImageGen, _enableImageGen);
    await prefs.setBool(ApiConstants.prefDisableSafety, _disableSafety);
    // Web Search (BYOK)
    await prefs.setString(
      ApiConstants.prefKeySearchProvider,
      _searchProvider.name,
    );
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyBraveApiKey,
      prefsKey: ApiConstants.prefKeyBraveApiKey,
      value: _braveApiKey,
    );
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyTavilyApiKey,
      prefsKey: ApiConstants.prefKeyTavilyApiKey,
      value: _tavilyApiKey,
    );
    await _persistApiKey(
      prefs: prefs,
      secureKey: ApiConstants.secureKeySerperApiKey,
      prefsKey: ApiConstants.prefKeySerperApiKey,
      value: _serperApiKey,
    );
    await prefs.setString(ApiConstants.prefKeySearXNGUrl, _searxngUrl);
    await prefs.setInt(ApiConstants.prefSearchResultCount, _searchResultCount);
    await prefs.setString(
      'airp_default_system_instruction',
      _systemInstruction,
    );
    await prefs.setString(
      'airp_advanced_system_instruction',
      _advancedSystemInstruction,
    );

    await prefs.setBool('airp_enable_system_prompt', _enableSystemPrompt);
    await prefs.setBool(
      'airp_enable_advanced_system_prompt',
      _enableAdvancedSystemPrompt,
    );
    await prefs.setBool('airp_enable_msg_history', _enableMsgHistory);
    await prefs.setBool('airp_enable_reasoning', _enableReasoning);
    await prefs.setBool(
      'airp_enable_generation_settings',
      _enableGenerationSettings,
    );
    await prefs.setBool(
      'airp_enable_max_output_tokens',
      _enableMaxOutputTokens,
    );

    // Persist lorebook / regex / formatting state alongside main settings
    await _saveSillyTavernState();

    if (_currentSessionId != null) {
      _scheduleAutoSave();
    }

    if (_currentProvider == AiProvider.gemini) {
      await initializeModel();
    }
  }

  /// Runs the configured BYOK search backend and returns a formatted context
  /// block, or `null` if the provider is set to [SearchProvider.provider]
  /// (i.e. delegate to the AI's native grounding) or if the search fails.
  Future<String?> performByokWebSearch(String query) async {
    if (_searchProvider == SearchProvider.provider) return null;

    List<WebSearchResult> results = [];

    switch (_searchProvider) {
      case SearchProvider.brave:
        if (_braveApiKey.isEmpty) {
          debugPrint('[WebSearch] Brave key not set — skipping BYOK search.');
          return null;
        }
        results = await WebSearchService.searchBrave(
          query,
          _braveApiKey,
          resultCount: _searchResultCount,
        );
      case SearchProvider.searxng:
        if (_searxngUrl.isEmpty) {
          debugPrint('[WebSearch] SearXNG URL not set — skipping BYOK search.');
          return null;
        }
        results = await WebSearchService.searchSearXNG(
          query,
          _searxngUrl,
          resultCount: _searchResultCount,
        );
      case SearchProvider.tavily:
        if (_tavilyApiKey.isEmpty) {
          debugPrint('[WebSearch] Tavily key not set — skipping BYOK search.');
          return null;
        }
        results = await WebSearchService.searchTavily(
          query,
          _tavilyApiKey,
          resultCount: _searchResultCount,
        );
      case SearchProvider.serper:
        if (_serperApiKey.isEmpty) {
          debugPrint('[WebSearch] Serper key not set — skipping BYOK search.');
          return null;
        }
        results = await WebSearchService.searchSerper(
          query,
          _serperApiKey,
          resultCount: _searchResultCount,
        );
      case SearchProvider.duckduckgo:
        results = await WebSearchService.searchDDG(
          query,
          resultCount: _searchResultCount,
        );
      case SearchProvider.provider:
        return null;
    }

    if (results.isEmpty) {
      return "\n\n*** SYSTEM NOTICE ***\nA web search for \"$query\" was attempted via ${_searchProvider.name}, but it returned 0 results or was blocked by the provider.\n\nPlease inform the user that the search failed or found nothing, and try answering their question using your knowledge if possible.\n*** END SYSTEM NOTICE ***\n\n";
    }
    return WebSearchService.formatResultsAsContextBlock(results, query: query);
  }

  // -------------------------------------------------------------------------
  // Lorebook / Regex / Formatting helpers
  // -------------------------------------------------------------------------

  /// Builds a [MacroContext] from the current provider state.
  MacroContext _buildMacroContext() {
    return MacroContext(
      char: _characterCard.name,
      user: 'User',
      description: _characterCard.description,
      personality: _characterCard.personality,
      scenario: _characterCard.scenario,
      mesExamples: _characterCard.mesExample,
      model: _selectedModel,
      lastMessageId: _messages.length,
      lastMessage: _messages.isNotEmpty ? _messages.last.text : '',
    );
  }

  /// Public accessor for the current macro context (used by display widgets).
  MacroContext get macroContext => _buildMacroContext();

  /// Evaluates all active lorebooks against [recentMessages] and returns
  /// a merged [LorebookEvalResult].
  ///
  /// [recentMessages] should be ordered newest-first.
  LorebookEvalResult _evaluateLorebooks(List<String> recentMessages) {
    if (!_enableLorebook) {
      return const LorebookEvalResult(byPosition: {}, estimatedTokens: 0);
    }

    final lorebooks = <Lorebook>[
      if (_globalLorebook.entries.isNotEmpty) _globalLorebook,
      if (_enableCharacterCard && _characterCard.characterBook != null)
        _characterCard.characterBook!,
    ];

    return PromptPipelineService.evaluateLorebooks(
      lorebooks: lorebooks,
      recentMessages: recentMessages,
      characterName: _characterCard.name,
    );
  }

  /// Collects depth-positioned entries from lorebook results and the character
  /// card into a flat list of `{content, depth, role}` maps.
  List<Map<String, dynamic>> _collectDepthEntries(
    LorebookEvalResult lorebookResult,
  ) {
    return PromptPipelineService.collectDepthEntries(
      lorebookResult: lorebookResult,
      characterCard: _characterCard,
      enableCharacterCard: _enableCharacterCard,
    );
  }

  /// Constructs the full system instruction including Main Prompt, Advanced
  /// Prompt, Character Card, and optionally lorebook entries.
  ///
  /// When [lorebookResult] is provided, activated entries are injected at
  /// their declared positions (beforeCharDefs, afterCharDefs, etc.).
  /// `atDepth` entries are NOT included here — use [_collectDepthEntries]
  /// for those.
  String _buildSystemInstruction({LorebookEvalResult? lorebookResult}) {
    return PromptPipelineService.buildSystemInstruction(
      systemInstruction: _systemInstruction,
      advancedSystemInstruction: _advancedSystemInstruction,
      enableSystemPrompt: _enableSystemPrompt,
      enableAdvancedSystemPrompt: _enableAdvancedSystemPrompt,
      enableCharacterCard: _enableCharacterCard,
      characterCard: _characterCard,
      lorebookResult: lorebookResult,
    );
  }

  /// Initializes the generative model based on the current provider and settings.
  ///
  /// This configures safety settings, system instructions, and generation
  /// parameters. It also rebuilds the chat history for the Gemini provider.
  Future<void> initializeModel({String? systemInstructionOverride}) async {
    String activeKey = _getProviderKey(_currentProvider);
    if (_currentProvider == AiProvider.gemini && activeKey.isEmpty) {
      activeKey = _defaultApiKey;
    }

    if (activeKey.isEmpty &&
        _currentProvider != AiProvider.local &&
        _currentProvider != AiProvider.huggingFace) {
      // HuggingFace can work without a key for some models, but rate limited.
      debugPrint("Warning: No API Key found for ${_currentProvider.name}");
    }

    try {
      final List<SafetySetting> safetySettings = _disableSafety
          ? [
              SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
              SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
              SafetySetting(
                HarmCategory.sexuallyExplicit,
                HarmBlockThreshold.none,
              ),
              SafetySetting(
                HarmCategory.dangerousContent,
                HarmBlockThreshold.none,
              ),
            ]
          : [];

      final String baseSystemInstruction =
          systemInstructionOverride ?? _buildSystemInstruction();
      String finalSystemInstruction = baseSystemInstruction;

      if (_currentProvider == AiProvider.gemini &&
          _enableReasoning &&
          (_reasoningEffort != "none" || _selectedModel.contains("thinking"))) {
        finalSystemInstruction +=
            "\n\n[SYSTEM: You are a reasoning model. You MUST enclose your internal thought process in <think> and </think> tags before your final response.";
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
          temperature: _enableGenerationSettings ? _temperature : null,
          topP: _enableGenerationSettings ? _topP : null,
          topK: _enableGenerationSettings ? _topK : null,
          maxOutputTokens: _enableMaxOutputTokens ? _maxOutputTokens : null,
        ),
        safetySettings: safetySettings,
      );

      List<Content> history = [];
      int effectiveHistoryLimit = _enableMsgHistory ? _historyLimit : 0;
      int startIndex = _messages.length - effectiveHistoryLimit;
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
              final mimeType = path.toLowerCase().endsWith('.png')
                  ? 'image/png'
                  : 'image/jpeg';
              parts.add(DataPart(mimeType, bytes));
            }
          }
          history.add(Content(role, parts));
        } else if (history.isNotEmpty && history.last.role == role) {
          final List<Part> existingParts = history.last.parts.toList();
          existingParts.add(TextPart("\n\n${msg.text}"));
          history[history.length - 1] = Content(role, existingParts);
        } else {
          history.add(
            msg.isUser
                ? Content.text(msg.text)
                : Content.model([TextPart(msg.text)]),
          );
        }
      }

      _chat = _model.startChat(history: history);
    } catch (e) {
      debugPrint("Model Init Error: $e");
    }
  }

  /// Sends a message to the active AI provider and streams the response.
  ///
  /// This method handles optimistic updates, grounding, image generation,
  /// and standard chat response streaming. Supports background streaming
  /// when the user switches conversations mid-response.
  Future<void> sendMessage(
    String messageText,
    List<String> imagesToSend,
  ) async {
    if (messageText.isEmpty && imagesToSend.isEmpty) return;

    // Ensure session ID exists before sending
    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final String streamSessionId = _currentSessionId!;

    _messages.add(
      ChatMessage(text: messageText, isUser: true, imagePaths: imagesToSend),
    );
    _cancelledSessions.remove(streamSessionId);
    notifyListeners();

    _scheduleAutoSave();

    // --- Pre-send: apply user input regex ---
    final macroCtx = _buildMacroContext();
    final scripts = activeRegexScripts;
    if (scripts.isNotEmpty) {
      final permanentText = await RegexService.applyPermanent(
        text: messageText,
        scripts: scripts,
        target: RegexTarget.userInput,
        macroContext: macroCtx,
      );
      if (permanentText != messageText) {
        messageText = permanentText;
        _messages.last = _messages.last.copyWith(text: permanentText);
        notifyListeners();
      }
    }

    // Build prompt-only version of user text (used when sending to AI).
    String sentUserText = messageText;
    if (scripts.isNotEmpty) {
      sentUserText = await RegexService.applyPromptOnly(
        text: messageText,
        scripts: scripts,
        target: RegexTarget.userInput,
        macroContext: macroCtx,
      );
    }

    // --- Evaluate lorebooks ---
    final recentMsgs = _messages.reversed.map((m) => m.text).toList();
    final lorebookResult = _evaluateLorebooks(recentMsgs);
    final depthEntries = _collectDepthEntries(lorebookResult);

    if (_enableGrounding &&
        _currentProvider == AiProvider.gemini &&
        imagesToSend.isEmpty &&
        _searchProvider == SearchProvider.provider) {
      try {
        _nonStreamingLoading = true;
        notifyListeners();

        final activeKey = _geminiKey.isNotEmpty ? _geminiKey : _defaultApiKey;

        // Get previous thought signature if available
        String? previousSignature;
        if (_messages.isNotEmpty) {
          for (int i = _messages.length - 1; i >= 0; i--) {
            if (!_messages[i].isUser && _messages[i].thoughtSignature != null) {
              previousSignature = _messages[i].thoughtSignature;
              break;
            }
          }
        }

        String finalSystemInstruction =
            _buildSystemInstruction(lorebookResult: lorebookResult);

        // Append depth entries to system instruction for Gemini grounding
        if (depthEntries.isNotEmpty) {
          for (final de in depthEntries) {
            finalSystemInstruction += '\n\n${de['content']}';
          }
        }

        final result = await ChatApiService.performGeminiGrounding(
          apiKey: activeKey,
          model: _selectedModel,
          history: _messages.sublist(0, _messages.length - 1),
          userMessage: sentUserText,
          systemInstruction: finalSystemInstruction,
          disableSafety: _disableSafety,
          thoughtSignature: previousSignature,
        );

        if (_cancelledSessions.contains(streamSessionId)) {
          _nonStreamingLoading = false;
          notifyListeners();
          return;
        }

        if (result != null) {
          if (_currentSessionId == streamSessionId) {
            _messages.add(
              ChatMessage(
                text: result['text'] ?? "Error",
                isUser: false,
                modelName: _selectedModel,
                thoughtSignature: result['thoughtSignature'],
              ),
            );
          } else {
            _addMessageToSavedSession(
              streamSessionId,
              ChatMessage(
                text: result['text'] ?? "Error",
                isUser: false,
                modelName: _selectedModel,
                thoughtSignature: result['thoughtSignature'],
              ),
            );
          }
        } else {
          if (_currentSessionId == streamSessionId) {
            _messages.add(
              ChatMessage(
                text: "Grounding Error",
                isUser: false,
                modelName: _selectedModel,
              ),
            );
          }
        }

        _nonStreamingLoading = false;
        notifyListeners();
        return;
      } catch (e) {
        _nonStreamingLoading = false;
        debugPrint("Grounding failed: $e");
      }
    }

    if (_enableImageGen) {
      try {
        _nonStreamingLoading = true;
        notifyListeners();

        String activeKey = '';
        String provider = 'openai';

        if (_currentProvider == AiProvider.openRouter) {
          activeKey = _openRouterKey;
          provider = 'openrouter';
        } else if (_currentProvider == AiProvider.openAi) {
          activeKey = _openAiKey;
          provider = 'openai';
        } else {
          _messages.add(
            ChatMessage(
              text:
                  "Image Gen currently only supported for OpenRouter/OpenAI in this mode.",
              isUser: false,
              modelName: "System",
            ),
          );
          _nonStreamingLoading = false;
          notifyListeners();
          return;
        }

        final imageUrl = await ChatApiService.generateImage(
          apiKey: activeKey,
          prompt: messageText,
          provider: provider,
        );

        if (_cancelledSessions.contains(streamSessionId)) {
          _nonStreamingLoading = false;
          notifyListeners();
          return;
        }

        if (imageUrl != null && imageUrl.startsWith('http')) {
          _messages.add(
            ChatMessage(text: imageUrl, isUser: false, modelName: "Image Gen"),
          );
        } else {
          _messages.add(
            ChatMessage(
              text: "Image Gen Failed: $imageUrl",
              isUser: false,
              modelName: "System",
            ),
          );
        }
        _nonStreamingLoading = false;
        notifyListeners();
        return;
      } catch (e) {
        _messages.add(
          ChatMessage(
            text: "Error generating image: $e",
            isUser: false,
            modelName: "System",
          ),
        );
        _nonStreamingLoading = false;
        notifyListeners();
        return;
      }
    }

    final contentNotifier = ValueNotifier<String>("");

    // ── BYOK Web Search ──────────────────────────────────────────────────────
    // Fetch search context before streaming when the user has chosen a
    // non-provider search backend. This runs regardless of AI provider.
    String? byokWebContext;
    if (_enableGrounding && _searchProvider != SearchProvider.provider) {
      try {
        _nonStreamingLoading = true;
        notifyListeners();
        byokWebContext = await performByokWebSearch(messageText);
      } catch (e) {
        debugPrint('[WebSearch] BYOK fetch failed during sendMessage: $e');
      } finally {
        _nonStreamingLoading = false;
        notifyListeners();
      }
    }
    _messages.add(
      ChatMessage(
        text: "",
        isUser: false,
        modelName: _selectedModel,
        contentNotifier: contentNotifier,
        regenerationVersions: _pendingRegenerationVersions,
        currentVersionIndex: _pendingRegenerationVersions.isNotEmpty
            ? _pendingRegenerationVersions.length - 1
            : 0,
      ),
    );

    // Clear pending versions after using them
    _pendingRegenerationVersions = [];

    notifyListeners();

    // Register active stream tracking
    _activeNotifiers[streamSessionId] = contentNotifier;
    _activeStreamTexts[streamSessionId] = "";
    _activeStreamModels[streamSessionId] = _selectedModel;

    Stream<String>? responseStream;

    try {
      if (_currentProvider == AiProvider.gemini) {
        // Re-initialise model with lorebook-enriched system instruction
        // so the chat session reflects the full prompt context.
        String geminiSysInstruction =
            _buildSystemInstruction(lorebookResult: lorebookResult);
        if (depthEntries.isNotEmpty) {
          for (final de in depthEntries) {
            geminiSysInstruction += '\n\n${de['content']}';
          }
        }
        await initializeModel(
            systemInstructionOverride: geminiSysInstruction);

        // Prepend any BYOK context to the user message.
        final String geminiMessage = byokWebContext != null
            ? '$byokWebContext\n\n---\n\n$sentUserText'
            : sentUserText;
        responseStream = ChatApiService.streamGeminiResponse(
          chatSession: _chat,
          message: geminiMessage,
          imagePaths: imagesToSend,
          modelName: _selectedModel,
        );
      } else {
        String baseUrl = "";
        String apiKey = "";
        Map<String, String>? headers;

        final contextMessages = _messages.sublist(0, _messages.length - 2);
        int effectiveHistoryLimit = _enableMsgHistory ? _historyLimit : 0;
        int startIndex = contextMessages.length - effectiveHistoryLimit;
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
        } else if (_currentProvider == AiProvider.openAi) {
          baseUrl = "https://api.openai.com/v1/chat/completions";
          apiKey = _openAiKey;
        } else if (_currentProvider == AiProvider.huggingFace) {
          baseUrl =
              "https://api-inference.huggingface.co/models/$_selectedModel/v1/chat/completions";
          apiKey = _huggingFaceKey;
        } else if (_currentProvider == AiProvider.groq) {
          baseUrl = "https://api.groq.com/openai/v1/chat/completions";
          apiKey = _groqKey;
        } else if (_currentProvider == AiProvider.local) {
          baseUrl = _localIp.trim();
          if (baseUrl.endsWith('/')) {
            baseUrl = baseUrl.substring(0, baseUrl.length - 1);
          }
          if (!baseUrl.endsWith('/chat/completions')) {
            baseUrl += baseUrl.endsWith('/v1')
                ? "/chat/completions"
                : "/v1/chat/completions";
          }
          apiKey = "local-key";
        }

        String finalSystemInstruction =
            _buildSystemInstruction(lorebookResult: lorebookResult);

        // Prepend BYOK search context to user message (not system prompt)
        // so each query gets its own fresh context and avoids mutating
        // the session-level system instruction.
        final String openAiUserMessage = byokWebContext != null
            ? '$byokWebContext\n\n---\n\n$sentUserText'
            : sentUserText;

        responseStream = ChatApiService.streamOpenAiCompatible(
          apiKey: apiKey,
          baseUrl: baseUrl,
          model: _currentProvider == AiProvider.local
              ? _localModelName
              : _selectedModel,
          history: limitedHistory,
          systemInstruction: finalSystemInstruction,
          userMessage: openAiUserMessage,
          imagePaths: imagesToSend,
          temperature: _enableGenerationSettings ? _temperature : null,
          topP: _enableGenerationSettings ? _topP : null,
          topK: _enableGenerationSettings ? _topK : null,
          maxTokens: _enableMaxOutputTokens ? _maxOutputTokens : null,
          // Only use native provider grounding when BYOK is not active
          enableGrounding:
              _enableGrounding && _searchProvider == SearchProvider.provider,
          reasoningEffort: _enableReasoning ? _reasoningEffort : null,
          extraHeaders: headers,
          includeUsage: _enableUsage,
          depthMessages:
              depthEntries.isNotEmpty ? depthEntries : null,
        );
      }

      String fullText = "";
      final subscription = responseStream.listen(
        (chunk) {
          if (_cancelledSessions.contains(streamSessionId)) return;
          if (chunk.startsWith('[[USAGE:')) {
            final usageStr = chunk.substring(8, chunk.length - 2);
            final usage = jsonDecode(usageStr) as Map<String, dynamic>;
            if (_currentSessionId == streamSessionId) {
              _messages.last = _messages.last.copyWith(usage: usage);
              notifyListeners();
            }
          } else if (chunk.startsWith('[[THOUGHT_SIG:')) {
            final sig = chunk.substring(14, chunk.length - 2);
            if (_currentSessionId == streamSessionId) {
              _messages.last = _messages.last.copyWith(thoughtSignature: sig);
              notifyListeners();
            }
          } else {
            fullText += chunk;
            contentNotifier.value = fullText;
            _activeStreamTexts[streamSessionId] = fullText;
            if (_currentSessionId == streamSessionId) {
              _messages.last = _messages.last.copyWith(text: fullText);
            }
          }
        },
        onError: (e) {
          if (!_cancelledSessions.contains(streamSessionId)) {
            final errorText = "$fullText\n\n**Error:** $e";
            if (_currentSessionId == streamSessionId) {
              _messages.last = _messages.last.copyWith(
                text: errorText,
                clearContentNotifier: true,
              );
              notifyListeners();
            } else {
              _finalizeBackgroundSession(streamSessionId, errorText);
            }
          }
          _cleanupStream(streamSessionId);
        },
        onDone: () async {
          if (!_cancelledSessions.contains(streamSessionId)) {
            // --- Post-stream: apply permanent AI output regex ---
            if (scripts.isNotEmpty && fullText.isNotEmpty) {
              final regexedOutput = await RegexService.applyPermanent(
                text: fullText,
                scripts: scripts,
                target: RegexTarget.aiOutput,
                macroContext: macroCtx,
              );
              if (regexedOutput != fullText) {
                fullText = regexedOutput;
              }
            }

            if (_currentSessionId == streamSessionId) {
              final lastMessage = _messages.last;
              final updatedVersions = List<String>.from(
                lastMessage.regenerationVersions,
              );
              if (updatedVersions.isNotEmpty &&
                  fullText.isNotEmpty &&
                  !updatedVersions.contains(fullText)) {
                updatedVersions.add(fullText);
              }

              _messages.last = lastMessage.copyWith(
                text: fullText,
                clearContentNotifier: true,
                regenerationVersions: updatedVersions,
                currentVersionIndex: updatedVersions.isNotEmpty
                    ? updatedVersions.length - 1
                    : lastMessage.currentVersionIndex,
              );
              notifyListeners();
              _scheduleAutoSave();

              if (_currentProvider == AiProvider.gemini) {
                await initializeModel();
              }

              if (!_enableGrounding) updateTokenCount();
            } else {
              // Background completion: update saved session and show notification
              _finalizeBackgroundSession(streamSessionId, fullText);
              _showBackgroundNotification(streamSessionId, fullText);
            }
          }
          _cleanupStream(streamSessionId);
        },
      );
      _activeStreams[streamSessionId] = subscription;
    } catch (e) {
      if (!_cancelledSessions.contains(streamSessionId)) {
        if (_currentSessionId == streamSessionId) {
          _messages.last = _messages.last.copyWith(clearContentNotifier: true);
          _messages.add(
            ChatMessage(
              text: "**System Error**\n\n```\n$e\n```",
              isUser: false,
              modelName: "System Alert",
            ),
          );
          notifyListeners();
          _scheduleAutoSave();
        }
      }
      _cleanupStream(streamSessionId);
    }
  }

  /// Cleans up tracking state for a completed/cancelled stream.
  void _cleanupStream(String sessionId) {
    _activeStreams.remove(sessionId);
    _activeNotifiers.remove(sessionId);
    _activeStreamTexts.remove(sessionId);
    _activeStreamModels.remove(sessionId);
    notifyListeners();
  }

  /// Updates a saved session's last AI message with the final text (background).
  void _finalizeBackgroundSession(String sessionId, String finalText) {
    final idx = _savedSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;

    final session = _savedSessions[idx];
    if (session.messages.isEmpty) return;

    final messages = List<ChatMessage>.from(session.messages);
    if (messages.isNotEmpty && !messages.last.isUser) {
      final lastMessage = messages.last;
      final updatedVersions = List<String>.from(
        lastMessage.regenerationVersions,
      );
      if (updatedVersions.isNotEmpty &&
          finalText.isNotEmpty &&
          !updatedVersions.contains(finalText)) {
        updatedVersions.add(finalText);
      }
      messages[messages.length - 1] = lastMessage.copyWith(
        text: finalText,
        clearContentNotifier: true,
        regenerationVersions: updatedVersions,
        currentVersionIndex: updatedVersions.isNotEmpty
            ? updatedVersions.length - 1
            : lastMessage.currentVersionIndex,
      );
    }

    _savedSessions[idx] = ChatSessionData(
      id: session.id,
      title: session.title,
      messages: messages,
      modelName: session.modelName,
      tokenCount: session.tokenCount,
      systemInstruction: session.systemInstruction,
      backgroundImage: session.backgroundImage,
      provider: session.provider,
      isBookmarked: session.isBookmarked,
    );

    // Persist the update
    _scheduleAutoSave();
  }

  /// Adds a message to a saved session (e.g. for grounding results arriving after switch).
  void _addMessageToSavedSession(String sessionId, ChatMessage message) {
    final idx = _savedSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;

    final session = _savedSessions[idx];
    final messages = List<ChatMessage>.from(session.messages);
    messages.add(message);

    _savedSessions[idx] = ChatSessionData(
      id: session.id,
      title: session.title,
      messages: messages,
      modelName: session.modelName,
      tokenCount: session.tokenCount,
      systemInstruction: session.systemInstruction,
      backgroundImage: session.backgroundImage,
      provider: session.provider,
      isBookmarked: session.isBookmarked,
    );
  }

  /// Shows a notification for a background stream that completed.
  void _showBackgroundNotification(String sessionId, String text) {
    final idx = _savedSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;

    final session = _savedSessions[idx];
    final modelName = _activeStreamModels[sessionId] ?? session.modelName;
    final preview = text.length > 120 ? "${text.substring(0, 120)}..." : text;

    _pendingNotifications.add(
      BackgroundNotification(
        sessionTitle: session.title,
        messagePreview: preview,
        modelName: modelName,
      ),
    );
    notifyListeners();
  }

  void cancelGeneration() async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;

    _cancelledSessions.add(sessionId);
    _nonStreamingLoading = false;

    final sub = _activeStreams.remove(sessionId);
    if (sub != null) {
      await sub.cancel();
    }

    // Finalize the current message safely (remove contentNotifier)
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      _messages.last = _messages.last.copyWith(clearContentNotifier: true);
    }

    _activeNotifiers.remove(sessionId);
    _activeStreamTexts.remove(sessionId);
    _activeStreamModels.remove(sessionId);

    notifyListeners();
  }

  /// Regenerate a response at the given index.
  /// Keeps the previous response as a version in the message's regenerationVersions list.
  Future<void> regenerateResponse(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final msg = _messages[index];

    String textToResend = "";
    List<String> imagesToResend = [];
    int userMsgIndex = -1;

    if (!msg.isUser) {
      userMsgIndex = index - 1;
      if (userMsgIndex >= 0 && _messages[userMsgIndex].isUser) {
        final userMsg = _messages[userMsgIndex];
        textToResend = userMsg.text;
        imagesToResend = userMsg.imagePaths;

        // Get current versions or create new list with current response
        List<String> currentVersions = [...msg.regenerationVersions];
        if (msg.text.isNotEmpty && !currentVersions.contains(msg.text)) {
          currentVersions.add(msg.text);
        }

        // Store versions for the next message that will be generated
        _pendingRegenerationVersions = currentVersions;

        // Remove BOTH user message and AI message to prevent duplication
        // removeRange removes indices [userMsgIndex, index+1)
        _safeDisposeMessageNotifiers(
          _messages.getRange(userMsgIndex, index + 1),
        );
        _messages.removeRange(userMsgIndex, index + 1);

        notifyListeners();
      } else {
        _safeDisposeMessageNotifiers([_messages[index]]);
        _messages.removeAt(index);
        notifyListeners();
        return;
      }
    } else {
      final userMsg = _messages[index];
      textToResend = userMsg.text;
      imagesToResend = userMsg.imagePaths;
      _safeDisposeMessageNotifiers(_messages.getRange(index, _messages.length));
      _messages.removeRange(index, _messages.length);
      notifyListeners();
    }

    await initializeModel();
    sendMessage(textToResend, imagesToResend);
  }

  /// Select a different version of an AI response.
  /// Updates the displayed message text to the selected version.
  void selectMessageVersion(int messageIndex, int versionIndex) {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final msg = _messages[messageIndex];

    if (msg.isUser || msg.regenerationVersions.isEmpty) return;
    if (versionIndex < 0 || versionIndex >= msg.regenerationVersions.length) {
      return;
    }

    final selectedVersionText = msg.regenerationVersions[versionIndex];
    _messages[messageIndex] = msg.copyWith(
      text: selectedVersionText,
      currentVersionIndex: versionIndex,
    );

    _scheduleAutoSave();
    notifyListeners();
  }

  /// Navigate to the next version of an AI response (forward).
  void nextMessageVersion(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final msg = _messages[messageIndex];

    if (msg.isUser || msg.regenerationVersions.isEmpty) return;

    int nextIndex = msg.currentVersionIndex + 1;
    if (nextIndex >= msg.regenerationVersions.length) {
      nextIndex = 0; // Loop back to first
    }
    selectMessageVersion(messageIndex, nextIndex);
  }

  /// Navigate to the previous version of an AI response (backward).
  void previousMessageVersion(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final msg = _messages[messageIndex];

    if (msg.isUser || msg.regenerationVersions.isEmpty) return;

    int prevIndex = msg.currentVersionIndex - 1;
    if (prevIndex < 0) {
      prevIndex = msg.regenerationVersions.length - 1; // Loop back to last
    }
    selectMessageVersion(messageIndex, prevIndex);
  }

  /// Creates a new conversation using the specified message as the starting point.
  /// Returns the new session ID.
  String createConversationFromMessage(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= _messages.length) return "";

    final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    // Start new conversation with the message that triggered fork
    // and all messages up to that point
    final forkedMessages = _messages.sublist(0, messageIndex + 1);

    final newSession = ChatSessionData(
      id: newSessionId,
      title: "Forked Conversation",
      messages: forkedMessages,
      modelName: _selectedModel,
      tokenCount: 0,
      systemInstruction: _systemInstruction,
      backgroundImage: null,
      provider: _currentProvider.name,
      isBookmarked: false,
    );

    _savedSessions.insert(0, newSession);
    return newSessionId;
  }

  Future<void> autoSaveCurrentSession({
    String? backgroundImagePath,
    bool clearBackground = false,
  }) async {
    if (_messages.isEmpty && _currentTitle.isEmpty) return;

    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final sessionId = _currentSessionId!;

    String title = _currentTitle;
    if (title.isEmpty && _messages.isNotEmpty) {
      title = _messages.first.text;
      if (title.length > ChatDefaults.sessionTitleMaxLength) {
        title = "${title.substring(0, ChatDefaults.sessionTitleMaxLength)}...";
      }
      _currentTitle = title;
    }
    if (title.isEmpty) title = "New Conversation";

    final messagesSnapshot = List<ChatMessage>.from(_messages);
    final tokenCountSnapshot = _tokenCount;
    final modelNameSnapshot = _selectedModel;
    final providerNameSnapshot = _currentProvider.name;
    final finalSystemInstruction = _buildSystemInstruction();

    String? currentBg = backgroundImagePath;
    if (!clearBackground && currentBg == null) {
      final existingIndex = _savedSessions.indexWhere((s) => s.id == sessionId);
      if (existingIndex != -1) {
        currentBg = _savedSessions[existingIndex].backgroundImage;
      }
    }

    final sessionData = ChatSessionData(
      id: sessionId,
      title: title,
      messages: messagesSnapshot,
      modelName: modelNameSnapshot,
      tokenCount: tokenCountSnapshot,
      systemInstruction: finalSystemInstruction,
      backgroundImage: currentBg,
      provider: providerNameSnapshot,
    );

    _savedSessions.removeWhere((s) => s.id == sessionId);
    _savedSessions.insert(0, sessionData);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(
      _savedSessions.map((s) => s.toJson()).toList(),
    );
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
    final String data = jsonEncode(
      _savedSessions.map((s) => s.toJson()).toList(),
    );
    await prefs.setString('airp_sessions', data);
  }

  void createNewSession() {
    // Save current session before switching if it has content
    if (_messages.isNotEmpty) {
      autoSaveCurrentSession();
    }

    _safeDisposeMessageNotifiers(_messages);
    _messages.clear();
    _tokenCount = 0;
    _nonStreamingLoading = false;
    _currentSessionId = null;
    _currentTitle = "";
    notifyListeners();
    initializeModel();
  }

  void loadSession(ChatSessionData session) {
    // Save current session before switching if it has content
    if (_messages.isNotEmpty && _currentSessionId != session.id) {
      autoSaveCurrentSession();
    }

    _safeDisposeMessageNotifiers(_messages);
    _messages = List.from(session.messages);
    _currentSessionId = session.id;
    _tokenCount = session.tokenCount;
    _systemInstruction = session.systemInstruction;
    _currentTitle = session.title;
    _nonStreamingLoading = false;

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
    } else if (session.provider == 'groq') {
      _currentProvider = AiProvider.groq;
      _selectedModel = session.modelName;
    } else if (session.provider == 'nanoGpt') {
      _currentProvider = AiProvider.nanoGpt;
      _selectedModel = session.modelName;
      _nanoGptModel = session.modelName;
    } else if (session.provider == 'arliAi') {
      _currentProvider = AiProvider.arliAi;
      _selectedModel = session.modelName;
      _arliAiModel = session.modelName;
    } else if (session.provider == 'huggingFace') {
      _currentProvider = AiProvider.huggingFace;
      _selectedModel = session.modelName;
      _huggingFaceModel = session.modelName;
    } else {
      _currentProvider = AiProvider.gemini;
      _selectedGeminiModel = session.modelName;
      _selectedModel = session.modelName;
    }

    // If this session has an active background stream, reconnect the notifier
    if (_activeStreams.containsKey(session.id)) {
      final notifier = _activeNotifiers[session.id];
      final currentText = _activeStreamTexts[session.id] ?? '';
      if (notifier != null && _messages.isNotEmpty && !_messages.last.isUser) {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          text: currentText,
          contentNotifier: notifier,
        );
      }
    }

    notifyListeners();
    initializeModel();
  }

  void deleteSession(String id) async {
    // Cancel any active stream for this session
    final sub = _activeStreams.remove(id);
    if (sub != null) {
      await sub.cancel();
      _activeNotifiers.remove(id);
      _activeStreamTexts.remove(id);
      _activeStreamModels.remove(id);
    }

    _savedSessions.removeWhere((s) => s.id == id);
    if (id == _currentSessionId) {
      createNewSession();
    } else {
      notifyListeners();
    }

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(
      _savedSessions.map((s) => s.toJson()).toList(),
    );
    await prefs.setString('airp_sessions', data);
  }

  void deleteMessage(int index) {
    _safeDisposeMessageNotifiers([_messages[index]]);
    _messages.removeAt(index);
    notifyListeners();
    _scheduleAutoSave();
    initializeModel();
  }

  void editMessage(int index, String newText) {
    _messages[index] = ChatMessage(
      text: newText,
      isUser: _messages[index].isUser,
    );
    notifyListeners();
    _scheduleAutoSave();
    initializeModel();
  }

  Future<void> _fetchProviderModels({
    required String apiKey,
    required String url,
    required String prefKey,
    required List<ModelInfo> Function(dynamic) parser,
    required void Function(List<ModelInfo>) updateList,
    required void Function(bool) updateLoading,
    Map<String, String>? headers,
    String? currentModel,
    void Function(String)? updateSelectedModel,
  }) async {
    if (apiKey.isEmpty && headers == null) return;

    updateLoading(true);
    notifyListeners();

    try {
      final models = await ChatApiService.fetchModels(
        url: url,
        headers:
            headers ??
            (apiKey.isNotEmpty ? {"Authorization": "Bearer $apiKey"} : null),
        parser: parser,
      );

      updateList(models);

      final prefs = await SharedPreferences.getInstance();
      final List<String> serializedModels = models
          .map((m) => jsonEncode(m.toJson()))
          .toList();
      await prefs.setStringList(prefKey, serializedModels);

      if (currentModel != null && updateSelectedModel != null) {
        if (!models.any((m) => m.id == currentModel) && models.isNotEmpty) {
          updateSelectedModel(models.first.id);
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      updateLoading(false);
      notifyListeners();
    }
  }

  Future<void> fetchGeminiModels() async {
    await _fetchProviderModels(
      apiKey: _geminiKey,
      url: "${ApiConstants.geminiBaseUrl}?key=$_geminiKey",
      prefKey: ApiConstants.prefListGemini,
      parser: (json) {
        final List<dynamic> models = json['models'];
        return models
            .where((m) {
              final methods = List<String>.from(
                m['supportedGenerationMethods'] ?? [],
              );
              return methods.contains('generateContent');
            })
            .map<ModelInfo>((m) {
              return ModelInfo(
                id: m['name'].toString(),
                name: m['displayName']?.toString() ?? m['name'].toString(),
                description: m['description']?.toString() ?? "",
                contextLength: m['inputTokenLimit']?.toString() ?? "",
              );
            })
            .toList();
      },
      updateList: (list) => _geminiModelsList = list,
      updateLoading: (val) => _isLoadingGeminiModels = val,
      currentModel: _selectedGeminiModel,
      updateSelectedModel: (val) => _selectedGeminiModel = val,
      headers: {},
    );
  }

  Future<void> fetchOpenRouterModels() async {
    await _fetchProviderModels(
      apiKey: "",
      url: ApiConstants.openRouterBaseUrl,
      prefKey: ApiConstants.prefListOpenRouter,
      parser: (json) {
        final List<dynamic> dataList = json['data'];
        return dataList.map<ModelInfo>((e) {
          final pricing = e['pricing'] ?? {};
          final prompt = pricing['prompt'] ?? "0";
          final completion = pricing['completion'] ?? "0";
          return ModelInfo(
            id: e['id'].toString(),
            name: e['name']?.toString() ?? e['id'].toString(),
            description: e['description']?.toString() ?? "",
            contextLength: e['context_length']?.toString() ?? "",
            pricing: "$prompt / $completion",
            created: e['created'],
            rawData: e,
          );
        }).toList();
      },
      updateList: (list) => _openRouterModelsList = list,
      updateLoading: (val) => _isLoadingOpenRouterModels = val,
      headers: {
        "HTTP-Referer": "https://airp-chat.com",
        "X-Title": "AIRP Chat",
      },
    );
  }

  Future<void> fetchArliAiModels() async {
    await _fetchProviderModels(
      apiKey: _arliAiKey,
      url: ApiConstants.arliAiBaseUrl,
      prefKey: ApiConstants.prefListArliAi,
      parser: (json) {
        final List<dynamic> dataList = json['data'];
        return dataList.map<ModelInfo>((e) {
          final rawId = e['id'].toString();
          final pricing = e['pricing'] ?? {};
          final prompt = pricing['prompt'] ?? "0";
          final completion = pricing['completion'] ?? "0";

          return ModelInfo(
            id: rawId,
            name: e['name']?.toString() ?? cleanModelName(rawId),
            description:
                e['description']?.toString() ??
                "Owned by: ${e['owned_by'] ?? 'Unknown'}",
            contextLength:
                (e['context_length'] ?? e['context_window'])?.toString() ?? "",
            pricing: (pricing.isNotEmpty) ? "$prompt / $completion" : "",
            created: e['created'],
            rawData: e,
          );
        }).toList();
      },
      updateList: (list) => _arliAiModelsList = list,
      updateLoading: (val) => _isLoadingArliAiModels = val,
    );
  }

  Future<void> fetchNanoGptModels() async {
    await _fetchProviderModels(
      apiKey: _nanoGptKey,
      url: ApiConstants.nanoGptBaseUrl,
      prefKey: ApiConstants.prefListNanoGpt,
      parser: (json) {
        final List<dynamic> dataList = json['data'] ?? [];
        return dataList.map<ModelInfo>((e) {
          final pricing = e['pricing'] ?? {};
          double prompt =
              double.tryParse(pricing['prompt']?.toString() ?? "0") ?? 0;
          double completion =
              double.tryParse(pricing['completion']?.toString() ?? "0") ?? 0;

          // NanoGPT returns per 1M tokens, normalize to per token
          // so that the UI formatter (which multiplies by 1M) works correctly.
          if (prompt > 0) prompt /= 1000000;
          if (completion > 0) completion /= 1000000;

          final rawId = e['id'].toString();

          return ModelInfo(
            id: rawId,
            name: e['name']?.toString() ?? cleanModelName(rawId),
            description:
                e['description']?.toString() ??
                "Owned by: ${e['owned_by'] ?? 'Unknown'}",
            contextLength:
                (e['context_length'] ?? e['context_window'])?.toString() ?? "",
            pricing: "$prompt / $completion",
            created: e['created'],
            rawData: e,
          );
        }).toList();
      },
      updateList: (list) => _nanoGptModelsList = list,
      updateLoading: (val) => _isLoadingNanoGptModels = val,
      currentModel: _nanoGptModel,
      updateSelectedModel: (val) {
        _nanoGptModel = val;
        if (_currentProvider == AiProvider.nanoGpt) {
          _selectedModel = _nanoGptModel;
        }
      },
    );
  }

  Future<void> fetchOpenAiModels() async {
    await _fetchProviderModels(
      apiKey: _openAiKey,
      url: ApiConstants.openAiBaseUrl,
      prefKey: ApiConstants.prefListOpenAi,
      parser: (json) {
        final List<dynamic> dataList = json['data'] ?? [];
        return dataList.map<ModelInfo>((e) {
          final rawId = e['id'].toString();
          final pricing = e['pricing'] ?? {};
          final prompt = pricing['prompt'] ?? "0";
          final completion = pricing['completion'] ?? "0";

          return ModelInfo(
            id: rawId,
            name: e['name']?.toString() ?? cleanModelName(rawId),
            description:
                e['description']?.toString() ??
                "Owned by: ${e['owned_by'] ?? 'Unknown'}",
            contextLength:
                (e['context_length'] ?? e['context_window'])?.toString() ?? "",
            pricing: (pricing.isNotEmpty) ? "$prompt / $completion" : "",
            created: e['created'],
            rawData: e,
          );
        }).toList();
      },
      updateList: (list) => _openAiModelsList = list,
      updateLoading: (val) => _isLoadingOpenAiModels = val,
      currentModel: _openAiModel,
      updateSelectedModel: (val) {
        _openAiModel = val;
        if (_currentProvider == AiProvider.openAi) {
          _selectedModel = _openAiModel;
        }
      },
    );
  }

  Future<void> fetchHuggingFaceModels() async {
    await _fetchProviderModels(
      apiKey: _huggingFaceKey,
      url: ApiConstants.huggingFaceBaseUrl,
      prefKey: ApiConstants.prefListHuggingFace,
      parser: (json) {
        final List<dynamic> dataList = json;
        return dataList.map<ModelInfo>((e) {
          final rawId = e['id'].toString();
          return ModelInfo(
            id: rawId,
            name: e['name']?.toString() ?? cleanModelName(rawId),
            description: e['description']?.toString() ?? "",
          );
        }).toList();
      },
      updateList: (list) => _huggingFaceModelsList = list,
      updateLoading: (val) => _isLoadingHuggingFaceModels = val,
      currentModel: _huggingFaceModel,
      updateSelectedModel: (val) {
        _huggingFaceModel = val;
        if (_currentProvider == AiProvider.huggingFace) {
          _selectedModel = _huggingFaceModel;
        }
      },
    );
  }

  Future<void> fetchGroqModels() async {
    await _fetchProviderModels(
      apiKey: _groqKey,
      url: ApiConstants.groqBaseUrl,
      prefKey: ApiConstants.prefListGroq,
      parser: (json) {
        final List<dynamic> dataList = json['data'] ?? [];
        return dataList.map<ModelInfo>((e) {
          final rawId = e['id'].toString();
          final pricing = e['pricing'] ?? {};
          final prompt = pricing['prompt'] ?? "0";
          final completion = pricing['completion'] ?? "0";

          return ModelInfo(
            id: rawId,
            name: e['name']?.toString() ?? cleanModelName(rawId),
            description:
                e['description']?.toString() ??
                "Owned by: ${e['owned_by'] ?? 'Unknown'}",
            contextLength:
                (e['context_length'] ?? e['context_window'])?.toString() ?? "",
            pricing: (pricing.isNotEmpty) ? "$prompt / $completion" : "",
            created: e['created'],
            rawData: e,
          );
        }).toList();
      },
      updateList: (list) => _groqModelsList = list,
      updateLoading: (val) => _isLoadingGroqModels = val,
      currentModel: _groqModel,
      updateSelectedModel: (val) {
        _groqModel = val;
        if (_currentProvider == AiProvider.groq) _selectedModel = _groqModel;
      },
    );
  }

  Future<void> savePromptToLibrary(String title, String content) async {
    if (title.isEmpty || content.isEmpty) return;

    final newPrompt = SystemPromptData(title: title, content: content);
    final index = _savedSystemPrompts.indexWhere(
      (p) => p.title == newPrompt.title,
    );

    if (index != -1) {
      _savedSystemPrompts[index] = newPrompt;
    } else {
      _savedSystemPrompts.add(newPrompt);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(
      _savedSystemPrompts.map((s) => s.toJson()).toList(),
    );
    await prefs.setString('airp_system_prompts', data);
  }

  Future<void> deletePromptFromLibrary(String title) async {
    _savedSystemPrompts.removeWhere((p) => p.title == title);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(
      _savedSystemPrompts.map((s) => s.toJson()).toList(),
    );
    await prefs.setString('airp_system_prompts', data);
  }

  Future<void> updateTokenCount() async {
    if (_messages.isEmpty) {
      _tokenCount = 0;
      notifyListeners();
      return;
    }

    if (_currentProvider == AiProvider.gemini) {
      try {
        final contents = _messages
            .map(
              (m) => m.isUser
                  ? Content.text(m.text)
                  : Content.model([TextPart(m.text)]),
            )
            .toList();
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

  Future<String> _loadApiKeyFromStorage({
    required SharedPreferences prefs,
    required String secureKey,
    required String prefsKey,
  }) async {
    try {
      final secureValue = await SecureStorageService.read(secureKey);
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } catch (e) {
      debugPrint('Secure storage read failed: $e');
    }

    final legacyValue = prefs.getString(prefsKey) ?? '';
    if (legacyValue.isNotEmpty) {
      try {
        await SecureStorageService.write(secureKey, legacyValue);
        await prefs.remove(prefsKey);
      } catch (e) {
        debugPrint('Secure storage migrate failed: $e');
      }
    }
    return legacyValue;
  }

  Future<void> _persistApiKey({
    required SharedPreferences prefs,
    required String secureKey,
    required String prefsKey,
    required String value,
  }) async {
    if (value.isEmpty) {
      try {
        await SecureStorageService.delete(secureKey);
      } catch (e) {
        debugPrint('Secure storage delete failed: $e');
      }
      await prefs.remove(prefsKey);
      return;
    }

    try {
      await SecureStorageService.write(secureKey, value);
      await prefs.remove(prefsKey);
    } catch (e) {
      debugPrint('Secure storage write failed: $e');
      await prefs.setString(prefsKey, value);
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(ChatDefaults.autoSaveDebounce, () {
      autoSaveCurrentSession();
    });
  }

  void _safeDisposeMessageNotifiers(Iterable<ChatMessage> messages) {
    final activeNotifierSet = _activeNotifiers.values.toSet();
    for (final message in messages) {
      if (message.contentNotifier != null &&
          !activeNotifierSet.contains(message.contentNotifier)) {
        try {
          message.contentNotifier!.dispose();
        } catch (_) {
          // Notifier may already be disposed or still has listeners; let GC handle it
        }
      }
    }
  }

  /// Exports all non-secret ChatProvider settings as a serializable map.
  Map<String, dynamic> exportSettingsMap() {
    return {
      'generation': {
        'temperature': _temperature,
        'topP': _topP,
        'topK': _topK,
        'maxOutputTokens': _maxOutputTokens,
        'historyLimit': _historyLimit,
        'reasoningEffort': _reasoningEffort,
      },
      'toggles': {
        'enableSystemPrompt': _enableSystemPrompt,
        'enableAdvancedSystemPrompt': _enableAdvancedSystemPrompt,
        'enableMsgHistory': _enableMsgHistory,
        'enableReasoning': _enableReasoning,
        'enableGenerationSettings': _enableGenerationSettings,
        'enableMaxOutputTokens': _enableMaxOutputTokens,
        'enableGrounding': _enableGrounding,
        'enableImageGen': _enableImageGen,
        'enableUsage': _enableUsage,
        'disableSafety': _disableSafety,
      },
      'provider': _currentProvider.name,
      'models': {
        'gemini': _selectedGeminiModel,
        'openRouter': _openRouterModel,
        'arliAi': _arliAiModel,
        'nanoGpt': _nanoGptModel,
        'openAi': _openAiModel,
        'huggingFace': _huggingFaceModel,
        'groq': _groqModel,
      },
      'modelBookmarks': _bookmarkedModels.toList(),
      'localIp': _localIp,
      'localModelName': _localModelName,
      'systemInstruction': _systemInstruction,
      'advancedSystemInstruction': _advancedSystemInstruction,
      'systemPrompts': _savedSystemPrompts.map((p) => p.toJson()).toList(),
      'sessions': _savedSessions.map((s) => s.toJson()).toList(),
      'characterCard': _characterCard.toJson(),
      'enableCharacterCard': _enableCharacterCard,
      'sillyTavernState': {
        'globalLorebook': _globalLorebook.toJson(),
        'globalRegexScripts':
            _globalRegexScripts.map((s) => s.toJson()).toList(),
        'formattingTemplate': _formattingTemplate?.toJson(),
        'enableLorebook': _enableLorebook,
        'enableRegex': _enableRegex,
        'enableFormatting': _enableFormatting,
      },
    };
  }

  /// Applies settings from a previously exported map.
  ///
  /// Settings are overwritten. System prompts and sessions are merged
  /// via [mergeSystemPrompts] and [mergeSessions].
  Future<void> importSettingsMap(Map<String, dynamic> data) async {
    final gen = data['generation'] as Map<String, dynamic>? ?? {};
    _temperature = (gen['temperature'] as num?)?.toDouble() ?? _temperature;
    _topP = (gen['topP'] as num?)?.toDouble() ?? _topP;
    _topK = (gen['topK'] as num?)?.toInt() ?? _topK;
    _maxOutputTokens =
        (gen['maxOutputTokens'] as num?)?.toInt() ?? _maxOutputTokens;
    _historyLimit = (gen['historyLimit'] as num?)?.toInt() ?? _historyLimit;
    _reasoningEffort = gen['reasoningEffort'] as String? ?? _reasoningEffort;

    final tog = data['toggles'] as Map<String, dynamic>? ?? {};
    _enableSystemPrompt =
        tog['enableSystemPrompt'] as bool? ?? _enableSystemPrompt;
    _enableAdvancedSystemPrompt =
        tog['enableAdvancedSystemPrompt'] as bool? ??
        _enableAdvancedSystemPrompt;
    _enableMsgHistory = tog['enableMsgHistory'] as bool? ?? _enableMsgHistory;
    _enableReasoning = tog['enableReasoning'] as bool? ?? _enableReasoning;
    _enableGenerationSettings =
        tog['enableGenerationSettings'] as bool? ?? _enableGenerationSettings;
    _enableMaxOutputTokens =
        tog['enableMaxOutputTokens'] as bool? ?? _enableMaxOutputTokens;
    _enableGrounding = tog['enableGrounding'] as bool? ?? _enableGrounding;
    _enableImageGen = tog['enableImageGen'] as bool? ?? _enableImageGen;
    _enableUsage = tog['enableUsage'] as bool? ?? _enableUsage;
    _disableSafety = tog['disableSafety'] as bool? ?? _disableSafety;

    final providerName = data['provider'] as String?;
    if (providerName != null) {
      try {
        _currentProvider = AiProvider.values.firstWhere(
          (p) => p.name == providerName,
        );
      } catch (_) {}
    }

    final models = data['models'] as Map<String, dynamic>? ?? {};
    _selectedGeminiModel = models['gemini'] as String? ?? _selectedGeminiModel;
    _openRouterModel = models['openRouter'] as String? ?? _openRouterModel;
    _arliAiModel = models['arliAi'] as String? ?? _arliAiModel;
    _nanoGptModel = models['nanoGpt'] as String? ?? _nanoGptModel;
    _openAiModel = models['openAi'] as String? ?? _openAiModel;
    _huggingFaceModel = models['huggingFace'] as String? ?? _huggingFaceModel;
    _groqModel = models['groq'] as String? ?? _groqModel;
    _selectedModel = _getProviderModel(_currentProvider);

    final bookmarks = data['modelBookmarks'] as List<dynamic>?;
    if (bookmarks != null) {
      _bookmarkedModels = bookmarks.map((e) => e.toString()).toSet();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'airp_bookmarked_models',
        _bookmarkedModels.toList(),
      );
    }

    _localIp = data['localIp'] as String? ?? _localIp;
    _localModelName = data['localModelName'] as String? ?? _localModelName;

    _systemInstruction =
        data['systemInstruction'] as String? ?? _systemInstruction;
    _advancedSystemInstruction =
        data['advancedSystemInstruction'] as String? ??
        _advancedSystemInstruction;

    // Merge (concatenate) system prompts and sessions
    if (data['systemPrompts'] != null) {
      final imported = (data['systemPrompts'] as List)
          .map((j) => SystemPromptData.fromJson(j))
          .toList();
      mergeSystemPrompts(imported);
    }

    if (data['sessions'] != null) {
      final imported = (data['sessions'] as List)
          .map((j) => ChatSessionData.fromJson(j))
          .toList();
      mergeSessions(imported);
    }

    // Character card
    if (data['characterCard'] != null) {
      try {
        _characterCard = CharacterCard.fromJson(
            Map<String, dynamic>.from(data['characterCard']));
        _saveCharacterCard();
      } catch (e) {
        debugPrint('Error importing character card: $e');
      }
    }
    if (data['enableCharacterCard'] != null) {
      _enableCharacterCard = data['enableCharacterCard'] as bool;
    }

    // SillyTavern state (lorebook, regex, formatting)
    if (data['sillyTavernState'] != null) {
      try {
        final st =
            Map<String, dynamic>.from(data['sillyTavernState']);
        if (st['globalLorebook'] != null) {
          _globalLorebook = Lorebook.fromJson(
              Map<String, dynamic>.from(st['globalLorebook']));
        }
        if (st['globalRegexScripts'] != null) {
          _globalRegexScripts = (st['globalRegexScripts'] as List)
              .map((j) =>
                  RegexScript.fromJson(Map<String, dynamic>.from(j)))
              .toList();
        }
        if (st['formattingTemplate'] != null) {
          _formattingTemplate = FormattingTemplate.fromJson(
              Map<String, dynamic>.from(st['formattingTemplate']));
        } else {
          _formattingTemplate = null;
        }
        _enableLorebook = st['enableLorebook'] as bool? ?? true;
        _enableRegex = st['enableRegex'] as bool? ?? true;
        _enableFormatting = st['enableFormatting'] as bool? ?? false;
        _saveSillyTavernState();
      } catch (e) {
        debugPrint('Error importing SillyTavern state: $e');
      }
    }

    notifyListeners();
    await saveSettings(showConfirmation: false);
  }

  /// Concatenates imported sessions with existing ones, skipping duplicates by ID.
  void mergeSessions(List<ChatSessionData> incoming) {
    final existingIds = _savedSessions.map((s) => s.id).toSet();
    for (final session in incoming) {
      if (!existingIds.contains(session.id)) {
        _savedSessions.add(session);
        existingIds.add(session.id);
      }
    }
  }

  /// Concatenates imported prompts with existing ones, skipping duplicates by title.
  void mergeSystemPrompts(List<SystemPromptData> incoming) {
    final existingTitles = _savedSystemPrompts.map((p) => p.title).toSet();
    for (final prompt in incoming) {
      if (!existingTitles.contains(prompt.title)) {
        _savedSystemPrompts.add(prompt);
        existingTitles.add(prompt.title);
      }
    }
  }

  List<ModelInfo> _deserializeModels(List<String>? serialized) {
    if (serialized == null) return [];
    return serialized.map<ModelInfo>((s) {
      try {
        final Map<String, dynamic> json = jsonDecode(s);
        return ModelInfo.fromJson(json);
      } catch (e) {
        // Fallback for legacy plain string lists
        return ModelInfo(id: s, name: s);
      }
    }).toList();
  }

  Future<void> refreshCurrentModels() async {
    switch (_currentProvider) {
      case AiProvider.gemini:
        await fetchGeminiModels();
        break;
      case AiProvider.openRouter:
        await fetchOpenRouterModels();
        break;
      case AiProvider.openAi:
        await fetchOpenAiModels();
        break;
      case AiProvider.arliAi:
        await fetchArliAiModels();
        break;
      case AiProvider.nanoGpt:
        await fetchNanoGptModels();
        break;
      case AiProvider.huggingFace:
        await fetchHuggingFaceModels();
        break;
      case AiProvider.groq:
        await fetchGroqModels();
        break;
      case AiProvider.local:
        break;
    }
  }
}
