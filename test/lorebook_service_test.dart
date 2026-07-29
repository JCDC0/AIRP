import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/models/lorebook_models.dart';
import 'package:airp/services/lorebook_service.dart';

/// Tests for the surviving lore matcher.
///
/// History-based scanning, positional grouping, activation diagnostics, and
/// timed effects (sticky / cooldown / delay) were removed in `0.6.11.1` when
/// the lorebook was replaced by current-input lore recognition. The engine now
/// matches a single text string and returns a flat, order-sorted list.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // Basic keyword matching
  // ---------------------------------------------------------------------------
  group('Basic keyword matching', () {
    test('triggered entry activates when keyword found', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(id: 1, keys: ['dragon'], content: 'A fearsome dragon.'),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'I saw a dragon in the mountains.',
      );

      expect(result.length, 1);
      expect(result.first.id, 1);
    });

    test('triggered entry does NOT activate when keyword absent', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(id: 1, keys: ['dragon'], content: 'A fearsome dragon.'),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'The cat sat on the mat.',
      );

      expect(result, isEmpty);
    });

    test('constant entry always activates regardless of keywords', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['unrelated'],
            content: 'Always present.',
            strategy: LorebookStrategy.constant,
          ),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'Nothing matches here.',
      );

      expect(result.length, 1);
      expect(result.first.id, 1);
    });

    test('disabled entry is skipped', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'A fearsome dragon.',
            enabled: false,
          ),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'I saw a dragon.',
      );

      expect(result, isEmpty);
    });

    test('matching is case-insensitive by default', () {
      final lorebook = Lorebook(
        entries: [LorebookEntry(id: 1, keys: ['Dragon'], content: 'Lore.')],
      );

      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: 'a dragon!'),
        hasLength(1),
      );
    });

    test('caseSensitive lorebook requires an exact-case match', () {
      final lorebook = Lorebook(
        caseSensitive: true,
        entries: [LorebookEntry(id: 1, keys: ['Dragon'], content: 'Lore.')],
      );

      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: 'a dragon!'),
        isEmpty,
      );
      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: 'a Dragon!'),
        hasLength(1),
      );
    });

    test('matchWholeWords requires word boundaries', () {
      final lorebook = Lorebook(
        matchWholeWords: true,
        entries: [LorebookEntry(id: 1, keys: ['cat'], content: 'Lore.')],
      );

      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: 'concatenate'),
        isEmpty,
      );
      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: 'the cat sat'),
        hasLength(1),
      );
    });

    test('any of several keywords triggers the entry', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon', 'wyrm', 'drake'],
            content: 'Lore.',
          ),
        ],
      );

      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: 'a drake flew'),
        hasLength(1),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Secondary keywords
  // ---------------------------------------------------------------------------
  group('Secondary keywords', () {
    test('AND mode requires both primary and secondary to match', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            secondaryKeys: ['fire'],
            selectiveLogic: true,
            content: 'A fire dragon.',
          ),
        ],
      );

      expect(
        LorebookService.matchEntries(
          lorebook: lorebook,
          text: 'a dragon breathing fire',
        ),
        hasLength(1),
      );
      expect(
        LorebookService.matchEntries(
          lorebook: lorebook,
          text: 'a dragon sleeping',
        ),
        isEmpty,
      );
    });

    test('NOT mode requires primary to match and secondary to be absent', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            secondaryKeys: ['friendly'],
            selectiveLogic: false,
            content: 'A hostile dragon.',
          ),
        ],
      );

      expect(
        LorebookService.matchEntries(
          lorebook: lorebook,
          text: 'a dragon attacks',
        ),
        hasLength(1),
      );
      expect(
        LorebookService.matchEntries(
          lorebook: lorebook,
          text: 'a friendly dragon',
        ),
        isEmpty,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Probability
  // ---------------------------------------------------------------------------
  group('Probability', () {
    test('probability 0 never activates', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'Lore.',
            probability: 0,
          ),
        ],
      );

      for (int i = 0; i < 50; i++) {
        expect(
          LorebookService.matchEntries(lorebook: lorebook, text: 'a dragon'),
          isEmpty,
        );
      }
    });

    test('probability 100 always activates', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'Lore.',
            probability: 100,
          ),
        ],
      );

      for (int i = 0; i < 50; i++) {
        expect(
          LorebookService.matchEntries(lorebook: lorebook, text: 'a dragon'),
          hasLength(1),
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Character filter
  // ---------------------------------------------------------------------------
  group('Character filter', () {
    Lorebook bookFor({
      required List<String> filter,
      required bool inclusive,
    }) => Lorebook(
      entries: [
        LorebookEntry(
          id: 1,
          keys: ['dragon'],
          content: 'Lore.',
          characterFilter: filter,
          characterFilterIsInclusive: inclusive,
        ),
      ],
    );

    test('inclusive filter allows a matching character', () {
      expect(
        LorebookService.matchEntries(
          lorebook: bookFor(filter: ['Alice'], inclusive: true),
          text: 'a dragon',
          characterName: 'Alice',
        ),
        hasLength(1),
      );
    });

    test('inclusive filter blocks a non-matching character', () {
      expect(
        LorebookService.matchEntries(
          lorebook: bookFor(filter: ['Alice'], inclusive: true),
          text: 'a dragon',
          characterName: 'Bob',
        ),
        isEmpty,
      );
    });

    test('exclusive filter blocks a matching character', () {
      expect(
        LorebookService.matchEntries(
          lorebook: bookFor(filter: ['Alice'], inclusive: false),
          text: 'a dragon',
          characterName: 'Alice',
        ),
        isEmpty,
      );
    });

    test('empty character filter allows all', () {
      expect(
        LorebookService.matchEntries(
          lorebook: bookFor(filter: [], inclusive: true),
          text: 'a dragon',
          characterName: 'Anyone',
        ),
        hasLength(1),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Inclusion groups
  // ---------------------------------------------------------------------------
  group('Inclusion groups', () {
    test('only the highest-weight entry wins within a group', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'Low weight.',
            group: 'dragons',
            groupWeight: 10,
          ),
          LorebookEntry(
            id: 2,
            keys: ['dragon'],
            content: 'High weight.',
            group: 'dragons',
            groupWeight: 90,
          ),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'a dragon',
      );

      expect(result.length, 1);
      expect(result.first.id, 2);
    });

    test('ungrouped entries all pass through', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(id: 1, keys: ['dragon'], content: 'A.'),
          LorebookEntry(id: 2, keys: ['dragon'], content: 'B.'),
        ],
      );

      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: 'a dragon'),
        hasLength(2),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Recursive scanning
  // ---------------------------------------------------------------------------
  group('Recursive scanning', () {
    test('an activated entry content can trigger another entry', () {
      final lorebook = Lorebook(
        recursionSteps: 1,
        entries: [
          LorebookEntry(id: 1, keys: ['dragon'], content: 'It guards a hoard.'),
          LorebookEntry(id: 2, keys: ['hoard'], content: 'Gold and gems.'),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'a dragon appears',
      );

      expect(result.map((e) => e.id).toSet(), {1, 2});
    });

    test('preventRecursion blocks content from the recursion corpus', () {
      final lorebook = Lorebook(
        recursionSteps: 1,
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'It guards a hoard.',
            preventRecursion: true,
          ),
          LorebookEntry(id: 2, keys: ['hoard'], content: 'Gold and gems.'),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'a dragon appears',
      );

      expect(result.map((e) => e.id).toSet(), {1});
    });

    test('no recursion when recursionSteps is 0', () {
      final lorebook = Lorebook(
        recursionSteps: 0,
        entries: [
          LorebookEntry(id: 1, keys: ['dragon'], content: 'It guards a hoard.'),
          LorebookEntry(id: 2, keys: ['hoard'], content: 'Gold and gems.'),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'a dragon appears',
      );

      expect(result.map((e) => e.id).toSet(), {1});
    });
  });

  // ---------------------------------------------------------------------------
  // Token budget
  // ---------------------------------------------------------------------------
  group('Token budget', () {
    test('entries are excluded once the budget is exceeded', () {
      final lorebook = Lorebook(
        tokenBudget: 5,
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'one two three',
            order: 1,
          ),
          LorebookEntry(
            id: 2,
            keys: ['dragon'],
            content: 'four five six seven eight nine ten',
            order: 2,
          ),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'a dragon',
      );

      expect(result.map((e) => e.id), [1]);
    });

    test('budget 0 means unlimited', () {
      final lorebook = Lorebook(
        tokenBudget: 0,
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'a very long entry with many words in it',
            order: 1,
          ),
          LorebookEntry(
            id: 2,
            keys: ['dragon'],
            content: 'another very long entry with many words',
            order: 2,
          ),
        ],
      );

      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: 'a dragon'),
        hasLength(2),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Ordering
  // ---------------------------------------------------------------------------
  group('Ordering', () {
    test('results are sorted by insertion order', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(id: 1, keys: ['dragon'], content: 'C.', order: 300),
          LorebookEntry(id: 2, keys: ['dragon'], content: 'A.', order: 100),
          LorebookEntry(id: 3, keys: ['dragon'], content: 'B.', order: 200),
        ],
      );

      final result = LorebookService.matchEntries(
        lorebook: lorebook,
        text: 'a dragon',
      );

      expect(result.map((e) => e.id), [2, 3, 1]);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------
  group('Edge cases', () {
    test('empty lorebook returns an empty list', () {
      expect(
        LorebookService.matchEntries(lorebook: Lorebook(), text: 'anything'),
        isEmpty,
      );
    });

    test('empty text still activates constant entries', () {
      final lorebook = Lorebook(
        entries: [
          LorebookEntry(
            id: 1,
            content: 'Always.',
            strategy: LorebookStrategy.constant,
          ),
        ],
      );

      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: ''),
        hasLength(1),
      );
    });

    test('entry with no keys never activates when triggered', () {
      final lorebook = Lorebook(
        entries: [LorebookEntry(id: 1, keys: const [], content: 'Lore.')],
      );

      expect(
        LorebookService.matchEntries(lorebook: lorebook, text: 'anything'),
        isEmpty,
      );
    });
  });
}
