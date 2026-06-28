import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../utils/constants.dart';
import 'secure_storage_service.dart';

/// Manages the secure storage, retrieval, and migration of API keys.
/// Centralized service for secure API credential management.
class ApiKeyService {
  final Map<AiProvider, String> _providerKeys = {};
  final Map<SearchProvider, String> _searchKeys = {};
  final VoidCallback onStateChanged;

  ApiKeyService({required this.onStateChanged}) {
    for (final provider in AiProvider.values) {
      _providerKeys[provider] = '';
    }
    for (final provider in SearchProvider.values) {
      _searchKeys[provider] = '';
    }
  }

  String getProviderKey(AiProvider provider) => _providerKeys[provider] ?? '';
  String getSearchKey(SearchProvider provider) => _searchKeys[provider] ?? '';

  /// Loads all API keys from storage, handling migration from SharedPreferences to SecureStorage.
  Future<void> loadAllKeys() async {
    final prefs = await SharedPreferences.getInstance();

    // Load AI Provider keys
    for (final provider in AiProvider.values) {
      final secureKey = _getSecureKeyForAiProvider(provider);
      final prefsKey = _getPrefsKeyForAiProvider(provider);
      if (secureKey == null || prefsKey == null) continue;

      _providerKeys[provider] = await _loadKeyWithMigration(
        prefs: prefs,
        secureKey: secureKey,
        prefsKey: prefsKey,
      );
    }

    // Load Search Provider keys
    _searchKeys[SearchProvider.brave] = await _loadKeyWithMigration(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyBraveApiKey,
      prefsKey: ApiConstants.prefKeyBraveApiKey,
    );
    _searchKeys[SearchProvider.tavily] = await _loadKeyWithMigration(
      prefs: prefs,
      secureKey: ApiConstants.secureKeyTavilyApiKey,
      prefsKey: ApiConstants.prefKeyTavilyApiKey,
    );
    _searchKeys[SearchProvider.serper] = await _loadKeyWithMigration(
      prefs: prefs,
      secureKey: ApiConstants.secureKeySerperApiKey,
      prefsKey: ApiConstants.prefKeySerperApiKey,
    );

    onStateChanged();
  }

  Future<void> setProviderKey(AiProvider provider, String key) async {
    _providerKeys[provider] = key;
    onStateChanged();
    await _persistProviderKey(provider, key);
  }

  Future<void> setSearchKey(SearchProvider provider, String key) async {
    _searchKeys[provider] = key;
    onStateChanged();
    await _persistSearchKey(provider, key);
  }

  Future<void> _persistProviderKey(AiProvider provider, String value) async {
    final secureKey = _getSecureKeyForAiProvider(provider);
    final prefsKey = _getPrefsKeyForAiProvider(provider);
    if (secureKey == null || prefsKey == null) return;

    await _saveKeySecurely(secureKey: secureKey, prefsKey: prefsKey, value: value);
  }

  Future<void> _persistSearchKey(SearchProvider provider, String value) async {
    String? secureKey;
    String? prefsKey;

    switch (provider) {
      case SearchProvider.brave:
        secureKey = ApiConstants.secureKeyBraveApiKey;
        prefsKey = ApiConstants.prefKeyBraveApiKey;
      case SearchProvider.tavily:
        secureKey = ApiConstants.secureKeyTavilyApiKey;
        prefsKey = ApiConstants.prefKeyTavilyApiKey;
      case SearchProvider.serper:
        secureKey = ApiConstants.secureKeySerperApiKey;
        prefsKey = ApiConstants.prefKeySerperApiKey;
      default: return;
    }

    await _saveKeySecurely(secureKey: secureKey, prefsKey: prefsKey, value: value);
  }

  Future<void> _saveKeySecurely({
    required String secureKey,
    required String prefsKey,
    required String value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
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

  Future<String> _loadKeyWithMigration({
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
      debugPrint('Secure storage read failed ($secureKey): $e');
    }

    final legacyValue = prefs.getString(prefsKey) ?? '';
    if (legacyValue.isNotEmpty) {
      try {
        await SecureStorageService.write(secureKey, legacyValue);
        await prefs.remove(prefsKey);
      } catch (e) {
        debugPrint('Secure storage migrate failed ($secureKey): $e');
      }
    }
    return legacyValue;
  }

  String? _getSecureKeyForAiProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini: return ApiConstants.secureKeyGemini;
      case AiProvider.openRouter: return ApiConstants.secureKeyOpenRouter;
      case AiProvider.openAi: return ApiConstants.secureKeyOpenAi;
      case AiProvider.arliAi: return ApiConstants.secureKeyArliAi;
      case AiProvider.nanoGpt: return ApiConstants.secureKeyNanoGpt;
      case AiProvider.nvidia: return ApiConstants.secureKeyNvidia;
      case AiProvider.huggingFace: return ApiConstants.secureKeyHuggingFace;
      case AiProvider.groq: return ApiConstants.secureKeyGroq;
      case AiProvider.vertexAi: return ApiConstants.secureKeyVertexAi;
      case AiProvider.blackboxAi: return ApiConstants.secureKeyBlackboxAi;
      case AiProvider.minimax: return ApiConstants.secureKeyMinimax;
      case AiProvider.openAiCompatible: return ApiConstants.secureKeyOpenAiCompatible;
      case AiProvider.deepseek: return ApiConstants.secureKeyDeepseek;
      case AiProvider.ollama: return ApiConstants.secureKeyOllama;
      case AiProvider.qwen: return ApiConstants.secureKeyQwen;
      case AiProvider.xAi: return ApiConstants.secureKeyXAi;
      case AiProvider.zAi: return ApiConstants.secureKeyZAi;
      case AiProvider.mistral: return ApiConstants.secureKeyMistral;
      case AiProvider.mimo: return ApiConstants.secureKeyMimo;
      default: return null;
    }
  }

  String? _getPrefsKeyForAiProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini: return ApiConstants.prefKeyGemini;
      case AiProvider.openRouter: return ApiConstants.prefKeyOpenRouter;
      case AiProvider.openAi: return ApiConstants.prefKeyOpenAi;
      case AiProvider.arliAi: return ApiConstants.prefKeyArliAi;
      case AiProvider.nanoGpt: return ApiConstants.prefKeyNanoGpt;
      case AiProvider.nvidia: return ApiConstants.prefKeyNvidia;
      case AiProvider.huggingFace: return ApiConstants.prefKeyHuggingFace;
      case AiProvider.groq: return ApiConstants.prefKeyGroq;
      case AiProvider.vertexAi: return ApiConstants.prefKeyVertexAi;
      case AiProvider.blackboxAi: return ApiConstants.prefKeyBlackboxAi;
      case AiProvider.minimax: return ApiConstants.prefKeyMinimax;
      case AiProvider.openAiCompatible: return ApiConstants.prefKeyOpenAiCompatible;
      case AiProvider.deepseek: return ApiConstants.prefKeyDeepseek;
      case AiProvider.ollama: return ApiConstants.prefKeyOllama;
      case AiProvider.qwen: return ApiConstants.prefKeyQwen;
      case AiProvider.xAi: return ApiConstants.prefKeyXAi;
      case AiProvider.zAi: return ApiConstants.prefKeyZAi;
      case AiProvider.mistral: return ApiConstants.prefKeyMistral;
      case AiProvider.mimo: return ApiConstants.prefKeyMimo;
      default: return null;
    }
  }
}
