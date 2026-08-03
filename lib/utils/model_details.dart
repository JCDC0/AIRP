import '../models/chat_models.dart';

/// One labelled fact about a model, ready to render.
class ModelDetail {
  const ModelDetail(this.label, this.value);

  final String label;
  final String value;
}

/// Extracts the provider metadata that [ModelInfo] carries in `rawData` but
/// that nothing used to display.
///
/// OpenRouter returns considerably more than id/context/pricing — modality,
/// tokenizer, moderation status, which sampling parameters the route actually
/// honours — and other providers return smaller but differently shaped
/// objects. Rather than model each provider, this reads a curated set of known
/// keys wherever they appear and silently skips what is absent, so a provider
/// that reports little simply yields a shorter list.
class ModelDetails {
  ModelDetails._();

  static List<ModelDetail> extract(ModelInfo model) {
    final raw = model.rawData;
    if (raw == null || raw.isEmpty) return const [];

    final details = <ModelDetail>[];

    void add(String label, Object? value) {
      final formatted = _format(value);
      if (formatted != null) details.add(ModelDetail(label, formatted));
    }

    add('Owner', raw['owned_by'] ?? raw['organization']);
    add('Slug', raw['canonical_slug']);
    add('Hugging Face', raw['hugging_face_id']);

    final architecture = _asMap(raw['architecture']);
    if (architecture != null) {
      add('Modality', architecture['modality']);
      add('Input', architecture['input_modalities']);
      add('Output', architecture['output_modalities']);
      add('Tokenizer', architecture['tokenizer']);
      add('Instruct Type', architecture['instruct_type']);
    }

    final topProvider = _asMap(raw['top_provider']);
    if (topProvider != null) {
      add('Provider Context', topProvider['context_length']);
      add('Max Output', topProvider['max_completion_tokens']);
      add('Moderated', topProvider['is_moderated']);
    }

    add('Context Window', raw['context_window']);
    add('Max Output', raw['max_completion_tokens']);
    add('Active', raw['active']);

    final limits = _asMap(raw['per_request_limits']);
    if (limits != null) {
      for (final entry in limits.entries) {
        add('Limit: ${_humanize(entry.key)}', entry.value);
      }
    }

    add('Supported Parameters', raw['supported_parameters']);

    return _deduplicate(details);
  }

  /// Later duplicates are dropped so the OpenRouter `top_provider` block wins
  /// over the flatter top-level keys some gateways also emit.
  static List<ModelDetail> _deduplicate(List<ModelDetail> details) {
    final seen = <String>{};
    return details.where((d) => seen.add(d.label)).toList();
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _format(Object? value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) return _formatNumber(value);
    if (value is List) {
      final parts = value
          .map((e) => _format(e))
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();
      return parts.isEmpty ? null : parts.join(', ');
    }
    if (value is Map) {
      final parts = value.entries
          .map((e) {
            final formatted = _format(e.value);
            return formatted == null
                ? null
                : '${_humanize(e.key.toString())}: $formatted';
          })
          .whereType<String>()
          .toList();
      return parts.isEmpty ? null : parts.join(', ');
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _formatNumber(num value) {
    if (value is double && value != value.roundToDouble()) {
      return value.toString();
    }
    final digits = value.toInt().abs().toString();
    final buffer = StringBuffer(value.isNegative ? '-' : '');
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String _humanize(String key) {
    return key
        .split(RegExp(r'[_\-]'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
