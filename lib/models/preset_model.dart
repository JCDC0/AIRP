/// Represents a system prompt preset, including main prompt, 
/// advanced prompt override, and custom rules.
class SystemPreset {
  String name;
  String description;
  String systemPrompt;
  String advancedPrompt; // Tweaks & Overrides
  List<Map<String, dynamic>> customRules;
  Map<String, dynamic> generationSettings; // Optional generation params
  
  // Metadata
  String version;

  SystemPreset({
    required this.name,
    this.description = '',
    this.systemPrompt = '',
    this.advancedPrompt = '',
    this.customRules = const [],
    this.generationSettings = const {},
    this.version = '1.0',
  });

  factory SystemPreset.fromJson(Map<String, dynamic> json) {
    return SystemPreset(
      name: json['name'] as String? ?? 'Untitled Preset',
      description: json['description'] as String? ?? '',
      systemPrompt: json['system_prompt'] as String? ?? '',
      advancedPrompt: json['advanced_prompt'] as String? ?? '',
      customRules: (json['custom_rules'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ?? [],
      generationSettings: (json['generation_settings'] as Map<String, dynamic>?) 
          ?? {},
      version: json['version'] as String? ?? '1.0',
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
    };
  }
}
