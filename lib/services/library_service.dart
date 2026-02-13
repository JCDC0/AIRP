import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/scale_provider.dart';
import '../utils/version.dart';
import '../models/character_card.dart';
import '../models/preset_model.dart';
import 'character_card_service.dart';

/// Options controlling which categories to include in a library export.
class ExportOptions {
  final bool conversations;
  final bool systemPrompt;
  final bool advancedSystemPrompt;
  final bool generationParams;
  final bool layoutScaling;
  final bool visualsAtmosphere;

  const ExportOptions({
    this.conversations = true,
    this.systemPrompt = true,
    this.advancedSystemPrompt = true,
    this.generationParams = true,
    this.layoutScaling = true,
    this.visualsAtmosphere = true,
  });
}

/// Service for exporting and importing the full application state as a
/// portable `.airp` library file.
///
/// Settings are **overwritten** on import; system prompts and chat sessions
/// are **concatenated** (merged without duplicates).
class LibraryService {
  LibraryService._();

  /// Collects selected application state into a single JSON string.
  static Future<String> exportLibraryAsync({
    required ChatProvider chatProvider,
    required ThemeProvider themeProvider,
    required ScaleProvider scaleProvider,
    ExportOptions options = const ExportOptions(),
  }) async {
    final Map<String, dynamic> library = {
      'airp_library_version': '1.0',
      'app_version': appVersion,
      'exported_at': DateTime.now().toIso8601String(),
    };

    // --- Chat provider settings ---
    final chatExport = chatProvider.exportSettingsMap();

    if (options.generationParams) {
      library['generation'] = chatExport['generation'];
      library['toggles'] = chatExport['toggles'];
      library['provider'] = chatExport['provider'];
      library['models'] = chatExport['models'];
      library['modelBookmarks'] = chatExport['modelBookmarks'];
      library['localIp'] = chatExport['localIp'];
      library['localModelName'] = chatExport['localModelName'];
    }

    if (options.systemPrompt) {
      library['systemInstruction'] = chatExport['systemInstruction'];
      library['systemPrompts'] = chatExport['systemPrompts'];
    }

    if (options.advancedSystemPrompt) {
      library['advancedSystemInstruction'] =
          chatExport['advancedSystemInstruction'];

      // Load custom rules from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String? rulesJson = prefs.getString('custom_sys_prompt_rules');
      if (rulesJson != null) {
        try {
          library['customRules'] = jsonDecode(rulesJson);
        } catch (_) {}
      }
    }

    if (options.conversations) {
      library['sessions'] = chatExport['sessions'];
    }

    // --- Theme ---
    if (options.visualsAtmosphere) {
      library['theme'] = themeProvider.exportSettingsMap();
    }

    // --- Scale ---
    if (options.layoutScaling) {
      library['scale'] = scaleProvider.exportSettingsMap();
    }

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(library);
  }

  /// Parses a `.airp` JSON string and applies it to all providers.
  static Future<ImportResult> importLibrary({
    required String fileContent,
    required ChatProvider chatProvider,
    required ThemeProvider themeProvider,
    required ScaleProvider scaleProvider,
  }) async {
    try {
      final Map<String, dynamic> data = jsonDecode(fileContent);

      // Validate format
      if (!data.containsKey('airp_library_version')) {
        return ImportResult(
          success: false,
          message: 'Invalid file: missing airp_library_version header.',
        );
      }

      // Re-assemble a settings map that ChatProvider.importSettingsMap expects
      final Map<String, dynamic> chatSettings = {};
      if (data.containsKey('generation')) {
        chatSettings['generation'] = data['generation'];
      }
      if (data.containsKey('toggles')) {
        chatSettings['toggles'] = data['toggles'];
      }
      if (data.containsKey('provider')) {
        chatSettings['provider'] = data['provider'];
      }
      if (data.containsKey('models')) {
        chatSettings['models'] = data['models'];
      }
      if (data.containsKey('modelBookmarks')) {
        chatSettings['modelBookmarks'] = data['modelBookmarks'];
      }
      if (data.containsKey('localIp')) {
        chatSettings['localIp'] = data['localIp'];
      }
      if (data.containsKey('localModelName')) {
        chatSettings['localModelName'] = data['localModelName'];
      }
      if (data.containsKey('systemInstruction')) {
        chatSettings['systemInstruction'] = data['systemInstruction'];
      }
      if (data.containsKey('advancedSystemInstruction')) {
        chatSettings['advancedSystemInstruction'] =
            data['advancedSystemInstruction'];
      }
      if (data.containsKey('systemPrompts')) {
        chatSettings['systemPrompts'] = data['systemPrompts'];
      }
      if (data.containsKey('sessions')) {
        chatSettings['sessions'] = data['sessions'];
      }

      if (chatSettings.isNotEmpty) {
        await chatProvider.importSettingsMap(chatSettings);
      }

      // Apply theme (overwrite)
      if (data['theme'] != null) {
        await themeProvider.importSettingsMap(
          data['theme'] as Map<String, dynamic>,
        );
      }

      // Apply scale (overwrite)
      if (data['scale'] != null) {
        await scaleProvider.importSettingsMap(
          data['scale'] as Map<String, dynamic>,
        );
      }

      // Apply custom rules if present
      if (data['customRules'] != null) {
        await _importCustomRules(data['customRules'] as List<dynamic>);
      }

      final importedVersion = data['app_version'] ?? 'unknown';
      return ImportResult(
        success: true,
        message: 'Library imported successfully (from v$importedVersion).',
      );
    } catch (e) {
      debugPrint('Library import error: $e');
      return ImportResult(
        success: false,
        message: 'Import failed: ${e.toString()}',
      );
    }
  }

  /// Merges imported custom rules into SharedPreferences, deduplicating by label.
  static Future<void> _importCustomRules(List<dynamic> incoming) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> existing = [];

    final String? existingJson = prefs.getString('custom_sys_prompt_rules');
    if (existingJson != null) {
      try {
        existing = (jsonDecode(existingJson) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}
    }

    final existingLabels = existing.map((r) => r['label']).toSet();
    for (final rule in incoming) {
      final map = Map<String, dynamic>.from(rule);
      if (!existingLabels.contains(map['label'])) {
        existing.add(map);
        existingLabels.add(map['label']);
      }
    }

    await prefs.setString('custom_sys_prompt_rules', jsonEncode(existing));
  }

  // --- Character Card Helpers ---

  static Future<String> exportCharacterCard(CharacterCard card) async {
    final map = card.toJson();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }

  static Future<String> exportPreset(SystemPreset preset) async {
    final map = preset.toJson();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }
}

/// Result of a library import operation.
class ImportResult {
  final bool success;
  final String message;
  const ImportResult({required this.success, required this.message});
}
