/// Represents a collection of formatting rules applied to AI output.
///
/// Controls how dialogue, thoughts, narration, and character names are
/// visually wrapped in the displayed text. Rules use `{{macro}}` placeholders
/// that are resolved at render time via the macro engine.
class FormattingTemplate {
  /// Display name for this template.
  String name;

  /// Whether this template is currently active.
  bool enabled;

  /// Description of what this template does.
  String description;

  /// Ordered list of formatting rules applied sequentially.
  List<FormattingRule> rules;

  /// Arbitrary extension data for round-trip fidelity.
  Map<String, dynamic> extensions;

  FormattingTemplate({
    this.name = '',
    this.enabled = false,
    this.description = '',
    List<FormattingRule>? rules,
    Map<String, dynamic>? extensions,
  })  : rules = rules ?? [],
        extensions = extensions ?? {};

  factory FormattingTemplate.fromJson(Map<String, dynamic> json) {
    List<FormattingRule> parsedRules = [];
    if (json['rules'] is List) {
      parsedRules = (json['rules'] as List)
          .map((e) => FormattingRule.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return FormattingTemplate(
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      rules: parsedRules,
      extensions: json['extensions'] is Map
          ? Map<String, dynamic>.from(json['extensions'])
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'enabled': enabled,
      'description': description,
      'rules': rules.map((r) => r.toJson()).toList(),
      'extensions': extensions,
    };
  }

  FormattingTemplate copyWith({
    String? name,
    bool? enabled,
    String? description,
    List<FormattingRule>? rules,
    Map<String, dynamic>? extensions,
  }) {
    return FormattingTemplate(
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      description: description ?? this.description,
      rules: rules ?? this.rules.map((r) => r.copyWith()).toList(),
      extensions: extensions ?? Map.from(this.extensions),
    );
  }
}

/// A single formatting rule that matches a text pattern and wraps it with
/// a template string.
///
/// The [pattern] is a regex that identifies text to format (e.g. dialogue
/// in quotes). The [template] defines how matched text is wrapped, using
/// `{{match}}` to reference the captured content and `{{char}}` etc. for
/// macro values.
class FormattingRule {
  /// Unique identifier.
  int id;

  /// Human-readable label.
  String label;

  /// What kind of text this rule targets.
  FormattingRuleType type;

  /// Regex pattern to match in the output text.
  String pattern;

  /// Template string applied to matched text. Use `{{match}}` for the
  /// captured content.
  String template;

  /// Whether this individual rule is enabled.
  bool enabled;

  /// Sort priority (lower = applied first).
  int sortOrder;

  FormattingRule({
    this.id = 0,
    this.label = '',
    this.type = FormattingRuleType.custom,
    this.pattern = '',
    this.template = '{{match}}',
    this.enabled = true,
    this.sortOrder = 0,
  });

  factory FormattingRule.fromJson(Map<String, dynamic> json) {
    return FormattingRule(
      id: json['id'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      type: _parseType(json['type']),
      pattern: json['pattern'] as String? ?? '',
      template: json['template'] as String? ?? '{{match}}',
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type.name,
      'pattern': pattern,
      'template': template,
      'enabled': enabled,
      'sortOrder': sortOrder,
    };
  }

  FormattingRule copyWith({
    int? id,
    String? label,
    FormattingRuleType? type,
    String? pattern,
    String? template,
    bool? enabled,
    int? sortOrder,
  }) {
    return FormattingRule(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      pattern: pattern ?? this.pattern,
      template: template ?? this.template,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  static FormattingRuleType _parseType(dynamic raw) {
    if (raw is String) {
      return FormattingRuleType.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => FormattingRuleType.custom,
      );
    }
    return FormattingRuleType.custom;
  }
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Categorises what a formatting rule targets.
enum FormattingRuleType {
  /// Spoken dialogue (typically text in quotes).
  dialogue,

  /// Internal thoughts (typically italicised or in asterisks).
  thought,

  /// Narration / action text.
  narration,

  /// Character name styling.
  characterName,

  /// User-defined custom formatting.
  custom,
}
