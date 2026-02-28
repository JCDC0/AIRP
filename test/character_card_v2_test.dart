import 'package:flutter_test/flutter_test.dart';
import 'package:airp/models/character_card.dart';
import 'package:airp/models/lorebook_models.dart';
import 'package:airp/models/regex_models.dart';

void main() {
  group('CharacterCard V2 fields', () {
    test('default constructor includes new V2 fields', () {
      final card = CharacterCard();
      expect(card.creatorNotes, '');
      expect(card.tags, isEmpty);
      expect(card.characterBook, isNull);
      expect(card.depthPromptText, '');
      expect(card.depthPromptDepth, 4);
      expect(card.depthPromptRole, LorebookRole.system);
      expect(card.regexScripts, isEmpty);
    });

    test('fromJson parses creator_notes and tags', () {
      final json = {
        'spec': 'chara_card_v2',
        'spec_version': '2.0',
        'data': {
          'name': 'Test Char',
          'description': 'A test character.',
          'personality': 'Brave',
          'scenario': 'Fantasy',
          'first_mes': 'Hello!',
          'mes_example': '',
          'creator': 'Author',
          'creator_notes': 'Some notes about this card.',
          'character_version': '1.2',
          'system_prompt': '',
          'post_history_instructions': '',
          'tags': ['fantasy', 'original', 'female'],
          'alternate_greetings': ['Hi there!'],
          'extensions': {},
        }
      };

      final card = CharacterCard.fromJson(json);
      expect(card.name, 'Test Char');
      expect(card.creatorNotes, 'Some notes about this card.');
      expect(card.tags, ['fantasy', 'original', 'female']);
      expect(card.alternateGreetings, ['Hi there!']);
      expect(card.characterBook, isNull);
    });

    test('fromJson parses embedded character_book', () {
      final json = {
        'data': {
          'name': 'Lore Char',
          'description': '',
          'personality': '',
          'scenario': '',
          'first_mes': '',
          'mes_example': '',
          'creator': '',
          'character_version': '',
          'system_prompt': '',
          'post_history_instructions': '',
          'extensions': {},
          'character_book': {
            'name': 'World Lore',
            'scan_depth': 3,
            'token_budget': 512,
            'recursive_scanning': false,
            'entries': [
              {
                'uid': 1,
                'comment': 'Kingdom',
                'content': 'The kingdom of Eldoria.',
                'keys': ['Eldoria', 'kingdom'],
                'enabled': true,
                'position': 0,
                'insertion_order': 10,
              }
            ],
            'extensions': {},
          }
        }
      };

      final card = CharacterCard.fromJson(json);
      expect(card.characterBook, isNotNull);
      expect(card.characterBook!.name, 'World Lore');
      expect(card.characterBook!.scanDepth, 3);
      expect(card.characterBook!.tokenBudget, 512);
      expect(card.characterBook!.entries.length, 1);
      expect(card.characterBook!.entries[0].comment, 'Kingdom');
      expect(card.characterBook!.entries[0].keys, ['Eldoria', 'kingdom']);
    });

    test('fromJson parses extensions.depth_prompt', () {
      final json = {
        'data': {
          'name': 'Depth Char',
          'description': '',
          'personality': '',
          'scenario': '',
          'first_mes': '',
          'mes_example': '',
          'creator': '',
          'character_version': '',
          'system_prompt': '',
          'post_history_instructions': '',
          'extensions': {
            'depth_prompt': {
              'prompt': 'Stay in character at all times.',
              'depth': 2,
              'role': 'system',
            }
          },
        }
      };

      final card = CharacterCard.fromJson(json);
      expect(card.depthPromptText, 'Stay in character at all times.');
      expect(card.depthPromptDepth, 2);
      expect(card.depthPromptRole, LorebookRole.system);
    });

    test('fromJson parses extensions.regex_scripts', () {
      final json = {
        'data': {
          'name': 'Regex Char',
          'description': '',
          'personality': '',
          'scenario': '',
          'first_mes': '',
          'mes_example': '',
          'creator': '',
          'character_version': '',
          'system_prompt': '',
          'post_history_instructions': '',
          'extensions': {
            'regex_scripts': [
              {
                'id': 1,
                'scriptName': 'Remove Brackets',
                'findRegex': r'\[.*?\]',
                'replaceString': '',
                'placement': [1],
              }
            ]
          },
        }
      };

      final card = CharacterCard.fromJson(json);
      expect(card.regexScripts.length, 1);
      expect(card.regexScripts[0].scriptName, 'Remove Brackets');
      expect(card.regexScripts[0].affectsAiOutput, true);
    });

    test('toJson includes new V2 fields', () {
      final card = CharacterCard(
        name: 'Export Test',
        creatorNotes: 'Notes here',
        tags: ['tag1', 'tag2'],
        characterBook: Lorebook(
          name: 'Book',
          entries: [LorebookEntry(id: 1, comment: 'e1', content: 'Lore')],
        ),
        depthPromptText: 'Stay in character.',
        depthPromptDepth: 3,
        depthPromptRole: LorebookRole.user,
        regexScripts: [
          RegexScript(id: 1, scriptName: 'Test Regex'),
        ],
      );

      final json = card.toJson();
      expect(json['spec'], 'chara_card_v2');
      expect(json['spec_version'], '2.0');

      final data = json['data'] as Map<String, dynamic>;
      expect(data['name'], 'Export Test');
      expect(data['creator_notes'], 'Notes here');
      expect(data['tags'], ['tag1', 'tag2']);
      expect(data['character_book'], isNotNull);
      expect((data['character_book']['entries'] as List).length, 1);

      final ext = data['extensions'] as Map<String, dynamic>;
      expect(ext['depth_prompt']['prompt'], 'Stay in character.');
      expect(ext['depth_prompt']['depth'], 3);
      expect(ext['depth_prompt']['role'], 'user');
      expect((ext['regex_scripts'] as List).length, 1);
    });

    test('toJson omits empty depth_prompt and regex_scripts', () {
      final card = CharacterCard(name: 'Minimal');
      final json = card.toJson();
      final ext = (json['data'] as Map<String, dynamic>)['extensions']
          as Map<String, dynamic>;
      expect(ext.containsKey('depth_prompt'), false);
      expect(ext.containsKey('regex_scripts'), false);
    });

    test('full V2 round-trip preserves all fields', () {
      final original = CharacterCard(
        name: 'Round Trip',
        description: 'Desc',
        personality: 'Brave',
        scenario: 'Fantasy world',
        firstMessage: 'Greetings!',
        mesExample: '<START>\n{{user}}: Hi\n{{char}}: Hello!',
        creator: 'Author',
        creatorNotes: 'Created for testing.',
        characterVersion: '2.1',
        systemPrompt: 'You are a knight.',
        postHistoryInstructions: 'Remember your oath.',
        alternateGreetings: ['Hey!', 'Salutations!'],
        tags: ['knight', 'fantasy'],
        characterBook: Lorebook(
          name: 'Knight Lore',
          scanDepth: 4,
          tokenBudget: 1024,
          entries: [
            LorebookEntry(
              id: 1,
              comment: 'Sword',
              content: 'The sword Excalibur.',
              keys: ['sword', 'Excalibur'],
            ),
          ],
        ),
        depthPromptText: 'Always speak formally.',
        depthPromptDepth: 1,
        depthPromptRole: LorebookRole.system,
        regexScripts: [
          RegexScript(
            id: 1,
            scriptName: 'Formalize',
            findRegex: r'gonna',
            replaceString: 'going to',
          ),
        ],
        extensions: {'custom': 'value'},
      );

      final json = original.toJson();
      final restored = CharacterCard.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.personality, original.personality);
      expect(restored.scenario, original.scenario);
      expect(restored.firstMessage, original.firstMessage);
      expect(restored.mesExample, original.mesExample);
      expect(restored.creator, original.creator);
      expect(restored.creatorNotes, original.creatorNotes);
      expect(restored.characterVersion, original.characterVersion);
      expect(restored.systemPrompt, original.systemPrompt);
      expect(restored.postHistoryInstructions, original.postHistoryInstructions);
      expect(restored.alternateGreetings, original.alternateGreetings);
      expect(restored.tags, original.tags);

      // Character book
      expect(restored.characterBook, isNotNull);
      expect(restored.characterBook!.name, 'Knight Lore');
      expect(restored.characterBook!.scanDepth, 4);
      expect(restored.characterBook!.entries.length, 1);
      expect(restored.characterBook!.entries[0].keys, ['sword', 'Excalibur']);

      // Depth prompt
      expect(restored.depthPromptText, 'Always speak formally.');
      expect(restored.depthPromptDepth, 1);
      expect(restored.depthPromptRole, LorebookRole.system);

      // Regex scripts
      expect(restored.regexScripts.length, 1);
      expect(restored.regexScripts[0].scriptName, 'Formalize');

      // Custom extension preserved
      expect(restored.extensions['custom'], 'value');
    });

    test('copyWith includes new V2 fields', () {
      final card = CharacterCard(
        name: 'Original',
        creatorNotes: 'Notes',
        tags: ['a'],
        characterBook: Lorebook(name: 'Book'),
        depthPromptText: 'dprompt',
        regexScripts: [RegexScript(id: 1)],
      );

      final copy = card.copyWith(name: 'Copy');
      expect(copy.name, 'Copy');
      expect(copy.creatorNotes, 'Notes');
      expect(copy.tags, ['a']);
      expect(copy.characterBook, isNotNull);
      expect(copy.depthPromptText, 'dprompt');
      expect(copy.regexScripts.length, 1);

      // Ensure deep copy independence
      copy.tags.add('b');
      expect(card.tags, ['a']);
    });

    test('backward compatibility: old V1 JSON still parses', () {
      final v1Json = {
        'name': 'OldChar',
        'char_persona': 'A persona desc',
        'world_scenario': 'A world',
        'char_greeting': 'Hello old friend',
        'example_dialogue': 'Example here',
      };

      final card = CharacterCard.fromJson(v1Json);
      expect(card.name, 'OldChar');
      expect(card.description, 'A persona desc');
      expect(card.scenario, 'A world');
      expect(card.firstMessage, 'Hello old friend');
      expect(card.mesExample, 'Example here');
      expect(card.creatorNotes, '');
      expect(card.tags, isEmpty);
      expect(card.characterBook, isNull);
    });
  });
}
