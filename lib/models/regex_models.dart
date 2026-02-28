/// Represents a SillyTavern-compatible regex script.
///
/// Matches ST's `RegexScriptData` structure. Supports scope-based targeting,
/// ephemeral modes (display-only / prompt-only), depth ranges, and macro modes.
class RegexScript {
  /// Unique identifier.
  int id;

  /// Human-readable label.
  String scriptName;

  /// The find pattern (regex or literal).
  String findRegex;

  /// The replacement string (may contain capture group refs and macros).
  String replaceString;

  /// Strings to trim from the input before regex matching.
  List<String> trimStrings;

  /// Whether this script is currently enabled.
  bool enabled;

  /// Scope of this script.
  RegexScope scope;

  // --- Placement / targeting ---

  /// Apply to user input before sending.
  bool affectsUserInput;

  /// Apply to AI response text.
  bool affectsAiOutput;

  /// Apply to World Info / lorebook content.
  bool affectsWorldInfo;

  /// Apply to reasoning / thinking output.
  bool affectsReasoning;

  // --- Ephemerality ---

  /// If true, only affects displayed text (stored text unchanged).
  bool displayOnly;

  /// If true, only affects the prompt sent to AI (stored text unchanged).
  bool promptOnly;

  // --- Depth range ---

  /// Minimum message depth (0 = most recent) for this script to apply.
  int minDepth;

  /// Maximum message depth for this script to apply (-1 = unlimited).
  int maxDepth;

  // --- Regex flags ---

  /// Case-insensitive matching.
  bool caseInsensitive;

  /// Dot matches newlines.
  bool dotAll;

  /// ^ and $ match line boundaries.
  bool multiLine;

  /// Enable unicode support.
  bool unicode;

  // --- Macro mode ---

  /// How macros in the replacement string are handled.
  RegexMacroMode macroMode;

  /// Sort order (lower = runs first).
  int sortOrder;

  /// Arbitrary extension data for round-trip fidelity.
  Map<String, dynamic> extensions;

  RegexScript({
    this.id = 0,
    this.scriptName = '',
    this.findRegex = '',
    this.replaceString = '',
    List<String>? trimStrings,
    this.enabled = true,
    this.scope = RegexScope.scoped,
    this.affectsUserInput = false,
    this.affectsAiOutput = true,
    this.affectsWorldInfo = false,
    this.affectsReasoning = false,
    this.displayOnly = false,
    this.promptOnly = false,
    this.minDepth = 0,
    this.maxDepth = -1,
    this.caseInsensitive = false,
    this.dotAll = false,
    this.multiLine = false,
    this.unicode = false,
    this.macroMode = RegexMacroMode.none,
    this.sortOrder = 0,
    Map<String, dynamic>? extensions,
  })  : trimStrings = trimStrings ?? [],
        extensions = extensions ?? {};

  /// Creates a [RegexScript] from a SillyTavern-compatible JSON map.
  ///
  /// ST uses:
  /// - `scriptName` (String)
  /// - `findRegex` (String)
  /// - `replaceString` (String)
  /// - `trimStrings` (`List<String>` or legacy `String`)
  /// - `disabled` (inverted → enabled)
  /// - `placement` (`List<int>` with indices: 0=user, 1=ai, 2=worldInfo, 3=reasoning)
  /// - `markdownOnly` → displayOnly
  /// - `promptOnly` (bool)
  /// - `minDepth` / `maxDepth`
  /// - `substituteRegex` (int, maps to macroMode)
  factory RegexScript.fromJson(Map<String, dynamic> json) {
    // --- Enabled ---
    bool enabled = true;
    if (json.containsKey('enabled')) {
      enabled = json['enabled'] as bool? ?? true;
    } else if (json.containsKey('disabled')) {
      enabled = !(json['disabled'] as bool? ?? false);
    }

    // --- Trim strings ---
    List<String> trimStrings = [];
    final rawTrim = json['trimStrings'] ?? json['trim_strings'];
    if (rawTrim is List) {
      trimStrings = rawTrim.map((e) => e.toString()).toList();
    } else if (rawTrim is String && rawTrim.isNotEmpty) {
      // Legacy: single comma-separated string
      trimStrings = rawTrim.split(',').map((s) => s.trim()).toList();
    }

    // --- Placement (ST numeric array) ---
    bool affectsUser = json['affectsUserInput'] as bool? ?? false;
    bool affectsAi = json['affectsAiOutput'] as bool? ?? true;
    bool affectsWI = json['affectsWorldInfo'] as bool? ?? false;
    bool affectsReason = json['affectsReasoning'] as bool? ?? false;

    if (json['placement'] is List) {
      final p = (json['placement'] as List).map((e) => e as int).toSet();
      affectsUser = p.contains(0);
      affectsAi = p.contains(1);
      affectsWI = p.contains(2);
      affectsReason = p.contains(3);
    }

    // --- Macro mode ---
    RegexMacroMode macroMode = RegexMacroMode.none;
    final rawMacro = json['substituteRegex'] ?? json['macroMode'];
    if (rawMacro is int) {
      macroMode = RegexMacroMode.values.elementAtOrNull(rawMacro) ??
          RegexMacroMode.none;
    } else if (rawMacro is String) {
      macroMode = RegexMacroMode.values.firstWhere(
        (m) => m.name == rawMacro,
        orElse: () => RegexMacroMode.none,
      );
    }

    // --- Scope ---
    RegexScope scope = RegexScope.scoped;
    if (json['scope'] is String) {
      scope = RegexScope.values.firstWhere(
        (s) => s.name == json['scope'],
        orElse: () => RegexScope.scoped,
      );
    }

    // --- Extensions ---
    Map<String, dynamic> ext = {};
    if (json['extensions'] is Map) {
      ext = Map<String, dynamic>.from(json['extensions']);
    }

    return RegexScript(
      id: json['id'] as int? ?? 0,
      scriptName: json['scriptName'] as String? ??
          json['script_name'] as String? ??
          '',
      findRegex: json['findRegex'] as String? ??
          json['find_regex'] as String? ??
          '',
      replaceString: json['replaceString'] as String? ??
          json['replace_string'] as String? ??
          '',
      trimStrings: trimStrings,
      enabled: enabled,
      scope: scope,
      affectsUserInput: affectsUser,
      affectsAiOutput: affectsAi,
      affectsWorldInfo: affectsWI,
      affectsReasoning: affectsReason,
      displayOnly:
          json['markdownOnly'] as bool? ?? json['displayOnly'] as bool? ?? false,
      promptOnly: json['promptOnly'] as bool? ??
          json['prompt_only'] as bool? ??
          false,
      minDepth: json['minDepth'] as int? ?? json['min_depth'] as int? ?? 0,
      maxDepth: json['maxDepth'] as int? ?? json['max_depth'] as int? ?? -1,
      caseInsensitive: json['caseInsensitive'] as bool? ??
          json['case_insensitive'] as bool? ??
          false,
      dotAll: json['dotAll'] as bool? ?? json['dot_all'] as bool? ?? false,
      multiLine: json['multiLine'] as bool? ??
          json['multi_line'] as bool? ??
          false,
      unicode: json['unicode'] as bool? ?? false,
      macroMode: macroMode,
      sortOrder:
          json['sortOrder'] as int? ?? json['sort_order'] as int? ?? 0,
      extensions: ext,
    );
  }

  /// Serialises to a JSON map using spec-canonical field names.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scriptName': scriptName,
      'findRegex': findRegex,
      'replaceString': replaceString,
      'trimStrings': trimStrings,
      'enabled': enabled,
      'scope': scope.name,
      'placement': _placementToList(),
      'markdownOnly': displayOnly,
      'promptOnly': promptOnly,
      'minDepth': minDepth,
      'maxDepth': maxDepth,
      'caseInsensitive': caseInsensitive,
      'dotAll': dotAll,
      'multiLine': multiLine,
      'unicode': unicode,
      'substituteRegex': macroMode.index,
      'sortOrder': sortOrder,
      'extensions': extensions,
    };
  }

  /// Converts the affects* booleans to ST's numeric placement array.
  List<int> _placementToList() {
    final list = <int>[];
    if (affectsUserInput) list.add(0);
    if (affectsAiOutput) list.add(1);
    if (affectsWorldInfo) list.add(2);
    if (affectsReasoning) list.add(3);
    return list;
  }

  RegexScript copyWith({
    int? id,
    String? scriptName,
    String? findRegex,
    String? replaceString,
    List<String>? trimStrings,
    bool? enabled,
    RegexScope? scope,
    bool? affectsUserInput,
    bool? affectsAiOutput,
    bool? affectsWorldInfo,
    bool? affectsReasoning,
    bool? displayOnly,
    bool? promptOnly,
    int? minDepth,
    int? maxDepth,
    bool? caseInsensitive,
    bool? dotAll,
    bool? multiLine,
    bool? unicode,
    RegexMacroMode? macroMode,
    int? sortOrder,
    Map<String, dynamic>? extensions,
  }) {
    return RegexScript(
      id: id ?? this.id,
      scriptName: scriptName ?? this.scriptName,
      findRegex: findRegex ?? this.findRegex,
      replaceString: replaceString ?? this.replaceString,
      trimStrings: trimStrings ?? List.from(this.trimStrings),
      enabled: enabled ?? this.enabled,
      scope: scope ?? this.scope,
      affectsUserInput: affectsUserInput ?? this.affectsUserInput,
      affectsAiOutput: affectsAiOutput ?? this.affectsAiOutput,
      affectsWorldInfo: affectsWorldInfo ?? this.affectsWorldInfo,
      affectsReasoning: affectsReasoning ?? this.affectsReasoning,
      displayOnly: displayOnly ?? this.displayOnly,
      promptOnly: promptOnly ?? this.promptOnly,
      minDepth: minDepth ?? this.minDepth,
      maxDepth: maxDepth ?? this.maxDepth,
      caseInsensitive: caseInsensitive ?? this.caseInsensitive,
      dotAll: dotAll ?? this.dotAll,
      multiLine: multiLine ?? this.multiLine,
      unicode: unicode ?? this.unicode,
      macroMode: macroMode ?? this.macroMode,
      sortOrder: sortOrder ?? this.sortOrder,
      extensions: extensions ?? Map.from(this.extensions),
    );
  }
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Scope controls when a regex script is active relative to character cards.
enum RegexScope {
  /// Active globally, regardless of character card.
  global,

  /// Active only when the associated character card is loaded.
  scoped,

  /// Bundled inside a preset, active when that preset is applied.
  preset,
}

/// How macro placeholders in replacement strings are processed.
enum RegexMacroMode {
  /// No macro processing.
  none,

  /// Macros resolved but regex special chars are NOT escaped.
  raw,

  /// Macros resolved with regex special chars escaped.
  escaped,
}
