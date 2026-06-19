import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/file_io_helper.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../models/character_card.dart';
import '../models/lorebook_models.dart';
import '../services/chat_api_service.dart';
import '../services/lorebook_service.dart';
import '../services/prompt_pipeline_service.dart';
import '../services/reasoning_utils.dart';
import '../services/global_settings_service.dart';
import '../services/web_search_service.dart';
import '../services/session_service.dart';
import '../services/model_registry_service.dart';
import '../services/api_key_service.dart';
import '../services/streaming_coordinator_service.dart';
import '../services/strategies/strategy_resolver.dart';
import '../utils/constants.dart';
import 'settings_provider.dart';

/// Central provider for managing chat state, API communication, and settings.
///
/// This class handles session persistence, model configuration for multiple
/// AI providers (Gemini, OpenRouter, OpenAI, etc.), and coordinates the
/// streaming of chat responses.
class ChatProvider extends ChangeNotifier {
  static const String _characterCardKeyV3 = 'airp_character_card_v3';
  static const String _characterCardKeyV2 = 'airp_character_card';

  late final SessionService _sessionService;
  late final ModelRegistryService _modelRegistry;
  late final ApiKeyService _apiKeys;
  late final StreamingCoordinatorService _streamingCoordinator;
  SettingsProvider? _settings;

  void updateSettings(SettingsProvider settings) {
    _settings = settings;
    notifyListeners();
  }

  // --- Background stream infrastructure ---
  bool _nonStreamingLoading = false;

  /// Stores regenerated versions to attach to the next generated message.
  List<String> _pendingRegenerationVersions = [];

  bool get isLoading =>
      _streamingCoordinator.isStreaming(_currentSessionId) ||
      _nonStreamingLoading;
  bool get isCancelled => _streamingCoordinator.isCancelled(_currentSessionId);

  /// Set of session IDs that currently have an active background stream.
  Set<String> get streamingSessionIds =>
      _streamingCoordinator.streamingSessionIds;

  /// Pending background notifications for completed responses.
  List<BackgroundNotification> get pendingNotifications =>
      _streamingCoordinator.pendingNotifications;

  void removeNotification(int index) {
    _streamingCoordinator.removeNotification(index);
  }

  List<ModelInfo> get geminiModelsList => _modelRegistry.getModels(AiProvider.gemini);
  List<ModelInfo> get openRouterModelsList =>
      _modelRegistry.getModels(AiProvider.openRouter);
  List<ModelInfo> get arliAiModelsList =>
      _modelRegistry.getModels(AiProvider.arliAi);
  List<ModelInfo> get nanoGptModelsList =>
      _modelRegistry.getModels(AiProvider.nanoGpt);
  List<ModelInfo> get nvidiaModelsList =>
      _modelRegistry.getModels(AiProvider.nvidia);
  List<ModelInfo> get openAiModelsList =>
      _modelRegistry.getModels(AiProvider.openAi);
  List<ModelInfo> get huggingFaceModelsList =>
      _modelRegistry.getModels(AiProvider.huggingFace);
  List<ModelInfo> get groqModelsList =>
      _modelRegistry.getModels(AiProvider.groq);
  List<ModelInfo> get vertexAiModelsList =>
      _modelRegistry.getModels(AiProvider.vertexAi);
  List<ModelInfo> get blackboxAiModelsList =>
      _modelRegistry.getModels(AiProvider.blackboxAi);
  List<ModelInfo> get minimaxModelsList =>
      _modelRegistry.getModels(AiProvider.minimax);
  List<ModelInfo> get openAiCompatibleModelsList =>
      _modelRegistry.getModels(AiProvider.openAiCompatible);
  List<ModelInfo> get deepseekModelsList =>
      _modelRegistry.getModels(AiProvider.deepseek);
  List<ModelInfo> get ollamaModelsList =>
      _modelRegistry.getModels(AiProvider.ollama);
  List<ModelInfo> get qwenModelsList =>
      _modelRegistry.getModels(AiProvider.qwen);
  List<ModelInfo> get xAiModelsList => _modelRegistry.getModels(AiProvider.xAi);
  List<ModelInfo> get zAiModelsList => _modelRegistry.getModels(AiProvider.zAi);
  List<ModelInfo> get mistralModelsList =>
      _modelRegistry.getModels(AiProvider.mistral);

  bool get isLoadingGeminiModels => _modelRegistry.isLoading(AiProvider.gemini);
  bool get isLoadingOpenRouterModels =>
      _modelRegistry.isLoading(AiProvider.openRouter);
  bool get isLoadingArliAiModels =>
      _modelRegistry.isLoading(AiProvider.arliAi);
  bool get isLoadingNanoGptModels =>
      _modelRegistry.isLoading(AiProvider.nanoGpt);
  bool get isLoadingNvidiaModels =>
      _modelRegistry.isLoading(AiProvider.nvidia);
  bool get isLoadingOpenAiModels =>
      _modelRegistry.isLoading(AiProvider.openAi);
  bool get isLoadingHuggingFaceModels =>
      _modelRegistry.isLoading(AiProvider.huggingFace);
  bool get isLoadingGroqModels => _modelRegistry.isLoading(AiProvider.groq);

  bool get isRefreshingModels => _modelRegistry.isAnyLoading;

  AiProvider _currentProvider = AiProvider.gemini;

  AiProvider get currentProvider => _currentProvider;
  String get geminiKey => _apiKeys.getProviderKey(AiProvider.gemini);
  String get openRouterKey => _apiKeys.getProviderKey(AiProvider.openRouter);
  String get openAiKey => _apiKeys.getProviderKey(AiProvider.openAi);
  String get arliAiKey => _apiKeys.getProviderKey(AiProvider.arliAi);
  String get nanoGptKey => _apiKeys.getProviderKey(AiProvider.nanoGpt);
  String get nvidiaKey => _apiKeys.getProviderKey(AiProvider.nvidia);
  String get huggingFaceKey => _apiKeys.getProviderKey(AiProvider.huggingFace);
  String get groqKey => _apiKeys.getProviderKey(AiProvider.groq);
  String get vertexAiKey => _apiKeys.getProviderKey(AiProvider.vertexAi);
  String get blackboxAiKey => _apiKeys.getProviderKey(AiProvider.blackboxAi);
  String get minimaxKey => _apiKeys.getProviderKey(AiProvider.minimax);
  String get openAiCompatibleKey =>
      _apiKeys.getProviderKey(AiProvider.openAiCompatible);
  String get deepseekKey => _apiKeys.getProviderKey(AiProvider.deepseek);
  String get ollamaKey => _apiKeys.getProviderKey(AiProvider.ollama);
  String get qwenKey => _apiKeys.getProviderKey(AiProvider.qwen);
  String get xAiKey => _apiKeys.getProviderKey(AiProvider.xAi);
  String get zAiKey => _apiKeys.getProviderKey(AiProvider.zAi);
  String get mistralKey => _apiKeys.getProviderKey(AiProvider.mistral);

  String _localIp = ChatDefaults.localIp;
  String _localModelName = 'local-model';
  String _vertexAiEndpoint = '';
  String _openAiCompatibleEndpoint = '';
  String _ollamaEndpoint = 'http://localhost:11434';
  final Set<AiProvider> _starredProviders = {};
  final GlobalSettingsService _globalSettings = GlobalSettingsService();
  String _modelPickerSortMode = GlobalSettingsService.defaultModelSortMode;

  String get localIp => _localIp;
  String get localModelName => _localModelName;
  String get vertexAiEndpoint => _vertexAiEndpoint;
  String get openAiCompatibleEndpoint => _openAiCompatibleEndpoint;
  String get ollamaEndpoint => _ollamaEndpoint;
  Set<AiProvider> get starredProviders => _starredProviders;
  String get modelPickerSortMode => _modelPickerSortMode;

  String _selectedGeminiModel = 'models/gemini-3-flash-preview';
  String _openRouterModel = 'z-ai/glm-4.5-air:free';
  String _arliAiModel = 'Mistral-Nemo-12B-Instruct-v1';
  String _nanoGptModel = 'gpt-4o';
  String _nvidiaModel = 'nvidia/llama-3.1-nemotron-ultra-253b-v1';
  String _openAiModel = 'gpt-4o';
  String _huggingFaceModel = 'meta-llama/Meta-Llama-3-8B-Instruct';
  String _groqModel = 'llama3-8b-8192';
  String _vertexAiModel = '';
  String _blackboxAiModel = '';
  String _minimaxModel = '';
  String _openAiCompatibleModel = '';
  String _deepseekModel = '';
  String _ollamaModel = '';
  String _qwenModel = '';
  String _xAiModel = '';
  String _zAiModel = '';
  String _mistralModel = '';
  String _selectedModel = 'models/gemini-3-flash-preview';

  String get selectedGeminiModel => _selectedGeminiModel;
  String get openRouterModel => _openRouterModel;
  String get arliAiModel => _arliAiModel;
  String get nanoGptModel => _nanoGptModel;
  String get nvidiaModel => _nvidiaModel;
  String get openAiModel => _openAiModel;
  String get huggingFaceModel => _huggingFaceModel;
  String get groqModel => _groqModel;
  String get vertexAiModel => _vertexAiModel;
  String get blackboxAiModel => _blackboxAiModel;
  String get minimaxModel => _minimaxModel;
  String get openAiCompatibleModel => _openAiCompatibleModel;
  String get deepseekModel => _deepseekModel;
  String get ollamaModel => _ollamaModel;
  String get qwenModel => _qwenModel;
  String get xAiModel => _xAiModel;
  String get zAiModel => _zAiModel;
  String get mistralModel => _mistralModel;
  String get selectedModel => _selectedModel;

  /// Returns the maximum context length for the currently selected model.
  int getMaxContext() {
    if (_currentProvider == AiProvider.local) return 32768;

    final currentList = _modelRegistry.getModels(_currentProvider);
    final currentId = _selectedModel;

    try {
      final model = currentList.firstWhere((m) => m.id == currentId);
      return int.tryParse(model.contextLength.replaceAll(',', '')) ?? 1048576;
    } catch (_) {
      return 1048576; // Default fallback
    }
  }

  /// Returns the ModelInfo object for the currently selected model.
  ModelInfo? getCurrentModelInfo() {
    final currentList = _modelRegistry.getModels(_currentProvider);
    final currentId = _selectedModel;

    try {
      return currentList.firstWhere((m) => m.id == currentId);
    } catch (_) {
      return null;
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

  // --- World Lore state ---
  Lorebook _globalLorebook = Lorebook(name: 'Global');
  LorebookEvalResult _lastLorebookEvalResult = const LorebookEvalResult(
    byPosition: {},
    estimatedTokens: 0,
  );
  List<LorebookEntry> _lastRecognizedLoreEntries = const [];
  Color _loreRecognizerGlowColor = Colors.orangeAccent;

  // Web Search (BYOK) Getters passed to _apiKeys
  String get braveApiKey => _apiKeys.getSearchKey(SearchProvider.brave);
  String get tavilyApiKey => _apiKeys.getSearchKey(SearchProvider.tavily);
  String get serperApiKey => _apiKeys.getSearchKey(SearchProvider.serper);

  // --- World Lore getters ---
  Lorebook get globalLorebook => _globalLorebook;
  LorebookEvalResult get lastLorebookEvalResult => _lastLorebookEvalResult;
  List<LorebookEntry> get lastRecognizedLoreEntries =>
      _lastRecognizedLoreEntries;
  Color get loreRecognizerGlowColor => _loreRecognizerGlowColor;
  bool get enableLorebook => _settings!.enableLorebook;

  /// Returns the character-scoped lorebook (from the active character card),
  /// or `null` if no card is loaded or the card has no embedded lorebook.
  Lorebook? get characterLorebook => _characterCard.characterBook;

  List<ChatMessage> _messages = [];
  String? _currentSessionId;
  int _tokenCount = 0;
  String _currentTitle = "";
  String _systemInstruction = "";
  CharacterCard _characterCard = CharacterCard();

  List<ChatMessage> get messages => _messages;
  List<ChatSessionData> get savedSessions => _sessionService.savedSessions;
  String? get currentSessionId => _currentSessionId;
  int get tokenCount => _tokenCount;
  String get currentTitle => _currentTitle;
  String get systemInstruction => _systemInstruction;
  CharacterCard get characterCard => _characterCard;

  List<SystemPromptData> _savedSystemPrompts = [];
  List<SystemPromptData> get savedSystemPrompts => _savedSystemPrompts;

  Set<String> _bookmarkedModels = {};
  Set<String> get bookmarkedModels => _bookmarkedModels;

  late GenerativeModel _model;
  late ChatSession _chat;
  static const _defaultApiKey = '';

  ChatProvider() {
    _sessionService = SessionService(onStateChanged: notifyListeners);
    _modelRegistry = ModelRegistryService(onStateChanged: notifyListeners);
    _apiKeys = ApiKeyService(onStateChanged: notifyListeners);
    _streamingCoordinator =
        StreamingCoordinatorService(onStateChanged: notifyListeners);
    _loadSettings();
    _loadSessions();
    _loadSystemPrompts();
  }

  @override
  void dispose() {
    _sessionService.dispose();
    _streamingCoordinator.dispose();
    _safeDisposeMessageNotifiers(_messages);
    super.dispose();
  }

  Future<void> _loadGlobalSettings(SharedPreferences prefs) async {
    _bookmarkedModels = await _globalSettings.loadModelBookmarks(prefs: prefs);
    _starredProviders
      ..clear()
      ..addAll(await _globalSettings.loadStarredProviders(prefs: prefs));
    _modelPickerSortMode = await _globalSettings.loadModelPickerSortMode(
      prefs: prefs,
    );
  }

  Future<void> toggleModelBookmark(String modelId) async {
    if (_bookmarkedModels.contains(modelId)) {
      _bookmarkedModels.remove(modelId);
    } else {
      _bookmarkedModels.add(modelId);
    }
    notifyListeners();
    await _globalSettings.saveModelBookmarks(_bookmarkedModels);
  }

  Future<void> _loadSessions() async {
    await _sessionService.loadSessions(_shouldStripReasoningFromStorage);
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
    final String? v3Data = prefs.getString(_characterCardKeyV3);
    final String? v2Data = prefs.getString(_characterCardKeyV2);
    final String? data = v3Data ?? v2Data;
    if (data != null) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(data);
        _characterCard = CharacterCard.fromJson(jsonMap);

        // One-time migration: persist to V3 key and remove legacy V2 key.
        if (v3Data == null) {
          await prefs.setString(
            _characterCardKeyV3,
            jsonEncode(_characterCard.toV3Json()),
          );
          await prefs.remove(_characterCardKeyV2);
        }

        notifyListeners();
      } catch (e) {
        debugPrint("Error loading character card: $e");
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await _loadGlobalSettings(prefs);
    await _apiKeys.loadAllKeys();

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
    } else if (providerString == 'nvidia') {
      _currentProvider = AiProvider.nvidia;
    } else if (providerString == 'nanoGptImage') {
      _currentProvider = AiProvider.nanoGpt;
    } else if (providerString == 'huggingFace') {
      _currentProvider = AiProvider.huggingFace;
    } else if (providerString == 'groq') {
      _currentProvider = AiProvider.groq;
    } else if (providerString == 'deepseek') {
      _currentProvider = AiProvider.deepseek;
    } else if (providerString == 'openAiCompatible') {
      _currentProvider = AiProvider.openAiCompatible;
    } else if (providerString == 'vertexAi') {
      _currentProvider = AiProvider.vertexAi;
    } else if (providerString == 'blackboxAi') {
      _currentProvider = AiProvider.blackboxAi;
    } else if (providerString == 'minimax') {
      _currentProvider = AiProvider.minimax;
    } else if (providerString == 'ollama') {
      _currentProvider = AiProvider.ollama;
    } else if (providerString == 'qwen') {
      _currentProvider = AiProvider.qwen;
    } else if (providerString == 'xAi') {
      _currentProvider = AiProvider.xAi;
    } else if (providerString == 'zAi') {
      _currentProvider = AiProvider.zAi;
    } else if (providerString == 'mistral') {
      _currentProvider = AiProvider.mistral;
    } else {
      _currentProvider = AiProvider.gemini;
    }

    await _modelRegistry.loadCachedModels();

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
    _nvidiaModel =
      prefs.getString(ApiConstants.prefModelNvidia) ??
      'nvidia/llama-3.1-nemotron-ultra-253b-v1';
    _openAiModel = prefs.getString(ApiConstants.prefModelOpenAi) ?? 'gpt-4o';
    _huggingFaceModel =
        prefs.getString(ApiConstants.prefModelHuggingFace) ??
        'meta-llama/Meta-Llama-3-8B-Instruct';
    _groqModel =
        prefs.getString(ApiConstants.prefModelGroq) ?? 'llama3-8b-8192';
    _vertexAiModel = prefs.getString(ApiConstants.prefModelVertexAi) ?? _vertexAiModel;
    _blackboxAiModel =
      prefs.getString(ApiConstants.prefModelBlackboxAi) ?? _blackboxAiModel;
    _minimaxModel = prefs.getString(ApiConstants.prefModelMinimax) ?? _minimaxModel;
    _openAiCompatibleModel =
      prefs.getString(ApiConstants.prefModelOpenAiCompatible) ??
      _openAiCompatibleModel;
    _deepseekModel =
      prefs.getString(ApiConstants.prefModelDeepseek) ?? _deepseekModel;
    _ollamaModel = prefs.getString(ApiConstants.prefModelOllama) ?? _ollamaModel;
    _qwenModel = prefs.getString(ApiConstants.prefModelQwen) ?? _qwenModel;
    _xAiModel = prefs.getString(ApiConstants.prefModelXAi) ?? _xAiModel;
    _zAiModel = prefs.getString(ApiConstants.prefModelZAi) ?? _zAiModel;
    _mistralModel = prefs.getString(ApiConstants.prefModelMistral) ?? _mistralModel;

    _selectedModel = _getProviderModel(_currentProvider);

    _systemInstruction =
        prefs.getString('airp_default_system_instruction') ?? '';

    _loreRecognizerGlowColor = Color(
      prefs.getInt('airp_lore_recognizer_glow_color') ??
          Colors.orangeAccent.toARGB32(),
    );

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

  // --- Lorebook / Regex / Formatting setters ---

  void setGlobalLorebook(Lorebook lorebook) {
    _globalLorebook = lorebook;
    notifyListeners();
    _saveSillyTavernState();
  }

  void setEnableLorebook(bool enable) {
    _settings!.setEnableLorebook(enable);
    notifyListeners();
    _saveSillyTavernState();
  }

  void setEnableCharacterCard(bool enable) {
    _settings!.setEnableCharacterCard(enable);
    notifyListeners();
    _saveEnableCharacterCard();
    if (_currentProvider == AiProvider.gemini) {
      initializeModel();
    }
  }

  Future<void> _saveEnableCharacterCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('airp_enable_character_card', _settings!.enableCharacterCard);
  }

  /// Persists SillyTavern state (World Lore) to SharedPreferences.
  Future<void> _saveSillyTavernState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'airp_global_lorebook',
      jsonEncode(_globalLorebook.toJson()),
    );
    await prefs.setBool('airp_enable_lorebook', _settings!.enableLorebook);
  }

  /// Loads SillyTavern state (World Lore) from SharedPreferences.
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
  }

  void setCharacterCard(CharacterCard card) {
    _characterCard = card;

    // Auto-load embedded character book and regex scripts.
    // The characterBook and regexScripts are stored on the card itself and
    // accessed via getters (characterLorebook, characterRegexScripts), so
    // no additional state assignment is needed — they become active
    // automatically when _settings!.enableCharacterCard and _settings!.enableLorebook/_enableRegex
    // are true.

    notifyListeners();
    _saveCharacterCard();
    if (_currentProvider == AiProvider.gemini) {
      initializeModel();
    }
  }

  Future<void> _saveCharacterCard() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_characterCard.toV3Json());
    await prefs.setString(_characterCardKeyV3, data);
    await prefs.remove(_characterCardKeyV2);
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
      case AiProvider.nvidia:
        return _nvidiaModel;
      case AiProvider.openAi:
        return _openAiModel;
      case AiProvider.huggingFace:
        return _huggingFaceModel;
      case AiProvider.groq:
        return _groqModel;
      case AiProvider.vertexAi:
        return _vertexAiModel;
      case AiProvider.blackboxAi:
        return _blackboxAiModel;
      case AiProvider.minimax:
        return _minimaxModel;
      case AiProvider.openAiCompatible:
        return _openAiCompatibleModel;
      case AiProvider.deepseek:
        return _deepseekModel;
      case AiProvider.ollama:
        return _ollamaModel;
      case AiProvider.qwen:
        return _qwenModel;
      case AiProvider.xAi:
        return _xAiModel;
      case AiProvider.zAi:
        return _zAiModel;
      case AiProvider.mistral:
        return _mistralModel;
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
      case AiProvider.nvidia:
        _nvidiaModel = model;
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
      case AiProvider.vertexAi:
        _vertexAiModel = model;
        break;
      case AiProvider.blackboxAi:
        _blackboxAiModel = model;
        break;
      case AiProvider.minimax:
        _minimaxModel = model;
        break;
      case AiProvider.openAiCompatible:
        _openAiCompatibleModel = model;
        break;
      case AiProvider.deepseek:
        _deepseekModel = model;
        break;
      case AiProvider.ollama:
        _ollamaModel = model;
        break;
      case AiProvider.qwen:
        _qwenModel = model;
        break;
      case AiProvider.xAi:
        _xAiModel = model;
        break;
      case AiProvider.zAi:
        _zAiModel = model;
        break;
      case AiProvider.mistral:
        _mistralModel = model;
        break;
      case AiProvider.local:
        break;
    }
  }

  String _getProviderKey(AiProvider provider) {
    if (provider == AiProvider.local) return "local-key";
    return _apiKeys.getProviderKey(provider);
  }

  void _setProviderKey(AiProvider provider, String key) {
    _apiKeys.setProviderKey(provider, key);
  }

  void setVertexAiEndpoint(String val) {
    _vertexAiEndpoint = val;
    notifyListeners();
  }

  void setOpenAiCompatibleEndpoint(String val) {
    _openAiCompatibleEndpoint = val;
    notifyListeners();
  }

  void setOllamaEndpoint(String val) {
    _ollamaEndpoint = val;
    notifyListeners();
  }

  void toggleProviderStar(AiProvider provider) {
    if (_starredProviders.contains(provider)) {
      _starredProviders.remove(provider);
    } else {
      _starredProviders.add(provider);
    }
    notifyListeners();
    _globalSettings.saveStarredProviders(_starredProviders);
  }

  Future<void> setModelPickerSortMode(String sortMode) async {
    final normalized = GlobalSettingsService.normalizeSortMode(sortMode);
    if (normalized == _modelPickerSortMode) {
      return;
    }
    _modelPickerSortMode = normalized;
    notifyListeners();
    await _globalSettings.saveModelPickerSortMode(_modelPickerSortMode);
  }


  void setBraveApiKey(String val) {
    _apiKeys.setSearchKey(SearchProvider.brave, val);
  }

  void setTavilyApiKey(String val) {
    _apiKeys.setSearchKey(SearchProvider.tavily, val);
  }

  void setSerperApiKey(String val) {
    _apiKeys.setSearchKey(SearchProvider.serper, val);
  }

  Future<void> setPersistReasoningBlocks(bool val) async {
    if (_settings!.persistReasoningBlocks == val &&
        (val || !_settings!.enableReasoningEfficiency)) {
      return;
    }
    _settings!.setPersistReasoningBlocks(val);
    _settings!.setEnableReasoningEfficiency(!val);
    _normalizeReasoningStorageMode();
    notifyListeners();
    await _applyReasoningStoragePolicyGlobally();
  }

  void setLoreRecognizerGlowColor(Color color) {
    _loreRecognizerGlowColor = color;
    notifyListeners();
  }

  Future<void> saveSettings({bool showConfirmation = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.prefLocalIp, _localIp);
    await prefs.setString(ApiConstants.prefLocalModelName, _localModelName);
    await prefs.setString('airp_provider', _currentProvider.name);
    await prefs.setString(ApiConstants.prefModelGemini, _selectedGeminiModel);
    await prefs.setString(ApiConstants.prefModelOpenRouter, _openRouterModel);
    await prefs.setString(ApiConstants.prefModelArliAi, _arliAiModel);
    await prefs.setString(ApiConstants.prefModelNanoGpt, _nanoGptModel);
    await prefs.setString(ApiConstants.prefModelNvidia, _nvidiaModel);
    await prefs.setString(ApiConstants.prefModelOpenAi, _openAiModel);
    await prefs.setString(ApiConstants.prefModelHuggingFace, _huggingFaceModel);
    await prefs.setString(ApiConstants.prefModelGroq, _groqModel);
    await prefs.setString(ApiConstants.prefModelVertexAi, _vertexAiModel);
    await prefs.setString(ApiConstants.prefModelBlackboxAi, _blackboxAiModel);
    await prefs.setString(ApiConstants.prefModelMinimax, _minimaxModel);
    await prefs.setString(
      ApiConstants.prefModelOpenAiCompatible,
      _openAiCompatibleModel,
    );
    await prefs.setString(ApiConstants.prefModelDeepseek, _deepseekModel);
    await prefs.setString(ApiConstants.prefModelOllama, _ollamaModel);
    await prefs.setString(ApiConstants.prefModelQwen, _qwenModel);
    await prefs.setString(ApiConstants.prefModelXAi, _xAiModel);
    await prefs.setString(ApiConstants.prefModelZAi, _zAiModel);
    await prefs.setString(ApiConstants.prefModelMistral, _mistralModel);
    
    await prefs.setString(
      'airp_default_system_instruction',
      _systemInstruction,
    );

    await prefs.setInt(
      'airp_lore_recognizer_glow_color',
      _loreRecognizerGlowColor.toARGB32(),
    );
    await _globalSettings.saveModelBookmarks(_bookmarkedModels, prefs: prefs);
    await _globalSettings.saveStarredProviders(_starredProviders, prefs: prefs);
    await _globalSettings.saveModelPickerSortMode(
      _modelPickerSortMode,
      prefs: prefs,
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

  /// Whether the current provider can drive the AI-initiated `web_search`
  /// function tool (i.e. supports OpenAI-style function calling or Gemini
  /// function declarations). Used to gate the web-search toggle in the UI.
  ///
  /// HuggingFace's free router does not reliably support function calling, so
  /// it is excluded. All other providers (OpenAI-compatible + Gemini) are
  /// considered capable; individual models that ignore the tool simply answer
  /// without searching.
  bool supportsWebSearchTool() {
    switch (_currentProvider) {
      case AiProvider.huggingFace:
        return false;
      default:
        return true;
    }
  }

  /// Returns `null` if web search can be enabled with the current provider +
  /// selected search backend, or a short human-readable reason string
  /// otherwise. Used to gate the web-search toggle in the UI.
  String? webSearchUnsupportedReason() {
    if (_settings!.searchProvider == SearchProvider.provider) {
      // Native grounding is only wired up for specific providers.
      switch (_currentProvider) {
        case AiProvider.gemini:
        case AiProvider.openRouter:
        case AiProvider.arliAi:
        case AiProvider.nanoGpt:
          return null;
        default:
          return 'Native grounding isn\'t available on this provider. '
              'Use a BYOK backend (SearXNG, Brave, Tavily, Serper, DDG) in '
              'Web Search settings.';
      }
    }
    // BYOK tool mode requires function-calling support.
    if (!supportsWebSearchTool()) {
      return 'This provider doesn\'t support AI-driven web search tool '
          'calls. Pick another provider or use native grounding on Gemini.';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BYOK Web Search Tool-Call Loop
  // ─────────────────────────────────────────────────────────────────────────

  /// Outcome of a BYOK web-search tool-call loop for a single user message.
  ///
  /// - [directAnswer]: the model produced a final answer (either without
  ///   calling the tool, or — for Gemini — after gathering tool results via a
  ///   final non-streamed call). The caller displays it without streaming.
  /// - [extraMessages]: accumulated assistant `tool_calls` + `role:"tool"`
  ///   result messages (OpenAI-compatible) to append to the final STREAMED
  ///   answer request. Mutually exclusive with [directAnswer].
  /// - [error]: the detection phase failed; surface as an error message.
  Future<_WebSearchLoopResult> _runWebSearchToolLoop({
    required String sentUserText,
    required List<ChatMessage> history,
    required List<LorebookEntry> recognizedLoreEntries,
    required LorebookEvalResult lorebookResult,
    required List<Map<String, dynamic>> depthEntries,
    required ValueNotifier<String> contentNotifier,
    required String streamSessionId,
  }) async {
    final int maxRounds = _settings!.maxSearchRounds;
    final String hint = WebSearchService.buildWebSearchSystemHint(
      maxRounds: maxRounds,
    );

    String baseSys = _buildSystemInstruction(
      lorebookResult: lorebookResult,
      recognizedLoreEntries: recognizedLoreEntries,
    );
    if (depthEntries.isNotEmpty) {
      for (final de in depthEntries) {
        baseSys += '\n\n${de['content']}';
      }
    }
    final String sysWithHint = '$baseSys$hint';

    final bool isGemini = _currentProvider == AiProvider.gemini;
    final String activeKey = _getProviderKey(_currentProvider);
    final strategy = StrategyResolver.resolve(_currentProvider);
    String? customUrl;
    if (_currentProvider == AiProvider.local) {
      customUrl = _localIp.trim();
    } else if (_currentProvider == AiProvider.openAiCompatible) {
      customUrl = _openAiCompatibleEndpoint.trim();
    } else if (_currentProvider == AiProvider.vertexAi) {
      customUrl = _vertexAiEndpoint.trim();
    }
    final String streamUrl = strategy.getStreamUrl(customUrl: customUrl);
    final String modelName =
        _currentProvider == AiProvider.local ? _localModelName : _selectedModel;

    final List<Map<String, dynamic>> openAiExtras = [];
    final List<Map<String, dynamic>> geminiExtras = [];

    for (int round = 0; round < maxRounds; round++) {
      if (_streamingCoordinator.isCancelled(streamSessionId)) {
        return _WebSearchLoopResult(
          extraMessages: openAiExtras.isNotEmpty ? openAiExtras : null,
        );
      }

      ToolDetectionResult det;
      if (isGemini) {
        final gemKey = geminiKey.isNotEmpty ? geminiKey : _defaultApiKey;
        det = await ChatApiService.performGeminiFunctionDetection(
          apiKey: gemKey,
          model: _selectedModel,
          history: history,
          userMessage: sentUserText,
          systemInstruction: sysWithHint,
          functionDeclarations:
              WebSearchService.buildGeminiFunctionDeclarations(),
          extraMessages: geminiExtras.isNotEmpty ? geminiExtras : null,
          disableSafety: _settings!.disableSafety,
          maxRoundsLeft: 1,
        );
      } else {
        det = await ChatApiService.requestOpenAiCompatibleWithToolDetection(
          apiKey: activeKey,
          baseUrl: streamUrl,
          model: modelName,
          history: history,
          systemInstruction: sysWithHint,
          userMessage: sentUserText,
          tools: [WebSearchService.buildWebSearchToolSpec()],
          extraMessages: openAiExtras.isNotEmpty ? openAiExtras : null,
          temperature:
              _settings!.enableGenerationSettings ? _settings!.temperature : null,
          topP: _settings!.enableGenerationSettings ? _settings!.topP : null,
          maxTokens:
              _settings!.enableMaxOutputTokens ? _settings!.maxOutputTokens : null,
          reasoningEffort:
              _settings!.enableReasoning ? _settings!.reasoningEffort : null,
          extraHeaders: strategy.getHeaders(activeKey),
          maxRoundsLeft: 1,
        );
      }

      if (det.isError) {
        return _WebSearchLoopResult(error: det.text);
      }

      if (!det.isToolCall) {
        // The model produced a final answer without (further) tool use.
        final answer =
            det.text.trim().isNotEmpty ? det.text : det.reasoning;
        return _WebSearchLoopResult(directAnswer: answer);
      }

      // ── Tool call: extract the AI-generated query and execute it ──
      final query = WebSearchService.extractQueryFromToolArgs(det.toolArguments);
      if (query == null) {
        // Malformed tool call — abandon the loop and let the final streamed
        // answer proceed with whatever context we have (likely none).
        return _WebSearchLoopResult(
          extraMessages: openAiExtras.isNotEmpty ? openAiExtras : null,
        );
      }

      // Show a transient "Searching the web for …" indicator on the
      // placeholder bubble so the user can see the AI's chosen query.
      final indicator = '🔍 Searching the web for "$query"…';
      contentNotifier.value = indicator;
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        _messages.last = _messages.last.copyWith(text: indicator);
        notifyListeners();
      }

      final resultText = await WebSearchService.executeSearch(
        provider: _settings!.searchProvider,
        query: query,
        braveApiKey: braveApiKey,
        tavilyApiKey: tavilyApiKey,
        serperApiKey: serperApiKey,
        searxngUrl: _settings!.searxngUrl,
        resultCount: _settings!.searchResultCount,
      );

      // Record the assistant tool call + tool result for the next round /
      // final answer.
      if (isGemini) {
        Map<String, dynamic> argsObj;
        try {
          argsObj = det.toolArguments.trim().isEmpty
              ? {}
              : jsonDecode(det.toolArguments) as Map<String, dynamic>;
        } catch (_) {
          argsObj = {'query': query};
        }
        geminiExtras.add({
          'role': 'model',
          'parts': [
            {'functionCall': {'name': det.toolName, 'args': argsObj}},
          ],
        });
        geminiExtras.add(
          ChatApiService.geminiToolResultContent(
            functionName: det.toolName,
            resultText: resultText,
          ),
        );
      } else {
        final callId =
            det.toolCallId.isNotEmpty ? det.toolCallId : 'call_$round';
        openAiExtras.add({
          'role': 'assistant',
          'content': det.reasoning.isNotEmpty ? det.reasoning : null,
          'tool_calls': [
            {
              'id': callId,
              'type': 'function',
              'function': {
                'name': det.toolName,
                'arguments': det.toolArguments,
              },
            },
          ],
        });
        openAiExtras.add({
          'role': 'tool',
          'tool_call_id': callId,
          'content': resultText,
        });
      }
    }

    // ── Rounds exhausted: force a final answer ──
    if (isGemini) {
      final gemKey = geminiKey.isNotEmpty ? geminiKey : _defaultApiKey;
      final det = await ChatApiService.performGeminiFunctionDetection(
        apiKey: gemKey,
        model: _selectedModel,
        history: history,
        userMessage: sentUserText,
        systemInstruction: sysWithHint,
        functionDeclarations:
            WebSearchService.buildGeminiFunctionDeclarations(),
        extraMessages: geminiExtras.isNotEmpty ? geminiExtras : null,
        disableSafety: _settings!.disableSafety,
        maxRoundsLeft: 0,
      );
      if (det.isError) return _WebSearchLoopResult(error: det.text);
      final answer = det.text.trim().isNotEmpty ? det.text : det.reasoning;
      return _WebSearchLoopResult(directAnswer: answer);
    }

    // OpenAI-compatible: stream the final answer with the accumulated tool
    // messages appended (the streaming request does not attach `tools`, so the
    // model is forced to answer from the gathered context).
    return _WebSearchLoopResult(
      extraMessages: openAiExtras.isNotEmpty ? openAiExtras : null,
    );
  }

  String getEditableMessageText(ChatMessage message) {
    if (message.isUser) return message.text;
    if (_settings!.enableDeveloperMode && _settings!.enableRawReasoningEdit) return message.text;
    return ReasoningUtils.split(message.text).content;
  }

  String getReadOnlyReasoningForEdit(ChatMessage message) {
    if (message.isUser) return '';
    if (_settings!.enableDeveloperMode && _settings!.enableRawReasoningEdit) return '';
    return ReasoningUtils.split(message.text).reasoning;
  }

  void _normalizeReasoningStorageMode() {
    // Keep modes mutually exclusive to avoid contradictory toggle states.
    if (_settings!.enableReasoningEfficiency) {
      _settings!.setPersistReasoningBlocks(false);
      return;
    }
    if (_settings!.persistReasoningBlocks) {
      _settings!.setEnableReasoningEfficiency(false);
      return;
    }
    _settings!.setPersistReasoningBlocks(true);
  }

  bool get _shouldStripReasoningFromStorage =>
      _settings?.enableReasoningEfficiency == true || 
      (_settings?.persistReasoningBlocks == false);

  Future<void> _applyReasoningStoragePolicyGlobally() async {
    await _sessionService.applyReasoningStoragePolicyGlobally(
      _settings!.enableReasoningEfficiency,
      _settings!.persistReasoningBlocks,
    );
  }

  Future<bool> hasSessionsBackup() => _sessionService.hasSessionsBackup();

  Future<int?> getLatestSessionsBackupTimestamp() =>
      _sessionService.getLatestSessionsBackupTimestamp();

  Future<bool> restoreLatestSessionsBackup() =>
      _sessionService.restoreLatestSessionsBackup();

  /// Returns lore entries whose keywords match [input] directly.
  ///
  /// This powers the input recognizer flow and intentionally ignores
  /// history-based matching.
  List<LorebookEntry> recognizeLoreEntriesFromInput(String input) {
    final trimmed = input.trim();
    if (!_settings!.enableLorebook || trimmed.isEmpty) return const [];

    final lorebooks = <Lorebook>[
      if (_globalLorebook.entries.isNotEmpty) _globalLorebook,
      if (_settings!.enableCharacterCard && _characterCard.characterBook != null)
        _characterCard.characterBook!,
    ];
    if (lorebooks.isEmpty) return const [];

    final matched = <LorebookEntry>[];
    for (final lorebook in lorebooks) {
      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: [trimmed],
        characterName: _characterCard.name,
      );
      matched.addAll(result.all);
    }

    matched.sort((a, b) => a.order.compareTo(b.order));
    return matched;
  }

  LorebookEntry? previewRecognizedLoreEntry(String input) {
    final matched = recognizeLoreEntriesFromInput(input);
    return matched.isEmpty ? null : matched.first;
  }

  /// Collects depth-positioned entries from lorebook results and the character
  /// card into a flat list of `{content, depth, role}` maps.
  List<Map<String, dynamic>> _collectDepthEntries(
    LorebookEvalResult lorebookResult,
  ) {
    return PromptPipelineService.collectDepthEntries(
      lorebookResult: lorebookResult,
      characterCard: _characterCard,
      enableCharacterCard: _settings!.enableCharacterCard,
    );
  }

  /// Constructs the full system instruction including Main Prompt, Advanced
  /// Prompt, Character Card, and optionally lorebook entries.
  ///
  /// When [lorebookResult] is provided, activated entries are injected at
  /// their declared positions (beforeCharDefs, afterCharDefs, etc.).
  /// `atDepth` entries are NOT included here — use [_collectDepthEntries]
  /// for those.
  String _buildSystemInstruction({
    LorebookEvalResult? lorebookResult,
    List<LorebookEntry> recognizedLoreEntries = const [],
  }) {
    return PromptPipelineService.buildSystemInstruction(
      systemInstruction: _systemInstruction,
      enableSystemPrompt: _settings!.enableSystemPrompt,
      enableCharacterCard: _settings!.enableCharacterCard,
      characterCard: _characterCard,
      lorebookResult: lorebookResult,
      recognizedLoreEntries: recognizedLoreEntries,
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
      final List<SafetySetting> safetySettings = _settings!.disableSafety
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
          _settings!.enableReasoning &&
          (_settings!.reasoningEffort != "none" || _selectedModel.contains("thinking"))) {
        finalSystemInstruction +=
            "\n\n[SYSTEM: You are a reasoning model. You MUST enclose your internal thought process in <think> and </think> tags before your final response.";
        if (_settings!.reasoningEffort != "none") {
          finalSystemInstruction += " Reasoning Effort: $_settings!.reasoningEffort.";
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
          temperature: _settings!.enableGenerationSettings ? _settings!.temperature : null,
          topP: _settings!.enableGenerationSettings ? _settings!.topP : null,
          topK: _settings!.enableGenerationSettings ? _settings!.topK : null,
          maxOutputTokens: _settings!.enableMaxOutputTokens ? _settings!.maxOutputTokens : null,
        ),
        safetySettings: safetySettings,
      );

      List<Content> history = [];
      int effectiveHistoryLimit = _settings!.enableMsgHistory ? _settings!.historyLimit : 0;
      int startIndex = _messages.length - effectiveHistoryLimit;
      if (startIndex < 0) startIndex = 0;
      final limitedMessages = _messages.sublist(startIndex);

      for (var msg in limitedMessages) {
        final String role = msg.isUser ? 'user' : 'model';
        final String contextText = msg.isUser
            ? msg.text
            : ChatMessage.sanitizeForContext(msg.text);
        if (msg.isUser && msg.imagePaths.isNotEmpty) {
          List<Part> parts = [];
          if (contextText.isNotEmpty) parts.add(TextPart(contextText));
          for (String path in msg.imagePaths) {
            if (await FileIOHelper.fileExists(path)) {
              final bytes = await FileIOHelper.readBytes(path);
              final mimeType = path.toLowerCase().endsWith('.png')
                  ? 'image/png'
                  : 'image/jpeg';
              parts.add(DataPart(mimeType, bytes));
            }
          }
          history.add(Content(role, parts));
        } else if (history.isNotEmpty && history.last.role == role) {
          final List<Part> existingParts = history.last.parts.toList();
          existingParts.add(TextPart("\n\n$contextText"));
          history[history.length - 1] = Content(role, existingParts);
        } else {
          history.add(
            msg.isUser
                ? Content.text(contextText)
                : Content.model([TextPart(contextText)]),
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
    List<String> imagesToSend, {
    Map<String, Uint8List>? attachmentBytes,
  }) async {
    if (messageText.isEmpty && imagesToSend.isEmpty) return;

    // Ensure session ID exists before sending
    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final String streamSessionId = _currentSessionId!;

    _messages.add(
      ChatMessage(text: messageText, isUser: true, imagePaths: imagesToSend),
    );
    notifyListeners();

    _scheduleAutoSave();

    // --- Input-based lore recognition ---
    final recognizedLoreEntries = recognizeLoreEntriesFromInput(messageText);
    _lastRecognizedLoreEntries = recognizedLoreEntries;
    const lorebookResult = LorebookEvalResult(byPosition: {}, estimatedTokens: 0);
    _lastLorebookEvalResult = lorebookResult;
    final depthEntries = _collectDepthEntries(lorebookResult);

    String sentUserText = messageText;

    if (_settings!.enableGrounding &&
        _currentProvider == AiProvider.gemini &&
        imagesToSend.isEmpty &&
        _settings!.searchProvider == SearchProvider.provider) {
      try {
        _nonStreamingLoading = true;
        notifyListeners();

        final activeKey = geminiKey.isNotEmpty ? geminiKey : _defaultApiKey;

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

        String finalSystemInstruction = _buildSystemInstruction(
          lorebookResult: lorebookResult,
          recognizedLoreEntries: recognizedLoreEntries,
        );

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
          disableSafety: _settings!.disableSafety,
          thoughtSignature: previousSignature,
        );

        if (_streamingCoordinator.isCancelled(streamSessionId)) {
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

    final contentNotifier = ValueNotifier<String>("");

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

    // ── BYOK Web Search Tool-Call Loop ───────────────────────────────────────
    // When web search is ON with a BYOK backend (not the AI provider's native
    // grounding), we expose a `web_search` function tool and let the model
    // decide whether/what to search — instead of the old behaviour of
    // pre-searching every message with the user's literal text.
    //
    // The loop runs up to `maxSearchRounds` non-streamed detection rounds. If
    // the model answers without calling the tool, that text is shown directly
    // (fast path). If the model calls the tool, we execute the search, append
    // the tool result, and — for OpenAI-compatible providers — stream the final
    // answer with the tool context. Gemini's final answer is non-streamed.
    final bool byokToolMode = _settings!.webSearchToolEnabled;
    List<Map<String, dynamic>>? toolExtraMessages;
    String? byokDirectAnswer;

    if (byokToolMode && imagesToSend.isEmpty && supportsWebSearchTool()) {
      try {
        _nonStreamingLoading = true;
        notifyListeners();

        final loopResult = await _runWebSearchToolLoop(
          sentUserText: sentUserText,
          history: _messages.sublist(0, _messages.length - 2),
          recognizedLoreEntries: recognizedLoreEntries,
          lorebookResult: lorebookResult,
          depthEntries: depthEntries,
          contentNotifier: contentNotifier,
          streamSessionId: streamSessionId,
        );

        if (_streamingCoordinator.isCancelled(streamSessionId)) {
          _nonStreamingLoading = false;
          notifyListeners();
          return;
        }

        if (loopResult.error != null) {
          _nonStreamingLoading = false;
          _messages.last = _messages.last.copyWith(
            text: loopResult.error!,
            clearContentNotifier: true,
          );
          notifyListeners();
          _scheduleAutoSave();
          return;
        }

        byokDirectAnswer = loopResult.directAnswer;
        toolExtraMessages = loopResult.extraMessages;
      } catch (e) {
        debugPrint('[WebSearch] tool loop failed: $e');
      } finally {
        _nonStreamingLoading = false;
        notifyListeners();
      }
    }

    // Fast path: the model produced a final answer without streaming (either
    // it answered directly, or — for Gemini — after gathering tool results).
    if (byokDirectAnswer != null) {
      final direct = byokDirectAnswer;
      _messages.last = _messages.last.copyWith(
        text: direct,
        clearContentNotifier: true,
      );
      notifyListeners();
      _scheduleAutoSave();
      if (_currentProvider == AiProvider.gemini) {
        await initializeModel();
      }
      if (!_settings!.enableGrounding) updateTokenCount();
      return;
    }

    Stream<String>? responseStream;

    try {
      final strategy = StrategyResolver.resolve(_currentProvider);
      final activeKey = _getProviderKey(_currentProvider);

      String? customUrl;
      if (_currentProvider == AiProvider.local) {
        customUrl = _localIp.trim();
      } else if (_currentProvider == AiProvider.openAiCompatible) {
        customUrl = _openAiCompatibleEndpoint.trim();
      } else if (_currentProvider == AiProvider.vertexAi) {
        customUrl = _vertexAiEndpoint.trim();
      }

      String finalSystemInstruction = _buildSystemInstruction(
        lorebookResult: lorebookResult,
        recognizedLoreEntries: recognizedLoreEntries,
      );
      if (depthEntries.isNotEmpty) {
        for (final de in depthEntries) {
          finalSystemInstruction += '\n\n${de['content']}';
        }
      }

      // In BYOK tool mode with gathered results, the tool context is delivered
      // via [toolExtraMessages]; the user message itself is unmodified.
      final String finalUserMessage = sentUserText;

      if (_currentProvider == AiProvider.gemini) {
        await initializeModel(systemInstructionOverride: finalSystemInstruction);
      }

      final contextMessages = _messages.sublist(0, _messages.length - 2);
      int effectiveHistoryLimit = _settings!.enableMsgHistory ? _settings!.historyLimit : 0;
      int startIndex = contextMessages.length - effectiveHistoryLimit;
      if (startIndex < 0) startIndex = 0;
      final limitedHistory = contextMessages.sublist(startIndex);

      responseStream = strategy.streamResponse(
        apiKey: activeKey,
        baseUrl: strategy.getStreamUrl(customUrl: customUrl),
        model:
            _currentProvider == AiProvider.local
                ? _localModelName
                : _selectedModel,
        history: limitedHistory,
        systemInstruction: finalSystemInstruction,
        userMessage: finalUserMessage,
        imagePaths: imagesToSend,
        temperature: _settings!.enableGenerationSettings ? _settings!.temperature : null,
        topP: _settings!.enableGenerationSettings ? _settings!.topP : null,
        topK: _settings!.enableGenerationSettings ? _settings!.topK : null,
        maxTokens: _settings!.enableMaxOutputTokens ? _settings!.maxOutputTokens : null,
        enableGrounding:
            _settings!.enableGrounding && _settings!.searchProvider == SearchProvider.provider,
        reasoningEffort: _settings!.enableReasoning ? _settings!.reasoningEffort : null,
        extraHeaders: strategy.getHeaders(activeKey),
        includeUsage: _settings!.enableUsage,
        depthMessages: depthEntries.isNotEmpty ? depthEntries : null,
        attachmentBytes: attachmentBytes,
        extraMessages: toolExtraMessages,
        providerSession: _currentProvider == AiProvider.gemini ? _chat : null,
      );

      _streamingCoordinator.registerStream(
        sessionId: streamSessionId,
        modelName:
            _currentProvider == AiProvider.local
                ? _localModelName
                : _selectedModel,
        contentNotifier: contentNotifier,
        stream: responseStream,
        onUpdate: (sessionId, text, usage) {
          if (usage != null && _currentSessionId == sessionId) {
            _messages.last = _messages.last.copyWith(usage: usage);
            notifyListeners();
          } else if (text.isNotEmpty && _currentSessionId == sessionId) {
            _messages.last = _messages.last.copyWith(text: text);
          }
        },
        onThoughtSignature: (sessionId, sig) {
          if (_currentSessionId == sessionId) {
            _messages.last = _messages.last.copyWith(thoughtSignature: sig);
            notifyListeners();
          }
        },
        onError: (sessionId, errorText) {
          if (_currentSessionId == sessionId) {
            _messages.last = _messages.last.copyWith(
              text: errorText,
              clearContentNotifier: true,
            );
            notifyListeners();
          } else {
            _finalizeBackgroundSession(sessionId, errorText);
          }
        },
        onDone: (sessionId, finalText, reasoningRecovered) async {
          if (_shouldStripReasoningFromStorage) {
            finalText = ChatMessage.sanitizeForContext(finalText);
          }

          if (_currentSessionId == sessionId) {
            final lastMessage = _messages.last;
            final updatedVersions = List<String>.from(
              lastMessage.regenerationVersions,
            );
            if (updatedVersions.isNotEmpty &&
                finalText.isNotEmpty &&
                !updatedVersions.contains(finalText)) {
              updatedVersions.add(finalText);
            }

            _messages.last = lastMessage.copyWith(
              text: finalText,
              reasoningRecovered: reasoningRecovered,
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

            if (!_settings!.enableGrounding) updateTokenCount();
          } else {
            // Background completion: update saved session and show notification
            _finalizeBackgroundSession(
              sessionId,
              finalText,
              reasoningRecovered: reasoningRecovered,
            );
            _showBackgroundNotification(sessionId, finalText);
          }
        },
      );
    } catch (e) {
      if (!_streamingCoordinator.isCancelled(streamSessionId)) {
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
      _streamingCoordinator.cancelStream(streamSessionId);
    }
  }

  void _finalizeBackgroundSession(
    String sessionId,
    String finalText, {
    bool reasoningRecovered = false,
  }) {
    _sessionService.finalizeBackgroundSession(
      sessionId,
      finalText,
      reasoningRecovered,
      _shouldStripReasoningFromStorage,
    );
  }

  /// Adds a message to a saved session (e.g. for grounding results arriving after switch).
  void _addMessageToSavedSession(String sessionId, ChatMessage message) {
    _sessionService.addMessageToSavedSession(sessionId, message);
  }

  /// Shows a notification for a background stream that completed.
  void _showBackgroundNotification(String sessionId, String text) {
    final idx = savedSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;

    final session = savedSessions[idx];
    final modelName =
        _streamingCoordinator.getActiveStreamModel(sessionId) ??
        session.modelName;
    final preview = text.length > 120 ? "${text.substring(0, 120)}..." : text;

    _streamingCoordinator.addNotification(
      BackgroundNotification(
        sessionTitle: session.title,
        messagePreview: preview,
        modelName: modelName,
      ),
    );
  }

  void cancelGeneration() async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;

    _nonStreamingLoading = false;

    // Finalize the current message safely (remove contentNotifier)
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      _messages.last = _messages.last.copyWith(clearContentNotifier: true);
    }

    await _streamingCoordinator.cancelStream(sessionId);
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

  /// Creates a new conversation branch using only the specified message.
  /// Returns the new session ID.
  String createBranchFromMessage(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= _messages.length) return "";

    final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    // Branch: start new conversation with only the selected message
    final selectedMessage = _messages[messageIndex].copyWith(
      clearContentNotifier: true,
    );
    final branchedMessages = [selectedMessage];

    final newSession = ChatSessionData(
      id: newSessionId,
      title: "Branched Conversation",
      messages: branchedMessages,
      modelName: _selectedModel,
      tokenCount: 0,
      systemInstruction: _systemInstruction,
      backgroundImage: null,
      provider: _currentProvider.name,
      isBookmarked: false,
    );

    _sessionService.prependSession(newSession);
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

    final messagesSnapshot = _shouldStripReasoningFromStorage
        ? _messages.map(ChatMessage.sanitizeForStorage).toList()
        : List<ChatMessage>.from(_messages);
    final tokenCountSnapshot = _tokenCount;
    final modelNameSnapshot = _selectedModel;
    final providerNameSnapshot = _currentProvider.name;
    final finalSystemInstruction = _buildSystemInstruction();

    String? currentBg = backgroundImagePath;
    bool isBookmarked = false;
    if (!clearBackground && currentBg == null) {
      currentBg = _sessionService.getSessionBackgroundImage(sessionId);
      isBookmarked = _sessionService.getSessionIsBookmarked(sessionId);
    } else {
      isBookmarked = _sessionService.getSessionIsBookmarked(sessionId);
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
      isBookmarked: isBookmarked,
    );

    _sessionService.saveCurrentSessionData(sessionData);
  }

  Future<void> bookmarkSession(String sessionId, bool isBookmarked) async {
    await _sessionService.bookmarkSession(sessionId, isBookmarked);
  }

  void createNewSession({bool saveCurrentSession = true}) {
    // Save current session before switching if it has content
    if (saveCurrentSession && _messages.isNotEmpty) {
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
    } else if (session.provider == 'vertexAi') {
      _currentProvider = AiProvider.vertexAi;
      _selectedModel = session.modelName;
      _vertexAiModel = session.modelName;
    } else if (session.provider == 'blackboxAi') {
      _currentProvider = AiProvider.blackboxAi;
      _selectedModel = session.modelName;
      _blackboxAiModel = session.modelName;
    } else if (session.provider == 'minimax') {
      _currentProvider = AiProvider.minimax;
      _selectedModel = session.modelName;
      _minimaxModel = session.modelName;
    } else if (session.provider == 'openAiCompatible') {
      _currentProvider = AiProvider.openAiCompatible;
      _selectedModel = session.modelName;
      _openAiCompatibleModel = session.modelName;
    } else if (session.provider == 'deepseek') {
      _currentProvider = AiProvider.deepseek;
      _selectedModel = session.modelName;
      _deepseekModel = session.modelName;
    } else if (session.provider == 'ollama') {
      _currentProvider = AiProvider.ollama;
      _selectedModel = session.modelName;
      _ollamaModel = session.modelName;
    } else if (session.provider == 'qwen') {
      _currentProvider = AiProvider.qwen;
      _selectedModel = session.modelName;
      _qwenModel = session.modelName;
    } else if (session.provider == 'xAi') {
      _currentProvider = AiProvider.xAi;
      _selectedModel = session.modelName;
      _xAiModel = session.modelName;
    } else if (session.provider == 'zAi') {
      _currentProvider = AiProvider.zAi;
      _selectedModel = session.modelName;
      _zAiModel = session.modelName;
    } else if (session.provider == 'mistral') {
      _currentProvider = AiProvider.mistral;
      _selectedModel = session.modelName;
      _mistralModel = session.modelName;
    } else {
      _currentProvider = AiProvider.gemini;
      _selectedGeminiModel = session.modelName;
      _selectedModel = session.modelName;
    }

    // If this session has an active background stream, reconnect the notifier
    if (_streamingCoordinator.isStreaming(session.id)) {
      final notifier = _streamingCoordinator.getActiveNotifier(session.id);
      final currentText = _streamingCoordinator.getActiveStreamText(session.id) ?? '';
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

  Future<void> deleteSession(String id) async {
    // Cancel any active stream for this session
    await _streamingCoordinator.cancelStream(id);

    await _sessionService.deleteSession(id);
    if (id == _currentSessionId) {
      createNewSession(saveCurrentSession: false);
    } else {
      notifyListeners();
    }
  }

  void deleteMessage(int index) {
    _safeDisposeMessageNotifiers([_messages[index]]);
    _messages.removeAt(index);
    notifyListeners();
    _scheduleAutoSave();
    initializeModel();
  }

  void editMessage(int index, String newText, {bool rawEdit = false}) {
    final existing = _messages[index];
    final canRawEdit =
        _settings!.enableDeveloperMode && _settings!.enableRawReasoningEdit && rawEdit;

    var updatedText = newText;
    if (!existing.isUser && !canRawEdit) {
      final split = ReasoningUtils.split(existing.text);
      if (split.reasoning.isNotEmpty &&
          !_shouldStripReasoningFromStorage &&
          _settings!.persistReasoningBlocks) {
        updatedText = '<think>\n${split.reasoning}\n</think>\n$newText';
      }
    }

    if (_shouldStripReasoningFromStorage) {
      updatedText = ChatMessage.sanitizeForContext(updatedText);
    }

    _messages[index] = existing.copyWith(
      text: updatedText,
      reasoningRecovered: false,
    );
    notifyListeners();
    _scheduleAutoSave();
    initializeModel();
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

  Future<void> saveCurrentSystemPrompt(String title) =>
      savePromptToLibrary(title, _systemInstruction);

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
                  : Content.model([TextPart(ChatMessage.sanitizeForContext(m.text))]),
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
        final effectiveText = msg.isUser
            ? msg.text
            : ChatMessage.sanitizeForContext(msg.text);
        totalChars += effectiveText.length;
        imgCount += msg.imagePaths.length;
      }
      _tokenCount = (totalChars / 3.5).ceil() + (imgCount * 200);
      notifyListeners();
    }
  }

  void _scheduleAutoSave() {
    _sessionService.scheduleAutoSave(
      ChatDefaults.autoSaveDebounce.inMilliseconds,
      autoSaveCurrentSession,
    );
  }

  void _safeDisposeMessageNotifiers(Iterable<ChatMessage> messages) {
    for (final message in messages) {
      if (message.contentNotifier != null &&
          !_streamingCoordinator.isActiveNotifier(message.contentNotifier)) {
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
      'provider': _currentProvider.name,
      'models': {
        'gemini': _selectedGeminiModel,
        'openRouter': _openRouterModel,
        'arliAi': _arliAiModel,
        'nanoGpt': _nanoGptModel,
        'nvidia': _nvidiaModel,
        'openAi': _openAiModel,
        'huggingFace': _huggingFaceModel,
        'groq': _groqModel,
        'vertexAi': _vertexAiModel,
        'blackboxAi': _blackboxAiModel,
        'minimax': _minimaxModel,
        'openAiCompatible': _openAiCompatibleModel,
        'deepseek': _deepseekModel,
        'ollama': _ollamaModel,
        'qwen': _qwenModel,
        'xAi': _xAiModel,
        'zAi': _zAiModel,
        'mistral': _mistralModel,
      },
      'modelBookmarks': _bookmarkedModels.toList(),
      'starredProviders': _starredProviders.map((p) => p.name).toList(),
      'ui': {'modelPickerSortMode': _modelPickerSortMode},
      'localIp': _localIp,
      'localModelName': _localModelName,
      'systemInstruction': _systemInstruction,
      'systemPrompts': _savedSystemPrompts.map((p) => p.toJson()).toList(),
      'sessions': savedSessions.map((s) => s.toJson()).toList(),
      'characterCard': _characterCard.toV3Json(),
      'sillyTavernState': {
        'globalLorebook': _globalLorebook.toJson(),
      },
    };
  }

  /// Applies settings from a previously exported map.
  ///
  /// Settings are overwritten. System prompts and sessions are merged
  /// via [mergeSystemPrompts] and [mergeSessions].
  Future<void> importSettingsMap(Map<String, dynamic> data) async {
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
    _nvidiaModel = models['nvidia'] as String? ?? _nvidiaModel;
    _openAiModel = models['openAi'] as String? ?? _openAiModel;
    _huggingFaceModel = models['huggingFace'] as String? ?? _huggingFaceModel;
    _groqModel = models['groq'] as String? ?? _groqModel;
    _vertexAiModel = models['vertexAi'] as String? ?? _vertexAiModel;
    _blackboxAiModel = models['blackboxAi'] as String? ?? _blackboxAiModel;
    _minimaxModel = models['minimax'] as String? ?? _minimaxModel;
    _openAiCompatibleModel =
      models['openAiCompatible'] as String? ?? _openAiCompatibleModel;
    _deepseekModel = models['deepseek'] as String? ?? _deepseekModel;
    _ollamaModel = models['ollama'] as String? ?? _ollamaModel;
    _qwenModel = models['qwen'] as String? ?? _qwenModel;
    _xAiModel = models['xAi'] as String? ?? _xAiModel;
    _zAiModel = models['zAi'] as String? ?? _zAiModel;
    _mistralModel = models['mistral'] as String? ?? _mistralModel;
    _selectedModel = _getProviderModel(_currentProvider);

    final bookmarks = data['modelBookmarks'] as List<dynamic>?;
    if (bookmarks != null) {
      _bookmarkedModels = bookmarks
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      await _globalSettings.saveModelBookmarks(_bookmarkedModels);
    }

    final starredProviders = data['starredProviders'] as List<dynamic>?;
    if (starredProviders != null) {
      _starredProviders.clear();
      for (final raw in starredProviders) {
        final providerName = raw.toString();
        try {
          _starredProviders.add(
            AiProvider.values.firstWhere((p) => p.name == providerName),
          );
        } catch (_) {
          continue;
        }
      }
      await _globalSettings.saveStarredProviders(_starredProviders);
    }

    final ui = data['ui'] as Map<String, dynamic>?;
    if (ui != null && ui['modelPickerSortMode'] is String) {
      _modelPickerSortMode = GlobalSettingsService.normalizeSortMode(
        ui['modelPickerSortMode'] as String,
      );
      await _globalSettings.saveModelPickerSortMode(_modelPickerSortMode);
    }

    _localIp = data['localIp'] as String? ?? _localIp;
    _localModelName = data['localModelName'] as String? ?? _localModelName;

    _systemInstruction =
        data['systemInstruction'] as String? ?? _systemInstruction;

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
          Map<String, dynamic>.from(data['characterCard']),
        );
        _saveCharacterCard();
      } catch (e) {
        debugPrint('Error importing character card: $e');
      }
    }

    // SillyTavern state (World Lore)
    if (data['sillyTavernState'] != null) {
      try {
        final st = Map<String, dynamic>.from(data['sillyTavernState']);
        if (st['globalLorebook'] != null) {
          _globalLorebook = Lorebook.fromJson(
            Map<String, dynamic>.from(st['globalLorebook']),
          );
        }
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
    _sessionService.mergeSessions(incoming, _shouldStripReasoningFromStorage);
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

  Future<void> refreshModels(AiProvider provider) async {
    final key = _getProviderKey(provider);
    Map<String, String>? headers;
    if (provider == AiProvider.openRouter) {
      headers = {
        "HTTP-Referer": "https://airp-chat.com",
        "X-Title": "AIRP Chat",
      };
    }
    await _modelRegistry.fetchModels(provider, key, headers: headers);
  }

  Future<void> refreshCurrentModels() => refreshModels(_currentProvider);
}

/// Outcome of a BYOK web-search tool-call loop for a single user message.
///
/// See [ChatProvider._runWebSearchToolLoop] for field semantics.
class _WebSearchLoopResult {
  final String? directAnswer;
  final List<Map<String, dynamic>>? extraMessages;
  final String? error;

  const _WebSearchLoopResult({
    this.directAnswer,
    this.extraMessages,
    this.error,
  });
}
