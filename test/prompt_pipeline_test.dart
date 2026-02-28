import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/models/character_card.dart';
import 'package:airp/models/lorebook_models.dart';
import 'package:airp/models/regex_models.dart';
import 'package:airp/models/formatting_models.dart';
import 'package:airp/services/lorebook_service.dart';
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
        advancedSystemInstruction: 'Advanced',
        enableSystemPrompt: false,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
      );
      expect(result, '');
    });

    test('includes only system prompt when others disabled', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'You are helpful.',
        advancedSystemInstruction: 'Advanced',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
      );
      expect(result, 'You are helpful.');
    });

    test('concatenates system + advanced prompts', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main',
        advancedSystemInstruction: 'Advanced',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: true,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
      );
      expect(result, 'Main\n\nAdvanced');
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
        advancedSystemInstruction: '',
        enableSystemPrompt: false,
        enableAdvancedSystemPrompt: false,
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
        advancedSystemInstruction: '',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: card,
      );
      expect(result, 'Main');
      expect(result, isNot(contains('Alice')));
    });

    test('injects lorebook beforeCharDefs entries', () {
      final card = CharacterCard(name: 'Bob', description: 'A builder');
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.beforeCharDefs: [
            LorebookEntry(content: 'World lore: Dragons exist.'),
          ],
        },
        estimatedTokens: 10,
      );
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main prompt',
        advancedSystemInstruction: '',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: true,
        characterCard: card,
        lorebookResult: lorebookResult,
      );
      // beforeCharDefs should appear between main prompt and character card
      final lorebookIdx = result.indexOf('World lore: Dragons exist.');
      final cardIdx = result.indexOf('--- Character Information ---');
      expect(lorebookIdx, greaterThan(-1));
      expect(cardIdx, greaterThan(lorebookIdx));
    });

    test('injects lorebook afterCharDefs entries', () {
      final card = CharacterCard(name: 'Eve', description: 'A hacker');
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.afterCharDefs: [
            LorebookEntry(content: 'Post-card lore.'),
          ],
        },
        estimatedTokens: 5,
      );
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: '',
        advancedSystemInstruction: '',
        enableSystemPrompt: false,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: true,
        characterCard: card,
        lorebookResult: lorebookResult,
      );
      final cardIdx = result.indexOf('--- Character Information ---');
      final postIdx = result.indexOf('Post-card lore.');
      expect(cardIdx, greaterThan(-1));
      expect(postIdx, greaterThan(cardIdx));
    });

    test('injects lorebook emTop and emBottom around example messages', () {
      final card = CharacterCard(
        name: 'Char',
        description: 'A character',
        mesExample: '<START>\nChar: Hi there!',
      );
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.emTop: [
            LorebookEntry(content: 'Before examples lore.'),
          ],
          LorebookPosition.emBottom: [
            LorebookEntry(content: 'After examples lore.'),
          ],
        },
        estimatedTokens: 10,
      );
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: '',
        advancedSystemInstruction: '',
        enableSystemPrompt: false,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: true,
        characterCard: card,
        lorebookResult: lorebookResult,
      );
      final emTopIdx = result.indexOf('Before examples lore.');
      final dialogueIdx = result.indexOf('Dialogue Examples:');
      final emBottomIdx = result.indexOf('After examples lore.');
      expect(emTopIdx, greaterThan(-1));
      expect(dialogueIdx, greaterThan(emTopIdx));
      expect(emBottomIdx, greaterThan(dialogueIdx));
    });

    test('injects lorebook anTop, anBottom, outlet at end', () {
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.anTop: [
            LorebookEntry(content: 'Author note top.'),
          ],
          LorebookPosition.anBottom: [
            LorebookEntry(content: 'Author note bottom.'),
          ],
          LorebookPosition.outlet: [
            LorebookEntry(content: 'Outlet content.'),
          ],
        },
        estimatedTokens: 15,
      );
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main',
        advancedSystemInstruction: '',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
        lorebookResult: lorebookResult,
      );
      expect(result, contains('Author note top.'));
      expect(result, contains('Author note bottom.'));
      expect(result, contains('Outlet content.'));
      // All come after main prompt
      final mainIdx = result.indexOf('Main');
      final anIdx = result.indexOf('Author note top.');
      expect(anIdx, greaterThan(mainIdx));
    });

    test('does not include atDepth entries in system instruction', () {
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.atDepth: [
            LorebookEntry(content: 'Depth-injected lore.', depth: 2),
          ],
          LorebookPosition.beforeCharDefs: [
            LorebookEntry(content: 'Regular lore.'),
          ],
        },
        estimatedTokens: 10,
      );
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main',
        advancedSystemInstruction: '',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
        lorebookResult: lorebookResult,
      );
      expect(result, contains('Regular lore.'));
      expect(result, isNot(contains('Depth-injected lore.')));
    });

    test('all positions together produce correct ordering', () {
      final card = CharacterCard(
        name: 'Hero',
        description: 'A brave hero',
        mesExample: 'Hero: Ready!',
      );
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.beforeCharDefs: [
            LorebookEntry(content: '[BEFORE_CARD]'),
          ],
          LorebookPosition.emTop: [
            LorebookEntry(content: '[EM_TOP]'),
          ],
          LorebookPosition.emBottom: [
            LorebookEntry(content: '[EM_BOTTOM]'),
          ],
          LorebookPosition.afterCharDefs: [
            LorebookEntry(content: '[AFTER_CARD]'),
          ],
          LorebookPosition.anTop: [
            LorebookEntry(content: '[AN_TOP]'),
          ],
        },
        estimatedTokens: 25,
      );
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: '[MAIN]',
        advancedSystemInstruction: '[ADVANCED]',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: true,
        enableCharacterCard: true,
        characterCard: card,
        lorebookResult: lorebookResult,
      );

      final positions = <String, int>{
        '[MAIN]': result.indexOf('[MAIN]'),
        '[ADVANCED]': result.indexOf('[ADVANCED]'),
        '[BEFORE_CARD]': result.indexOf('[BEFORE_CARD]'),
        'Character Information': result.indexOf('--- Character Information ---'),
        '[EM_TOP]': result.indexOf('[EM_TOP]'),
        'Dialogue Examples': result.indexOf('Dialogue Examples:'),
        '[EM_BOTTOM]': result.indexOf('[EM_BOTTOM]'),
        '[AFTER_CARD]': result.indexOf('[AFTER_CARD]'),
        '[AN_TOP]': result.indexOf('[AN_TOP]'),
      };

      // Verify ordering
      expect(positions['[MAIN]']!, lessThan(positions['[ADVANCED]']!));
      expect(positions['[ADVANCED]']!, lessThan(positions['[BEFORE_CARD]']!));
      expect(positions['[BEFORE_CARD]']!,
          lessThan(positions['Character Information']!));
      expect(positions['Character Information']!,
          lessThan(positions['[EM_TOP]']!));
      expect(positions['[EM_TOP]']!,
          lessThan(positions['Dialogue Examples']!));
      expect(positions['Dialogue Examples']!,
          lessThan(positions['[EM_BOTTOM]']!));
      expect(positions['[EM_BOTTOM]']!, lessThan(positions['[AFTER_CARD]']!));
      expect(positions['[AFTER_CARD]']!, lessThan(positions['[AN_TOP]']!));
    });

    test('handles no lorebook result gracefully', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Prompt',
        advancedSystemInstruction: '',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
      );
      expect(result, 'Prompt');
    });

    test('handles empty lorebook result', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Prompt',
        advancedSystemInstruction: '',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
        lorebookResult:
            const LorebookEvalResult(byPosition: {}, estimatedTokens: 0),
      );
      expect(result, 'Prompt');
    });
  });

  // ===========================================================================
  // evaluateLorebooks
  // ===========================================================================
  group('evaluateLorebooks', () {
    test('returns empty result for empty lorebook list', () {
      final result = PromptPipelineService.evaluateLorebooks(
        lorebooks: [],
        recentMessages: ['Hello world'],
      );
      expect(result.isEmpty, true);
      expect(result.estimatedTokens, 0);
    });

    test('evaluates single lorebook', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['dragon'],
          content: 'Dragons are powerful.',
          position: LorebookPosition.beforeCharDefs,
        ),
      ]);
      final result = PromptPipelineService.evaluateLorebooks(
        lorebooks: [lorebook],
        recentMessages: ['I saw a dragon.'],
      );
      expect(result.isNotEmpty, true);
      expect(result.forPosition(LorebookPosition.beforeCharDefs).length, 1);
    });

    test('merges results from multiple lorebooks', () {
      final global = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['castle'],
          content: 'A mighty castle.',
          position: LorebookPosition.beforeCharDefs,
        ),
      ]);
      final character = Lorebook(entries: [
        LorebookEntry(
          id: 2,
          keys: ['castle'],
          content: 'The castle has a dungeon.',
          position: LorebookPosition.afterCharDefs,
        ),
      ]);
      final result = PromptPipelineService.evaluateLorebooks(
        lorebooks: [global, character],
        recentMessages: ['The castle looms ahead.'],
      );
      expect(result.forPosition(LorebookPosition.beforeCharDefs).length, 1);
      expect(result.forPosition(LorebookPosition.afterCharDefs).length, 1);
    });

    test('no activation when keywords not found', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['unicorn'],
          content: 'Unicorns are rare.',
          position: LorebookPosition.beforeCharDefs,
        ),
      ]);
      final result = PromptPipelineService.evaluateLorebooks(
        lorebooks: [lorebook],
        recentMessages: ['I saw a horse.'],
      );
      expect(result.isEmpty, true);
    });

    test('constant entries always activate', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['unused_keyword'],
          content: 'Always present.',
          strategy: LorebookStrategy.constant,
          position: LorebookPosition.anTop,
        ),
      ]);
      final result = PromptPipelineService.evaluateLorebooks(
        lorebooks: [lorebook],
        recentMessages: ['No keywords here.'],
      );
      expect(result.forPosition(LorebookPosition.anTop).length, 1);
    });

    test('accumulates tokens from multiple lorebooks', () {
      final l1 = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['fire'],
          content: 'Fire is hot. ' * 10, // ~40 words ≈ 52 tokens
          position: LorebookPosition.beforeCharDefs,
        ),
      ]);
      final l2 = Lorebook(entries: [
        LorebookEntry(
          id: 2,
          keys: ['fire'],
          content: 'Flames dance. ' * 10,
          position: LorebookPosition.afterCharDefs,
        ),
      ]);
      final result = PromptPipelineService.evaluateLorebooks(
        lorebooks: [l1, l2],
        recentMessages: ['The fire burns.'],
      );
      expect(result.estimatedTokens, greaterThan(0));
    });
  });

  // ===========================================================================
  // collectDepthEntries
  // ===========================================================================
  group('collectDepthEntries', () {
    test('returns empty list when no depth entries exist', () {
      final lorebookResult =
          const LorebookEvalResult(byPosition: {}, estimatedTokens: 0);
      final entries = PromptPipelineService.collectDepthEntries(
        lorebookResult: lorebookResult,
        characterCard: CharacterCard(),
        enableCharacterCard: true,
      );
      expect(entries, isEmpty);
    });

    test('collects lorebook atDepth entries', () {
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.atDepth: [
            LorebookEntry(
              content: 'Depth lore.',
              depth: 3,
              role: LorebookRole.system,
            ),
          ],
        },
        estimatedTokens: 5,
      );
      final entries = PromptPipelineService.collectDepthEntries(
        lorebookResult: lorebookResult,
        characterCard: CharacterCard(),
        enableCharacterCard: true,
      );
      expect(entries.length, 1);
      expect(entries[0]['content'], 'Depth lore.');
      expect(entries[0]['depth'], 3);
      expect(entries[0]['role'], 'system');
    });

    test('collects character card depth prompt', () {
      final card = CharacterCard(
        depthPromptText: 'Stay in character!',
        depthPromptDepth: 2,
        depthPromptRole: LorebookRole.system,
      );
      final entries = PromptPipelineService.collectDepthEntries(
        lorebookResult:
            const LorebookEvalResult(byPosition: {}, estimatedTokens: 0),
        characterCard: card,
        enableCharacterCard: true,
      );
      expect(entries.length, 1);
      expect(entries[0]['content'], 'Stay in character!');
      expect(entries[0]['depth'], 2);
    });

    test('collects post-history instructions at depth 0', () {
      final card = CharacterCard(
        postHistoryInstructions: 'Remember your role.',
      );
      final entries = PromptPipelineService.collectDepthEntries(
        lorebookResult:
            const LorebookEvalResult(byPosition: {}, estimatedTokens: 0),
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
        lorebookResult:
            const LorebookEvalResult(byPosition: {}, estimatedTokens: 0),
        characterCard: card,
        enableCharacterCard: false,
      );
      expect(entries, isEmpty);
    });

    test('combines lorebook and character card depth entries', () {
      final card = CharacterCard(
        depthPromptText: 'Card depth prompt.',
        depthPromptDepth: 4,
        postHistoryInstructions: 'Post-history.',
      );
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.atDepth: [
            LorebookEntry(
              content: 'Lorebook depth entry.',
              depth: 2,
              role: LorebookRole.user,
            ),
          ],
        },
        estimatedTokens: 5,
      );
      final entries = PromptPipelineService.collectDepthEntries(
        lorebookResult: lorebookResult,
        characterCard: card,
        enableCharacterCard: true,
      );
      expect(entries.length, 3);
      expect(entries[0]['content'], 'Lorebook depth entry.');
      expect(entries[0]['role'], 'user');
      expect(entries[1]['content'], 'Card depth prompt.');
      expect(entries[1]['depth'], 4);
      expect(entries[2]['content'], 'Post-history.');
      expect(entries[2]['depth'], 0);
    });

    test('uses correct roles for lorebook depth entries', () {
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.atDepth: [
            LorebookEntry(
              content: 'As user.',
              depth: 1,
              role: LorebookRole.user,
            ),
            LorebookEntry(
              content: 'As assistant.',
              depth: 1,
              role: LorebookRole.assistant,
            ),
          ],
        },
        estimatedTokens: 5,
      );
      final entries = PromptPipelineService.collectDepthEntries(
        lorebookResult: lorebookResult,
        characterCard: CharacterCard(),
        enableCharacterCard: false,
      );
      expect(entries.length, 2);
      expect(entries[0]['role'], 'user');
      expect(entries[1]['role'], 'assistant');
    });
  });

  // ===========================================================================
  // combineActiveScripts
  // ===========================================================================
  group('combineActiveScripts', () {
    test('returns empty when regex disabled', () {
      final result = PromptPipelineService.combineActiveScripts(
        enableRegex: false,
        enableCharacterCard: true,
        globalScripts: [RegexScript(id: 1, scriptName: 'Global')],
        characterScripts: [RegexScript(id: 2, scriptName: 'Character')],
      );
      expect(result, isEmpty);
    });

    test('returns only global scripts when card disabled', () {
      final result = PromptPipelineService.combineActiveScripts(
        enableRegex: true,
        enableCharacterCard: false,
        globalScripts: [RegexScript(id: 1, scriptName: 'Global')],
        characterScripts: [RegexScript(id: 2, scriptName: 'Character')],
      );
      expect(result.length, 1);
      expect(result[0].scriptName, 'Global');
    });

    test('combines global and character scripts', () {
      final result = PromptPipelineService.combineActiveScripts(
        enableRegex: true,
        enableCharacterCard: true,
        globalScripts: [
          RegexScript(id: 1, scriptName: 'A'),
          RegexScript(id: 2, scriptName: 'B'),
        ],
        characterScripts: [
          RegexScript(id: 3, scriptName: 'C'),
        ],
      );
      expect(result.length, 3);
      expect(result.map((s) => s.scriptName).toList(), ['A', 'B', 'C']);
    });

    test('handles empty script lists', () {
      final result = PromptPipelineService.combineActiveScripts(
        enableRegex: true,
        enableCharacterCard: true,
        globalScripts: [],
        characterScripts: [],
      );
      expect(result, isEmpty);
    });
  });

  // ===========================================================================
  // Integration: buildSystemInstruction with evaluated lorebook
  // ===========================================================================
  group('Full pipeline integration', () {
    test('lorebook evaluation + system instruction building', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['sword'],
          content: 'The Sword of Light shines brilliantly.',
          position: LorebookPosition.beforeCharDefs,
        ),
        LorebookEntry(
          id: 2,
          keys: ['sword'],
          content: 'Combat stance information.',
          position: LorebookPosition.afterCharDefs,
        ),
        LorebookEntry(
          id: 3,
          keys: ['sword'],
          content: 'Battle cry: For honor!',
          position: LorebookPosition.atDepth,
          depth: 1,
        ),
      ]);

      final evalResult = PromptPipelineService.evaluateLorebooks(
        lorebooks: [lorebook],
        recentMessages: ['I draw my sword.'],
      );

      final card = CharacterCard(
        name: 'Knight',
        description: 'A noble knight',
      );

      final sysInstruction = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Be heroic.',
        advancedSystemInstruction: '',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: true,
        characterCard: card,
        lorebookResult: evalResult,
      );

      // beforeCharDefs entry included in system instruction
      expect(sysInstruction, contains('Sword of Light'));
      // afterCharDefs entry included
      expect(sysInstruction, contains('Combat stance'));
      // atDepth entry NOT in system instruction
      expect(sysInstruction, isNot(contains('Battle cry')));

      // Depth entries should be collected separately
      final depthEntries = PromptPipelineService.collectDepthEntries(
        lorebookResult: evalResult,
        characterCard: card,
        enableCharacterCard: true,
      );
      expect(depthEntries.length, 1);
      expect(depthEntries[0]['content'], contains('Battle cry'));
    });

    test('character card with embedded lorebook and depth prompt', () {
      final charBook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['magic'],
          content: 'Magic is real.',
          strategy: LorebookStrategy.constant,
          position: LorebookPosition.anTop,
        ),
      ]);

      final card = CharacterCard(
        name: 'Wizard',
        description: 'A powerful wizard',
        characterBook: charBook,
        depthPromptText: 'Cast spells wisely.',
        depthPromptDepth: 3,
        postHistoryInstructions: 'Jailbreak text.',
      );

      // Simulate what ChatProvider does: evaluate character lorebook
      final evalResult = PromptPipelineService.evaluateLorebooks(
        lorebooks: [charBook],
        recentMessages: ['Anything.'],
        characterName: 'Wizard',
      );

      final sysInstruction = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main prompt.',
        advancedSystemInstruction: '',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: true,
        characterCard: card,
        lorebookResult: evalResult,
      );

      // Constant entry goes to anTop → appended at end
      expect(sysInstruction, contains('Magic is real.'));
      expect(sysInstruction, contains('Name: Wizard'));

      // Depth entries
      final depthEntries = PromptPipelineService.collectDepthEntries(
        lorebookResult: evalResult,
        characterCard: card,
        enableCharacterCard: true,
      );
      expect(depthEntries.length, 2); // depth prompt + post-history
      expect(
          depthEntries.any((e) => e['content'] == 'Cast spells wisely.'), true);
      expect(
          depthEntries.any((e) => e['content'] == 'Jailbreak text.'), true);
    });
  });

  // ===========================================================================
  // Persistence round-trip (serialization only — no ChatProvider instantiation)
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
    });

    test('RegexScript list round-trips through JSON', () {
      final scripts = [
        RegexScript(
          id: 1,
          scriptName: 'Filter',
          findRegex: r'\bfoo\b',
          replaceString: 'bar',
          affectsAiOutput: true,
          displayOnly: true,
        ),
        RegexScript(
          id: 2,
          scriptName: 'Clean',
          findRegex: r'\s+',
          replaceString: ' ',
        ),
      ];
      final jsonList = scripts.map((s) => s.toJson()).toList();
      final restored = jsonList
          .map((j) => RegexScript.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      expect(restored.length, 2);
      expect(restored[0].scriptName, 'Filter');
      expect(restored[0].displayOnly, true);
      expect(restored[1].scriptName, 'Clean');
    });

    test('FormattingTemplate round-trips through JSON', () {
      final template = FormattingTemplate(
        name: 'RP Format',
        enabled: true,
        rules: [
          FormattingRule(
            id: 1,
            label: 'Dialogue',
            type: FormattingRuleType.dialogue,
            pattern: r'"([^"]*)"',
            template: '"{{match}}"',
          ),
        ],
      );
      final json = template.toJson();
      final restored = FormattingTemplate.fromJson(json);
      expect(restored.name, 'RP Format');
      expect(restored.enabled, true);
      expect(restored.rules.length, 1);
      expect(restored.rules[0].label, 'Dialogue');
    });
  });

  // ===========================================================================
  // Character card auto-loading
  // ===========================================================================
  group('Character card auto-loading', () {
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

      // Simulates what ChatProvider.characterLorebook getter does
      expect(card.characterBook, isNotNull);
      expect(card.characterBook!.name, 'Char Lore');
      expect(card.characterBook!.entries.length, 1);
    });

    test('character card with regex scripts is accessible', () {
      final card = CharacterCard(
        name: 'Scholar',
        description: 'A wise scholar',
        regexScripts: [
          RegexScript(
            id: 1,
            scriptName: 'Censor',
            findRegex: r'secret',
            replaceString: '[REDACTED]',
            affectsAiOutput: true,
            displayOnly: true,
          ),
        ],
      );

      expect(card.regexScripts.length, 1);
      expect(card.regexScripts[0].scriptName, 'Censor');
    });

    test('combine scripts includes character card scripts when enabled', () {
      final scripts = PromptPipelineService.combineActiveScripts(
        enableRegex: true,
        enableCharacterCard: true,
        globalScripts: [RegexScript(id: 1, scriptName: 'Global')],
        characterScripts: [RegexScript(id: 2, scriptName: 'CharScript')],
      );
      expect(scripts.length, 2);
    });

    test('combine scripts excludes character scripts when card disabled', () {
      final scripts = PromptPipelineService.combineActiveScripts(
        enableRegex: true,
        enableCharacterCard: false,
        globalScripts: [RegexScript(id: 1, scriptName: 'Global')],
        characterScripts: [RegexScript(id: 2, scriptName: 'CharScript')],
      );
      expect(scripts.length, 1);
      expect(scripts[0].scriptName, 'Global');
    });

    test('character card from JSON preserves characterBook and regexScripts',
        () {
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
                'position': 0, // beforeCharDefs
              },
            ],
          },
          'extensions': {
            'regex_scripts': [
              {
                'id': 1,
                'scriptName': 'ElfFilter',
                'findRegex': r'human',
                'replaceString': 'mortal',
              },
            ],
          },
        },
      };

      final card = CharacterCard.fromJson(json);
      expect(card.name, 'Elf');
      expect(card.characterBook, isNotNull);
      expect(card.characterBook!.entries.length, 1);
      expect(card.regexScripts.length, 1);
      expect(card.regexScripts[0].scriptName, 'ElfFilter');
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================
  group('Edge cases', () {
    test('empty character card produces no card section', () {
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: 'Main',
        advancedSystemInstruction: '',
        enableSystemPrompt: true,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: true,
        characterCard: CharacterCard(), // all empty
      );
      expect(result, 'Main');
      expect(result, isNot(contains('Character Information')));
    });

    test('lorebook with multiple entries per position', () {
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.beforeCharDefs: [
            LorebookEntry(content: 'Lore A.'),
            LorebookEntry(content: 'Lore B.'),
            LorebookEntry(content: 'Lore C.'),
          ],
        },
        estimatedTokens: 10,
      );
      final result = PromptPipelineService.buildSystemInstruction(
        systemInstruction: '',
        advancedSystemInstruction: '',
        enableSystemPrompt: false,
        enableAdvancedSystemPrompt: false,
        enableCharacterCard: false,
        characterCard: CharacterCard(),
        lorebookResult: lorebookResult,
      );
      expect(result, contains('Lore A.'));
      expect(result, contains('Lore B.'));
      expect(result, contains('Lore C.'));
    });

    test('multiple depth entries collected with different depths', () {
      final lorebookResult = LorebookEvalResult(
        byPosition: {
          LorebookPosition.atDepth: [
            LorebookEntry(content: 'Depth 0 lore.', depth: 0),
            LorebookEntry(content: 'Depth 5 lore.', depth: 5),
            LorebookEntry(content: 'Depth 10 lore.', depth: 10),
          ],
        },
        estimatedTokens: 15,
      );
      final entries = PromptPipelineService.collectDepthEntries(
        lorebookResult: lorebookResult,
        characterCard: CharacterCard(),
        enableCharacterCard: false,
      );
      expect(entries.length, 3);
      expect(entries[0]['depth'], 0);
      expect(entries[1]['depth'], 5);
      expect(entries[2]['depth'], 10);
    });
  });
}
