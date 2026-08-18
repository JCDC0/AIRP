import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/scale_provider.dart';
import '../models/character_card.dart';

/// Service for exporting and importing the full application state as a
/// portable `.airp` library file.
///
/// Settings are **overwritten** on import; system prompts and chat sessions
/// are **concatenated** (merged without duplicates).
class LibraryService {
  LibraryService._();

  /// Parses a `.airp` JSON string and applies it to all providers.
  static Future<ImportResult> importLibrary({
    required String fileContent,
    required ChatProvider chatProvider,
    required ThemeProvider themeProvider,
    required VfxProvider vfxProvider,
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
      if (data.containsKey('starredProviders')) {
        chatSettings['starredProviders'] = data['starredProviders'];
      }
      if (data.containsKey('ui')) {
        chatSettings['ui'] = data['ui'];
      }
      if (data.containsKey('localIp')) {
        chatSettings['localIp'] = data['localIp'];
      }
      if (data.containsKey('localModelName')) {
        chatSettings['localModelName'] = data['localModelName'];
      }
      if (data.containsKey('openAiCompatibleEndpoint')) {
        chatSettings['openAiCompatibleEndpoint'] =
            data['openAiCompatibleEndpoint'];
      }
      if (data.containsKey('ollamaEndpoint')) {
        chatSettings['ollamaEndpoint'] = data['ollamaEndpoint'];
      }
      if (data.containsKey('systemInstruction')) {
        chatSettings['systemInstruction'] = data['systemInstruction'];
      }
      if (data.containsKey('systemPrompts')) {
        chatSettings['systemPrompts'] = data['systemPrompts'];
      }
      if (data.containsKey('sessions')) {
        chatSettings['sessions'] = data['sessions'];
      }

      // Character card
      if (data.containsKey('characterCard')) {
        chatSettings['characterCard'] = data['characterCard'];
      }
      if (data.containsKey('enableCharacterCard')) {
        chatSettings['enableCharacterCard'] = data['enableCharacterCard'];
      }

      // SillyTavern state (lorebook, regex, formatting)
      if (data.containsKey('sillyTavernState')) {
        chatSettings['sillyTavernState'] = data['sillyTavernState'];
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

      // Apply vfx (overwrite)
      if (data['vfx'] != null) {
        await vfxProvider.importSettingsMap(
          data['vfx'] as Map<String, dynamic>,
        );
      }

      // Apply scale (overwrite)
      if (data['scale'] != null) {
        await scaleProvider.importSettingsMap(
          data['scale'] as Map<String, dynamic>,
        );
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

  // --- Character Card Helpers ---

  static Future<String> exportCharacterCard(CharacterCard card) async {
    final map = card.toV3Json();
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
