import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/models/character_card.dart';
import 'package:airp/models/lorebook_models.dart';
import 'package:airp/services/prompt_pipeline_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ===========================================================================
  // buildSystemInstruction
  // ===========================================================================
  group('buildSystemInstruction', () {
    test('returns empty string when all prompts disabled', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main prompt',
        enableSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
      );
      expect(result, '');
    });

    test('includes only system prompt when others disabled', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'You are helpful.',
        enableSystemPrompt: true,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
      );
      expect(result, 'You are helpful.');
    });

    test('includes character card fields', () {
      final card = CharacterCard(
        name: 'Alice',
        description: 'A curious girl',
        personality: 'Curious and brave',
        scenario: 'In Wonderland',
        mesExample: '<START>\nAlice: Hello!',
        systemPrompt: 'Stay in character.',
      );
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: '',
        enableSystemPrompt: false,
        enableCharacterCard: true,
        characterCard: card,
      );
      expect(result, contains('Name: Alice'));
      expect(result, contains('Details/Persona: A curious girl'));
      expect(result, contains('Personality: Curious and brave'));
      expect(result, contains('Scenario: In Wonderland'));
      expect(result, contains('Dialogue Examples:'));
      expect(result, contains('Instructions: Stay in character.'));
    });

    test('skips character card when disabled', () {
      final card = CharacterCard(name: 'Alice', description: 'A curious girl');
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main',
        enableSystemPrompt: true,
        enableCharacterCard: false,
        characterCard: card,
      );
      expect(result, 'Main');
      expect(result, isNot(contains('Alice')));
    });

    test('character card ordering: system prompt, then card block', () {
      final card = CharacterCard(
        name: 'Alice',
        mesExample: 'Alice: Hi!',
        systemPrompt: 'Stay in character.',
      );
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main prompt.',
        enableSystemPrompt: true,
        enableCharacterCard: true,
        characterCard: card,
      );
      expect(
        result.indexOf('Main prompt.'),
        lessThan(result.indexOf('--- Character Information ---')),
      );
      expect(
        result.indexOf('Dialogue Examples:'),
        lessThan(result.indexOf('Instructions: Stay in character.')),
      );
    });
  });

  // ===========================================================================
  // Recognized lore entries (the surviving input-recognizer injection path)
  // ===========================================================================
  group('buildSystemInstruction recognized lore', () {
    test('appends recognized entries under a labelled block', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main.',
        enableSystemPrompt: true,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
        recognizedLoreEntries: [
          LorebookEntry(
            id: 1,
            comment: 'Dragons',
            keys: ['dragon'],
            content: 'Dragons hoard gold.',
          ),
        ],
      );
      expect(result, contains('--- Recognized World Lore ---'));
      expect(result, contains('Dragons [tags: dragon]: Dragons hoard gold.'));
      expect(
        result.indexOf('Main.'),
        lessThan(result.indexOf('--- Recognized World Lore ---')),
      );
    });

    test('falls back to entry id when comment is blank', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: '',
        enableSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
        recognizedLoreEntries: [
          LorebookEntry(id: 7, keys: ['orc'], content: 'Orcs raid at dusk.'),
        ],
      );
      expect(result, contains('Entry 7 [tags: orc]: Orcs raid at dusk.'));
    });

    test('omits the tag suffix when the entry has no keys', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: '',
        enableSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
        recognizedLoreEntries: [
          LorebookEntry(id: 2, comment: 'Always', content: 'The sky is red.'),
        ],
      );
      expect(result, contains('Always: The sky is red.'));
      expect(result, isNot(contains('[tags:')));
    });

    test('emits nothing when no entries were recognized', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main.',
        enableSystemPrompt: true,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
        recognizedLoreEntries: const [],
      );
      expect(result, 'Main.');
      expect(result, isNot(contains('Recognized World Lore')));
    });

    test('joins multiple recognized entries in the given order', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: '',
        enableSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
        recognizedLoreEntries: [
          LorebookEntry(id: 1, comment: 'A', content: 'Lore A.'),
          LorebookEntry(id: 2, comment: 'B', content: 'Lore B.'),
          LorebookEntry(id: 3, comment: 'C', content: 'Lore C.'),
        ],
      );
      expect(result.indexOf('Lore A.'), lessThan(result.indexOf('Lore B.')));
      expect(result.indexOf('Lore B.'), lessThan(result.indexOf('Lore C.')));
    });
  });

  // ===========================================================================
  // collectDepthEntries (character card only since 0.6.11.1)
  // ===========================================================================
  group('collectDepthEntries', () {
    test('returns empty list when no depth entries exist', () {
      final entries = PromptPipelineService.collectDepthEntries(
        characterCard: CharacterCard(),
        enableCharacterCard: true,
      );
      expect(entries, isEmpty);
    });

    test('collects character card depth prompt', () {
      final card = CharacterCard(
        depthPromptText: 'Stay in character!',
        depthPromptDepth: 2,
        depthPromptRole: LorebookRole.system,
      );
      final entries = PromptPipelineService.collectDepthEntries(
        characterCard: card,
        enableCharacterCard: true,
      );
      expect(entries.length, 1);
      expect(entries[0]['content'], 'Stay in character!');
      expect(entries[0]['depth'], 2);
      expect(entries[0]['role'], 'system');
    });

    test('honours a non-default depth prompt role', () {
      final card = CharacterCard(
        depthPromptText: 'Spoken as the user.',
        depthPromptDepth: 1,
        depthPromptRole: LorebookRole.user,
      );
      final entries = PromptPipelineService.collectDepthEntries(
        characterCard: card,
        enableCharacterCard: true,
      );
      expect(entries[0]['role'], 'user');
    });

    test('collects post-history instructions at depth 0', () {
      final card = CharacterCard(
        postHistoryInstructions: 'Remember your role.',
      );
      final entries = PromptPipelineService.collectDepthEntries(
        characterCard: card,
        enableCharacterCard: true,
      );
      expect(entries.length, 1);
      expect(entries[0]['content'], 'Remember your role.');
      expect(entries[0]['depth'], 0);
      expect(entries[0]['role'], 'system');
    });

    test('skips character card entries when card disabled', () {
      final card = CharacterCard(
        depthPromptText: 'Should not appear.',
        postHistoryInstructions: 'Also should not appear.',
      );
      final entries = PromptPipelineService.collectDepthEntries(
        characterCard: card,
        enableCharacterCard: false,
      );
      expect(entries, isEmpty);
    });

    test('depth prompt precedes post-history instructions', () {
      final card = CharacterCard(
        depthPromptText: 'Card depth prompt.',
        depthPromptDepth: 4,
        postHistoryInstructions: 'Post-history.',
      );
      final entries = PromptPipelineService.collectDepthEntries(
        characterCard: card,
        enableCharacterCard: true,
      );
      expect(entries.length, 2);
      expect(entries[0]['content'], 'Card depth prompt.');
      expect(entries[0]['depth'], 4);
      expect(entries[1]['content'], 'Post-history.');
      expect(entries[1]['depth'], 0);
    });
  });

  // ===========================================================================
  // Full pipeline integration
  // ===========================================================================
  group('Full pipeline integration', () {
    test('character card with depth prompt and recognized lore', () {
      final card = CharacterCard(
        name: 'Wizard',
        description: 'An old wizard',
        depthPromptText: 'Cast spells wisely.',
        depthPromptDepth: 3,
        postHistoryInstructions: 'Jailbreak text.',
      );

      final systemInstruction = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Base prompt.',
        enableSystemPrompt: true,
        enableCharacterCard: true,
        characterCard: card,
        recognizedLoreEntries: [
          LorebookEntry(id: 1, comment: 'Magic', content: 'Magic is rare.'),
        ],
      );

      expect(systemInstruction, contains('Base prompt.'));
      expect(systemInstruction, contains('Name: Wizard'));
      expect(systemInstruction, contains('Magic: Magic is rare.'));

      final depthEntries = PromptPipelineService.collectDepthEntries(
        characterCard: card,
        enableCharacterCard: true,
      );
      expect(depthEntries.length, 2); // depth prompt + post-history
      expect(
        depthEntries.any((e) => e['content'] == 'Cast spells wisely.'),
        true,
      );
      expect(depthEntries.any((e) => e['content'] == 'Jailbreak text.'), true);
    });
  });

  // ===========================================================================
  // Serialization round-trip
  //
  // The lorebook engine no longer consumes these fields, but they remain part
  // of the SillyTavern V2 `character_book` spec and MUST survive an
  // import/export cycle. See docs/audits/DEAD-CODE-AND-DOCS.md.
  // ===========================================================================
  group('State serialization', () {
    test('Lorebook round-trips through JSON', () {
      final lorebook = Lorebook(
        name: 'Test',
        scanDepth: 5,
        tokenBudget: 1024,
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['key1', 'key2'],
            content: 'Content.',
            position: LorebookPosition.afterCharDefs,
          ),
        ],
      );
      final json = lorebook.toJson();
      final restored = Lorebook.fromJson(json);
      expect(restored.name, 'Test');
      expect(restored.scanDepth, 5);
      expect(restored.tokenBudget, 1024);
      expect(restored.entries.length, 1);
      expect(restored.entries[0].keys, ['key1', 'key2']);
      expect(restored.entries[0].position, LorebookPosition.afterCharDefs);
    });

    test('entry round-trips spec fields the engine no longer reads', () {
      final entry = LorebookEntry(
        id: 9,
        content: 'Kept verbatim.',
        keys: ['k'],
        position: LorebookPosition.atDepth,
        depth: 7,
        role: LorebookRole.assistant,
        sticky: 3,
        cooldown: 4,
        delay: 2,
        preventRecursion: true,
        excludeRecursion: true,
      );
      final restored = LorebookEntry.fromJson(entry.toJson());
      expect(restored.position, LorebookPosition.atDepth);
      expect(restored.depth, 7);
      expect(restored.role, LorebookRole.assistant);
      expect(restored.sticky, 3);
      expect(restored.cooldown, 4);
      expect(restored.delay, 2);
      expect(restored.preventRecursion, true);
      expect(restored.excludeRecursion, true);
    });
  });

  // ===========================================================================
  // Character card embedded book
  // ===========================================================================
  group('Character card embedded book', () {
    test('character card with embedded characterBook is accessible', () {
      final book = Lorebook(
        name: 'Char Lore',
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['tavern'],
            content: 'The tavern is lively.',
          ),
        ],
      );

      final card = CharacterCard(
        name: 'Bartender',
        description: 'A friendly bartender',
        characterBook: book,
      );

      expect(card.characterBook, isNotNull);
      expect(card.characterBook!.name, 'Char Lore');
      expect(card.characterBook!.entries.length, 1);
    });

    test('character card from JSON preserves characterBook', () {
      final json = {
        'data': {
          'name': 'Elf',
          'description': 'An ancient elf',
          'personality': 'Wise',
          'character_book': {
            'name': 'Elf Lore',
            'scan_depth': 3,
            'entries': [
              {
                'keys': ['forest'],
                'content': 'The forest is enchanted.',
                'enabled': true,
                'position': 0,
              },
            ],
          },
        },
      };

      final card = CharacterCard.fromJson(json);
      expect(card.name, 'Elf');
      expect(card.characterBook, isNotNull);
      expect(card.characterBook!.entries.length, 1);
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================
  group('Edge cases', () {
    test('empty character card produces no card section', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main',
        enableSystemPrompt: true,
        enableCharacterCard: true,
        characterCard: CharacterCard(), // all empty
      );
      expect(result, 'Main');
      expect(result, isNot(contains('Character Information')));
    });

    test('card with only a name still emits the card block', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: '',
        enableSystemPrompt: false,
        enableCharacterCard: true,
        characterCard: CharacterCard(name: 'Solo'),
      );
      expect(result, contains('--- Character Information ---'));
      expect(result, contains('Name: Solo'));
    });
  });
}
