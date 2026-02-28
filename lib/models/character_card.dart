import 'lorebook_models.dart';
import 'regex_models.dart';

/// Represents a SillyTavern-compatible character card.
/// Supports V1 and V2 specifications.
class CharacterCard {
  // Core V1/V2 fields
  String name;
  String description; // Persona
  String personality;
  String scenario;
  String firstMessage;
  String mesExample; // Example dialogue

  // V2 Spec fields
  String creator;
  String characterVersion;
  String systemPrompt;
  String postHistoryInstructions;
  List<String> alternateGreetings;
  Map<String, dynamic> extensions;
  
  // V2 Spec fields — added for full spec parity
  String creatorNotes;
  List<String> tags;

  /// Embedded lorebook parsed from `data.character_book`.
  Lorebook? characterBook;

  /// Depth prompt extracted from `extensions.depth_prompt`.
  /// Injected at the specified depth in the message history.
  String depthPromptText;
  int depthPromptDepth;
  LorebookRole depthPromptRole;

  /// Regex scripts extracted from `extensions.regex_scripts`.
  List<RegexScript> regexScripts;

  // Metadata for V2
  String spec;
  String specVersion;

  // Compatibility flags
  bool hasIncompatibleFields;
  List<String> compatibilityWarnings;

  CharacterCard({
    this.name = '',
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMessage = '',
    this.mesExample = '',
    this.creator = '',
    this.characterVersion = '',
    this.systemPrompt = '',
    this.postHistoryInstructions = '',
    List<String>? alternateGreetings,
    Map<String, dynamic>? extensions,
    this.creatorNotes = '',
    List<String>? tags,
    this.characterBook,
    this.depthPromptText = '',
    this.depthPromptDepth = 4,
    this.depthPromptRole = LorebookRole.system,
    List<RegexScript>? regexScripts,
    this.spec = 'chara_card_v2',
    this.specVersion = '2.0',
    this.hasIncompatibleFields = false,
    this.compatibilityWarnings = const [],
  }) : 
    alternateGreetings = alternateGreetings ?? [],
    extensions = extensions ?? {},
    tags = tags ?? [],
    regexScripts = regexScripts ?? [];

  /// Creates a CharacterCard from a JSON map (SillyTavern V1/V2 compatible).
  factory CharacterCard.fromJson(Map<String, dynamic> json) {
    final warnings = <String>[];
    bool incompatible = false;

    // Check strict version if present
    if (json.containsKey('spec') && json['spec'] != 'chara_card_v2') {
      warnings.add("Unknown spec: ${json['spec']}. Import may be lossy.");
      incompatible = true;
    }

    // Handle V2 'data' wrapper if present (embedded in PNG usually wraps content in 'data')
    Map<String, dynamic> content = json;
    if (json.containsKey('data') && json['data'] is Map) {
      content = json['data'];
    }

    // Extract fields with fail-safe defaults
    // Support both V1 and V2 field names where applicable
    final name = content['name'] as String? ?? '';
    final description = content['description'] as String? ?? content['char_persona'] as String? ?? '';
    final personality = content['personality'] as String? ?? '';
    final scenario = content['scenario'] as String? ?? content['world_scenario'] as String? ?? '';
    final firstMessage = content['first_mes'] as String? ?? content['char_greeting'] as String? ?? '';
    final mesExample = content['mes_example'] as String? ?? content['example_dialogue'] as String? ?? '';
    
    final creator = content['creator'] as String? ?? '';
    final characterVersion = content['character_version'] as String? ?? '';
    final systemPrompt = content['system_prompt'] as String? ?? '';
    final postHistoryInstructions = content['post_history_instructions'] as String? ?? '';
    
    List<String> altGreetings = [];
    if (content['alternate_greetings'] is List) {
      altGreetings = (content['alternate_greetings'] as List).map((e) => e.toString()).toList();
    }
    
    Map<String, dynamic> ext = {};
    if (content['extensions'] is Map) {
      ext = Map<String, dynamic>.from(content['extensions']);
    }

    // --- V2 additional fields ---
    final creatorNotes = content['creator_notes'] as String? ?? '';

    List<String> tags = [];
    if (content['tags'] is List) {
      tags = (content['tags'] as List).map((e) => e.toString()).toList();
    }

    // --- Character book (embedded lorebook) ---
    // V2 spec places it at data.character_book (NOT extensions.world).
    Lorebook? characterBook;
    if (content['character_book'] is Map) {
      characterBook = Lorebook.fromJson(
          Map<String, dynamic>.from(content['character_book']));
    }

    // --- Depth prompt from extensions ---
    String depthPromptText = '';
    int depthPromptDepth = 4;
    LorebookRole depthPromptRole = LorebookRole.system;
    if (ext['depth_prompt'] is Map) {
      final dp = ext['depth_prompt'] as Map<String, dynamic>;
      depthPromptText = dp['prompt'] as String? ?? '';
      depthPromptDepth = dp['depth'] as int? ?? 4;
      final roleVal = dp['role'] as String? ?? 'system';
      depthPromptRole = LorebookRole.values.firstWhere(
        (r) => r.name == roleVal,
        orElse: () => LorebookRole.system,
      );
    }

    // --- Regex scripts from extensions ---
    List<RegexScript> regexScripts = [];
    if (ext['regex_scripts'] is List) {
      regexScripts = (ext['regex_scripts'] as List)
          .map((e) => RegexScript.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // Spec metadata
    final spec = content['spec'] as String? ?? 'chara_card_v2';
    final specVersion = content['spec_version'] as String? ?? '2.0';

    return CharacterCard(
      name: name,
      description: description,
      personality: personality,
      scenario: scenario,
      firstMessage: firstMessage,
      mesExample: mesExample,
      creator: creator,
      characterVersion: characterVersion,
      systemPrompt: systemPrompt,
      postHistoryInstructions: postHistoryInstructions,
      alternateGreetings: altGreetings,
      extensions: ext,
      creatorNotes: creatorNotes,
      tags: tags,
      characterBook: characterBook,
      depthPromptText: depthPromptText,
      depthPromptDepth: depthPromptDepth,
      depthPromptRole: depthPromptRole,
      regexScripts: regexScripts,
      spec: spec,
      specVersion: specVersion,
      hasIncompatibleFields: incompatible,
      compatibilityWarnings: warnings,
    );
  }

  /// Converts the card to a JSON map.
  Map<String, dynamic> toJson() {
    // Build extensions with depth_prompt and regex_scripts included.
    final ext = Map<String, dynamic>.from(extensions);
    if (depthPromptText.isNotEmpty) {
      ext['depth_prompt'] = {
        'prompt': depthPromptText,
        'depth': depthPromptDepth,
        'role': depthPromptRole.name,
      };
    }
    if (regexScripts.isNotEmpty) {
      ext['regex_scripts'] = regexScripts.map((r) => r.toJson()).toList();
    }

    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'personality': personality,
      'scenario': scenario,
      'first_mes': firstMessage,
      'mes_example': mesExample,
      'creator': creator,
      'creator_notes': creatorNotes,
      'character_version': characterVersion,
      'system_prompt': systemPrompt,
      'post_history_instructions': postHistoryInstructions,
      'alternate_greetings': alternateGreetings,
      'tags': tags,
      'extensions': ext,
    };

    if (characterBook != null) {
      data['character_book'] = characterBook!.toJson();
    }

    return {
      'spec': spec,
      'spec_version': specVersion,
      'data': data,
    };
  }
  
  /// Creates a deep copy of the CharacterCard
  CharacterCard copyWith({
    String? name,
    String? description,
    String? personality,
    String? scenario,
    String? firstMessage,
    String? mesExample,
    String? creator,
    String? characterVersion,
    String? systemPrompt,
    String? postHistoryInstructions,
    List<String>? alternateGreetings,
    Map<String, dynamic>? extensions,
    String? creatorNotes,
    List<String>? tags,
    Lorebook? characterBook,
    String? depthPromptText,
    int? depthPromptDepth,
    LorebookRole? depthPromptRole,
    List<RegexScript>? regexScripts,
  }) {
    return CharacterCard(
      name: name ?? this.name,
      description: description ?? this.description,
      personality: personality ?? this.personality,
      scenario: scenario ?? this.scenario,
      firstMessage: firstMessage ?? this.firstMessage,
      mesExample: mesExample ?? this.mesExample,
      creator: creator ?? this.creator,
      characterVersion: characterVersion ?? this.characterVersion,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      postHistoryInstructions: postHistoryInstructions ?? this.postHistoryInstructions,
      alternateGreetings: alternateGreetings ?? List.from(this.alternateGreetings),
      extensions: extensions ?? Map.from(this.extensions),
      creatorNotes: creatorNotes ?? this.creatorNotes,
      tags: tags ?? List.from(this.tags),
      characterBook: characterBook ?? this.characterBook?.copyWith(),
      depthPromptText: depthPromptText ?? this.depthPromptText,
      depthPromptDepth: depthPromptDepth ?? this.depthPromptDepth,
      depthPromptRole: depthPromptRole ?? this.depthPromptRole,
      regexScripts: regexScripts ?? this.regexScripts.map((r) => r.copyWith()).toList(),
      spec: spec,
      specVersion: specVersion,
      hasIncompatibleFields: hasIncompatibleFields,
      compatibilityWarnings: List.from(compatibilityWarnings),
    );
  }
}
