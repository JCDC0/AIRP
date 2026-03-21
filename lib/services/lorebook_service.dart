import 'dart:developer' as developer;
import 'dart:math';

import '../models/lorebook_models.dart';
import 'lorebook_state_service.dart';

///
/// Contains entries grouped by their [LorebookPosition] for downstream
/// prompt construction.  The caller can iterate [byPosition] to inject
/// entries at the correct prompt locations.
class LorebookEvalResult {
  /// All activated entries grouped by insertion position.
  final Map<LorebookPosition, List<LorebookEntry>> byPosition;

  /// Total token estimate for budgeting purposes.
  /// Uses a simple word-count × 1.3 heuristic.
  final int estimatedTokens;

  /// Activation diagnostics for each evaluated entry.
  final List<LorebookActivationTrace> activationTraces;

  const LorebookEvalResult({
    required this.byPosition,
    required this.estimatedTokens,
    this.activationTraces = const [],
  });

  /// Convenience: all activated entries in a flat list sorted by
  /// [LorebookEntry.order].
  List<LorebookEntry> get all {
    final flat = byPosition.values.expand((e) => e).toList();
    flat.sort((a, b) => a.order.compareTo(b.order));
    return flat;
  }

  /// Returns entries for a specific position, empty list if none.
  List<LorebookEntry> forPosition(LorebookPosition pos) =>
      byPosition[pos] ?? [];

  /// Whether any entries were activated.
  bool get isEmpty => byPosition.values.every((l) => l.isEmpty);
  bool get isNotEmpty => !isEmpty;

  /// Latest diagnostic trace per entry id.
  Map<int, LorebookActivationTrace> get traceByEntryId {
    final map = <int, LorebookActivationTrace>{};
    for (final trace in activationTraces) {
      map[trace.entryId] = trace;
    }
    return map;
  }
}

/// High-level cause for an entry activation decision.
enum LorebookActivationReason {
  constant,
  keyword,
  recursive,
  rejected,
}

/// Structured per-entry diagnostic emitted by evaluator.
class LorebookActivationTrace {
  final int entryId;
  final String entryLabel;
  final bool activated;
  final LorebookActivationReason reason;
  final String? matchedKey;
  final String? secondaryMatchedKey;
  final String? blockedBy;

  const LorebookActivationTrace({
    required this.entryId,
    required this.entryLabel,
    required this.activated,
    required this.reason,
    this.matchedKey,
    this.secondaryMatchedKey,
    this.blockedBy,
  });
}

enum _LorebookActivationSource {
  keyword,
  recursive,
}

class _ActivationDecision {
  final bool activated;
  final LorebookActivationTrace trace;

  const _ActivationDecision({required this.activated, required this.trace});
}

class _TimedEffectDecision {
  final bool passed;
  final String? blockedBy;

  const _TimedEffectDecision({required this.passed, this.blockedBy});
}

/// Evaluates [LorebookEntry] items against recent messages to determine which
/// entries should be activated and injected into the prompt.
///
/// Implements the full SillyTavern-compatible evaluation pipeline:
/// 1. Filter disabled entries and character-filtered entries.
/// 2. Constant entries always activate.
/// 3. Triggered entries matched via primary keyword scan.
/// 4. Secondary keyword filter (AND / NOT selective logic).
/// 5. Probability roll.
/// 6. Timed-effect gating (delay, sticky, cooldown) via [LorebookStateService].
/// 7. Inclusion-group conflict resolution (highest weight wins).
/// 8. Recursive keyword scanning (up to [Lorebook.recursionSteps] passes).
/// 9. Token budget enforcement.
/// 10. Results grouped by [LorebookPosition].
class LorebookService {
  static final Random _rng = Random();

  /// Evaluates all entries in [lorebook] against [recentMessages].
  ///
  /// [recentMessages] should be ordered newest-first (index 0 = last message).
  /// Only the first [lorebook.scanDepth] messages are scanned (0 = all).
  ///
  /// [characterName] is the active character's name, used for character
  /// filter evaluation.
  ///
  /// [sessionState] provides per-session timed-effect tracking. Pass `null`
  /// to skip timed effects.
  ///
  /// Returns a [LorebookEvalResult] with entries grouped by position.
  static LorebookEvalResult evaluateEntries({
    required Lorebook lorebook,
    required List<String> recentMessages,
    String characterName = '',
    LorebookSessionState? sessionState,
  }) {
    if (lorebook.entries.isEmpty) {
      return const LorebookEvalResult(byPosition: {}, estimatedTokens: 0);
    }

    // Build the scan corpus from the N most recent messages.
    final scanDepth = lorebook.scanDepth <= 0
        ? recentMessages.length
        : lorebook.scanDepth;
    final corpus = recentMessages.take(scanDepth).join('\n');

    // Phase 1: Filter to eligible entries.
    final eligible = lorebook.entries.where((e) {
      if (!e.enabled) return false;
      if (!_passesCharacterFilter(e, characterName)) return false;
      return true;
    }).toList();

    final activationTraces = <LorebookActivationTrace>[];

    // Phase 2-6: Evaluate each entry.
    final activated = <LorebookEntry>[];
    for (final entry in eligible) {
      final decision = _shouldActivate(
        entry: entry,
        corpus: corpus,
        caseSensitive: lorebook.caseSensitive,
        matchWholeWords: lorebook.matchWholeWords,
        sessionState: sessionState,
        source: _LorebookActivationSource.keyword,
      );
      activationTraces.add(decision.trace);
      if (decision.activated) {
        activated.add(entry);
      }
    }

    // Phase 7: Recursive scanning — activated entries' content may trigger
    // additional entries.
    final allActivated = _recursiveScan(
      activated: activated,
      remaining: eligible.where((e) => !activated.contains(e)).toList(),
      recursionSteps: lorebook.recursionSteps,
      caseSensitive: lorebook.caseSensitive,
      matchWholeWords: lorebook.matchWholeWords,
      sessionState: sessionState,
      activationTraces: activationTraces,
    );

    // Phase 8: Inclusion group conflict resolution.
    final afterGroups = _resolveGroups(allActivated);

    // Phase 9: Sort by insertion_order and enforce token budget.
    afterGroups.sort((a, b) => a.order.compareTo(b.order));
    final budgeted = _enforceBudget(afterGroups, lorebook.tokenBudget);

    // Phase 10: Group by position.
    final byPosition = <LorebookPosition, List<LorebookEntry>>{};
    int totalTokens = 0;
    for (final entry in budgeted) {
      byPosition.putIfAbsent(entry.position, () => []).add(entry);
      totalTokens += _estimateTokens(entry.content);

      // Update session state for timed effects.
      sessionState?.recordActivation(entry.id);
    }

    return LorebookEvalResult(
      byPosition: byPosition,
      estimatedTokens: totalTokens,
      activationTraces: activationTraces,
    );
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
  static _ActivationDecision _shouldActivate({
    required LorebookEntry entry,
    required String corpus,
    required bool caseSensitive,
    required bool matchWholeWords,
    LorebookSessionState? sessionState,
    required _LorebookActivationSource source,
  }) {
    final entryLabel = entry.comment.isNotEmpty
        ? entry.comment
        : 'UID:${entry.id}';

    // Constant entries always activate (no keyword matching needed).
    if (entry.strategy == LorebookStrategy.constant) {
      final timed = _passTimedEffects(entry, sessionState);
      if (timed.passed) {
        developer.log('[$entryLabel] activated (Constant)', name: 'Lorebook');
        return _ActivationDecision(
          activated: true,
          trace: LorebookActivationTrace(
            entryId: entry.id,
            entryLabel: entryLabel,
            activated: true,
            reason: LorebookActivationReason.constant,
          ),
        );
      }
      return _ActivationDecision(
        activated: false,
        trace: LorebookActivationTrace(
          entryId: entry.id,
          entryLabel: entryLabel,
          activated: false,
          reason: LorebookActivationReason.rejected,
          blockedBy: timed.blockedBy,
        ),
      );
    }

    // Primary keyword match.
    final matchedKey = _matchesKeys(
      entry.keys,
      corpus,
      caseSensitive: caseSensitive,
      matchWholeWords: matchWholeWords,
    );

    if (matchedKey == null) {
      return _ActivationDecision(
        activated: false,
        trace: LorebookActivationTrace(
          entryId: entry.id,
          entryLabel: entryLabel,
          activated: false,
          reason: LorebookActivationReason.rejected,
          blockedBy: 'no_primary_match',
        ),
      );
    }

    // Secondary keyword filter.
    if (entry.secondaryKeys.isNotEmpty) {
      final secondaryHit = _matchesKeys(
        entry.secondaryKeys,
        corpus,
        caseSensitive: caseSensitive,
        matchWholeWords: matchWholeWords,
      );

      if (entry.selectiveLogic) {
        // AND mode: secondary keys MUST also match.
        if (secondaryHit == null) {
          return _ActivationDecision(
            activated: false,
            trace: LorebookActivationTrace(
              entryId: entry.id,
              entryLabel: entryLabel,
              activated: false,
              reason: LorebookActivationReason.rejected,
              matchedKey: matchedKey,
              blockedBy: 'secondary_and_failed',
            ),
          );
        }
      } else {
        // NOT mode: secondary keys must NOT match.
        if (secondaryHit != null) {
          return _ActivationDecision(
            activated: false,
            trace: LorebookActivationTrace(
              entryId: entry.id,
              entryLabel: entryLabel,
              activated: false,
              reason: LorebookActivationReason.rejected,
              matchedKey: matchedKey,
              secondaryMatchedKey: secondaryHit,
              blockedBy: 'secondary_not_failed',
            ),
          );
        }
      }
    }

    // Probability roll.
    if (entry.probability < 100) {
      if (_rng.nextInt(100) >= entry.probability) {
        developer.log(
          '[$entryLabel] matched "$matchedKey" but failed probability roll (${entry.probability}%)',
          name: 'Lorebook',
        );
        return _ActivationDecision(
          activated: false,
          trace: LorebookActivationTrace(
            entryId: entry.id,
            entryLabel: entryLabel,
            activated: false,
            reason: LorebookActivationReason.rejected,
            matchedKey: matchedKey,
            blockedBy: 'probability_failed',
          ),
        );
      }
    }

    // Timed effects.
    final timed = _passTimedEffects(entry, sessionState);
    if (timed.passed) {
      developer.log(
        '[$entryLabel] activated via keyword: "$matchedKey"',
        name: 'Lorebook',
      );
      return _ActivationDecision(
        activated: true,
        trace: LorebookActivationTrace(
          entryId: entry.id,
          entryLabel: entryLabel,
          activated: true,
          reason: source == _LorebookActivationSource.recursive
              ? LorebookActivationReason.recursive
              : LorebookActivationReason.keyword,
          matchedKey: matchedKey,
        ),
      );
    } else {
      developer.log(
        '[$entryLabel] matched "$matchedKey" but blocked by Timed Effects',
        name: 'Lorebook',
      );
      return _ActivationDecision(
        activated: false,
        trace: LorebookActivationTrace(
          entryId: entry.id,
          entryLabel: entryLabel,
          activated: false,
          reason: LorebookActivationReason.rejected,
          matchedKey: matchedKey,
          blockedBy: timed.blockedBy,
        ),
      );
    }
  }

  /// Checks delay, cooldown, and sticky timed effects.
  static _TimedEffectDecision _passTimedEffects(
    LorebookEntry entry,
    LorebookSessionState? state,
  ) {
    if (state == null) {
      return const _TimedEffectDecision(passed: true);
    }

    // Delay: entry needs N keyword matches before first activation.
    if (entry.delay != null && entry.delay! > 0) {
      state.incrementMatchCount(entry.id);
      if (!state.hasPassedDelay(entry.id, entry.delay!)) {
        return _TimedEffectDecision(
          passed: false,
          blockedBy: 'delay_pending',
        );
      }
    }

    // Cooldown: entry is on cooldown after sticky expired.
    if (entry.cooldown != null && entry.cooldown! > 0) {
      if (state.isOnCooldown(entry.id, entry.cooldown!)) {
        return const _TimedEffectDecision(
          passed: false,
          blockedBy: 'cooldown_active',
        );
      }
    }

    // Sticky: if previously activated and still within sticky window,
    // force activation regardless of keyword match.
    if (entry.sticky != null && entry.sticky! > 0) {
      if (state.isStickyActive(entry.id, entry.sticky!)) {
        return const _TimedEffectDecision(passed: true);
      }
    }

    return const _TimedEffectDecision(passed: true);
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
    LorebookSessionState? sessionState,
    required List<LorebookActivationTrace> activationTraces,
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
        final decision = _shouldActivate(
          entry: entry,
          corpus: recursionCorpus,
          caseSensitive: caseSensitive,
          matchWholeWords: matchWholeWords,
          sessionState: sessionState,
          source: _LorebookActivationSource.recursive,
        );
        activationTraces.add(decision.trace);
        if (decision.activated) {
          allActivated.add(entry);
          anyNew = true;
        }
      }

      if (!anyNew) break; // No new activations → stop recursing.
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
