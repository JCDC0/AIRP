import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import 'strategies/strategy_resolver.dart';

/// Manages AI model discovery, listing, and metadata caching.
/// Extracted from ChatProvider to simplify provider model management.
class ModelRegistryService {
  final Map<AiProvider, List<ModelInfo>> _modelLists = {};
  final Map<AiProvider, bool> _loadingStates = {};
  final VoidCallback onStateChanged;

  ModelRegistryService({required this.onStateChanged}) {
    for (final provider in AiProvider.values) {
      _modelLists[provider] = [];
      _loadingStates[provider] = false;
    }
  }

  List<ModelInfo> getModels(AiProvider provider) => _modelLists[provider] ?? [];
  bool isLoading(AiProvider provider) => _loadingStates[provider] ?? false;

  bool get isAnyLoading => _loadingStates.values.any((loading) => loading);

  /// Initializes registry by loading cached lists from SharedPreferences.
  Future<void> loadCachedModels() async {
    final prefs = await SharedPreferences.getInstance();
    for (final provider in AiProvider.values) {
      final strategy = StrategyResolver.resolve(provider);
      final List<String>? cached = prefs.getStringList(strategy.prefKey);

      if (cached != null) {
        _modelLists[provider] =
            cached.map((s) {
              try {
                return ModelInfo.fromJson(jsonDecode(s));
              } catch (e) {
                return ModelInfo(id: s, name: s);
              }
            }).toList();
      }
    }
    onStateChanged();
  }

  Future<void> fetchModels(
    AiProvider provider,
    String apiKey, {
    Map<String, String>? headers,
    String? customUrl,
  }) async {
    final strategy = StrategyResolver.resolve(provider);
    final url =
        customUrl ??
        (provider == AiProvider.gemini
            ? "${strategy.baseUrl}?key=$apiKey"
            : strategy.baseUrl);

    if (url.isEmpty) return;

    _loadingStates[provider] = true;
    onStateChanged();

    try {
      final models = await ChatApiService.fetchModels(
        url: url,
        headers: headers ?? strategy.getHeaders(apiKey),
        parser: strategy.parseModels,
      );

      _modelLists[provider] = models;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        strategy.prefKey,
        models.map((m) => jsonEncode(m.toJson())).toList(),
      );
    } catch (e) {
      debugPrint("Registry Fetch Error ($provider): $e");
    } finally {
      _loadingStates[provider] = false;
      onStateChanged();
    }
  }
}
