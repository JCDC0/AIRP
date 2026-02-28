import 'package:airp/models/lorebook_models.dart';
import 'package:airp/models/regex_models.dart';
import 'package:airp/models/formatting_models.dart';

/// Represents a system prompt preset, including main prompt,
/// advanced prompt override, custom rules, and optional v0.5.12+
/// subsystem bundles (lorebook entries, regex scripts, formatting template).
class SystemPreset {
  String name;
  String description;
  String systemPrompt;
  String advancedPrompt; // Tweaks & Overrides
  List<Map<String, dynamic>> customRules;
  Map<String, dynamic> generationSettings; // Optional generation params

  // Metadata
  String version;

  // --- v0.5.12+ subsystem bundles ---

  /// Optional lorebook entries bundled with this preset.
  List<LorebookEntry> lorebookEntries;

  /// Optional regex scripts bundled with this preset.
  List<RegexScript> regexScripts;

  /// Optional formatting template bundled with this preset.
  FormattingTemplate? formattingTemplate;

  /// Post-history instructions (injected after the chat history).
  String postHistoryInstructions;

  /// Source format identifier for imported presets.
  /// - `'airp'` — native AIRP preset
  /// - `'sillytavern'` — imported from SillyTavern
  String sourceFormat;

  SystemPreset({
    required this.name,
    this.description = '',
    this.systemPrompt = '',
    this.advancedPrompt = '',
    this.customRules = const [],
    this.generationSettings = const {},
    this.version = '1.0',
    List<LorebookEntry>? lorebookEntries,
    List<RegexScript>? regexScripts,
    this.formattingTemplate,
    this.postHistoryInstructions = '',
    this.sourceFormat = 'airp',
  })  : lorebookEntries = lorebookEntries ?? [],
        regexScripts = regexScripts ?? [];

  factory SystemPreset.fromJson(Map<String, dynamic> json) {
    // --- Lorebook entries ---
    List<LorebookEntry> parsedLorebook = [];
    if (json['lorebook_entries'] is List) {
      parsedLorebook = (json['lorebook_entries'] as List)
          .map((e) => LorebookEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // --- Regex scripts ---
    List<RegexScript> parsedRegex = [];
    if (json['regex_scripts'] is List) {
      parsedRegex = (json['regex_scripts'] as List)
          .map((e) => RegexScript.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // --- Formatting template ---
    FormattingTemplate? parsedFormatting;
    if (json['formatting_template'] is Map) {
      parsedFormatting = FormattingTemplate.fromJson(
          Map<String, dynamic>.from(json['formatting_template']));
    }

    return SystemPreset(
      name: json['name'] as String? ?? 'Untitled Preset',
      description: json['description'] as String? ?? '',
      systemPrompt: json['system_prompt'] as String? ?? '',
      advancedPrompt: json['advanced_prompt'] as String? ?? '',
      customRules: (json['custom_rules'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      generationSettings:
          (json['generation_settings'] as Map<String, dynamic>?) ?? {},
      version: json['version'] as String? ?? '1.0',
      lorebookEntries: parsedLorebook,
      regexScripts: parsedRegex,
      formattingTemplate: parsedFormatting,
      postHistoryInstructions:
          json['post_history_instructions'] as String? ?? '',
      sourceFormat: json['source_format'] as String? ?? 'airp',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'system_prompt': systemPrompt,
      'advanced_prompt': advancedPrompt,
      'custom_rules': customRules,
      'generation_settings': generationSettings,
      'version': version,
      'lorebook_entries': lorebookEntries.map((e) => e.toJson()).toList(),
      'regex_scripts': regexScripts.map((e) => e.toJson()).toList(),
      if (formattingTemplate != null)
        'formatting_template': formattingTemplate!.toJson(),
      'post_history_instructions': postHistoryInstructions,
      'source_format': sourceFormat,
    };
  }

  /// Creates a deep copy with optional overrides.
  SystemPreset copyWith({
    String? name,
    String? description,
    String? systemPrompt,
    String? advancedPrompt,
    List<Map<String, dynamic>>? customRules,
    Map<String, dynamic>? generationSettings,
    String? version,
    List<LorebookEntry>? lorebookEntries,
    List<RegexScript>? regexScripts,
    FormattingTemplate? formattingTemplate,
    String? postHistoryInstructions,
    String? sourceFormat,
  }) {
    return SystemPreset(
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      advancedPrompt: advancedPrompt ?? this.advancedPrompt,
      customRules: customRules ??
          this.customRules.map((r) => Map<String, dynamic>.from(r)).toList(),
      generationSettings: generationSettings ??
          Map<String, dynamic>.from(this.generationSettings),
      version: version ?? this.version,
      lorebookEntries: lorebookEntries ??
          this.lorebookEntries.map((e) => e.copyWith()).toList(),
      regexScripts:
          regexScripts ?? this.regexScripts.map((e) => e.copyWith()).toList(),
      formattingTemplate:
          formattingTemplate ?? this.formattingTemplate?.copyWith(),
      postHistoryInstructions:
          postHistoryInstructions ?? this.postHistoryInstructions,
      sourceFormat: sourceFormat ?? this.sourceFormat,
    );
  }
}
