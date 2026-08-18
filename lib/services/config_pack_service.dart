import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config_pack.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/scale_provider.dart';
import '../utils/constants.dart';

/// Captures, persists, and applies named [ConfigPack] bundles.
///
/// A ConfigPack holds the full settings-drawer state (provider, models,
/// system prompt, character card, lorebook, generation/toggles, theme, vfx,
/// scale) but **never** conversations or API keys. Packs are persisted in-app
/// (SharedPreferences) so they can be switched with one tap, and can also be
/// exported to / imported from a file.
class ConfigPackService {
  ConfigPackService._();

  /// Loads the in-app named packs (newest first).
  static Future<List<ConfigPack>> listPacks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ApiConstants.prefKeyConfigPacks);
    if (raw == null) return <ConfigPack>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ConfigPack.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('ConfigPackService.listPacks: $e');
      return <ConfigPack>[];
    }
  }

  /// Upserts a pack by name (replaces an existing pack with the same name).
  static Future<void> savePack(ConfigPack pack) async {
    final packs = List<ConfigPack>.from(await listPacks());
    packs.removeWhere((p) => p.name == pack.name);
    packs.insert(0, pack);
    await _persist(packs);
  }

  static Future<void> deletePack(String name) async {
    final packs = List<ConfigPack>.from(await listPacks());
    packs.removeWhere((p) => p.name == name);
    await _persist(packs);
  }

  static Future<void> renamePack(String oldName, String newName) async {
    final packs = List<ConfigPack>.from(await listPacks());
    final idx = packs.indexWhere((p) => p.name == oldName);
    if (idx == -1) return;
    packs[idx] = packs[idx].copyWith(name: newName);
    await _persist(packs);
  }

  static Future<void> _persist(List<ConfigPack> packs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiConstants.prefKeyConfigPacks,
      jsonEncode(packs.map((p) => p.toJson()).toList()),
    );
  }

  /// Snapshots the current settings of every provider into a new ConfigPack.
  /// Conversations and API keys are never captured.
  static ConfigPack captureCurrent({
    required ChatProvider chatProvider,
    required SettingsProvider settingsProvider,
    required ThemeProvider themeProvider,
    required VfxProvider vfxProvider,
    required ScaleProvider scaleProvider,
    required String name,
    String description = '',
  }) {
    final chat = Map<String, dynamic>.from(chatProvider.exportSettingsMap());
    chat.remove('sessions'); // conversations are not part of a ConfigPack
    return ConfigPack(
      name: name,
      description: description,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      sourceFormat: 'airp',
      settings: {
        'chat': chat,
        'settings': settingsProvider.exportSettingsMap(),
        'theme': themeProvider.exportSettingsMap(),
        'vfx': vfxProvider.exportSettingsMap(),
        'scale': scaleProvider.exportSettingsMap(),
      },
    );
  }

  /// Overwrites the live settings from a ConfigPack. Conversations and API
  /// keys are never touched. Throws on failure; callers should catch.
  static Future<void> applyPack(
    ConfigPack pack, {
    required ChatProvider chatProvider,
    required SettingsProvider settingsProvider,
    required ThemeProvider themeProvider,
    required VfxProvider vfxProvider,
    required ScaleProvider scaleProvider,
  }) async {
    final s = pack.settings;
    final chat = Map<String, dynamic>.from(
      s['chat'] as Map? ?? const {},
    );
    chat.remove('sessions'); // defensive: never apply conversations
    await chatProvider.importSettingsMap(chat);
    if (s['settings'] is Map) {
      await settingsProvider
          .importSettingsMap(Map<String, dynamic>.from(s['settings'] as Map));
    }
    if (s['theme'] is Map) {
      await themeProvider
          .importSettingsMap(Map<String, dynamic>.from(s['theme'] as Map));
    }
    if (s['vfx'] is Map) {
      await vfxProvider
          .importSettingsMap(Map<String, dynamic>.from(s['vfx'] as Map));
    }
    if (s['scale'] is Map) {
      await scaleProvider
          .importSettingsMap(Map<String, dynamic>.from(s['scale'] as Map));
    }
  }

  /// Parses an exported AIRP ConfigPack file. Returns null if the content is
  /// not a recognizable AIRP pack.
  static ConfigPack? parsePackFile(String content) {
    try {
      final json = jsonDecode(content);
      if (json is! Map) return null;
      final map = Map<String, dynamic>.from(json);
      if (map['settings'] == null && map['sourceFormat'] == null) {
        return null; // not a ConfigPack
      }
      return ConfigPack.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Tolerantly maps a SillyTavern Chat-Completion preset JSON into a
  /// ConfigPack (import-only). Maps the ordered/enabled `prompts` into the
  /// system instruction (and a saved system-prompt entry), and the generation
  /// fields (temperature/top_p/top_k/max_tokens) into the generation bucket.
  /// Never throws — missing/unknown fields are skipped.
  static ConfigPack importSillyTavernPreset(String content) {
    final json = jsonDecode(content);
    final map = json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};

    final name = map['name']?.toString().trim().isNotEmpty == true
        ? map['name'].toString().trim()
        : 'Imported ST Preset';

    final assembled = _assembleStPrompts(map);

    final gen = <String, dynamic>{};
    final t = _num(map, 'temperature');
    if (t != null) gen['temperature'] = t;
    final tp = _num(map, 'top_p');
    if (tp != null) gen['topP'] = tp;
    final tk = _num(map, 'top_k');
    if (tk != null) gen['topK'] = tk.toInt();
    final mt = _num(map, 'max_tokens') ?? _num(map, 'max_response_tokens');
    if (mt != null) gen['maxOutputTokens'] = mt.toInt();

    final settings = <String, dynamic>{
      'chat': <String, dynamic>{
        'systemInstruction': assembled,
        if (assembled.trim().isNotEmpty)
          'systemPrompts': [
            {'title': name, 'content': assembled},
          ],
      },
    };
    if (gen.isNotEmpty) {
      settings['settings'] = <String, dynamic>{
        'generation': gen,
        'toggles': {
          'enableGenerationSettings': true,
          'enableMaxOutputTokens': gen.containsKey('maxOutputTokens'),
        },
      };
    }

    return ConfigPack(
      name: name,
      description: 'Imported from SillyTavern',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      sourceFormat: 'sillytavern',
      settings: settings,
    );
  }

  /// Concatenates the content of enabled prompts in `prompt_order` (falling
  /// back to array order when no order is declared).
  static String _assembleStPrompts(Map<String, dynamic> map) {
    final byId = <String, String>{};
    final prompts = map['prompts'];
    if (prompts is! List) return '';
    for (final p in prompts) {
      if (p is! Map) continue;
      final id = p['identifier']?.toString() ?? '';
      final content = p['content']?.toString() ?? '';
      if (id.isNotEmpty) byId[id] = content;
    }

    final orderedIds = <String>[];
    final promptOrder = map['prompt_order'];
    if (promptOrder is List && promptOrder.isNotEmpty) {
      final order = (promptOrder[0] as Map?)?['order'];
      if (order is List) {
        for (final o in order) {
          if (o is Map && o['enabled'] == true) {
            final id = o['identifier']?.toString();
            if (id != null && id.isNotEmpty) orderedIds.add(id);
          }
        }
      }
    }

    final ids = orderedIds.isNotEmpty
        ? orderedIds
        : prompts
            .whereType<Map>()
            .map((p) => p['identifier']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();

    final parts = <String>[];
    for (final id in ids) {
      final c = byId[id];
      if (c != null && c.trim().isNotEmpty) parts.add(c);
    }
    return parts.join('\n\n');
  }

  static double? _num(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is num) return v.toDouble();
    return null;
  }
}
