import 'dart:convert';

import 'package:airp/models/preset_model.dart';
import 'package:airp/models/regex_models.dart';

// ---------------------------------------------------------------------------
// PresetService
// ---------------------------------------------------------------------------

/// Service for importing, exporting, and converting [SystemPreset] objects.
///
/// ## Native AIRP presets
///
/// Full-fidelity round-trip via [exportAirpPreset] / [importAirpPreset].
/// All fields (system prompt, generation settings, lorebook entries, regex
/// scripts, formatting template, post-history instructions) are preserved.
///
/// ## SillyTavern preset import
///
/// [importSillyTavernPreset] extracts what AIRP can use from an ST OpenAI
/// preset JSON:
///
/// | ST field | AIRP mapping |
/// |----------|-------------|
/// | `name` | preset name |
/// | `temperature` | generationSettings.temperature |
/// | `top_p` / `frequency_penalty` / `presence_penalty` | generationSettings |
/// | `top_k` | generationSettings.top_k |
/// | `max_tokens` / `openai_max_tokens` | generationSettings.max_tokens |
/// | `main_prompt` (from prompts[]) | systemPrompt |
/// | `post_history_instructions` (from prompts[]) | postHistoryInstructions |
///
/// The incompatible `prompts[]` / `prompt_order[]` orchestration structure
/// is discarded. A [PresetImportResult] is returned containing the preset
/// and a list of warnings about discarded fields.
class PresetService {
  PresetService._();

  // -------------------------------------------------------------------------
  // AIRP native
  // -------------------------------------------------------------------------

  /// Serialises a [SystemPreset] to a JSON string for file export.
  static String exportAirpPreset(SystemPreset preset) {
    final map = preset.toJson();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }

  /// Deserialises a JSON string into a [SystemPreset].
  ///
  /// Throws [FormatException] if [jsonStr] is not valid JSON.
  static SystemPreset importAirpPreset(String jsonStr) {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object at top level.');
    }
    return SystemPreset.fromJson(decoded);
  }

  // -------------------------------------------------------------------------
  // SillyTavern import
  // -------------------------------------------------------------------------

  /// Attempts to import a SillyTavern OpenAI-format preset.
  ///
  /// Returns a [PresetImportResult] containing the converted [SystemPreset]
  /// and a list of human-readable warnings about fields that were discarded
  /// or could not be mapped.
  static PresetImportResult importSillyTavernPreset(String jsonStr) {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object at top level.');
    }
    return _parseSillyTavernPreset(decoded);
  }

  /// Detects whether a JSON map looks like a SillyTavern preset.
  ///
  /// Heuristic: the presence of `prompts` list or `prompt_order` list or
  /// `chat_completion_source` string strongly suggests an ST preset.
  static bool isSillyTavernPreset(Map<String, dynamic> json) {
    return json.containsKey('prompts') ||
        json.containsKey('prompt_order') ||
        json.containsKey('chat_completion_source');
  }

  /// Auto-detects the format and imports accordingly.
  ///
  /// If the JSON looks like a SillyTavern preset, it is imported with
  /// [importSillyTavernPreset]. Otherwise, it falls through to
  /// [importAirpPreset].
  static PresetImportResult importAutoDetect(String jsonStr) {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object at top level.');
    }

    if (isSillyTavernPreset(decoded)) {
      return _parseSillyTavernPreset(decoded);
    }

    return PresetImportResult(
      preset: SystemPreset.fromJson(decoded),
      warnings: [],
    );
  }

  // -------------------------------------------------------------------------
  // SillyTavern parser internals
  // -------------------------------------------------------------------------

  static PresetImportResult _parseSillyTavernPreset(
      Map<String, dynamic> json) {
    final warnings = <String>[];

    // --- Name ---
    final name = json['name'] as String? ?? 'Imported ST Preset';

    // --- Generation settings ---
    final genSettings = <String, dynamic>{};

    if (json['temperature'] != null) {
      genSettings['temperature'] = _toDouble(json['temperature']);
    }
    if (json['top_p'] != null) {
      genSettings['top_p'] = _toDouble(json['top_p']);
    }
    if (json['top_k'] != null) {
      genSettings['top_k'] = _toInt(json['top_k']);
    }
    if (json['frequency_penalty'] != null) {
      genSettings['frequency_penalty'] =
          _toDouble(json['frequency_penalty']);
    }
    if (json['presence_penalty'] != null) {
      genSettings['presence_penalty'] =
          _toDouble(json['presence_penalty']);
    }

    // max_tokens — ST uses both 'max_tokens' and 'openai_max_tokens'.
    final maxTokens =
        json['openai_max_tokens'] ?? json['max_tokens'];
    if (maxTokens != null) {
      genSettings['max_tokens'] = _toInt(maxTokens);
    }

    // --- Extract main prompt and post-history from prompts[] ---
    String systemPrompt = '';
    String postHistory = '';

    if (json['prompts'] is List) {
      final prompts = json['prompts'] as List;
      for (final p in prompts) {
        if (p is! Map) continue;
        final role = p['role'] as String? ?? '';
        final content = p['content'] as String? ?? '';
        final identifier = p['identifier'] as String? ??
            p['name'] as String? ??
            '';

        // ST's "main" prompt is identified by role=system + identifier
        // containing "main" or being the first system prompt.
        if (_isMainPrompt(role, identifier)) {
          systemPrompt = content;
        } else if (_isPostHistory(role, identifier)) {
          postHistory = content;
        }
      }
    }

    // --- Warn about discarded structures ---
    if (json['prompts'] is List && (json['prompts'] as List).length > 2) {
      final count = (json['prompts'] as List).length;
      warnings.add(
          'Discarded $count prompt entries from ST prompts[] array '
          '(only main prompt and post-history instructions were imported).');
    }

    if (json['prompt_order'] is List) {
      warnings.add(
          'Discarded prompt_order[] orchestration — AIRP does not '
          'support ST\'s multi-slot prompt assembly.');
    }

    if (json['chat_completion_source'] != null) {
      warnings.add(
          'Ignored chat_completion_source '
          '"${json['chat_completion_source']}" — AIRP uses its '
          'own backend selection.');
    }

    // Warn about ST-specific fields we can't map.
    const stOnlyFields = [
      'assistant_prefill',
      'claude_use_sysprompt',
      'squash_system_messages',
      'continue_nudge_prompt',
      'bias_preset_selected',
      'jailbreak_prompt',
      'jailbreak_system',
      'impersonation_prompt',
      'wi_format',
      'scenario_format',
      'personality_format',
      'group_nudge_prompt',
    ];
    final foundStFields = stOnlyFields
        .where((f) => json.containsKey(f) && json[f] != null)
        .toList();
    if (foundStFields.isNotEmpty) {
      warnings.add(
          'Ignored ST-specific fields: ${foundStFields.join(', ')}.');
    }

    // --- Regex scripts embedded in ST preset ---
    List<RegexScript> regexScripts = [];
    if (json['regex_scripts'] is List) {
      regexScripts = (json['regex_scripts'] as List)
          .whereType<Map>()
          .map((e) =>
              RegexScript.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // --- Build the preset ---
    final preset = SystemPreset(
      name: name,
      description: 'Imported from SillyTavern preset.',
      systemPrompt: systemPrompt,
      advancedPrompt: '',
      generationSettings: genSettings,
      postHistoryInstructions: postHistory,
      regexScripts: regexScripts,
      sourceFormat: 'sillytavern',
    );

    return PresetImportResult(
      preset: preset,
      warnings: warnings,
    );
  }

  /// Checks if a prompt entry is the "main" system prompt.
  static bool _isMainPrompt(String role, String identifier) {
    if (role != 'system') return false;
    final id = identifier.toLowerCase();
    return id == 'main' ||
        id == 'main_prompt' ||
        id == 'systemprompt' ||
        id == 'system_prompt';
  }

  /// Checks if a prompt entry is the post-history instructions.
  static bool _isPostHistory(String role, String identifier) {
    final id = identifier.toLowerCase();
    return id == 'post_history_instructions' ||
        id == 'posthistoryinstructions' ||
        id == 'post_history' ||
        id == 'jailbreak';
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

// ---------------------------------------------------------------------------
// Import result
// ---------------------------------------------------------------------------

/// Result of a preset import operation.
///
/// Contains the converted [preset] and any [warnings] about fields that
/// were discarded or could not be mapped from the source format.
class PresetImportResult {
  /// The imported preset.
  final SystemPreset preset;

  /// Human-readable warnings about discarded or unmapped fields.
  final List<String> warnings;

  /// True if no warnings were generated.
  bool get isClean => warnings.isEmpty;

  const PresetImportResult({
    required this.preset,
    required this.warnings,
  });
}
