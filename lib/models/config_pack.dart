/// A named bundle of application settings (everything in the settings drawer
/// except conversations and API keys).
///
/// Captured via [ConfigPackService.captureCurrent] and restored via
/// [ConfigPackService.applyPack]. The [sourceFormat] distinguishes native
/// AIRP packs from packs imported (tolerantly) from a SillyTavern
/// Chat-Completion preset.
class ConfigPack {
  final String name;
  final String description;
  final int createdAt;
  final String sourceFormat;

  /// The captured provider settings. Nested buckets:
  /// `chat` (provider/models/system instruction/character card/lorebook,
  /// **no sessions**), `settings` (generation/toggles/web search),
  /// `theme`, `vfx`, `scale`. API keys are never present.
  final Map<String, dynamic> settings;

  const ConfigPack({
    required this.name,
    this.description = '',
    required this.createdAt,
    this.sourceFormat = 'airp',
    required this.settings,
  });

  factory ConfigPack.fromJson(Map<String, dynamic> json) {
    return ConfigPack(
      name: json['name'] as String? ?? 'Untitled Pack',
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] as int? ?? 0,
      sourceFormat: json['sourceFormat'] as String? ?? 'airp',
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'createdAt': createdAt,
        'sourceFormat': sourceFormat,
        'settings': settings,
      };

  ConfigPack copyWith({
    String? name,
    String? description,
    int? createdAt,
    String? sourceFormat,
    Map<String, dynamic>? settings,
  }) {
    return ConfigPack(
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      settings: settings ?? Map<String, dynamic>.from(this.settings),
    );
  }
}
