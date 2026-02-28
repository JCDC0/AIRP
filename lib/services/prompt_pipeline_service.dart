import '../models/character_card.dart';
import '../models/lorebook_models.dart';
import '../models/regex_models.dart';
import '../services/lorebook_service.dart';

/// Static helper that encapsulates prompt pipeline operations used by
/// [ChatProvider].
///
/// Extracted for testability. All methods are pure functions that take
/// their dependencies as parameters — no internal state or singletons.
class PromptPipelineService {
  PromptPipelineService._();

  // -------------------------------------------------------------------------
  // System instruction construction
  // -------------------------------------------------------------------------

  /// Builds the full system instruction string with optional lorebook entries
  /// injected at their declared positions.
  ///
  /// Positions handled:
  /// - [LorebookPosition.beforeCharDefs] — between advanced prompt and card.
  /// - [LorebookPosition.emTop] / [LorebookPosition.emBottom] — around
  ///   example messages within the card block.
  /// - [LorebookPosition.afterCharDefs] — after the card block.
  /// - [LorebookPosition.anTop] / [LorebookPosition.anBottom] /
  ///   [LorebookPosition.outlet] — appended at the end.
  ///
  /// [LorebookPosition.atDepth] entries are NOT included — use
  /// [collectDepthEntries] for those.
  static String buildSystemInstruction({
    required String systemInstruction,
    required String advancedSystemInstruction,
    required bool enableSystemPrompt,
    required bool enableAdvancedSystemPrompt,
    required bool enableCharacterCard,
    required CharacterCard characterCard,
    LorebookEvalResult? lorebookResult,
  }) {
    String result = '';
    if (enableSystemPrompt) result += systemInstruction;
    if (enableAdvancedSystemPrompt && advancedSystemInstruction.isNotEmpty) {
      if (result.isNotEmpty) result += '\n\n';
      result += advancedSystemInstruction;
    }

    // --- Lorebook: beforeCharDefs ---
    if (lorebookResult != null) {
      final before =
          lorebookResult.forPosition(LorebookPosition.beforeCharDefs);
      if (before.isNotEmpty) {
        if (result.isNotEmpty) result += '\n\n';
        result += before.map((e) => e.content).join('\n');
      }
    }

    // --- Character Card ---
    if (enableCharacterCard &&
        (characterCard.name.isNotEmpty ||
            characterCard.description.isNotEmpty ||
            characterCard.personality.isNotEmpty)) {
      if (result.isNotEmpty) result += '\n\n';

      final buf = StringBuffer();
      buf.writeln('--- Character Information ---');

      if (characterCard.name.isNotEmpty) {
        buf.writeln('Name: ${characterCard.name}');
      }
      if (characterCard.description.isNotEmpty) {
        buf.writeln('Details/Persona: ${characterCard.description}');
      }
      if (characterCard.personality.isNotEmpty) {
        buf.writeln('Personality: ${characterCard.personality}');
      }
      if (characterCard.scenario.isNotEmpty) {
        buf.writeln('Scenario: ${characterCard.scenario}');
      }

      // --- Lorebook: emTop ---
      if (lorebookResult != null) {
        final emTop = lorebookResult.forPosition(LorebookPosition.emTop);
        if (emTop.isNotEmpty) {
          buf.writeln(emTop.map((e) => e.content).join('\n'));
        }
      }

      if (characterCard.mesExample.isNotEmpty) {
        buf.writeln('Dialogue Examples:\n${characterCard.mesExample}');
      }

      // --- Lorebook: emBottom ---
      if (lorebookResult != null) {
        final emBottom = lorebookResult.forPosition(LorebookPosition.emBottom);
        if (emBottom.isNotEmpty) {
          buf.writeln(emBottom.map((e) => e.content).join('\n'));
        }
      }

      if (characterCard.systemPrompt.isNotEmpty) {
        buf.writeln('Instructions: ${characterCard.systemPrompt}');
      }

      result += buf.toString();
    }

    // --- Lorebook: afterCharDefs ---
    if (lorebookResult != null) {
      final after =
          lorebookResult.forPosition(LorebookPosition.afterCharDefs);
      if (after.isNotEmpty) {
        if (result.isNotEmpty) result += '\n\n';
        result += after.map((e) => e.content).join('\n');
      }
    }

    // --- Lorebook: Author's Note + outlet ---
    if (lorebookResult != null) {
      final anTop = lorebookResult.forPosition(LorebookPosition.anTop);
      final anBottom = lorebookResult.forPosition(LorebookPosition.anBottom);
      final outlet = lorebookResult.forPosition(LorebookPosition.outlet);
      final anEntries = [...anTop, ...anBottom, ...outlet];
      if (anEntries.isNotEmpty) {
        if (result.isNotEmpty) result += '\n\n';
        result += anEntries.map((e) => e.content).join('\n');
      }
    }

    return result;
  }

  // -------------------------------------------------------------------------
  // Lorebook evaluation
  // -------------------------------------------------------------------------

  /// Evaluates all [lorebooks] against [recentMessages] and returns a merged
  /// [LorebookEvalResult].
  ///
  /// [recentMessages] should be ordered newest-first.
  static LorebookEvalResult evaluateLorebooks({
    required List<Lorebook> lorebooks,
    required List<String> recentMessages,
    String characterName = '',
  }) {
    if (lorebooks.isEmpty) {
      return const LorebookEvalResult(byPosition: {}, estimatedTokens: 0);
    }

    final mergedByPosition = <LorebookPosition, List<LorebookEntry>>{};
    int totalTokens = 0;

    for (final lorebook in lorebooks) {
      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: recentMessages,
        characterName: characterName,
      );

      for (final entry in result.byPosition.entries) {
        mergedByPosition.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
      totalTokens += result.estimatedTokens;
    }

    return LorebookEvalResult(
      byPosition: mergedByPosition,
      estimatedTokens: totalTokens,
    );
  }

  // -------------------------------------------------------------------------
  // Depth entries collection
  // -------------------------------------------------------------------------

  /// Collects depth-positioned entries from [lorebookResult] and the
  /// [characterCard] into a flat list of `{content, depth, role}` maps
  /// suitable for passing to [ChatApiService.streamOpenAiCompatible].
  static List<Map<String, dynamic>> collectDepthEntries({
    required LorebookEvalResult lorebookResult,
    required CharacterCard characterCard,
    required bool enableCharacterCard,
  }) {
    final entries = <Map<String, dynamic>>[];

    // Lorebook at-depth entries
    for (final entry in lorebookResult.forPosition(LorebookPosition.atDepth)) {
      entries.add({
        'content': entry.content,
        'depth': entry.depth,
        'role': entry.role.name,
      });
    }

    // Character card depth prompt
    if (enableCharacterCard && characterCard.depthPromptText.isNotEmpty) {
      entries.add({
        'content': characterCard.depthPromptText,
        'depth': characterCard.depthPromptDepth,
        'role': characterCard.depthPromptRole.name,
      });
    }

    // Character card post-history instructions (depth 0)
    if (enableCharacterCard &&
        characterCard.postHistoryInstructions.isNotEmpty) {
      entries.add({
        'content': characterCard.postHistoryInstructions,
        'depth': 0,
        'role': 'system',
      });
    }

    return entries;
  }

  // -------------------------------------------------------------------------
  // Active script combination
  // -------------------------------------------------------------------------

  /// Returns all currently active regex scripts by combining global and
  /// character-scoped scripts.
  static List<RegexScript> combineActiveScripts({
    required bool enableRegex,
    required bool enableCharacterCard,
    required List<RegexScript> globalScripts,
    required List<RegexScript> characterScripts,
  }) {
    if (!enableRegex) return [];
    return [
      ...globalScripts,
      if (enableCharacterCard) ...characterScripts,
    ];
  }
}
