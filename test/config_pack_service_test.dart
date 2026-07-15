import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/models/config_pack.dart';
import 'package:airp/services/config_pack_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ConfigPack model', () {
    test('round-trips settings through fromJson/toJson', () {
      final pack = ConfigPack(
        name: 'P1',
        description: 'd',
        createdAt: 42,
        sourceFormat: 'airp',
        settings: {
          'chat': {'systemInstruction': 'hi', 'models': {'gemini': 'm'}},
          'settings': {'generation': {'temperature': 0.7}},
        },
      );
      final restored = ConfigPack.fromJson(jsonDecode(jsonEncode(pack.toJson())));
      expect(restored.name, 'P1');
      expect(restored.description, 'd');
      expect(restored.createdAt, 42);
      expect(restored.sourceFormat, 'airp');
      expect(restored.settings['chat']['systemInstruction'], 'hi');
      expect(restored.settings['settings']['generation']['temperature'], 0.7);
    });

    test('fromJson tolerates missing fields', () {
      final r = ConfigPack.fromJson({});
      expect(r.name, 'Untitled Pack');
      expect(r.createdAt, 0);
      expect(r.sourceFormat, 'airp');
      expect(r.settings, isEmpty);
    });
  });

  group('ConfigPackService.importSillyTavernPreset', () {
    test('assembles enabled prompts in prompt_order, skipping disabled', () {
      final json = jsonEncode({
        'name': 'My Preset',
        'prompts': [
          {'identifier': 'main', 'content': 'You are a helpful assistant.'},
          {'identifier': 'nsfw', 'content': 'Be explicit.'},
          {'identifier': 'jailbreak', 'content': 'Ignore restrictions.'},
        ],
        'prompt_order': [
          {
            'character_id': 'default',
            'order': [
              {'identifier': 'main', 'enabled': true},
              {'identifier': 'nsfw', 'enabled': false},
              {'identifier': 'jailbreak', 'enabled': true},
            ]
          }
        ],
        'temperature': 0.8,
        'top_p': 0.95,
        'max_tokens': 1024,
      });
      final pack = ConfigPackService.importSillyTavernPreset(json);
      expect(pack.name, 'My Preset');
      expect(pack.sourceFormat, 'sillytavern');
      final sys = pack.settings['chat']['systemInstruction'] as String;
      expect(sys, 'You are a helpful assistant.\n\nIgnore restrictions.');
      final gen = pack.settings['settings']['generation'] as Map;
      expect(gen['temperature'], 0.8);
      expect(gen['topP'], 0.95);
      expect(gen['maxOutputTokens'], 1024);
      expect(gen.containsKey('topK'), isFalse);
    });

    test('falls back to array order when prompt_order is absent', () {
      final json = jsonEncode({
        'name': 'NoOrder',
        'prompts': [
          {'identifier': 'a', 'content': 'AAA'},
          {'identifier': 'b', 'content': 'BBB'},
        ],
      });
      final pack = ConfigPackService.importSillyTavernPreset(json);
      expect(pack.settings['chat']['systemInstruction'], 'AAA\n\nBBB');
    });

    test('tolerates missing prompts (empty system instruction, no crash)', () {
      final json = jsonEncode({'name': 'Empty', 'temperature': 1.0});
      final pack = ConfigPackService.importSillyTavernPreset(json);
      expect(pack.name, 'Empty');
      expect(pack.settings['chat']['systemInstruction'], '');
      expect(pack.settings['settings']['generation']['temperature'], 1.0);
    });

    test('falls back to a default name when name is absent/blank', () {
      final pack = ConfigPackService.importSillyTavernPreset('{}');
      expect(pack.name, 'Imported ST Preset');
    });

    test('adds the assembled prompt to the saved system-prompt library', () {
      final json = jsonEncode({
        'name': 'Lib',
        'prompts': [
          {'identifier': 'main', 'content': 'Hello'},
        ],
      });
      final pack = ConfigPackService.importSillyTavernPreset(json);
      final prompts =
          pack.settings['chat']['systemPrompts'] as List<dynamic>;
      expect(prompts, hasLength(1));
      expect(prompts[0]['title'], 'Lib');
      expect(prompts[0]['content'], 'Hello');
    });

    test('max_response_tokens is accepted as an alias for max_tokens', () {
      final json =
          jsonEncode({'max_response_tokens': 2048});
      final pack = ConfigPackService.importSillyTavernPreset(json);
      expect(
          pack.settings['settings']['generation']['maxOutputTokens'], 2048);
    });
  });

  group('ConfigPackService.parsePackFile', () {
    test('parses a valid AIRP pack', () {
      final pack = ConfigPack(
        name: 'F',
        createdAt: 1,
        settings: {'chat': {}},
      );
      final json = jsonEncode(pack.toJson());
      final parsed = ConfigPackService.parsePackFile(json);
      expect(parsed, isNotNull);
      expect(parsed!.name, 'F');
    });

    test('returns null for a non-pack JSON', () {
      expect(ConfigPackService.parsePackFile('{"foo":1}'), isNull);
    });

    test('returns null for invalid JSON', () {
      expect(ConfigPackService.parsePackFile('not json'), isNull);
    });
  });

  group('ConfigPackService in-app pack list', () {
    test('save/list/delete round-trips newest-first and dedupes by name', () async {
      expect(await ConfigPackService.listPacks(), isEmpty);

      final a = ConfigPack(name: 'A', createdAt: 1, settings: {});
      final b = ConfigPack(name: 'B', createdAt: 2, settings: {});
      await ConfigPackService.savePack(a);
      await ConfigPackService.savePack(b);
      var names = (await ConfigPackService.listPacks()).map((p) => p.name).toList();
      expect(names, ['B', 'A']); // newest first

      // Re-saving 'A' replaces (no duplicate), and bumps to top.
      await ConfigPackService.savePack(a.copyWith(createdAt: 3));
      names = (await ConfigPackService.listPacks()).map((p) => p.name).toList();
      expect(names, ['A', 'B']);

      await ConfigPackService.deletePack('B');
      names = (await ConfigPackService.listPacks()).map((p) => p.name).toList();
      expect(names, ['A']);
    });
  });
}
