import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
import '../utils/token_utils.dart';
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

  /// Set of session IDs that currently have an active background stream.
  Set<String> get streamingSessionIds =>
      _streamingCoordinator.streamingSessionIds;

  /// Pending background notifications for completed responses.
  List<BackgroundNotification> get pendingNotifications =>
      _streamingCoordinator.pendingNotifications;

  void removeNotification(int index) {
    _streamingCoordinator.removeNotification(index);
  }

  List<ModelInfo> get geminiModelsList =>
      _modelRegistry.getModels(AiProvider.gemini);
  List<ModelInfo> get openRouterModelsList =>
      _modelRegistry.getModels(AiProvider.openRouter);
  List<ModelInfo> get nanoGptModelsList =>
      _modelRegistry.getModels(AiProvider.nanoGpt);
  List<ModelInfo> get nvidiaModelsList =>
      _modelRegistry.getModels(AiProvider.nvidia);
  List<ModelInfo> get openAiCompatibleModelsList =>
      _modelRegistry.getModels(AiProvider.openAiCompatible);
  List<ModelInfo> get deepseekModelsList =>
      _modelRegistry.getModels(AiProvider.deepseek);
  List<ModelInfo> get ollamaModelsList =>
      _modelRegistry.getModels(AiProvider.ollama);
  List<ModelInfo> get localModelsList =>
      _modelRegistry.getModels(AiProvider.local);

  bool get isLoadingGeminiModels => _modelRegistry.isLoading(AiProvider.gemini);
  bool get isLoadingOpenRouterModels =>
      _modelRegistry.isLoading(AiProvider.openRouter);
  bool get isLoadingNanoGptModels =>
      _modelRegistry.isLoading(AiProvider.nanoGpt);
  bool get isLoadingNvidiaModels => _modelRegistry.isLoading(AiProvider.nvidia);
  bool get isLoadingOpenAiCompatibleModels =>
      _modelRegistry.isLoading(AiProvider.openAiCompatible);
  bool get isLoadingDeepseekModels =>
      _modelRegistry.isLoading(AiProvider.deepseek);
  bool get isLoadingOllamaModels => _modelRegistry.isLoading(AiProvider.ollama);
  bool get isLoadingLocalModels => _modelRegistry.isLoading(AiProvider.local);

  bool get isRefreshingModels => _modelRegistry.isAnyLoading;

  /// The failure message from the last model fetch for [provider], or null.
  String? modelFetchError(AiProvider provider) =>
      _modelRegistry.lastError(provider);

  /// The failure message from the last model fetch for the active provider.
  String? get currentModelFetchError =>
      _modelRegistry.lastError(_currentProvider);

  AiProvider _currentProvider = AiProvider.gemini;

  AiProvider get currentProvider => _currentProvider;

  /// The live list of models for the currently active provider. Reads the
  /// registry directly so callers always observe the most recent fetch —
  /// used by the model picker dialog to update in place after a refresh.
  List<ModelInfo> get currentModelsList =>
      _modelRegistry.getModels(_currentProvider);
  String get geminiKey => _apiKeys.getProviderKey(AiProvider.gemini);
  String get openRouterKey => _apiKeys.getProviderKey(AiProvider.openRouter);
  String get nanoGptKey => _apiKeys.getProviderKey(AiProvider.nanoGpt);
  String get nvidiaKey => _apiKeys.getProviderKey(AiProvider.nvidia);
  String get openAiCompatibleKey =>
      _apiKeys.getProviderKey(AiProvider.openAiCompatible);
  String get deepseekKey => _apiKeys.getProviderKey(AiProvider.deepseek);
  String get ollamaKey => _apiKeys.getProviderKey(AiProvider.ollama);

  String _localIp = ChatDefaults.localIp;
  String _localModelName = '';
  String _openAiCompatibleEndpoint = '';
  String _ollamaEndpoint = ApiConstants.ollamaDefaultEndpoint;
  final Set<AiProvider> _starredProviders = {};
  final GlobalSettingsService _globalSettings = GlobalSettingsService();
  String _modelPickerSortMode = GlobalSettingsService.defaultModelSortMode;

  String get localIp => _localIp;
  String get localModelName => _localModelName;

  /// The model id actually sent to the Local provider.
  ///
  /// A blank Target Model ID means Auto: the first model the server listed,
  /// or the generic placeholder when discovery has not run. llama.cpp and
  /// LM Studio ignore the field entirely, but an empty string is a 400 on some
  /// OpenAI-compatible servers, so it is never sent as-is.
  String get effectiveLocalModel {
    final name = _localModelName.trim();
    if (name.isNotEmpty) return name;
    final discovered = _modelRegistry.getModels(AiProvider.local);
    if (discovered.isNotEmpty) return discovered.first.id;
    return 'local-model';
  }

  /// The model id for the active provider, resolved rather than raw.
  ///
  /// [_selectedModel] holds the Target Model ID verbatim for Local, which is
  /// blank whenever the user means Auto. Read this instead wherever a model
  /// name is sent, displayed or persisted, or a Local reply is labelled with
  /// nothing and saves a session that records nothing.
  String get activeModelId => _currentProvider == AiProvider.local
      ? effectiveLocalModel
      : _selectedModel;
  String get openAiCompatibleEndpoint => _openAiCompatibleEndpoint;
  String get ollamaEndpoint => _ollamaEndpoint;
  Set<AiProvider> get starredProviders => _starredProviders;
  String get modelPickerSortMode => _modelPickerSortMode;

  String _selectedGeminiModel = 'models/gemini-3-flash-preview';
  String _openRouterModel = 'z-ai/glm-4.5-air:free';
  String _nanoGptModel = 'gpt-4o';
  String _nvidiaModel = 'nvidia/llama-3.1-nemotron-ultra-253b-v1';
  String _openAiCompatibleModel = '';
  String _deepseekModel = '';
  String _ollamaModel = '';
  String _selectedModel = 'models/gemini-3-flash-preview';

  String get selectedGeminiModel => _selectedGeminiModel;
  String get openRouterModel => _openRouterModel;
  String get nanoGptModel => _nanoGptModel;
  String get nvidiaModel => _nvidiaModel;
  String get openAiCompatibleModel => _openAiCompatibleModel;
  String get deepseekModel => _deepseekModel;
  String get ollamaModel => _ollamaModel;
  String get selectedModel => _selectedModel;

  /// Returns the maximum context length for the currently selected model.
  int getMaxContext() {
    final model = getCurrentModelInfo();
    if (model == null) {
      return _currentProvider == AiProvider.local ? 32768 : 1048576;
    }
    return int.tryParse(model.contextLength.replaceAll(',', '')) ??
        (_currentProvider == AiProvider.local ? 32768 : 1048576);
  }

  /// Returns the ModelInfo object for the currently selected model.
  ModelInfo? getCurrentModelInfo() {
    final currentList = _modelRegistry.getModels(_currentProvider);
    final currentId = activeModelId;

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
  Color _loreRecognizerGlowColor = Colors.orangeAccent;

  // Web Search (BYOK) Getters passed to _apiKeys
  String get braveApiKey => _apiKeys.getSearchKey(SearchProvider.brave);
  String get tavilyApiKey => _apiKeys.getSearchKey(SearchProvider.tavily);
  String get serperApiKey => _apiKeys.getSearchKey(SearchProvider.serper);

  // --- World Lore getters ---
  Color get loreRecognizerGlowColor => _loreRecognizerGlowColor;

  List<ChatMessage> _messages = [];
  String? _currentSessionId;
  int _tokenCount = 0;

  /// Last `prompt_tokens` the active provider actually reported, with the
  /// message count it covered. The context meter is anchored to this and only
  /// estimates what has been added since. Cleared when the session or provider
  /// changes, because a reading from one does not describe the other.
  int? _anchorPromptTokens;
  int _anchorMessageCount = 0;

  /// Per-provider ratio of reported tokens to locally estimated tokens.
  /// Persisted so a fresh session starts from an already-calibrated meter.
  final Map<String, double> _tokenCalibration = {};
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

  static const _defaultApiKey = '';

  ChatProvider() {
    _sessionService = SessionService(onStateChanged: notifyListeners);
    _modelRegistry = ModelRegistryService(onStateChanged: notifyListeners);
    _apiKeys = ApiKeyService(onStateChanged: notifyListeners);
    _streamingCoordinator = StreamingCoordinatorService(
      onStateChanged: notifyListeners,
    );
    _loadSettings();
    _loadSessions();
    _loadSystemPrompts();
  }

  @override
  void dispose() {
    _modelAutoFetchTimer?.cancel();
    _settingsSaveTimer?.cancel();
    _sessionService.dispose();
    _streamingCoordinator.dispose();
    _safeDisposeMessageNotifiers(_messages);
    super.dispose();
  }

  /// Writes a debounced autosave to disk immediately.
  ///
  /// Call when the app is backgrounded or detached: autosave is debounced and
  /// the process can go away before the timer fires, taking the last turn with
  /// it. Also persists an in-flight streamed response as far as it has got.
  Future<void> flushPendingSave() async {
    if (_settingsSaveTimer?.isActive ?? false) {
      _settingsSaveTimer!.cancel();
      await saveSettings(showConfirmation: false);
    }
    if (_messages.isNotEmpty || _currentTitle.isNotEmpty) {
      await autoSaveCurrentSession();
    }
    await _sessionService.flushPendingSave();
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
    await _sessionService.loadSessions();
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
    await _loadTokenCalibration(prefs);
    await _apiKeys.loadAllKeys();

    _localIp =
        prefs.getString(ApiConstants.prefLocalIp) ?? ChatDefaults.localIp;
    _localModelName =
        prefs.getString(ApiConstants.prefLocalModelName) ?? _localModelName;

    final providerString = prefs.getString('airp_provider') ?? 'gemini';
    _currentProvider = _providerFromName(providerString);

    await _modelRegistry.loadCachedModels();

    _selectedGeminiModel =
        prefs.getString(ApiConstants.prefModelGemini) ??
        'models/gemini-3-flash-preview';
    _openRouterModel =
        prefs.getString(ApiConstants.prefModelOpenRouter) ??
        'z-ai/glm-4.5-air:free';
    _nanoGptModel = prefs.getString(ApiConstants.prefModelNanoGpt) ?? 'gpt-4o';
    _nvidiaModel =
        prefs.getString(ApiConstants.prefModelNvidia) ??
        'nvidia/llama-3.1-nemotron-ultra-253b-v1';
    _openAiCompatibleModel =
        prefs.getString(ApiConstants.prefModelOpenAiCompatible) ??
        _openAiCompatibleModel;
    _deepseekModel =
        prefs.getString(ApiConstants.prefModelDeepseek) ?? _deepseekModel;
    _ollamaModel =
        prefs.getString(ApiConstants.prefModelOllama) ?? _ollamaModel;

    _openAiCompatibleEndpoint =
        prefs.getString(ApiConstants.prefOpenAiCompatibleEndpoint) ??
        _openAiCompatibleEndpoint;
    _ollamaEndpoint =
        prefs.getString(ApiConstants.prefOllamaEndpoint) ?? _ollamaEndpoint;

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
  }

  /// Resolves a persisted provider name back to its enum value.
  ///
  /// Unknown names (a provider that has since been retired, or a config pack
  /// from a newer build) fall back to Gemini rather than throwing.
  static AiProvider _providerFromName(String name) {
    if (name == 'nanoGptImage') return AiProvider.nanoGpt;
    for (final provider in AiProvider.values) {
      if (provider.name == name) return provider;
    }
    return AiProvider.gemini;
  }

  void setProvider(AiProvider provider) {
    _currentProvider = provider;
    _selectedModel = _getProviderModel(provider);
    _clearTokenAnchor();
    updateTokenCount();

    notifyListeners();
    saveSettings(showConfirmation: false);
  }

  void setApiKey(String key) {
    _setProviderKey(_currentProvider, key);
    notifyListeners();
    _scheduleModelAutoFetch(_currentProvider);
  }

  /// Debounce for the model list fetch that follows a credential edit.
  Timer? _modelAutoFetchTimer;

  /// Fetches the model list shortly after the user finishes entering an API
  /// key or endpoint.
  ///
  /// Entering a key used to issue no request at all: the list stayed empty
  /// until the user found the separate refresh button, which reads as the key
  /// having been ignored. The debounce keeps a pasted key from firing a
  /// request per keystroke.
  void _scheduleModelAutoFetch(AiProvider provider) {
    _modelAutoFetchTimer?.cancel();
    _modelAutoFetchTimer = Timer(const Duration(milliseconds: 900), () {
      if (provider != _currentProvider) return;
      if (_modelRegistry.isLoading(provider)) return;

      final needsKey = provider.needsApiKey;
      if (needsKey && _getProviderKey(provider).trim().isEmpty) return;
      if (!needsKey && (_customEndpointFor(provider) ?? '').isEmpty) return;

      refreshModels(provider);
    });
  }

  void setLocalIp(String ip) {
    _localIp = ip;
    notifyListeners();
    _scheduleModelAutoFetch(AiProvider.local);
  }

  void setLocalModelName(String name) {
    _localModelName = name;
    notifyListeners();
  }

  /// Debounce for the settings write that follows a keystroke-rate edit.
  Timer? _settingsSaveTimer;

  /// Coalesces [saveSettings] across a burst of edits.
  ///
  /// [saveSettings] issues around twenty awaited SharedPreferences writes, a
  /// lorebook JSON encode and a session autosave. Calling it straight from a
  /// TextField's `onChanged` charged every single letter that round trip,
  /// which is what made typing a model id feel like it hung.
  void saveSettingsDebounced() {
    _settingsSaveTimer?.cancel();
    _settingsSaveTimer = Timer(const Duration(milliseconds: 600), () {
      saveSettings(showConfirmation: false);
    });
  }

  void setTitle(String title) {
    _currentTitle = title;
    notifyListeners();
  }

  void setSystemInstruction(String instruction) {
    _systemInstruction = instruction;
    notifyListeners();
  }

  void setEnableCharacterCard(bool enable) {
    _settings!.setEnableCharacterCard(enable);
    notifyListeners();
    _saveEnableCharacterCard();
  }

  Future<void> _saveEnableCharacterCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      'airp_enable_character_card',
      _settings!.enableCharacterCard,
    );
  }

  /// Persists SillyTavern state (World Lore) to SharedPreferences.
  ///
  /// `airp_enable_lorebook` is owned by [SettingsProvider] and is deliberately
  /// not written here.
  Future<void> _saveSillyTavernState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'airp_global_lorebook',
      jsonEncode(_globalLorebook.toJson()),
    );
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
    notifyListeners();
    _saveCharacterCard();
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
      case AiProvider.nanoGpt:
        return _nanoGptModel;
      case AiProvider.nvidia:
        return _nvidiaModel;
      case AiProvider.openAiCompatible:
        return _openAiCompatibleModel;
      case AiProvider.deepseek:
        return _deepseekModel;
      case AiProvider.ollama:
        return _ollamaModel;
      case AiProvider.local:
        return _localModelName;
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
      case AiProvider.nanoGpt:
        _nanoGptModel = model;
        break;
      case AiProvider.nvidia:
        _nvidiaModel = model;
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
      case AiProvider.local:
        _localModelName = model;
        break;
    }
  }

  String _getProviderKey(AiProvider provider) {
    if (provider == AiProvider.local) return "local-key";
    return _apiKeys.getProviderKey(provider);
  }

  /// The reason the active provider cannot be called, or null when it can.
  ///
  /// Without this the request still goes out, carrying `Authorization: Bearer `
  /// with nothing after it. OpenRouter answers that with a flat
  /// `401 Missing Authentication header`, which reads as a rejected key and
  /// sends the user to re-paste one that was never the problem.
  String? missingCredentialError() {
    final provider = _currentProvider;
    if (provider.needsApiKey && _getProviderKey(provider).trim().isEmpty) {
      return 'No API key set for ${provider.displayName}.\n\n'
          'Open Settings then API and paste your key. The key box is per '
          'provider, so a key entered under a different provider does not '
          'carry over.';
    }
    if (!provider.needsApiKey &&
        (_customEndpointFor(provider) ?? '').isEmpty) {
      return 'No Server Endpoint URL set for ${provider.displayName}.\n\n'
          'Open Settings then API and enter the address your server listens '
          'on.';
    }
    return null;
  }

  void _setProviderKey(AiProvider provider, String key) {
    _apiKeys.setProviderKey(provider, key);
  }

  /// The user-configured server root for providers that talk to an endpoint
  /// the user owns, or null for hosted providers that use a fixed base URL.
  String? _customEndpointFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.local:
        return _localIp.trim();
      case AiProvider.openAiCompatible:
        return _openAiCompatibleEndpoint.trim();
      case AiProvider.ollama:
        return _ollamaEndpoint.trim();
      default:
        return null;
    }
  }

  void setOpenAiCompatibleEndpoint(String val) {
    _openAiCompatibleEndpoint = val;
    notifyListeners();
    _scheduleModelAutoFetch(AiProvider.openAiCompatible);
  }

  void setOllamaEndpoint(String val) {
    _ollamaEndpoint = val;
    notifyListeners();
    _scheduleModelAutoFetch(AiProvider.ollama);
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
    await prefs.setString(ApiConstants.prefModelNanoGpt, _nanoGptModel);
    await prefs.setString(ApiConstants.prefModelNvidia, _nvidiaModel);
    await prefs.setString(
      ApiConstants.prefModelOpenAiCompatible,
      _openAiCompatibleModel,
    );
    await prefs.setString(ApiConstants.prefModelDeepseek, _deepseekModel);
    await prefs.setString(ApiConstants.prefModelOllama, _ollamaModel);

    await prefs.setString(
      ApiConstants.prefOpenAiCompatibleEndpoint,
      _openAiCompatibleEndpoint,
    );
    await prefs.setString(ApiConstants.prefOllamaEndpoint, _ollamaEndpoint);

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
  }

  /// Whether the current provider can drive the AI-initiated `web_search`
  /// function tool (i.e. supports OpenAI-style function calling or Gemini
  /// function declarations). Used to gate the web-search toggle in the UI.
  ///
  /// HuggingFace's free router does not reliably support function calling, so
  /// it is excluded. All other providers (OpenAI-compatible + Gemini) are
  /// considered capable; individual models that ignore the tool simply answer
  /// without searching.
  bool supportsWebSearchTool() => true;

  /// Returns `null` if web search can be enabled with the current provider +
  /// selected search backend, or a short human-readable reason string
  /// otherwise. Used to gate the web-search toggle in the UI.
  String? webSearchUnsupportedReason() {
    if (_settings!.searchProvider == SearchProvider.provider) {
      // Native grounding is only wired up for specific providers.
      switch (_currentProvider) {
        case AiProvider.gemini:
        case AiProvider.openRouter:
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
    required List<Map<String, dynamic>> depthEntries,
    required ValueNotifier<String> contentNotifier,
    required String streamSessionId,
  }) async {
    final int maxRounds = _settings!.maxSearchRounds;
    final String hint = WebSearchService.buildWebSearchSystemHint(
      maxRounds: maxRounds,
      resultCount: _settings!.searchResultCount,
    );

    String baseSys = _buildSystemInstruction(
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
    final String? customUrl = _customEndpointFor(_currentProvider);
    final String streamUrl = strategy.getStreamUrl(customUrl: customUrl);
    final String modelName = activeModelId;

    final List<Map<String, dynamic>> openAiExtras = [];
    final List<Map<String, dynamic>> geminiExtras = [];
    final List<String> searchedQueries = [];

    for (int round = 0; round < maxRounds; round++) {
      if (_streamingCoordinator.isCancelled(streamSessionId)) {
        return _WebSearchLoopResult(
          extraMessages: openAiExtras.isNotEmpty ? openAiExtras : null,
          searchedQueries: searchedQueries,
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
          temperature: _settings!.enableGenerationSettings
              ? _settings!.temperature
              : null,
          topP: _settings!.enableGenerationSettings ? _settings!.topP : null,
          topK: _settings!.enableGenerationSettings ? _settings!.topK : null,
          maxTokens: _settings!.enableMaxOutputTokens
              ? _settings!.maxOutputTokens
              : null,
          reasoningEffort: _settings!.enableReasoning
              ? _settings!.reasoningEffort
              : null,
        );
      } else {
        // Streamed detection: if the model answers instead of searching, the
        // answer is already flowing and is handed straight to the coordinator,
        // so reasoning streams live rather than landing as one blob.
        final aware =
            await ChatApiService.streamOpenAiCompatibleWithToolDetection(
              apiKey: activeKey,
              baseUrl: streamUrl,
              model: modelName,
              history: history,
              systemInstruction: sysWithHint,
              userMessage: sentUserText,
              tools: [WebSearchService.buildWebSearchToolSpec()],
              extraMessages: openAiExtras.isNotEmpty ? openAiExtras : null,
              temperature: _settings!.enableGenerationSettings
                  ? _settings!.temperature
                  : null,
              topP: _settings!.enableGenerationSettings ? _settings!.topP : null,
              topK: _settings!.enableGenerationSettings ? _settings!.topK : null,
              maxTokens: _settings!.enableMaxOutputTokens
                  ? _settings!.maxOutputTokens
                  : null,
              reasoningEffort: _settings!.enableReasoning
                  ? _settings!.reasoningEffort
                  : null,
              applyReasoningEffort: strategy.applyReasoningEffort,
              extraHeaders: strategy.getHeaders(activeKey),
              includeUsage: _settings!.enableUsage,
              maxRoundsLeft: 1,
            );

        if (aware.isError) {
          return _WebSearchLoopResult(
            error: aware.error,
            searchedQueries: searchedQueries,
          );
        }
        if (!aware.isToolCall) {
          return _WebSearchLoopResult(
            directStream: aware.textStream ?? const Stream<String>.empty(),
            searchedQueries: searchedQueries,
          );
        }
        det = aware.toolCall!;
      }

      if (det.isError) {
        return _WebSearchLoopResult(
          error: det.text,
          searchedQueries: searchedQueries,
        );
      }

      if (!det.isToolCall) {
        // The model produced a final answer without (further) tool use.
        final answer = _composeDirectAnswer(det.text, det.reasoning);
        return _WebSearchLoopResult(
          directAnswer: answer,
          searchedQueries: searchedQueries,
          reasoningRecovered:
              det.text.trim().isEmpty && det.reasoning.trim().isNotEmpty,
        );
      }

      // ── Tool call: extract the AI-generated query and execute it ──
      final query = WebSearchService.extractQueryFromToolArgs(
        det.toolArguments,
      );
      if (query == null) {
        // Malformed tool call — abandon the loop and let the final streamed
        // answer proceed with whatever context we have (likely none).
        return _WebSearchLoopResult(
          extraMessages: openAiExtras.isNotEmpty ? openAiExtras : null,
          searchedQueries: searchedQueries,
        );
      }
      // Show progress on the placeholder bubble: every query run so far plus
      // the one in flight, so a multi-round search reads as a running log
      // rather than a single line that keeps being overwritten.
      final done = List<String>.from(searchedQueries);
      searchedQueries.add(query);
      final progress = StringBuffer();
      for (final q in done) {
        progress.writeln('🔍 Searched the web for "$q"');
      }
      progress.write(
        '🔍 Searching the web for "$query"… '
        '(round ${round + 1} of $maxRounds)',
      );
      final indicator = progress.toString();
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
            {
              'functionCall': {'name': det.toolName, 'args': argsObj},
            },
          ],
        });
        geminiExtras.add(
          ChatApiService.geminiToolResultContent(
            functionName: det.toolName,
            resultText: resultText,
          ),
        );
      } else {
        final callId = det.toolCallId.isNotEmpty
            ? det.toolCallId
            : 'call_$round';
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
        temperature: _settings!.enableGenerationSettings
            ? _settings!.temperature
            : null,
        topP: _settings!.enableGenerationSettings ? _settings!.topP : null,
        topK: _settings!.enableGenerationSettings ? _settings!.topK : null,
        maxTokens: _settings!.enableMaxOutputTokens
            ? _settings!.maxOutputTokens
            : null,
        reasoningEffort: _settings!.enableReasoning
            ? _settings!.reasoningEffort
            : null,
      );
      if (det.isError) {
        return _WebSearchLoopResult(
          error: det.text,
          searchedQueries: searchedQueries,
        );
      }
      final answer = _composeDirectAnswer(det.text, det.reasoning);
      return _WebSearchLoopResult(
        directAnswer: answer,
        searchedQueries: searchedQueries,
        reasoningRecovered:
            det.text.trim().isEmpty && det.reasoning.trim().isNotEmpty,
      );
    }

    // OpenAI-compatible: stream the final answer with the accumulated tool
    // messages appended (the streaming request does not attach `tools`, so the
    // model is forced to answer from the gathered context).
    return _WebSearchLoopResult(
      extraMessages: openAiExtras.isNotEmpty ? openAiExtras : null,
      searchedQueries: searchedQueries,
    );
  }

  /// Builds a compact inline indicator showing which web-search queries were
  /// executed. Used for both the direct-answer and streaming paths.
  String _buildSearchIndicator(List<String> queries) {
    if (queries.isEmpty) return '';
    final formatted = queries.map((q) => '"$q"').join(', ');
    return '🔍 Searched the web for $formatted\n\n';
  }

  /// Prepends the search indicator to [text] when queries exist.
  String _prefixSearchIndicator(String text, List<String> queries) {
    final indicator = _buildSearchIndicator(queries);
    if (indicator.isEmpty) return text;
    return '$indicator$text';
  }

  /// Combines a non-streamed detection result's visible text and reasoning
  /// into a single message body, mirroring the streamed format (reasoning
  /// wrapped in think tags, followed by the visible answer). When only one
  /// part is present, that part alone is returned.
  String _composeDirectAnswer(String text, String reasoning) {
    if (reasoning.trim().isNotEmpty && text.trim().isNotEmpty) {
      return '<think>\n$reasoning\n</think>\n$text';
    }
    return text.trim().isNotEmpty ? text : reasoning;
  }

  String getEditableMessageText(ChatMessage message) {
    if (message.isUser) return message.text;
    return ReasoningUtils.split(message.text).content;
  }

  String getReadOnlyReasoningForEdit(ChatMessage message) {
    if (message.isUser) return '';
    return ReasoningUtils.split(message.text).reasoning;
  }

  /// Returns lore entries whose keywords match [input] directly.
  ///
  /// This powers the input recognizer flow and intentionally ignores
  /// history-based matching.
  List<LorebookEntry> recognizeLoreEntriesFromInput(String input) {
    final trimmed = input.trim();
    if (!_settings!.enableLorebook || trimmed.isEmpty) return const [];

    final lorebooks = <Lorebook>[
      if (_globalLorebook.entries.isNotEmpty) _globalLorebook,
      if (_settings!.enableCharacterCard &&
          _characterCard.characterBook != null)
        _characterCard.characterBook!,
    ];
    if (lorebooks.isEmpty) return const [];

    final matched = <LorebookEntry>[];
    for (final lorebook in lorebooks) {
      matched.addAll(
        LorebookService.matchEntries(
          lorebook: lorebook,
          text: trimmed,
          characterName: _characterCard.name,
        ),
      );
    }

    matched.sort((a, b) => a.order.compareTo(b.order));
    return matched;
  }

  LorebookEntry? previewRecognizedLoreEntry(String input) {
    final matched = recognizeLoreEntriesFromInput(input);
    return matched.isEmpty ? null : matched.first;
  }

  /// Collects the character card's depth-positioned prompts into a flat list
  /// of `{content, depth, role}` maps.
  List<Map<String, dynamic>> _collectDepthEntries() {
    return PromptPipelineService.collectDepthEntries(
      characterCard: _characterCard,
      enableCharacterCard: _settings!.enableCharacterCard,
    );
  }

  /// Constructs the full system instruction including Main Prompt, Advanced
  /// Prompt, Character Card, and any lore entries recognized from the current
  /// user input.
  String _buildSystemInstruction({
    List<LorebookEntry> recognizedLoreEntries = const [],
  }) {
    return PromptPipelineService.buildSystemInstruction(
      systemInstruction: _systemInstruction,
      enableSystemPrompt: _settings!.enableSystemPrompt,
      enableCharacterCard: _settings!.enableCharacterCard,
      characterCard: _characterCard,
      recognizedLoreEntries: recognizedLoreEntries,
    );
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
    final depthEntries = _collectDepthEntries();

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
        modelName: activeModelId,
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

    final String? credentialError = missingCredentialError();
    if (credentialError != null) {
      _messages.last = _messages.last.copyWith(
        text: credentialError,
        modelName: "System Alert",
        clearContentNotifier: true,
      );
      notifyListeners();
      _scheduleAutoSave();
      return;
    }

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
    _WebSearchLoopResult? loopResult;

    if (byokToolMode && imagesToSend.isEmpty && supportsWebSearchTool()) {
      try {
        _nonStreamingLoading = true;
        notifyListeners();

        loopResult = await _runWebSearchToolLoop(
          sentUserText: sentUserText,
          history: _limitedHistory(),
          recognizedLoreEntries: recognizedLoreEntries,
          depthEntries: depthEntries,
          contentNotifier: contentNotifier,
          streamSessionId: streamSessionId,
        );

        if (_streamingCoordinator.isCancelled(streamSessionId)) {
          // A detection round that answered hands back an open socket. Nothing
          // downstream will consume it now, so close it here.
          await loopResult.directStream?.listen(null).cancel();
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
      final direct = _prefixSearchIndicator(
        byokDirectAnswer,
        loopResult?.searchedQueries ?? const [],
      );
      _messages.last = _messages.last.copyWith(
        text: direct,
        reasoningRecovered: loopResult?.reasoningRecovered ?? false,
        clearContentNotifier: true,
      );
      notifyListeners();
      _scheduleAutoSave();
      updateTokenCount();
      return;
    }

    Stream<String>? responseStream;
    final byokDirectStream = loopResult?.directStream;

    try {
      final strategy = StrategyResolver.resolve(_currentProvider);
      final activeKey = _getProviderKey(_currentProvider);

      final String? customUrl = _customEndpointFor(_currentProvider);

      String finalSystemInstruction = _buildSystemInstruction(
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

      final limitedHistory = _limitedHistory();

      // When the tool-detection round already answered, that socket is live
      // and carries the whole response; re-requesting would bill a second
      // generation and discard the one in flight.
      responseStream =
          byokDirectStream ??
          strategy.streamResponse(
            apiKey: activeKey,
            baseUrl: strategy.getStreamUrl(customUrl: customUrl),
            model: activeModelId,
            history: limitedHistory,
            systemInstruction: finalSystemInstruction,
            userMessage: finalUserMessage,
            imagePaths: imagesToSend,
            temperature: _settings!.enableGenerationSettings
                ? _settings!.temperature
                : null,
            topP: _settings!.enableGenerationSettings ? _settings!.topP : null,
            topK: _settings!.enableGenerationSettings ? _settings!.topK : null,
            maxTokens: _settings!.enableMaxOutputTokens
                ? _settings!.maxOutputTokens
                : null,
            enableGrounding:
                _settings!.enableGrounding &&
                _settings!.searchProvider == SearchProvider.provider,
            reasoningEffort: _settings!.enableReasoning
                ? _settings!.reasoningEffort
                : null,
            extraHeaders: strategy.getHeaders(activeKey),
            includeUsage: _settings!.enableUsage,
            depthMessages: depthEntries.isNotEmpty ? depthEntries : null,
            attachmentBytes: attachmentBytes,
            extraMessages: toolExtraMessages,
            disableSafety: _settings!.disableSafety,
          );

      final queries = loopResult?.searchedQueries ?? const [];
      if (queries.isNotEmpty) {
        final indicator = _buildSearchIndicator(queries);
        final originalStream = responseStream;
        responseStream = (() async* {
          yield indicator;
          await for (final chunk in originalStream) {
            yield chunk;
          }
        })();
      }

      _streamingCoordinator.registerStream(
        sessionId: streamSessionId,
        modelName: activeModelId,
        contentNotifier: contentNotifier,
        stream: responseStream,
        onUpdate: (sessionId, text, usage) {
          if (usage != null && _currentSessionId == sessionId) {
            _messages.last = _messages.last.copyWith(usage: usage);
            _recordUsage(usage);
            updateTokenCount();
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
            updateTokenCount();
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
          // Write the error into the placeholder rather than appending after
          // it; leaving the empty bubble in place strands a blank turn between
          // the prompt and the error.
          _messages.last = _messages.last.copyWith(
            text: "**System Error**\n\n```\n$e\n```",
            modelName: "System Alert",
            clearContentNotifier: true,
          );
          notifyListeners();
          _scheduleAutoSave();
        }
      }
      _streamingCoordinator.cancelStream(streamSessionId);
    }
  }

  /// The conversation history to send, excluding the user message currently
  /// being answered and its streaming placeholder, trimmed to the configured
  /// history limit.
  ///
  /// Shared by the plain send path and the web-search tool loop; when only the
  /// former applied the limit, turning web search on silently sent the entire
  /// conversation.
  List<ChatMessage> _limitedHistory() {
    final contextMessages = _messages.sublist(0, _messages.length - 2);
    final int effectiveHistoryLimit = _settings!.enableMsgHistory
        ? _settings!.historyLimit
        : 0;
    int startIndex = contextMessages.length - effectiveHistoryLimit;
    if (startIndex < 0) startIndex = 0;
    return contextMessages.sublist(startIndex);
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
      modelName: activeModelId,
      tokenCount: 0,
      systemInstruction: _systemInstruction,
      backgroundImage: null,
      provider: _currentProvider.name,
      isBookmarked: false,
    );

    _sessionService.prependSession(newSession);
    return newSessionId;
  }

  /// Compresses the current conversation into a narrative summary + voice
  /// samples (two one-shot LLM calls), appends both as AI messages into the
  /// current chat, then creates a fresh branched conversation seeded with
  /// [summary]+[voices]+[last N assistant/user pairs]. The original
  /// conversation is left intact (only appended-to).  After branching, the
  /// active session is switched to the new one.
  ///
  /// Returns `null` on success or an error string.
  Future<String?> compressAndBranch({
    required int pairCount,
    required String compressPrompt,
    required String voiceSamplesPrompt,
  }) async {
    if (_messages.isEmpty) {
      return "Nothing to summarize — the conversation is empty.";
    }
    final int n = pairCount.clamp(
      SummarizeDefaults.minPairs,
      SummarizeDefaults.maxPairs,
    );

    // 1. Build a plain-text transcript of the whole conversation.
    final buf = StringBuffer();
    for (final m in _messages) {
      final role = m.isUser ? 'User' : 'Assistant';
      final body = ChatMessage.sanitizeForContext(m.text).trim();
      if (body.isEmpty) continue;
      buf.writeln('$role: $body');
      buf.writeln();
    }
    final transcript = buf.toString().trimRight();
    if (transcript.isEmpty) {
      return "Nothing to summarize — no message text found.";
    }

    _nonStreamingLoading = true;
    notifyListeners();

    try {
      // 2. Two one-shot LLM calls.
      final summaryText = await _oneShotGenerate(
        '$compressPrompt\n\n$transcript',
      );
      if (summaryText == null) {
        return "Summarize call failed (check API key / model).";
      }
      final voicesText = await _oneShotGenerate(
        '$voiceSamplesPrompt\n\n$transcript',
      );
      if (voicesText == null) {
        return "Voice-samples call failed (check API key / model).";
      }

      final modelNameForNote = activeModelId;

      // 3. Emit summary + voices as two AI messages into the current chat.
      final summaryMessage = ChatMessage(
        text: '**[Summary]**\n\n$summaryText',
        isUser: false,
        modelName: modelNameForNote,
      );
      final voicesMessage = ChatMessage(
        text: '**[Voice Samples]**\n\n$voicesText',
        isUser: false,
        modelName: modelNameForNote,
      );
      _messages.add(summaryMessage);
      _messages.add(voicesMessage);
      notifyListeners();
      await autoSaveCurrentSession();

      // 4. Collect last N assistant/user pairs from the ORIGINAL messages
      //    (i.e. before the two emitted notes).
      final pairs = collectTrailingPairs(
        _messages.sublist(0, _messages.length - 2),
        n,
      );

      // 5. New branch: [summary]+[voices]+[last N pairs]
      final branchedMessages = <ChatMessage>[
        summaryMessage.copyWith(clearContentNotifier: true),
        voicesMessage.copyWith(clearContentNotifier: true),
        ...pairs,
      ];
      final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final newSession = ChatSessionData(
        id: newSessionId,
        title: _currentTitle.isEmpty
            ? "Summarized Conversation"
            : "Summary of $_currentTitle",
        messages: branchedMessages,
        modelName: activeModelId,
        tokenCount: 0,
        systemInstruction: _systemInstruction,
        backgroundImage: null,
        provider: _currentProvider.name,
        isBookmarked: false,
      );
      _sessionService.prependSession(newSession);
      loadSession(newSession);
      return null; // success
    } catch (e) {
      return "Summarize failed: $e";
    } finally {
      _nonStreamingLoading = false;
      notifyListeners();
    }
  }

  /// Returns the trailing [n] assistant turns from [messages], each preceded by
  /// its own user turn where one exists, in original conversation order.
  ///
  /// Walks backwards anchoring on assistant turns. The result always reads
  /// user-then-assistant: a pair whose assistant reply came first in the list
  /// must not be emitted above the message that prompted it.
  @visibleForTesting
  static List<ChatMessage> collectTrailingPairs(
    List<ChatMessage> messages,
    int n,
  ) {
    final pairs = <ChatMessage>[];
    int i = messages.length - 1;
    int collected = 0;
    while (i >= 0 && collected < n) {
      if (!messages[i].isUser) {
        // Both inserts target index 0, so the assistant must go in FIRST for
        // the user turn to end up above it.
        pairs.insert(0, messages[i].copyWith(clearContentNotifier: true));
        if (i - 1 >= 0 && messages[i - 1].isUser) {
          pairs.insert(0, messages[i - 1].copyWith(clearContentNotifier: true));
        }
        collected++;
        i -= 2;
      } else {
        i -= 1;
      }
    }
    return pairs;
  }

  /// One-shot non-streaming generation using the active provider's strategy.
  /// Returns the plain text answer or `null` on error.  Does NOT touch chat
  /// session state.
  Future<String?> _oneShotGenerate(String userPrompt) async {
    final bool isGemini = _currentProvider == AiProvider.gemini;
    final String activeKey = _getProviderKey(_currentProvider);
    final strategy = StrategyResolver.resolve(_currentProvider);
    final String? customUrl = _customEndpointFor(_currentProvider);
    final String streamUrl = strategy.getStreamUrl(customUrl: customUrl);
    final String modelName = activeModelId;
    const String sysInstr = 'You are a helpful assistant.';

    ToolDetectionResult det;
    if (isGemini) {
      final gemKey = geminiKey.isNotEmpty ? geminiKey : _defaultApiKey;
      det = await ChatApiService.performGeminiFunctionDetection(
        apiKey: gemKey,
        model: _selectedModel,
        history: const [],
        userMessage: userPrompt,
        systemInstruction: sysInstr,
        functionDeclarations: const [],
        extraMessages: null,
        disableSafety: _settings?.disableSafety ?? true,
        maxRoundsLeft: 1,
        reasoningEffort: _settings?.enableReasoning == true
            ? _settings!.reasoningEffort
            : null,
      );
    } else {
      det = await ChatApiService.requestOpenAiCompatibleWithToolDetection(
        apiKey: activeKey,
        baseUrl: streamUrl,
        model: modelName,
        history: const [],
        systemInstruction: sysInstr,
        userMessage: userPrompt,
        tools: const [],
        extraMessages: null,
        temperature: _settings?.enableGenerationSettings == true
            ? _settings!.temperature
            : null,
        topP: _settings?.enableGenerationSettings == true
            ? _settings!.topP
            : null,
        maxTokens: _settings?.enableMaxOutputTokens == true
            ? _settings!.maxOutputTokens
            : null,
        reasoningEffort: _settings?.enableReasoning == true
            ? _settings!.reasoningEffort
            : null,
        applyReasoningEffort: strategy.applyReasoningEffort,
        extraHeaders: strategy.getHeaders(activeKey),
        maxRoundsLeft: 1,
      );
    }
    if (det.isError) return null;
    return ChatMessage.sanitizeForContext(det.text).trim();
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
    final modelNameSnapshot = activeModelId;
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
    _clearTokenAnchor();
    _nonStreamingLoading = false;
    _currentSessionId = null;
    _currentTitle = "";
    notifyListeners();
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

    final sessionProvider = _providerFromName(session.provider);
    _currentProvider = sessionProvider;
    if (sessionProvider == AiProvider.local) {
      // Sessions saved before 0.7.30.4 stored the literal "Local Network AI"
      // as their model name, so the session is not a usable source here. The
      // user's configured Target Model ID stays authoritative.
      _selectedModel = effectiveLocalModel;
    } else {
      _setProviderModel(sessionProvider, session.modelName);
      _selectedModel = session.modelName;
    }

    _restoreTokenAnchorFromHistory();
    updateTokenCount();

    // If this session has an active background stream, reconnect the notifier
    if (_streamingCoordinator.isStreaming(session.id)) {
      final notifier = _streamingCoordinator.getActiveNotifier(session.id);
      final currentText =
          _streamingCoordinator.getActiveStreamText(session.id) ?? '';
      if (notifier != null && _messages.isNotEmpty && !_messages.last.isUser) {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          text: currentText,
          contentNotifier: notifier,
        );
      }
    }

    notifyListeners();
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
    updateTokenCount();
  }

  void editMessage(int index, String newText) {
    final existing = _messages[index];

    var updatedText = newText;
    if (!existing.isUser) {
      final split = ReasoningUtils.split(existing.text);
      if (split.reasoning.isNotEmpty) {
        updatedText = '<think>\n${split.reasoning}\n</think>\n$newText';
      }
    }

    _messages[index] = existing.copyWith(
      text: updatedText,
      reasoningRecovered: false,
    );
    notifyListeners();
    _scheduleAutoSave();
    updateTokenCount();
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

  /// Recomputes the context meter.
  ///
  /// Local and synchronous: the meter is projected from the provider's own
  /// last `prompt_tokens` reading rather than measured by a separate
  /// `countTokens` round trip, which cost a request per turn, needed a valid
  /// key, and left a silently stale number whenever it failed.
  void updateTokenCount() {
    if (_messages.isEmpty || _settings == null) {
      _tokenCount = 0;
      notifyListeners();
      return;
    }

    final int rawEstimate = _estimatePromptTokens(_messages.length);
    int? anchorRaw;
    if (_anchorPromptTokens != null &&
        _anchorMessageCount > 0 &&
        _anchorMessageCount <= _messages.length) {
      anchorRaw = _estimatePromptTokens(_anchorMessageCount);
    }

    _tokenCount = TokenUtils.projectContext(
      rawEstimate: rawEstimate,
      calibration: _currentCalibration,
      anchorPromptTokens: anchorRaw == null ? null : _anchorPromptTokens,
      anchorRawEstimate: anchorRaw,
    );
    notifyListeners();
  }

  double get _currentCalibration =>
      _tokenCalibration[_currentProvider.name] ?? 1.0;

  /// Estimates the outbound prompt for the first [messageCount] messages.
  ///
  /// Mirrors what is actually sent: the assembled system instruction (system
  /// prompt plus character card plus recognized lore) rather than the raw
  /// prompt field, and only the messages inside the active history window.
  int _estimatePromptTokens(int messageCount) {
    final int end = messageCount.clamp(0, _messages.length);
    final considered = _messages.sublist(0, end);

    final int effectiveHistoryLimit = _settings!.enableMsgHistory
        ? _settings!.historyLimit
        : 0;
    int startIndex = considered.length - effectiveHistoryLimit;
    if (startIndex < 0) startIndex = 0;
    final window = considered.sublist(startIndex);

    int imageCount = 0;
    for (final msg in window) {
      imageCount += msg.imagePaths.length;
    }

    return TokenUtils.estimatePrompt(
      messageTexts: window.map(
        (m) => m.isUser ? m.text : ChatMessage.sanitizeForContext(m.text),
      ),
      systemInstruction: _buildSystemInstruction(),
      imageCount: imageCount,
    );
  }

  /// Anchors the context meter to a real usage reading and folds it into the
  /// provider's calibration ratio.
  ///
  /// [usage] is already normalized by [StreamingCoordinatorService]. The
  /// reading describes every message except the assistant reply currently
  /// being written, hence the count of one less than the list length.
  void _recordUsage(Map<String, dynamic> usage) {
    final promptTokens = usage['prompt_tokens'];
    if (promptTokens is! int || promptTokens <= 0) return;

    final int covered = _messages.length - 1;
    if (covered <= 0) return;

    final int rawEstimate = _estimatePromptTokens(covered);
    final double updated = TokenUtils.calibrate(
      _currentCalibration,
      promptTokens,
      rawEstimate,
    );

    _anchorPromptTokens = promptTokens;
    _anchorMessageCount = covered;

    if (updated != _currentCalibration) {
      _tokenCalibration[_currentProvider.name] = updated;
      _saveTokenCalibration();
    }
  }

  /// Drops the anchor when it can no longer describe the current request,
  /// leaving the meter on a pure calibrated estimate until the next reply.
  void _clearTokenAnchor() {
    _anchorPromptTokens = null;
    _anchorMessageCount = 0;
  }

  /// Re-anchors from the most recent reply that carries a usage reading, so a
  /// reopened conversation keeps the provider-accurate meter it had.
  void _restoreTokenAnchorFromHistory() {
    _clearTokenAnchor();
    for (int i = _messages.length - 1; i > 0; i--) {
      final msg = _messages[i];
      if (msg.isUser) continue;
      final promptTokens = TokenUtils.normalizeUsage(
        msg.usage,
      )?['prompt_tokens'];
      if (promptTokens is int && promptTokens > 0) {
        _anchorPromptTokens = promptTokens;
        _anchorMessageCount = i;
        return;
      }
    }
  }

  Future<void> _loadTokenCalibration(SharedPreferences prefs) async {
    final raw = prefs.getString('airp_token_calibration');
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        if (value is num) {
          _tokenCalibration[key] = value.toDouble().clamp(
            TokenUtils.minCalibration,
            TokenUtils.maxCalibration,
          );
        }
      });
    } catch (e) {
      debugPrint('Token calibration load error: $e');
    }
  }

  Future<void> _saveTokenCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'airp_token_calibration',
      jsonEncode(_tokenCalibration),
    );
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
        'nanoGpt': _nanoGptModel,
        'nvidia': _nvidiaModel,
        'openAiCompatible': _openAiCompatibleModel,
        'deepseek': _deepseekModel,
        'ollama': _ollamaModel,
      },
      'modelBookmarks': _bookmarkedModels.toList(),
      'starredProviders': _starredProviders.map((p) => p.name).toList(),
      'ui': {'modelPickerSortMode': _modelPickerSortMode},
      'localIp': _localIp,
      'localModelName': _localModelName,
      'openAiCompatibleEndpoint': _openAiCompatibleEndpoint,
      'ollamaEndpoint': _ollamaEndpoint,
      'systemInstruction': _systemInstruction,
      'systemPrompts': _savedSystemPrompts.map((p) => p.toJson()).toList(),
      'sessions': savedSessions.map((s) => s.toJson()).toList(),
      'characterCard': _characterCard.toV3Json(),
      'sillyTavernState': {'globalLorebook': _globalLorebook.toJson()},
    };
  }

  /// Applies settings from a previously exported map.
  ///
  /// Settings are overwritten. System prompts and sessions are merged
  /// via [mergeSystemPrompts] and [mergeSessions].
  Future<void> importSettingsMap(Map<String, dynamic> data) async {
    final providerName = data['provider'] as String?;
    if (providerName != null) {
      _currentProvider = _providerFromName(providerName);
    }

    final models = data['models'] as Map<String, dynamic>? ?? {};
    _selectedGeminiModel = models['gemini'] as String? ?? _selectedGeminiModel;
    _openRouterModel = models['openRouter'] as String? ?? _openRouterModel;
    _nanoGptModel = models['nanoGpt'] as String? ?? _nanoGptModel;
    _nvidiaModel = models['nvidia'] as String? ?? _nvidiaModel;
    _openAiCompatibleModel =
        models['openAiCompatible'] as String? ?? _openAiCompatibleModel;
    _deepseekModel = models['deepseek'] as String? ?? _deepseekModel;
    _ollamaModel = models['ollama'] as String? ?? _ollamaModel;
    _selectedModel = _getProviderModel(_currentProvider);

    _openAiCompatibleEndpoint =
        data['openAiCompatibleEndpoint'] as String? ??
        _openAiCompatibleEndpoint;
    _ollamaEndpoint = data['ollamaEndpoint'] as String? ?? _ollamaEndpoint;

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
    _sessionService.mergeSessions(incoming);
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
    await _modelRegistry.fetchModels(
      provider,
      key,
      headers: headers,
      customBase: _customEndpointFor(provider),
    );
  }

  Future<void> refreshCurrentModels() => refreshModels(_currentProvider);
}

/// Outcome of a BYOK web-search tool-call loop for a single user message.
///
/// See [ChatProvider._runWebSearchToolLoop] for field semantics.
class _WebSearchLoopResult {
  final String? directAnswer;
  final Stream<String>? directStream;
  final List<Map<String, dynamic>>? extraMessages;
  final List<String> searchedQueries;
  final String? error;
  final bool reasoningRecovered;

  const _WebSearchLoopResult({
    this.directAnswer,
    this.directStream,
    this.extraMessages,
    this.searchedQueries = const [],
    this.error,
    this.reasoningRecovered = false,
  });
}
