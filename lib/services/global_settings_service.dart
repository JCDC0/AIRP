import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

class GlobalSettingsService {
  static const String rootKey = 'airp_global_settings_v1';
  static const String schemaVersionKey = 'schemaVersion';
  static const int schemaVersion = 1;

  static const String modelBookmarksKey = 'modelBookmarks';
  static const String starredProvidersKey = 'starredProviders';
  static const String modelPickerSortModeKey = 'modelPickerSortMode';

  static const String legacyModelBookmarksKey = 'airp_bookmarked_models';
  static const String legacyModelBookmarksKeyV0 = 'bookmarked_models';
  static const String legacyStarredProvidersKey = 'airp_starred_providers';
  static const String legacyModelPickerSortModeKey =
      'airp_model_picker_sort_mode';

  static const List<String> allowedSortModes = <String>[
    'Newest',
    'Name (A-Z)',
    'Name (Z-A)',
    'Cost (Low to High)',
    'Cost (High to Low)',
  ];
  static const String defaultModelSortMode = 'Newest';

  Future<Set<String>> loadModelBookmarks({SharedPreferences? prefs}) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final root = await _readRoot(resolvedPrefs);
    final rawRootList = root[modelBookmarksKey] as List<dynamic>?;

    final migratedLegacy = _sanitizeStringSet(
      rawRootList ??
          resolvedPrefs.getStringList(legacyModelBookmarksKey) ??
          resolvedPrefs.getStringList(legacyModelBookmarksKeyV0) ??
          const <String>[],
    );

    await _writeModelBookmarks(migratedLegacy, prefs: resolvedPrefs);
    if (resolvedPrefs.containsKey(legacyModelBookmarksKeyV0)) {
      await resolvedPrefs.remove(legacyModelBookmarksKeyV0);
    }
    return migratedLegacy;
  }

  Future<void> saveModelBookmarks(
    Set<String> bookmarks, {
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await _writeModelBookmarks(_sanitizeStringSet(bookmarks), prefs: resolvedPrefs);
  }

  Future<Set<AiProvider>> loadStarredProviders({
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final root = await _readRoot(resolvedPrefs);
    final rawRootList = root[starredProvidersKey] as List<dynamic>?;

    final names = _sanitizeStringSet(
      rawRootList ??
          resolvedPrefs.getStringList(legacyStarredProvidersKey) ??
          const <String>[],
    );
    final providers = _decodeProviders(names);
    await _writeStarredProviders(providers, prefs: resolvedPrefs);
    return providers;
  }

  Future<void> saveStarredProviders(
    Set<AiProvider> providers, {
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await _writeStarredProviders(providers, prefs: resolvedPrefs);
  }

  Future<String> loadModelPickerSortMode({SharedPreferences? prefs}) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final root = await _readRoot(resolvedPrefs);
    final rootMode = root[modelPickerSortModeKey] as String?;
    final legacyMode = resolvedPrefs.getString(legacyModelPickerSortModeKey);
    final normalized = normalizeSortMode(rootMode ?? legacyMode);
    await saveModelPickerSortMode(normalized, prefs: resolvedPrefs);
    return normalized;
  }

  Future<void> saveModelPickerSortMode(
    String sortMode, {
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final root = await _readRoot(resolvedPrefs);
    root[modelPickerSortModeKey] = normalizeSortMode(sortMode);
    await _writeRoot(root, prefs: resolvedPrefs);
    await resolvedPrefs.setString(
      legacyModelPickerSortModeKey,
      normalizeSortMode(sortMode),
    );
  }

  static String normalizeSortMode(String? sortMode) {
    if (sortMode == null) return defaultModelSortMode;
    if (allowedSortModes.contains(sortMode)) return sortMode;
    return defaultModelSortMode;
  }

  Future<Map<String, dynamic>> _readRoot(SharedPreferences prefs) async {
    final raw = prefs.getString(rootKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{schemaVersionKey: schemaVersion};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        decoded[schemaVersionKey] ??= schemaVersion;
        return decoded;
      }
    } catch (_) {}

    return <String, dynamic>{schemaVersionKey: schemaVersion};
  }

  Future<void> _writeRoot(
    Map<String, dynamic> root, {
    required SharedPreferences prefs,
  }) async {
    root[schemaVersionKey] = schemaVersion;
    await prefs.setString(rootKey, jsonEncode(root));
  }

  Future<void> _writeModelBookmarks(
    Set<String> bookmarks, {
    required SharedPreferences prefs,
  }) async {
    final root = await _readRoot(prefs);
    final values = bookmarks.toList()..sort();
    root[modelBookmarksKey] = values;
    await _writeRoot(root, prefs: prefs);
    await prefs.setStringList(legacyModelBookmarksKey, values);
  }

  Future<void> _writeStarredProviders(
    Set<AiProvider> providers, {
    required SharedPreferences prefs,
  }) async {
    final root = await _readRoot(prefs);
    final names = providers.map((p) => p.name).toList()..sort();
    root[starredProvidersKey] = names;
    await _writeRoot(root, prefs: prefs);
    await prefs.setStringList(legacyStarredProvidersKey, names);
  }

  Set<String> _sanitizeStringSet(Iterable<dynamic> values) {
    return values
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Set<AiProvider> _decodeProviders(Set<String> names) {
    final providers = <AiProvider>{};
    for (final name in names) {
      try {
        providers.add(AiProvider.values.firstWhere((p) => p.name == name));
      } catch (_) {
        continue;
      }
    }
    return providers;
  }
}