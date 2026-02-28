import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:airp/models/preset_model.dart';
import 'package:airp/models/lorebook_models.dart';
import 'package:airp/models/regex_models.dart';
import 'package:airp/models/formatting_models.dart';
import 'package:airp/services/preset_service.dart';

void main() {
  // ===========================================================================
  // SystemPreset model (extended)
  // ===========================================================================
  group('SystemPreset model', () {
    test('default constructor sets correct defaults', () {
      final preset = SystemPreset(name: 'Test');
      expect(preset.name, 'Test');
      expect(preset.description, '');
      expect(preset.systemPrompt, '');
      expect(preset.advancedPrompt, '');
      expect(preset.customRules, isEmpty);
      expect(preset.generationSettings, isEmpty);
      expect(preset.version, '1.0');
      expect(preset.lorebookEntries, isEmpty);
      expect(preset.regexScripts, isEmpty);
      expect(preset.formattingTemplate, isNull);
      expect(preset.postHistoryInstructions, '');
      expect(preset.sourceFormat, 'airp');
    });

    test('fromJson parses legacy preset (no new fields)', () {
      final json = {
        'name': 'Legacy',
        'system_prompt': 'You are helpful.',
        'custom_rules': [
          {'label': 'Rule1', 'content': 'Be nice', 'active': true},
        ],
      };

      final preset = SystemPreset.fromJson(json);
      expect(preset.name, 'Legacy');
      expect(preset.systemPrompt, 'You are helpful.');
      expect(preset.customRules, hasLength(1));
      expect(preset.lorebookEntries, isEmpty);
      expect(preset.regexScripts, isEmpty);
      expect(preset.formattingTemplate, isNull);
      expect(preset.postHistoryInstructions, '');
      expect(preset.sourceFormat, 'airp');
    });

    test('fromJson parses full preset with all new fields', () {
      final json = {
        'name': 'Full',
        'system_prompt': 'prompt',
        'advanced_prompt': 'advanced',
        'custom_rules': [],
        'generation_settings': {'temperature': 0.8},
        'version': '2.0',
        'lorebook_entries': [
          {
            'id': 1,
            'keys': ['hello'],
            'content': 'world',
            'enabled': true,
          },
        ],
        'regex_scripts': [
          {
            'id': 1,
            'scriptName': 'Script1',
            'findRegex': 'a',
            'replaceString': 'b',
          },
        ],
        'formatting_template': {
          'name': 'Custom',
          'enabled': true,
          'rules': [],
        },
        'post_history_instructions': 'Stay in character.',
        'source_format': 'airp',
      };

      final preset = SystemPreset.fromJson(json);
      expect(preset.lorebookEntries, hasLength(1));
      expect(preset.lorebookEntries[0].keys, ['hello']);
      expect(preset.regexScripts, hasLength(1));
      expect(preset.regexScripts[0].scriptName, 'Script1');
      expect(preset.formattingTemplate, isNotNull);
      expect(preset.formattingTemplate!.name, 'Custom');
      expect(preset.postHistoryInstructions, 'Stay in character.');
      expect(preset.sourceFormat, 'airp');
    });

    test('toJson includes new fields', () {
      final preset = SystemPreset(
        name: 'Export',
        lorebookEntries: [
          LorebookEntry(id: 1, keys: ['key1'], content: 'content1'),
        ],
        regexScripts: [
          RegexScript(id: 1, scriptName: 'Regex1', findRegex: 'x'),
        ],
        formattingTemplate: FormattingTemplate(name: 'Fmt', enabled: true),
        postHistoryInstructions: 'Post hist.',
        sourceFormat: 'airp',
      );

      final json = preset.toJson();
      expect(json['lorebook_entries'], hasLength(1));
      expect(json['regex_scripts'], hasLength(1));
      expect(json['formatting_template'], isNotNull);
      expect(json['post_history_instructions'], 'Post hist.');
      expect(json['source_format'], 'airp');
    });

    test('toJson omits formatting_template when null', () {
      final preset = SystemPreset(name: 'NoFmt');
      final json = preset.toJson();
      expect(json.containsKey('formatting_template'), false);
    });

    test('round-trip preserves all fields', () {
      final original = SystemPreset(
        name: 'Round',
        description: 'Trip test',
        systemPrompt: 'sys',
        advancedPrompt: 'adv',
        customRules: [
          {'label': 'R1', 'active': true}
        ],
        generationSettings: {'temperature': 0.7},
        version: '3.0',
        lorebookEntries: [
          LorebookEntry(id: 5, keys: ['k'], content: 'c'),
        ],
        regexScripts: [
          RegexScript(id: 2, scriptName: 'S', findRegex: 'f'),
        ],
        formattingTemplate: FormattingTemplate(
          name: 'F',
          enabled: true,
          rules: [FormattingRule(id: 1, label: 'R', pattern: '.', template: 'T')],
        ),
        postHistoryInstructions: 'phi',
        sourceFormat: 'sillytavern',
      );

      final json = original.toJson();
      final restored = SystemPreset.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.systemPrompt, original.systemPrompt);
      expect(restored.advancedPrompt, original.advancedPrompt);
      expect(restored.customRules.length, original.customRules.length);
      expect(restored.generationSettings['temperature'], 0.7);
      expect(restored.version, original.version);
      expect(restored.lorebookEntries.length, 1);
      expect(restored.lorebookEntries[0].id, 5);
      expect(restored.regexScripts.length, 1);
      expect(restored.regexScripts[0].scriptName, 'S');
      expect(restored.formattingTemplate, isNotNull);
      expect(restored.formattingTemplate!.name, 'F');
      expect(restored.formattingTemplate!.rules.length, 1);
      expect(restored.postHistoryInstructions, 'phi');
      expect(restored.sourceFormat, 'sillytavern');
    });

    test('copyWith creates independent copy', () {
      final original = SystemPreset(
        name: 'Orig',
        lorebookEntries: [LorebookEntry(id: 1, keys: ['a'], content: 'b')],
        regexScripts: [RegexScript(id: 1, scriptName: 'R')],
        formattingTemplate: FormattingTemplate(name: 'F'),
      );

      final copy = original.copyWith(name: 'Copy');
      expect(copy.name, 'Copy');
      expect(copy.lorebookEntries.length, 1);

      // Mutating copy should not affect original.
      copy.lorebookEntries.add(LorebookEntry(id: 2, keys: ['c'], content: 'd'));
      expect(original.lorebookEntries.length, 1);
    });
  });

  // ===========================================================================
  // PresetService — AIRP native
  // ===========================================================================
  group('PresetService AIRP native', () {
    test('exportAirpPreset produces valid JSON', () {
      final preset = SystemPreset(
        name: 'Export Test',
        systemPrompt: 'Hello',
        generationSettings: {'temperature': 0.5},
      );

      final jsonStr = PresetService.exportAirpPreset(preset);
      final decoded = jsonDecode(jsonStr);
      expect(decoded['name'], 'Export Test');
      expect(decoded['system_prompt'], 'Hello');
      expect(decoded['generation_settings']['temperature'], 0.5);
    });

    test('importAirpPreset round-trips correctly', () {
      final preset = SystemPreset(
        name: 'Native',
        systemPrompt: 'prompt',
        postHistoryInstructions: 'post',
        lorebookEntries: [
          LorebookEntry(id: 1, keys: ['abc'], content: 'def'),
        ],
      );

      final jsonStr = PresetService.exportAirpPreset(preset);
      final restored = PresetService.importAirpPreset(jsonStr);

      expect(restored.name, 'Native');
      expect(restored.systemPrompt, 'prompt');
      expect(restored.postHistoryInstructions, 'post');
      expect(restored.lorebookEntries.length, 1);
    });

    test('importAirpPreset throws on invalid JSON', () {
      expect(
        () => PresetService.importAirpPreset('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('importAirpPreset throws on non-object JSON', () {
      expect(
        () => PresetService.importAirpPreset('[1,2,3]'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ===========================================================================
  // PresetService — SillyTavern import
  // ===========================================================================
  group('PresetService SillyTavern import', () {
    test('extracts generation settings', () {
      final stJson = jsonEncode({
        'name': 'ST Preset',
        'temperature': 0.9,
        'top_p': 0.95,
        'top_k': 40,
        'frequency_penalty': 0.3,
        'presence_penalty': 0.2,
        'openai_max_tokens': 4096,
        'prompts': [],
        'prompt_order': [],
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      final gen = result.preset.generationSettings;

      expect(result.preset.name, 'ST Preset');
      expect(gen['temperature'], 0.9);
      expect(gen['top_p'], 0.95);
      expect(gen['top_k'], 40);
      expect(gen['frequency_penalty'], 0.3);
      expect(gen['presence_penalty'], 0.2);
      expect(gen['max_tokens'], 4096);
      expect(result.preset.sourceFormat, 'sillytavern');
    });

    test('extracts main prompt from prompts array', () {
      final stJson = jsonEncode({
        'name': 'Main Prompt',
        'prompts': [
          {
            'role': 'system',
            'identifier': 'main',
            'content': 'You are a helpful AI.',
          },
          {
            'role': 'system',
            'identifier': 'nsfw',
            'content': 'Not imported.',
          },
        ],
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.preset.systemPrompt, 'You are a helpful AI.');
    });

    test('extracts post-history instructions', () {
      final stJson = jsonEncode({
        'name': 'Post Hist',
        'prompts': [
          {
            'role': 'system',
            'identifier': 'main',
            'content': 'Main prompt.',
          },
          {
            'role': 'system',
            'identifier': 'post_history_instructions',
            'content': 'Stay in character at all times.',
          },
        ],
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.preset.postHistoryInstructions,
          'Stay in character at all times.');
    });

    test('jailbreak identifier maps to post-history', () {
      final stJson = jsonEncode({
        'name': 'JB',
        'prompts': [
          {
            'role': 'system',
            'identifier': 'jailbreak',
            'content': 'JB content.',
          },
        ],
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.preset.postHistoryInstructions, 'JB content.');
    });

    test('warns about discarded prompt_order', () {
      final stJson = jsonEncode({
        'name': 'Warnings',
        'prompts': [],
        'prompt_order': [
          {'identifier': 'main', 'enabled': true},
        ],
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.warnings,
          anyElement(contains('prompt_order')));
    });

    test('warns about discarded chat_completion_source', () {
      final stJson = jsonEncode({
        'name': 'Source',
        'chat_completion_source': 'openai',
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.warnings,
          anyElement(contains('chat_completion_source')));
    });

    test('warns about ST-specific fields', () {
      final stJson = jsonEncode({
        'name': 'STFields',
        'assistant_prefill': 'Sure!',
        'jailbreak_prompt': 'JB',
        'impersonation_prompt': 'IMP',
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.warnings, anyElement(contains('assistant_prefill')));
      expect(result.warnings, anyElement(contains('jailbreak_prompt')));
    });

    test('imports embedded regex scripts', () {
      final stJson = jsonEncode({
        'name': 'WithRegex',
        'regex_scripts': [
          {
            'id': 1,
            'scriptName': 'Remove OOC',
            'findRegex': r'\(OOC:.*?\)',
            'replaceString': '',
            'placement': [1],
          },
        ],
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.preset.regexScripts, hasLength(1));
      expect(result.preset.regexScripts[0].scriptName, 'Remove OOC');
      expect(result.preset.regexScripts[0].affectsAiOutput, true);
    });

    test('handles max_tokens fallback to openai_max_tokens', () {
      // Only max_tokens, no openai_max_tokens
      final stJson = jsonEncode({
        'name': 'MaxTok',
        'max_tokens': 2048,
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.preset.generationSettings['max_tokens'], 2048);
    });

    test('handles numeric string values in generation settings', () {
      final stJson = jsonEncode({
        'name': 'Strings',
        'temperature': '0.7',
        'top_k': '50',
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.preset.generationSettings['temperature'], 0.7);
      expect(result.preset.generationSettings['top_k'], 50);
    });

    test('warns about extra prompts beyond main and post-history', () {
      final stJson = jsonEncode({
        'name': 'ManyPrompts',
        'prompts': [
          {'role': 'system', 'identifier': 'main', 'content': 'A'},
          {'role': 'system', 'identifier': 'nsfw', 'content': 'B'},
          {'role': 'system', 'identifier': 'jailbreak', 'content': 'C'},
        ],
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.warnings, anyElement(contains('Discarded 3 prompt')));
    });

    test('isClean returns true when no warnings', () {
      final stJson = jsonEncode({
        'name': 'Clean',
        'temperature': 0.5,
      });

      final result = PresetService.importSillyTavernPreset(stJson);
      expect(result.isClean, true);
    });
  });

  // ===========================================================================
  // PresetService — auto-detect
  // ===========================================================================
  group('PresetService auto-detect', () {
    test('detects SillyTavern preset by prompts key', () {
      final stJson = jsonEncode({
        'name': 'ST',
        'prompts': [],
      });

      final result = PresetService.importAutoDetect(stJson);
      expect(result.preset.sourceFormat, 'sillytavern');
    });

    test('detects SillyTavern preset by prompt_order key', () {
      final stJson = jsonEncode({
        'name': 'ST',
        'prompt_order': [],
      });

      final result = PresetService.importAutoDetect(stJson);
      expect(result.preset.sourceFormat, 'sillytavern');
    });

    test('detects SillyTavern preset by chat_completion_source', () {
      final stJson = jsonEncode({
        'name': 'ST',
        'chat_completion_source': 'openai',
      });

      final result = PresetService.importAutoDetect(stJson);
      expect(result.preset.sourceFormat, 'sillytavern');
    });

    test('falls back to AIRP native for non-ST JSON', () {
      final airpJson = jsonEncode({
        'name': 'Native',
        'system_prompt': 'Hello',
        'source_format': 'airp',
      });

      final result = PresetService.importAutoDetect(airpJson);
      expect(result.preset.name, 'Native');
      expect(result.preset.sourceFormat, 'airp');
      expect(result.isClean, true);
    });

    test('throws on invalid JSON', () {
      expect(
        () => PresetService.importAutoDetect('not json'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ===========================================================================
  // isSillyTavernPreset
  // ===========================================================================
  group('isSillyTavernPreset', () {
    test('returns true for ST presets', () {
      expect(
          PresetService.isSillyTavernPreset({'prompts': []}), true);
      expect(
          PresetService.isSillyTavernPreset({'prompt_order': []}), true);
      expect(
          PresetService.isSillyTavernPreset(
              {'chat_completion_source': 'openai'}),
          true);
    });

    test('returns false for non-ST presets', () {
      expect(
          PresetService.isSillyTavernPreset(
              {'name': 'AIRP', 'system_prompt': ''}),
          false);
    });
  });
}
