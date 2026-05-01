import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import '../utils/constants.dart';

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
      final key = _getPrefKeyForProvider(provider);
      if (key == null) continue;

      final List<String>? cached = prefs.getStringList(key);
      if (cached != null) {
        _modelLists[provider] = cached.map((s) {
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

  String? _getPrefKeyForProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini: return ApiConstants.prefListGemini;
      case AiProvider.openRouter: return ApiConstants.prefListOpenRouter;
      case AiProvider.arliAi: return ApiConstants.prefListArliAi;
      case AiProvider.nanoGpt: return ApiConstants.prefListNanoGpt;
      case AiProvider.nvidia: return ApiConstants.prefListNvidia;
      case AiProvider.openAi: return ApiConstants.prefListOpenAi;
      case AiProvider.huggingFace: return ApiConstants.prefListHuggingFace;
      case AiProvider.groq: return ApiConstants.prefListGroq;
      case AiProvider.vertexAi: return ApiConstants.prefListVertexAi;
      case AiProvider.blackboxAi: return ApiConstants.prefListBlackboxAi;
      case AiProvider.minimax: return ApiConstants.prefListMinimax;
      case AiProvider.deepseek: return ApiConstants.prefListDeepseek;
      case AiProvider.ollama: return ApiConstants.prefListOllama;
      case AiProvider.qwen: return ApiConstants.prefListQwen;
      case AiProvider.xAi: return ApiConstants.prefListXAi;
      case AiProvider.zAi: return ApiConstants.prefListZAi;
      case AiProvider.mistral: return ApiConstants.prefListMistral;
      case AiProvider.openAiCompatible: return ApiConstants.prefListOpenAiCompatible;
      default: return null;
    }
  }

  Future<void> fetchModels(AiProvider provider, String apiKey, {Map<String, String>? headers}) async {
    final url = _getUrlForProvider(provider, apiKey);
    final key = _getPrefKeyForProvider(provider);
    if (url == null || key == null) return;

    _loadingStates[provider] = true;
    onStateChanged();

    try {
      final models = await ChatApiService.fetchModels(
        url: url,
        headers: headers ?? (apiKey.isNotEmpty ? {"Authorization": "Bearer $apiKey"} : null),
        parser: (json) => _getParserForProvider(provider)(json),
      );

      _modelLists[provider] = models;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, models.map((m) => jsonEncode(m.toJson())).toList());
    } catch (e) {
      debugPrint("Registry Fetch Error ($provider): $e");
    } finally {
      _loadingStates[provider] = false;
      onStateChanged();
    }
  }

  String? _getUrlForProvider(AiProvider provider, String apiKey) {
    switch (provider) {
      case AiProvider.gemini: return "${ApiConstants.geminiBaseUrl}?key=$apiKey";
      case AiProvider.openRouter: return ApiConstants.openRouterBaseUrl;
      case AiProvider.arliAi: return ApiConstants.arliAiBaseUrl;
      case AiProvider.nanoGpt: return ApiConstants.nanoGptBaseUrl;
      case AiProvider.nvidia: return ApiConstants.nvidiaBaseUrl;
      case AiProvider.openAi: return ApiConstants.openAiBaseUrl;
      case AiProvider.huggingFace: return ApiConstants.huggingFaceBaseUrl;
      case AiProvider.groq: return ApiConstants.groqBaseUrl;
      case AiProvider.blackboxAi: return ApiConstants.blackboxAiBaseUrl;
      case AiProvider.minimax: return ApiConstants.minimaxBaseUrl;
      case AiProvider.deepseek: return ApiConstants.deepseekBaseUrl;
      case AiProvider.qwen: return ApiConstants.qwenBaseUrl;
      case AiProvider.xAi: return ApiConstants.xAiBaseUrl;
      case AiProvider.zAi: return ApiConstants.zAiBaseUrl;
      case AiProvider.mistral: return ApiConstants.mistralBaseUrl;
      default: return null;
    }
  }

  List<ModelInfo> Function(dynamic) _getParserForProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini:
        return (json) {
          final List<dynamic> models = json['models'];
          return models.where((m) {
            final methods = List<String>.from(m['supportedGenerationMethods'] ?? []);
            return methods.contains('generateContent');
          }).map<ModelInfo>((m) => ModelInfo(
            id: m['name'].toString(),
            name: m['displayName']?.toString() ?? m['name'].toString(),
            description: m['description']?.toString() ?? "",
            contextLength: m['inputTokenLimit']?.toString() ?? "",
          )).toList();
        };
      case AiProvider.openRouter:
        return (json) {
          final List<dynamic> dataList = json['data'];
          return dataList.map<ModelInfo>((e) {
            final pricing = e['pricing'] ?? {};
            return ModelInfo(
              id: e['id'].toString(),
              name: e['name']?.toString() ?? e['id'].toString(),
              description: e['description']?.toString() ?? "",
              contextLength: e['context_length']?.toString() ?? "",
              pricing: "${pricing['prompt'] ?? '0'} / ${pricing['completion'] ?? '0'}",
              created: e['created'],
              rawData: e,
            );
          }).toList();
        };
      case AiProvider.huggingFace:
        return (json) {
          final List<dynamic> dataList = json;
          return dataList.map<ModelInfo>((e) => ModelInfo(
            id: e['id'].toString(),
            name: e['name']?.toString() ?? cleanModelName(e['id'].toString()),
            description: e['description']?.toString() ?? "",
          )).toList();
        };
      case AiProvider.nanoGpt:
        return (json) {
          final List<dynamic> dataList = json['data'] ?? [];
          return dataList.map<ModelInfo>((e) {
            final pricing = e['pricing'] ?? {};
            double prompt = double.tryParse(pricing['prompt']?.toString() ?? "0") ?? 0;
            double completion = double.tryParse(pricing['completion']?.toString() ?? "0") ?? 0;
            if (prompt > 0) prompt /= 1000000;
            if (completion > 0) completion /= 1000000;
            return ModelInfo(
              id: e['id'].toString(),
              name: e['name']?.toString() ?? cleanModelName(e['id'].toString()),
              description: e['description']?.toString() ?? "Owned by: ${e['owned_by'] ?? 'Unknown'}",
              contextLength: (e['context_length'] ?? e['context_window'])?.toString() ?? "",
              pricing: "$prompt / $completion",
              created: e['created'],
              rawData: e,
            );
          }).toList();
        };
      default:
        // Standard OpenAI-compatible parser
        return (json) {
          final List<dynamic> dataList = json['data'] ?? [];
          return dataList.map<ModelInfo>((e) {
            final rawId = e['id'].toString();
            final pricing = e['pricing'] ?? {};
            return ModelInfo(
              id: rawId,
              name: e['name']?.toString() ?? cleanModelName(rawId),
              description: e['description']?.toString() ?? "Owned by: ${e['owned_by'] ?? 'Unknown'}",
              contextLength: (e['context_length'] ?? e['context_window'])?.toString() ?? "",
              pricing: pricing.isNotEmpty ? "${pricing['prompt'] ?? '0'} / ${pricing['completion'] ?? '0'}" : "",
              created: e['created'],
              rawData: e,
            );
          }).toList();
        };
    }
  }
}
