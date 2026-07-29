import 'dart:developer' as developer;
import 'dart:math';

import '../models/lorebook_models.dart';

/// Matches [LorebookEntry] items against text to determine which entries
/// should be injected into the prompt.
///
/// Scope note: history-based scanning and positional injection were removed in
/// `0.6.11.1`, which replaced them with current-input lore recognition. This
/// service now serves that single caller. It returns a flat, order-sorted list;
/// callers inject the entries wherever they see fit.
///
/// The evaluation pipeline is:
/// 1. Filter disabled entries and character-filtered entries.
/// 2. Constant entries always activate.
/// 3. Triggered entries matched via primary keyword scan.
/// 4. Secondary keyword filter (AND / NOT selective logic).
/// 5. Probability roll.
/// 6. Recursive keyword scanning (up to [Lorebook.recursionSteps] passes).
/// 7. Inclusion-group conflict resolution (highest weight wins).
/// 8. Token budget enforcement.
class LorebookService {
  static final Random _rng = Random();

  /// Returns the entries in [lorebook] activated by [text], sorted by
  /// [LorebookEntry.order].
  ///
  /// [characterName] is the active character's name, used for character
  /// filter evaluation.
  static List<LorebookEntry> matchEntries({
    required Lorebook lorebook,
    required String text,
    String characterName = '',
  }) {
    if (lorebook.entries.isEmpty) return const [];

    final eligible = lorebook.entries
        .where((e) => e.enabled && _passesCharacterFilter(e, characterName))
        .toList();

    final activated = <LorebookEntry>[];
    for (final entry in eligible) {
      if (_shouldActivate(
        entry: entry,
        corpus: text,
        caseSensitive: lorebook.caseSensitive,
        matchWholeWords: lorebook.matchWholeWords,
      )) {
        activated.add(entry);
      }
    }

    final allActivated = _recursiveScan(
      activated: activated,
      remaining: eligible.where((e) => !activated.contains(e)).toList(),
      recursionSteps: lorebook.recursionSteps,
      caseSensitive: lorebook.caseSensitive,
      matchWholeWords: lorebook.matchWholeWords,
    );

    final afterGroups = _resolveGroups(allActivated);
    afterGroups.sort((a, b) => a.order.compareTo(b.order));
    return _enforceBudget(afterGroups, lorebook.tokenBudget);
  }

  // ---------------------------------------------------------------------------
  // Keyword matching
  // ---------------------------------------------------------------------------

  /// Returns the matching key, or null if none match.
  static String? _matchesKeys(
    List<String> keys,
    String corpus, {
    required bool caseSensitive,
    required bool matchWholeWords,
  }) {
    if (keys.isEmpty) return null;

    final effectiveCorpus = caseSensitive ? corpus : corpus.toLowerCase();

    for (final key in keys) {
      final effectiveKey = caseSensitive ? key : key.toLowerCase();
      if (effectiveKey.isEmpty) continue;

      if (matchWholeWords) {
        final escaped = RegExp.escape(effectiveKey);
        final pattern = RegExp(
          r'\b' + escaped + r'\b',
          caseSensitive: caseSensitive,
        );
        if (pattern.hasMatch(corpus)) return key;
      } else {
        if (effectiveCorpus.contains(effectiveKey)) return key;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Entry activation logic
  // ---------------------------------------------------------------------------

  /// Determines whether a single entry should activate.
  static bool _shouldActivate({
    required LorebookEntry entry,
    required String corpus,
    required bool caseSensitive,
    required bool matchWholeWords,
  }) {
    final entryLabel = entry.comment.isNotEmpty
        ? entry.comment
        : 'UID:${entry.id}';

    // Constant entries always activate (no keyword matching needed).
    if (entry.strategy == LorebookStrategy.constant) {
      developer.log('[$entryLabel] activated (Constant)', name: 'Lorebook');
      return true;
    }

    // Primary keyword match.
    final matchedKey = _matchesKeys(
      entry.keys,
      corpus,
      caseSensitive: caseSensitive,
      matchWholeWords: matchWholeWords,
    );
    if (matchedKey == null) return false;

    // Secondary keyword filter.
    if (entry.secondaryKeys.isNotEmpty) {
      final secondaryHit = _matchesKeys(
        entry.secondaryKeys,
        corpus,
        caseSensitive: caseSensitive,
        matchWholeWords: matchWholeWords,
      );

      // AND mode requires a secondary hit; NOT mode forbids one.
      if (entry.selectiveLogic ? secondaryHit == null : secondaryHit != null) {
        return false;
      }
    }

    // Probability roll.
    if (entry.probability < 100 && _rng.nextInt(100) >= entry.probability) {
      developer.log(
        '[$entryLabel] matched "$matchedKey" but failed probability roll (${entry.probability}%)',
        name: 'Lorebook',
      );
      return false;
    }

    developer.log(
      '[$entryLabel] activated via keyword: "$matchedKey"',
      name: 'Lorebook',
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // Character filter
  // ---------------------------------------------------------------------------

  /// Returns true if the entry should apply to the given character.
  static bool _passesCharacterFilter(
    LorebookEntry entry,
    String characterName,
  ) {
    if (entry.characterFilter.isEmpty) return true;
    if (characterName.isEmpty) return true;

    final nameLC = characterName.toLowerCase();
    final inList = entry.characterFilter.any((n) => n.toLowerCase() == nameLC);

    // Inclusive list: character must be in list.
    // Exclusive list: character must NOT be in list.
    return entry.characterFilterIsInclusive ? inList : !inList;
  }

  // ---------------------------------------------------------------------------
  // Recursive scanning
  // ---------------------------------------------------------------------------

  /// Performs recursive keyword scanning: activated entries' content is added
  /// to the corpus and remaining entries are re-evaluated.
  static List<LorebookEntry> _recursiveScan({
    required List<LorebookEntry> activated,
    required List<LorebookEntry> remaining,
    required int recursionSteps,
    required bool caseSensitive,
    required bool matchWholeWords,
  }) {
    if (recursionSteps <= 0 || remaining.isEmpty) return activated;

    final allActivated = List<LorebookEntry>.from(activated);

    for (int step = 0; step < recursionSteps; step++) {
      // Build corpus from all activated entries' content.
      final recursionCorpus = allActivated
          .where((e) => !e.preventRecursion && !e.excludeRecursion)
          .map((e) => e.content)
          .join('\n');

      if (recursionCorpus.isEmpty) break;

      final stillRemaining = remaining
          .where((e) => !allActivated.contains(e))
          .toList();

      if (stillRemaining.isEmpty) break;

      bool anyNew = false;
      for (final entry in stillRemaining) {
        if (_shouldActivate(
          entry: entry,
          corpus: recursionCorpus,
          caseSensitive: caseSensitive,
          matchWholeWords: matchWholeWords,
        )) {
          allActivated.add(entry);
          anyNew = true;
        }
      }

      if (!anyNew) break; // No new activations, stop recursing.
    }

    return allActivated;
  }

  // ---------------------------------------------------------------------------
  // Inclusion group resolution
  // ---------------------------------------------------------------------------

  /// Within each named group, only the entry with the highest groupWeight
  /// survives.  Entries without a group pass through unchanged.
  static List<LorebookEntry> _resolveGroups(List<LorebookEntry> entries) {
    final ungrouped = <LorebookEntry>[];
    final groups = <String, List<LorebookEntry>>{};

    for (final entry in entries) {
      if (entry.group.isEmpty) {
        ungrouped.add(entry);
      } else {
        groups.putIfAbsent(entry.group, () => []).add(entry);
      }
    }

    // For each group, pick the highest-weight entry.
    final winners = <LorebookEntry>[];
    for (final group in groups.values) {
      group.sort((a, b) => b.groupWeight.compareTo(a.groupWeight));
      winners.add(group.first);
    }

    return [...ungrouped, ...winners];
  }

  // ---------------------------------------------------------------------------
  // Token budget
  // ---------------------------------------------------------------------------

  /// Simple word-count heuristic: ~1.3 tokens per word.
  static int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    final wordCount = text.split(RegExp(r'\s+')).length;
    return (wordCount * 1.3).ceil();
  }

  /// Enforces the token budget by including entries in order until the budget
  /// is exhausted.
  static List<LorebookEntry> _enforceBudget(
    List<LorebookEntry> entries,
    int budget,
  ) {
    if (budget <= 0) return entries; // 0 = unlimited
    final result = <LorebookEntry>[];
    int used = 0;
    for (final entry in entries) {
      final cost = _estimateTokens(entry.content);
      if (used + cost > budget) continue; // skip, over budget
      result.add(entry);
      used += cost;
    }
    return result;
  }
}
