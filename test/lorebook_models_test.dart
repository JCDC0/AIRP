import 'package:flutter_test/flutter_test.dart';
import 'package:airp/models/lorebook_models.dart';

void main() {
  group('Lorebook', () {
    test('default constructor applies sensible defaults', () {
      final book = Lorebook();
      expect(book.name, '');
      expect(book.scanDepth, 2);
      expect(book.tokenBudget, 2048);
      expect(book.recursionSteps, 0);
      expect(book.caseSensitive, false);
      expect(book.matchWholeWords, false);
      expect(book.entries, isEmpty);
      expect(book.extensions, isEmpty);
    });

    test('fromJson round-trips through toJson', () {
      final json = {
        'name': 'Test Book',
        'scan_depth': 5,
        'token_budget': 1024,
        'recursive_scanning': true,
        'extensions': {
          'case_sensitive': true,
          'match_whole_words': true,
        },
        'entries': [
          {
            'uid': 1,
            'comment': 'Entry 1',
            'content': 'Some lore content',
            'keys': ['dragon', 'fire'],
            'secondary_keys': ['ice'],
            'enabled': true,
            'constant': false,
            'position': 0,
            'depth': 4,
            'role': 0,
            'insertion_order': 50,
            'probability': 80,
            'group': 'creatures',
            'group_weight': 200,
          }
        ],
      };

      final book = Lorebook.fromJson(json);
      expect(book.name, 'Test Book');
      expect(book.scanDepth, 5);
      expect(book.tokenBudget, 1024);
      expect(book.recursionSteps, 1);
      expect(book.caseSensitive, true);
      expect(book.matchWholeWords, true);
      expect(book.entries.length, 1);

      final out = book.toJson();
      expect(out['name'], 'Test Book');
      expect(out['scan_depth'], 5);
      expect(out['token_budget'], 1024);
      expect(out['recursive_scanning'], true);
      expect((out['entries'] as List).length, 1);
    });

    test('copyWith creates independent copy', () {
      final book = Lorebook(
        name: 'Original',
        entries: [LorebookEntry(id: 1, comment: 'e1')],
      );
      final copy = book.copyWith(name: 'Copy');
      expect(copy.name, 'Copy');
      expect(copy.entries.length, 1);
      copy.entries[0].comment = 'modified';
      expect(book.entries[0].comment, 'e1'); // original unchanged
    });
  });

  group('LorebookEntry', () {
    test('default constructor applies correct defaults', () {
      final entry = LorebookEntry();
      expect(entry.id, 0);
      expect(entry.comment, '');
      expect(entry.content, '');
      expect(entry.keys, isEmpty);
      expect(entry.secondaryKeys, isEmpty);
      expect(entry.enabled, true);
      expect(entry.strategy, LorebookStrategy.triggered);
      expect(entry.position, LorebookPosition.beforeCharDefs);
      expect(entry.depth, 4);
      expect(entry.role, LorebookRole.system);
      expect(entry.order, 100);
      expect(entry.probability, 100);
      expect(entry.group, '');
      expect(entry.groupWeight, 100);
      expect(entry.selectiveLogic, true);
      expect(entry.sticky, isNull);
      expect(entry.cooldown, isNull);
      expect(entry.delay, isNull);
      expect(entry.preventRecursion, false);
      expect(entry.excludeRecursion, false);
      expect(entry.characterFilter, isEmpty);
      expect(entry.characterFilterIsInclusive, true);
    });

    test('fromJson parses V2 spec field names', () {
      final json = {
        'uid': 42,
        'comment': 'Dragon Lore',
        'content': 'Dragons breathe fire.',
        'keys': ['dragon', 'wyrm'],
        'secondary_keys': ['ancient'],
        'enabled': true,
        'constant': false,
        'position': 4,
        'depth': 2,
        'role': 0,
        'insertion_order': 10,
        'probability': 75,
        'group': 'mythical',
        'group_weight': 150,
        'selectiveLogic': 0,
        'sticky': 3,
        'cooldown': 5,
        'delay': 1,
        'prevent_recursion': true,
        'exclude_recursion': false,
        'characterFilter': {
          'names': ['Alice'],
          'isExclude': false,
        },
        'extensions': {'custom_key': 'val'},
      };

      final entry = LorebookEntry.fromJson(json);
      expect(entry.id, 42);
      expect(entry.comment, 'Dragon Lore');
      expect(entry.content, 'Dragons breathe fire.');
      expect(entry.keys, ['dragon', 'wyrm']);
      expect(entry.secondaryKeys, ['ancient']);
      expect(entry.enabled, true);
      expect(entry.strategy, LorebookStrategy.triggered);
      expect(entry.position, LorebookPosition.atDepth);
      expect(entry.depth, 2);
      expect(entry.role, LorebookRole.system);
      expect(entry.order, 10);
      expect(entry.probability, 75);
      expect(entry.group, 'mythical');
      expect(entry.groupWeight, 150);
      expect(entry.selectiveLogic, true); // 0 = AND = true
      expect(entry.sticky, 3);
      expect(entry.cooldown, 5);
      expect(entry.delay, 1);
      expect(entry.preventRecursion, true);
      expect(entry.excludeRecursion, false);
      expect(entry.characterFilter, ['Alice']);
      expect(entry.characterFilterIsInclusive, true);
      expect(entry.extensions['custom_key'], 'val');
    });

    test('fromJson handles ST internal field names (key, keysecondary, disable)', () {
      final json = {
        'uid': 10,
        'comment': 'ST Entry',
        'content': 'Content here',
        'key': 'cat, dog',
        'keysecondary': 'pet',
        'disable': true,
        'constant': true,
        'position': 1,
        'order': 55,
      };

      final entry = LorebookEntry.fromJson(json);
      expect(entry.keys, ['cat', 'dog']);
      expect(entry.secondaryKeys, ['pet']);
      expect(entry.enabled, false); // disable=true => enabled=false
      expect(entry.strategy, LorebookStrategy.constant);
      expect(entry.position, LorebookPosition.afterCharDefs);
      expect(entry.order, 55);
    });

    test('fromJson handles comma-separated key strings', () {
      final json = {
        'key': 'alpha, beta, gamma',
        'keysecondary': 'delta',
      };
      final entry = LorebookEntry.fromJson(json);
      expect(entry.keys, ['alpha', 'beta', 'gamma']);
      expect(entry.secondaryKeys, ['delta']);
    });

    test('toJson produces spec-compatible output', () {
      final entry = LorebookEntry(
        id: 7,
        comment: 'Test',
        content: 'Test content',
        keys: ['a', 'b'],
        secondaryKeys: ['c'],
        enabled: true,
        strategy: LorebookStrategy.constant,
        position: LorebookPosition.anBottom,
        depth: 3,
        role: LorebookRole.assistant,
        order: 20,
        probability: 90,
        group: 'grp',
        groupWeight: 50,
        selectiveLogic: false,
        sticky: 2,
        cooldown: 4,
        characterFilter: ['Bob'],
        characterFilterIsInclusive: false,
      );

      final json = entry.toJson();
      expect(json['uid'], 7);
      expect(json['comment'], 'Test');
      expect(json['content'], 'Test content');
      expect(json['keys'], ['a', 'b']);
      expect(json['secondary_keys'], ['c']);
      expect(json['enabled'], true);
      expect(json['constant'], true);
      expect(json['position'], 3); // anBottom = 3
      expect(json['depth'], 3);
      expect(json['role'], 2); // assistant = 2
      expect(json['insertion_order'], 20);
      expect(json['probability'], 90);
      expect(json['group'], 'grp');
      expect(json['group_weight'], 50);
      expect(json['selectiveLogic'], 1); // false = NOT = 1
      expect(json['sticky'], 2);
      expect(json['cooldown'], 4);
      expect(json['characterFilter']['names'], ['Bob']);
      expect(json['characterFilter']['isExclude'], true);
    });

    test('toJson omits null timed effects', () {
      final entry = LorebookEntry(id: 1);
      final json = entry.toJson();
      expect(json.containsKey('sticky'), false);
      expect(json.containsKey('cooldown'), false);
      expect(json.containsKey('delay'), false);
    });

    test('all position values round-trip through int', () {
      for (final pos in LorebookPosition.values) {
        final entry = LorebookEntry(position: pos);
        final json = entry.toJson();
        final restored = LorebookEntry.fromJson(json);
        expect(restored.position, pos,
            reason: 'Position $pos failed round-trip');
      }
    });

    test('all role values round-trip through int', () {
      for (final role in LorebookRole.values) {
        final entry = LorebookEntry(role: role);
        final json = entry.toJson();
        final restored = LorebookEntry.fromJson(json);
        expect(restored.role, role,
            reason: 'Role $role failed round-trip');
      }
    });

    test('copyWith preserves all fields', () {
      final entry = LorebookEntry(
        id: 5,
        comment: 'orig',
        content: 'data',
        keys: ['k1'],
        secondaryKeys: ['s1'],
        enabled: false,
        strategy: LorebookStrategy.constant,
        position: LorebookPosition.emTop,
        depth: 8,
        role: LorebookRole.user,
        order: 30,
        probability: 50,
        group: 'g',
        groupWeight: 75,
        selectiveLogic: false,
        sticky: 1,
        cooldown: 2,
        delay: 3,
        preventRecursion: true,
        excludeRecursion: true,
        characterFilter: ['X'],
        characterFilterIsInclusive: false,
        extensions: {'foo': 'bar'},
      );

      final copy = entry.copyWith(comment: 'changed');
      expect(copy.comment, 'changed');
      expect(copy.id, 5);
      expect(copy.keys, ['k1']);
      expect(copy.strategy, LorebookStrategy.constant);
      expect(copy.sticky, 1);
      expect(copy.characterFilter, ['X']);
      expect(copy.extensions['foo'], 'bar');
    });
  });
}
