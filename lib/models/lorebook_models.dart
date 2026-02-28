/// Represents a SillyTavern-compatible Character Book (World Info / Lorebook).
///
/// Container for [LorebookEntry] items with global scanning and budget
/// parameters. Matches the V2 spec `data.character_book` structure and
/// round-trips both spec field names and SillyTavern internal names.
class Lorebook {
  /// Display name for this lorebook.
  String name;

  /// How many recent messages to scan for keyword matches (0 = all).
  int scanDepth;

  /// Maximum total tokens the activated entries may consume.
  int tokenBudget;

  /// How many recursive passes to perform when one entry's content may
  /// trigger another entry's keywords.
  int recursionSteps;

  /// Whether keyword matching is case-sensitive (default: false).
  bool caseSensitive;

  /// Whether keyword matching requires whole-word boundaries.
  bool matchWholeWords;

  /// The ordered list of lorebook entries.
  List<LorebookEntry> entries;

  /// Arbitrary extension data for round-trip fidelity.
  Map<String, dynamic> extensions;

  Lorebook({
    this.name = '',
    this.scanDepth = 2,
    this.tokenBudget = 2048,
    this.recursionSteps = 0,
    this.caseSensitive = false,
    this.matchWholeWords = false,
    List<LorebookEntry>? entries,
    Map<String, dynamic>? extensions,
  })  : entries = entries ?? [],
        extensions = extensions ?? {};

  /// Creates a [Lorebook] from a SillyTavern `character_book` JSON map.
  ///
  /// Handles both V2 spec field names and SillyTavern internal aliases:
  /// - `scan_depth` (spec) / `scan_depth` (ST)
  /// - `token_budget` (spec) / `token_budget` (ST)
  /// - `recursive_scanning` (spec) → `recursionSteps` (0 or 1)
  /// - `extensions.match_whole_words`, `extensions.case_sensitive`
  factory Lorebook.fromJson(Map<String, dynamic> json) {
    final ext = json['extensions'] is Map
        ? Map<String, dynamic>.from(json['extensions'])
        : <String, dynamic>{};

    List<LorebookEntry> parsedEntries = [];
    if (json['entries'] is List) {
      parsedEntries = (json['entries'] as List)
          .map((e) => LorebookEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return Lorebook(
      name: json['name'] as String? ?? '',
      scanDepth: json['scan_depth'] as int? ?? 2,
      tokenBudget: json['token_budget'] as int? ?? 2048,
      recursionSteps: json['recursive_scanning'] == true
          ? 1
          : (json['recursion_steps'] as int? ?? 0),
      caseSensitive: ext['case_sensitive'] as bool? ?? false,
      matchWholeWords: ext['match_whole_words'] as bool? ?? false,
      entries: parsedEntries,
      extensions: ext,
    );
  }

  /// Serialises to a V2-compatible `character_book` JSON map.
  Map<String, dynamic> toJson() {
    // Merge our flags into extensions for round-trip.
    final ext = Map<String, dynamic>.from(extensions);
    ext['case_sensitive'] = caseSensitive;
    ext['match_whole_words'] = matchWholeWords;

    return {
      'name': name,
      'scan_depth': scanDepth,
      'token_budget': tokenBudget,
      'recursive_scanning': recursionSteps > 0,
      'extensions': ext,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  Lorebook copyWith({
    String? name,
    int? scanDepth,
    int? tokenBudget,
    int? recursionSteps,
    bool? caseSensitive,
    bool? matchWholeWords,
    List<LorebookEntry>? entries,
    Map<String, dynamic>? extensions,
  }) {
    return Lorebook(
      name: name ?? this.name,
      scanDepth: scanDepth ?? this.scanDepth,
      tokenBudget: tokenBudget ?? this.tokenBudget,
      recursionSteps: recursionSteps ?? this.recursionSteps,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      matchWholeWords: matchWholeWords ?? this.matchWholeWords,
      entries: entries ?? this.entries.map((e) => e.copyWith()).toList(),
      extensions: extensions ?? Map.from(this.extensions),
    );
  }
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// How an entry is activated.
enum LorebookStrategy {
  /// Activated when keywords are found in recent messages.
  triggered,

  /// Always included regardless of keyword matches.
  constant,
}

/// Where the entry content is inserted relative to the prompt structure.
///
/// Values correspond to SillyTavern's `position` / `insertion_order` semantics.
enum LorebookPosition {
  /// Before character definitions (description, personality, etc.).
  beforeCharDefs,

  /// After character definitions.
  afterCharDefs,

  /// At the top of Author's Note.
  anTop,

  /// At the bottom of Author's Note.
  anBottom,

  /// At a specific message depth (uses [LorebookEntry.depth]).
  atDepth,

  /// At the top of example messages.
  emTop,

  /// At the bottom of example messages.
  emBottom,

  /// Routed to a named outlet (custom injection point).
  outlet,
}

/// The role used when inserting as a depth-based message.
enum LorebookRole {
  system,
  user,
  assistant,
}

// ---------------------------------------------------------------------------
// Lorebook Entry
// ---------------------------------------------------------------------------

/// A single entry in a [Lorebook].
///
/// Covers the full SillyTavern Character Book V2 entry spec plus ST-specific
/// extensions (sticky, cooldown, delay, group scoring, character filter, etc.).
class LorebookEntry {
  /// Unique identifier (ST uses incrementing `uid`).
  int id;

  /// Human-readable title / comment for the entry.
  String comment;

  /// The text injected into the prompt when this entry activates.
  String content;

  /// Primary trigger keywords (comma-separated or list).
  List<String> keys;

  /// Optional secondary keywords for AND / NOT filtering.
  List<String> secondaryKeys;

  /// Whether the entry is currently enabled.
  bool enabled;

  /// Activation strategy.
  LorebookStrategy strategy;

  /// Where to insert this entry.
  LorebookPosition position;

  /// Depth offset when [position] is [LorebookPosition.atDepth].
  int depth;

  /// Role for depth-based insertion.
  LorebookRole role;

  /// Sort / priority order (lower = earlier in prompt).
  int order;

  /// Probability (0–100) that the entry activates when keywords match.
  int probability;

  // --- Inclusion groups ---

  /// Group label. Within a group, only the highest-weight activated entry wins.
  String group;

  /// Weight for inclusion-group conflict resolution (higher wins).
  int groupWeight;

  /// Whether secondary keywords use AND logic (true) or NOT logic (false).
  bool selectiveLogic;

  // --- Timed effects ---

  /// Number of messages this entry stays active after first activation.
  int? sticky;

  /// Cooldown in messages after sticky expires before re-activation.
  int? cooldown;

  /// Number of keyword matches required before first activation.
  int? delay;

  // --- Recursion ---

  /// If false, this entry's content is not scanned for further keyword matches.
  bool preventRecursion;

  /// If true, content is excluded from recursion scanning even when global
  /// recursion is enabled.
  bool excludeRecursion;

  // --- Character filter ---

  /// Character names this entry applies to (empty = all characters).
  List<String> characterFilter;

  /// Whether [characterFilter] is an inclusion list (true) or exclusion list.
  bool characterFilterIsInclusive;

  /// Arbitrary extension data for round-trip fidelity.
  Map<String, dynamic> extensions;

  LorebookEntry({
    this.id = 0,
    this.comment = '',
    this.content = '',
    List<String>? keys,
    List<String>? secondaryKeys,
    this.enabled = true,
    this.strategy = LorebookStrategy.triggered,
    this.position = LorebookPosition.beforeCharDefs,
    this.depth = 4,
    this.role = LorebookRole.system,
    this.order = 100,
    this.probability = 100,
    this.group = '',
    this.groupWeight = 100,
    this.selectiveLogic = true,
    this.sticky,
    this.cooldown,
    this.delay,
    this.preventRecursion = false,
    this.excludeRecursion = false,
    List<String>? characterFilter,
    this.characterFilterIsInclusive = true,
    Map<String, dynamic>? extensions,
  })  : keys = keys ?? [],
        secondaryKeys = secondaryKeys ?? [],
        characterFilter = characterFilter ?? [],
        extensions = extensions ?? {};

  /// Creates a [LorebookEntry] from a SillyTavern entry JSON map.
  ///
  /// Handles both V2 spec and ST internal field names:
  /// - `keys` (spec) / `key` (ST internal, comma-joined string)
  /// - `secondary_keys` (spec) / `keysecondary` (ST)
  /// - `insertion_order` (spec) / `order` (ST)
  /// - `enabled` (spec) / inverted `disable` (ST)
  /// - `constant` (bool, ST) → strategy
  /// - `selective` / `selectiveLogic` (ST)
  /// - `position` (int, ST) → LorebookPosition enum
  factory LorebookEntry.fromJson(Map<String, dynamic> json) {
    // --- Keys ---
    List<String> parsedKeys = _parseKeys(json['keys'] ?? json['key']);
    List<String> parsedSecondary =
        _parseKeys(json['secondary_keys'] ?? json['keysecondary']);

    // --- Enabled ---
    bool enabled = true;
    if (json.containsKey('enabled')) {
      enabled = json['enabled'] as bool? ?? true;
    } else if (json.containsKey('disable')) {
      enabled = !(json['disable'] as bool? ?? false);
    }

    // --- Strategy ---
    LorebookStrategy strategy = LorebookStrategy.triggered;
    if (json['constant'] == true) {
      strategy = LorebookStrategy.constant;
    } else if (json['strategy'] is String) {
      strategy = json['strategy'] == 'constant'
          ? LorebookStrategy.constant
          : LorebookStrategy.triggered;
    }

    // --- Position (ST uses int 0-7) ---
    LorebookPosition position = _parsePosition(json['position']);

    // --- Role ---
    LorebookRole role = LorebookRole.system;
    if (json['role'] is int) {
      switch (json['role'] as int) {
        case 1:
          role = LorebookRole.user;
          break;
        case 2:
          role = LorebookRole.assistant;
          break;
        default:
          role = LorebookRole.system;
      }
    } else if (json['role'] is String) {
      role = LorebookRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => LorebookRole.system,
      );
    }

    // --- Selective logic ---
    bool selectiveLogic = true;
    if (json['selectiveLogic'] is int) {
      selectiveLogic = (json['selectiveLogic'] as int) == 0; // 0=AND, 1=NOT
    } else if (json['selective_logic'] is bool) {
      selectiveLogic = json['selective_logic'] as bool;
    } else if (json['selectiveLogic'] is bool) {
      selectiveLogic = json['selectiveLogic'] as bool;
    }

    // --- Character filter ---
    List<String> charFilter = [];
    bool charFilterInclusive = true;
    if (json['characterFilter'] is Map) {
      final cf = json['characterFilter'] as Map<String, dynamic>;
      if (cf['names'] is List) {
        charFilter = (cf['names'] as List).map((e) => e.toString()).toList();
      }
      charFilterInclusive = cf['isExclude'] != true;
    }

    // --- Extensions ---
    Map<String, dynamic> ext = {};
    if (json['extensions'] is Map) {
      ext = Map<String, dynamic>.from(json['extensions']);
    }

    return LorebookEntry(
      id: json['uid'] as int? ?? json['id'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      content: json['content'] as String? ?? '',
      keys: parsedKeys,
      secondaryKeys: parsedSecondary,
      enabled: enabled,
      strategy: strategy,
      position: position,
      depth: json['depth'] as int? ?? 4,
      role: role,
      order: json['insertion_order'] as int? ?? json['order'] as int? ?? 100,
      probability: json['probability'] as int? ?? 100,
      group: json['group'] as String? ?? '',
      groupWeight: json['group_weight'] as int? ??
          json['groupWeight'] as int? ??
          100,
      selectiveLogic: selectiveLogic,
      sticky: json['sticky'] as int?,
      cooldown: json['cooldown'] as int?,
      delay: json['delay'] as int?,
      preventRecursion: json['prevent_recursion'] as bool? ??
          json['preventRecursion'] as bool? ??
          false,
      excludeRecursion: json['exclude_recursion'] as bool? ??
          json['excludeRecursion'] as bool? ??
          false,
      characterFilter: charFilter,
      characterFilterIsInclusive: charFilterInclusive,
      extensions: ext,
    );
  }

  /// Serialises to a V2-compatible entry JSON map.
  ///
  /// Uses spec-canonical field names for export fidelity.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'uid': id,
      'comment': comment,
      'content': content,
      'keys': keys,
      'secondary_keys': secondaryKeys,
      'enabled': enabled,
      'constant': strategy == LorebookStrategy.constant,
      'position': _positionToInt(position),
      'depth': depth,
      'role': role.index,
      'insertion_order': order,
      'probability': probability,
      'group': group,
      'group_weight': groupWeight,
      'selectiveLogic': selectiveLogic ? 0 : 1,
      'prevent_recursion': preventRecursion,
      'exclude_recursion': excludeRecursion,
      'extensions': extensions,
    };

    if (sticky != null) map['sticky'] = sticky;
    if (cooldown != null) map['cooldown'] = cooldown;
    if (delay != null) map['delay'] = delay;

    if (characterFilter.isNotEmpty) {
      map['characterFilter'] = {
        'names': characterFilter,
        'isExclude': !characterFilterIsInclusive,
      };
    }

    return map;
  }

  LorebookEntry copyWith({
    int? id,
    String? comment,
    String? content,
    List<String>? keys,
    List<String>? secondaryKeys,
    bool? enabled,
    LorebookStrategy? strategy,
    LorebookPosition? position,
    int? depth,
    LorebookRole? role,
    int? order,
    int? probability,
    String? group,
    int? groupWeight,
    bool? selectiveLogic,
    int? sticky,
    int? cooldown,
    int? delay,
    bool? preventRecursion,
    bool? excludeRecursion,
    List<String>? characterFilter,
    bool? characterFilterIsInclusive,
    Map<String, dynamic>? extensions,
  }) {
    return LorebookEntry(
      id: id ?? this.id,
      comment: comment ?? this.comment,
      content: content ?? this.content,
      keys: keys ?? List.from(this.keys),
      secondaryKeys: secondaryKeys ?? List.from(this.secondaryKeys),
      enabled: enabled ?? this.enabled,
      strategy: strategy ?? this.strategy,
      position: position ?? this.position,
      depth: depth ?? this.depth,
      role: role ?? this.role,
      order: order ?? this.order,
      probability: probability ?? this.probability,
      group: group ?? this.group,
      groupWeight: groupWeight ?? this.groupWeight,
      selectiveLogic: selectiveLogic ?? this.selectiveLogic,
      sticky: sticky ?? this.sticky,
      cooldown: cooldown ?? this.cooldown,
      delay: delay ?? this.delay,
      preventRecursion: preventRecursion ?? this.preventRecursion,
      excludeRecursion: excludeRecursion ?? this.excludeRecursion,
      characterFilter:
          characterFilter ?? List.from(this.characterFilter),
      characterFilterIsInclusive:
          characterFilterIsInclusive ?? this.characterFilterIsInclusive,
      extensions: extensions ?? Map.from(this.extensions),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parses keys from either a `List<String>` or a comma-separated `String`.
  static List<String> _parseKeys(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Maps a position value (int or String) to a [LorebookPosition].
  static LorebookPosition _parsePosition(dynamic raw) {
    if (raw is int) {
      const mapping = {
        0: LorebookPosition.beforeCharDefs,
        1: LorebookPosition.afterCharDefs,
        2: LorebookPosition.anTop,
        3: LorebookPosition.anBottom,
        4: LorebookPosition.atDepth,
        5: LorebookPosition.emTop,
        6: LorebookPosition.emBottom,
        7: LorebookPosition.outlet,
      };
      return mapping[raw] ?? LorebookPosition.beforeCharDefs;
    }
    if (raw is String) {
      return LorebookPosition.values.firstWhere(
        (p) => p.name == raw,
        orElse: () => LorebookPosition.beforeCharDefs,
      );
    }
    return LorebookPosition.beforeCharDefs;
  }

  /// Converts a [LorebookPosition] back to an int for serialization.
  static int _positionToInt(LorebookPosition pos) {
    const mapping = {
      LorebookPosition.beforeCharDefs: 0,
      LorebookPosition.afterCharDefs: 1,
      LorebookPosition.anTop: 2,
      LorebookPosition.anBottom: 3,
      LorebookPosition.atDepth: 4,
      LorebookPosition.emTop: 5,
      LorebookPosition.emBottom: 6,
      LorebookPosition.outlet: 7,
    };
    return mapping[pos] ?? 0;
  }
}
