import '../models/character_card.dart';
import '../models/lorebook_models.dart';

/// Static helper that encapsulates prompt pipeline operations used by
/// [ChatProvider].
///
/// A stateless, testable service for assembling prompts. All methods are pure functions that take
/// their dependencies as parameters — no internal state or singletons.
class PromptPipelineService {
  PromptPipelineService._();

  // -------------------------------------------------------------------------
  // System instruction construction
  // -------------------------------------------------------------------------

  /// Builds the full system instruction string, appending any lore entries
  /// recognized from the current user input.
  static String buildSystemInstruction({
    required String systemInstruction,
    required bool enableSystemPrompt,
    required bool enableCharacterCard,
    required CharacterCard characterCard,
    List<LorebookEntry> recognizedLoreEntries = const [],
  }) {
    String result = '';
    if (enableSystemPrompt) result += systemInstruction;

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

      if (characterCard.mesExample.isNotEmpty) {
        buf.writeln('Dialogue Examples:\n${characterCard.mesExample}');
      }

      if (characterCard.systemPrompt.isNotEmpty) {
        buf.writeln('Instructions: ${characterCard.systemPrompt}');
      }

      result += buf.toString();
    }

    // --- Input-recognized lore entries ---
    if (recognizedLoreEntries.isNotEmpty) {
      if (result.isNotEmpty) result += '\n\n';
      result += '--- Recognized World Lore ---\n';
      result += recognizedLoreEntries.map((e) {
        final label = e.comment.trim().isNotEmpty ? e.comment.trim() : 'Entry ${e.id}';
        final tags = e.keys.where((k) => k.trim().isNotEmpty).join(', ');
        if (tags.isNotEmpty) {
          return '$label [tags: $tags]: ${e.content}';
        }
        return '$label: ${e.content}';
      }).join('\n');
    }

    return result;
  }

  // -------------------------------------------------------------------------
  // Depth entries collection
  // -------------------------------------------------------------------------

  /// Collects the [characterCard]'s depth-positioned prompts into a flat list
  /// of `{content, depth, role}` maps suitable for passing to
  /// [ChatApiService.streamOpenAiCompatible].
  static List<Map<String, dynamic>> collectDepthEntries({
    required CharacterCard characterCard,
    required bool enableCharacterCard,
  }) {
    final entries = <Map<String, dynamic>>[];

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
}
