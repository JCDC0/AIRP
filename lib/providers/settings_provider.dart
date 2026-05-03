import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Central provider for application-wide settings and configuration.
///
/// Manages user preferences for generation parameters, web search (BYOK),
/// and application toggles (e.g., developer mode, safety).
class SettingsProvider extends ChangeNotifier {
  double _temperature = ChatDefaults.temperature;
  double _topP = ChatDefaults.topP;
  int _topK = ChatDefaults.topK;
  int _maxOutputTokens = ChatDefaults.maxOutputTokens;
  int _historyLimit = ChatDefaults.historyLimit;
  bool _enableGrounding = false;
  bool _enableUsage = false;
  bool _disableSafety = true;
  String _reasoningEffort = "none";

  // Web Search (BYOK)
  SearchProvider _searchProvider = SearchProvider.provider;
  String _searxngUrl = '';
  int _searchResultCount = 5;

  // Toggles
  bool _enableSystemPrompt = true;
  bool _enableCharacterCard = true;
  bool _enableMsgHistory = true;
  bool _enableReasoning = false;
  bool _enableGenerationSettings = true;
  bool _enableMaxOutputTokens = true;
  bool _enableReasoningEfficiency = true;
  bool _persistReasoningBlocks = true;
  bool _enableDeveloperMode = false;
  bool _enableRawReasoningEdit = false;
  bool _rawReasoningEditWarningAcknowledged = false;
  bool _enableLorebook = true;

  // Dirty tracking — indicates unsaved changes exist in the settings drawer.
  // Panels call markDirty() to flag changes; the save button calls clearDirty().
  bool _hasPendingChanges = false;

  static const String _rawEditWarningAckKey =
      'airp_raw_reasoning_edit_warning_ack';

  // --- Dirty tracking ---
  bool get hasPendingChanges => _hasPendingChanges;

  /// Mark that settings have been modified but not yet persisted.
  void markDirty() {
    if (!_hasPendingChanges) {
      _hasPendingChanges = true;
      notifyListeners();
    }
  }

  /// Clear the dirty flag after a successful save.
  void clearDirty() {
    if (_hasPendingChanges) {
      _hasPendingChanges = false;
      notifyListeners();
    }
  }

  // --- Getters ---
  double get temperature => _temperature;
  double get topP => _topP;
  int get topK => _topK;
  int get maxOutputTokens => _maxOutputTokens;
  int get historyLimit => _historyLimit;
  bool get enableGrounding => _enableGrounding;
  bool get enableUsage => _enableUsage;
  bool get disableSafety => _disableSafety;
  String get reasoningEffort => _reasoningEffort;

  SearchProvider get searchProvider => _searchProvider;
  String get searxngUrl => _searxngUrl;
  int get searchResultCount => _searchResultCount;

  bool get enableSystemPrompt => _enableSystemPrompt;
  bool get enableCharacterCard => _enableCharacterCard;
  bool get enableMsgHistory => _enableMsgHistory;
  bool get enableReasoning => _enableReasoning;
  bool get enableGenerationSettings => _enableGenerationSettings;
  bool get enableMaxOutputTokens => _enableMaxOutputTokens;
  bool get enableReasoningEfficiency => _enableReasoningEfficiency;
  bool get persistReasoningBlocks => _persistReasoningBlocks;
  bool get enableDeveloperMode => _enableDeveloperMode;
  bool get enableRawReasoningEdit => _enableRawReasoningEdit;
  bool get rawReasoningEditWarningAcknowledged =>
      _rawReasoningEditWarningAcknowledged;
  bool get enableLorebook => _enableLorebook;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _temperature =
        prefs.getDouble('airp_temperature') ?? ChatDefaults.temperature;
    _topP = prefs.getDouble('airp_top_p') ?? ChatDefaults.topP;
    _topK = prefs.getInt('airp_top_k') ?? ChatDefaults.topK;
    _maxOutputTokens =
        prefs.getInt('airp_max_output_tokens') ?? ChatDefaults.maxOutputTokens;
    _historyLimit =
        prefs.getInt('airp_history_limit') ?? ChatDefaults.historyLimit;

    _enableSystemPrompt = prefs.getBool('airp_enable_system_prompt') ?? true;
    _enableCharacterCard = prefs.getBool('airp_enable_character_card') ?? true;
    _enableLorebook = prefs.getBool('airp_enable_lorebook') ?? true;
    _enableMsgHistory = prefs.getBool('airp_enable_msg_history') ?? true;
    _enableReasoning = prefs.getBool('airp_enable_reasoning') ?? false;
    _enableUsage = prefs.getBool('airp_enable_usage') ?? false;
    _reasoningEffort = prefs.getString('airp_reasoning_effort') ?? 'none';
    _enableGenerationSettings =
        prefs.getBool('airp_enable_generation_settings') ?? true;
    _enableMaxOutputTokens =
        prefs.getBool('airp_enable_max_output_tokens') ?? true;
    _enableReasoningEfficiency =
        prefs.getBool('airp_enable_reasoning_efficiency') ?? true;
    _persistReasoningBlocks =
        prefs.getBool('airp_persist_reasoning_blocks') ?? true;
    _enableDeveloperMode = prefs.getBool('airp_enable_developer_mode') ?? false;
    _enableRawReasoningEdit =
        prefs.getBool('airp_enable_raw_reasoning_edit') ?? false;
    _rawReasoningEditWarningAcknowledged =
        prefs.getBool(_rawEditWarningAckKey) ?? false;

    _enableGrounding =
        prefs.getBool(ApiConstants.prefEnableGrounding) ?? false;
    _disableSafety = prefs.getBool(ApiConstants.prefDisableSafety) ?? true;

    final providerName =
        prefs.getString(ApiConstants.prefKeySearchProvider) ?? 'provider';
    _searchProvider = SearchProvider.values.firstWhere(
      (e) => e.name == providerName,
      orElse: () => SearchProvider.provider,
    );
    _searxngUrl = prefs.getString(ApiConstants.prefKeySearXNGUrl) ?? '';
    _searchResultCount =
        prefs.getInt(ApiConstants.prefSearchResultCount) ?? 5;

    notifyListeners();
  }

  Future<void> saveSettings({bool showConfirmation = true}) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('airp_temperature', _temperature);
    await prefs.setDouble('airp_top_p', _topP);
    await prefs.setInt('airp_top_k', _topK);
    await prefs.setInt('airp_max_output_tokens', _maxOutputTokens);
    await prefs.setInt('airp_history_limit', _historyLimit);

    await prefs.setBool('airp_enable_system_prompt', _enableSystemPrompt);
    await prefs.setBool('airp_enable_character_card', _enableCharacterCard);
    await prefs.setBool('airp_enable_lorebook', _enableLorebook);
    await prefs.setBool('airp_enable_msg_history', _enableMsgHistory);
    await prefs.setBool('airp_enable_reasoning', _enableReasoning);
    await prefs.setBool('airp_enable_usage', _enableUsage);
    await prefs.setString('airp_reasoning_effort', _reasoningEffort);
    await prefs.setBool(
      'airp_enable_generation_settings',
      _enableGenerationSettings,
    );
    await prefs.setBool('airp_enable_max_output_tokens', _enableMaxOutputTokens);
    await prefs.setBool(
      'airp_enable_reasoning_efficiency',
      _enableReasoningEfficiency,
    );
    await prefs.setBool('airp_persist_reasoning_blocks', _persistReasoningBlocks);
    await prefs.setBool('airp_enable_developer_mode', _enableDeveloperMode);
    await prefs.setBool('airp_enable_raw_reasoning_edit', _enableRawReasoningEdit);
    await prefs.setBool(_rawEditWarningAckKey, _rawReasoningEditWarningAcknowledged);

    await prefs.setBool(ApiConstants.prefEnableGrounding, _enableGrounding);
    await prefs.setBool(ApiConstants.prefDisableSafety, _disableSafety);

    // Web Search (BYOK)
    await prefs.setString(
      ApiConstants.prefKeySearchProvider,
      _searchProvider.name,
    );
    await prefs.setString(ApiConstants.prefKeySearXNGUrl, _searxngUrl);
    await prefs.setInt(ApiConstants.prefSearchResultCount, _searchResultCount);

    notifyListeners();
  }

  // --- Setters ---
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

  void setEnableSystemPrompt(bool val) {
    _enableSystemPrompt = val;
    notifyListeners();
  }

  void setEnableCharacterCard(bool val) {
    _enableCharacterCard = val;
    notifyListeners();
  }

  void setEnableLorebook(bool val) {
    _enableLorebook = val;
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

  void setEnableReasoningEfficiency(bool val) {
    _enableReasoningEfficiency = val;
    notifyListeners();
  }

  void setPersistReasoningBlocks(bool val) {
    _persistReasoningBlocks = val;
    notifyListeners();
  }

  void setEnableDeveloperMode(bool val) {
    _enableDeveloperMode = val;
    notifyListeners();
  }

  void setEnableRawReasoningEdit(bool val) {
    _enableRawReasoningEdit = val;
    notifyListeners();
  }

  void acknowledgeRawEditWarning() {
    _rawReasoningEditWarningAcknowledged = true;
    saveSettings(showConfirmation: false);
  }

  void setEnableUsage(bool val) {
    _enableUsage = val;
    notifyListeners();
  }

  void setDisableSafety(bool val) {
    _disableSafety = val;
    notifyListeners();
  }

  void setReasoningEffort(String val) {
    _reasoningEffort = val;
    notifyListeners();
  }

  void setEnableGrounding(bool val) {
    _enableGrounding = val;
    notifyListeners();
  }

  void setSearchProvider(SearchProvider val) {
    _searchProvider = val;
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
        'enableMsgHistory': _enableMsgHistory,
        'enableReasoning': _enableReasoning,
        'enableGenerationSettings': _enableGenerationSettings,
        'enableMaxOutputTokens': _enableMaxOutputTokens,
        'enableReasoningEfficiency': _enableReasoningEfficiency,
        'persistReasoningBlocks': _persistReasoningBlocks,
        'enableDeveloperMode': _enableDeveloperMode,
        'enableRawReasoningEdit': _enableRawReasoningEdit,
        'rawReasoningEditWarningAcknowledged':
            _rawReasoningEditWarningAcknowledged,
        'enableGrounding': _enableGrounding,
        'enableUsage': _enableUsage,
        'disableSafety': _disableSafety,
        'enableCharacterCard': _enableCharacterCard,
      },
      'sillyTavernState': {
        'enableLorebook': _enableLorebook,
      },
    };
  }

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
    _enableMsgHistory = tog['enableMsgHistory'] as bool? ?? _enableMsgHistory;
    _enableReasoning = tog['enableReasoning'] as bool? ?? _enableReasoning;
    _enableGenerationSettings =
        tog['enableGenerationSettings'] as bool? ?? _enableGenerationSettings;
    _enableMaxOutputTokens =
        tog['enableMaxOutputTokens'] as bool? ?? _enableMaxOutputTokens;
    _enableReasoningEfficiency =
        tog['enableReasoningEfficiency'] as bool? ?? _enableReasoningEfficiency;
    _persistReasoningBlocks =
        tog['persistReasoningBlocks'] as bool? ?? _persistReasoningBlocks;

    _enableDeveloperMode =
        tog['enableDeveloperMode'] as bool? ?? _enableDeveloperMode;
    _enableRawReasoningEdit =
        tog['enableRawReasoningEdit'] as bool? ?? _enableRawReasoningEdit;
    _rawReasoningEditWarningAcknowledged =
        tog['rawReasoningEditWarningAcknowledged'] as bool? ??
        _rawReasoningEditWarningAcknowledged;
    if (!_enableDeveloperMode) {
      _enableRawReasoningEdit = false;
    }
    _enableGrounding = tog['enableGrounding'] as bool? ?? _enableGrounding;
    _enableUsage = tog['enableUsage'] as bool? ?? _enableUsage;
    _disableSafety = tog['disableSafety'] as bool? ?? _disableSafety;
    _enableCharacterCard =
        tog['enableCharacterCard'] as bool? ?? _enableCharacterCard;

    if (data.containsKey('enableCharacterCard')) {
      _enableCharacterCard = data['enableCharacterCard'] as bool;
    }

    final st = data['sillyTavernState'] as Map<String, dynamic>? ?? {};
    _enableLorebook = st['enableLorebook'] as bool? ?? true;

    await saveSettings(showConfirmation: false);
    notifyListeners();
  }
}
