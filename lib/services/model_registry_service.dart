import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import 'strategies/strategy_resolver.dart';

/// Manages AI model discovery, listing, and metadata caching.
/// Centralized service for managing AI model discovery and caching.
class ModelRegistryService {
  final Map<AiProvider, List<ModelInfo>> _modelLists = {};
  final Map<AiProvider, bool> _loadingStates = {};
  final Map<AiProvider, String> _lastErrors = {};
  final VoidCallback onStateChanged;

  ModelRegistryService({required this.onStateChanged}) {
    for (final provider in AiProvider.values) {
      _modelLists[provider] = [];
      _loadingStates[provider] = false;
    }
  }

  List<ModelInfo> getModels(AiProvider provider) => _modelLists[provider] ?? [];
  bool isLoading(AiProvider provider) => _loadingStates[provider] ?? false;

  /// The failure message from this provider's most recent fetch, or null if
  /// the last fetch succeeded. A silently swallowed fetch error is
  /// indistinguishable from "the key did nothing", so the UI surfaces this.
  String? lastError(AiProvider provider) => _lastErrors[provider];

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

  /// Fetches the model list for [provider].
  ///
  /// [customBase] is the user-configured server root for providers that point
  /// at an endpoint the user owns; each strategy decides how to turn it into a
  /// listing URL. [customUrl] overrides the result outright.
  Future<void> fetchModels(
    AiProvider provider,
    String apiKey, {
    Map<String, String>? headers,
    String? customBase,
    String? customUrl,
  }) async {
    final strategy = StrategyResolver.resolve(provider);
    final resolved = strategy.getModelsUrl(customBase: customBase);
    final url =
        customUrl ??
        (provider == AiProvider.gemini ? "$resolved?key=$apiKey" : resolved);

    if (url.isEmpty) {
      _lastErrors[provider] =
          'No server endpoint configured for this provider.';
      onStateChanged();
      return;
    }

    _loadingStates[provider] = true;
    _lastErrors.remove(provider);
    onStateChanged();

    try {
      final models = await ChatApiService.fetchModels(
        url: url,
        headers: headers ?? strategy.getHeaders(apiKey),
        parser: strategy.parseModels,
      );

      _modelLists[provider] = models;
      if (models.isEmpty) {
        _lastErrors[provider] =
            'The provider returned an empty model list.';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        strategy.prefKey,
        models.map((m) => jsonEncode(m.toJson())).toList(),
      );
    } catch (e) {
      debugPrint("Registry Fetch Error ($provider): $e");
      _lastErrors[provider] = _readableError(e);
    } finally {
      _loadingStates[provider] = false;
      onStateChanged();
    }
  }

  /// Reduces an exception to a single line a user can act on, without leaking
  /// the request URL (which for Gemini carries the API key as a query param).
  static String _readableError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    final status = RegExp(r'Failed to fetch models: (\d{3})').firstMatch(text);
    if (status != null) {
      final code = status.group(1);
      switch (code) {
        case '401':
        case '403':
          return 'Rejected by the provider ($code). Check the API key.';
        case '404':
          return 'Model list endpoint not found (404). Check the endpoint URL.';
        case '429':
          return 'Rate limited by the provider (429). Try again shortly.';
        default:
          return 'Provider returned HTTP $code.';
      }
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused')) {
      return 'Could not reach the server. Check the endpoint and network.';
    }
    if (text.contains('TimeoutException')) {
      return 'The request timed out.';
    }
    return text.length > 160 ? '${text.substring(0, 157)}...' : text;
  }
}
