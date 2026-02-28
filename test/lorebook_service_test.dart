import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/models/lorebook_models.dart';
import 'package:airp/services/lorebook_service.dart';
import 'package:airp/services/lorebook_state_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // Basic keyword matching
  // ---------------------------------------------------------------------------
  group('Basic keyword evaluation', () {
    test('triggered entry activates when keyword found', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['dragon'],
          content: 'A fearsome dragon.',
          position: LorebookPosition.beforeCharDefs,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['I saw a dragon in the mountains.'],
      );

      expect(result.isNotEmpty, true);
      expect(result.all.length, 1);
      expect(result.all.first.id, 1);
    });

    test('triggered entry does NOT activate when keyword absent', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['dragon'],
          content: 'A fearsome dragon.',
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['The cat sat on the mat.'],
      );

      expect(result.isEmpty, true);
    });

    test('constant entry always activates regardless of keywords', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['nonexistent_keyword'],
          content: 'Always here.',
          strategy: LorebookStrategy.constant,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['Hello, world.'],
      );

      expect(result.isNotEmpty, true);
      expect(result.all.first.id, 1);
    });

    test('disabled entry is skipped', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['dragon'],
          content: 'Should not appear.',
          enabled: false,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['A dragon flew overhead.'],
      );

      expect(result.isEmpty, true);
    });

    test('keyword matching respects case sensitivity', () {
      final lorebook = Lorebook(
        caseSensitive: true,
        entries: [
          LorebookEntry(id: 1, keys: ['Dragon'], content: 'case match'),
        ],
      );

      // "dragon" (lowercase) should NOT match "Dragon" (capital)
      final noMatch = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['I saw a dragon.'],
      );
      expect(noMatch.isEmpty, true);

      // "Dragon" (capital) should match
      final match = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['I saw a Dragon.'],
      );
      expect(match.isNotEmpty, true);
    });

    test('keyword matching respects whole-word boundaries', () {
      final lorebook = Lorebook(
        matchWholeWords: true,
        entries: [
          LorebookEntry(id: 1, keys: ['cat'], content: 'whole word match'),
        ],
      );

      // "catalog" contains "cat" but not as a whole word
      final noMatch = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['Check the catalog.'],
      );
      expect(noMatch.isEmpty, true);

      // "cat" as a standalone word should match
      final match = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['The cat sat down.'],
      );
      expect(match.isNotEmpty, true);
    });
  });

  // ---------------------------------------------------------------------------
  // Scan depth
  // ---------------------------------------------------------------------------
  group('Scan depth', () {
    test('only scans scanDepth most recent messages', () {
      final lorebook = Lorebook(
        scanDepth: 2,
        entries: [
          LorebookEntry(id: 1, keys: ['ancient'], content: 'Old lore'),
        ],
      );

      // "ancient" is in the 3rd message (index 2) but scanDepth=2
      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['Hello', 'World', 'The ancient temple'],
      );

      expect(result.isEmpty, true);
    });

    test('scanDepth 0 scans all messages', () {
      final lorebook = Lorebook(
        scanDepth: 0,
        entries: [
          LorebookEntry(id: 1, keys: ['ancient'], content: 'Old lore'),
        ],
      );

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['Hello', 'World', 'The ancient temple'],
      );

      expect(result.isNotEmpty, true);
    });
  });

  // ---------------------------------------------------------------------------
  // Secondary keywords (selective logic)
  // ---------------------------------------------------------------------------
  group('Secondary keywords', () {
    test('AND mode: requires both primary AND secondary match', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['sword'],
          secondaryKeys: ['magic'],
          selectiveLogic: true, // AND
          content: 'Magic sword lore.',
        ),
      ]);

      // Only primary matches → should NOT activate
      final noSecondary = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['I found a sword.'],
      );
      expect(noSecondary.isEmpty, true);

      // Both match → should activate
      final bothMatch = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['I found a magic sword.'],
      );
      expect(bothMatch.isNotEmpty, true);
    });

    test('NOT mode: primary must match, secondary must NOT match', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['sword'],
          secondaryKeys: ['broken'],
          selectiveLogic: false, // NOT
          content: 'Intact sword lore.',
        ),
      ]);

      // "sword" matches, "broken" also present → should NOT activate
      final blocked = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['A broken sword lay on the ground.'],
      );
      expect(blocked.isEmpty, true);

      // "sword" matches, "broken" absent → should activate
      final allowed = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['A shining sword gleamed.'],
      );
      expect(allowed.isNotEmpty, true);
    });
  });

  // ---------------------------------------------------------------------------
  // Probability
  // ---------------------------------------------------------------------------
  group('Probability', () {
    test('probability 0 never activates', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['always_here'],
          content: 'Should not appear.',
          probability: 0,
        ),
      ]);

      // Run several times — should never activate with probability 0.
      for (int i = 0; i < 10; i++) {
        final result = LorebookService.evaluateEntries(
          lorebook: lorebook,
          recentMessages: ['always_here'],
        );
        expect(result.isEmpty, true);
      }
    });

    test('probability 100 always activates', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['always_here'],
          content: 'Always present.',
          probability: 100,
        ),
      ]);

      for (int i = 0; i < 10; i++) {
        final result = LorebookService.evaluateEntries(
          lorebook: lorebook,
          recentMessages: ['always_here'],
        );
        expect(result.isNotEmpty, true);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Character filter
  // ---------------------------------------------------------------------------
  group('Character filter', () {
    test('inclusive filter allows matching character', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['test'],
          content: 'For Alice only.',
          characterFilter: ['Alice'],
          characterFilterIsInclusive: true,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['test'],
        characterName: 'Alice',
      );
      expect(result.isNotEmpty, true);
    });

    test('inclusive filter blocks non-matching character', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['test'],
          content: 'For Alice only.',
          characterFilter: ['Alice'],
          characterFilterIsInclusive: true,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['test'],
        characterName: 'Bob',
      );
      expect(result.isEmpty, true);
    });

    test('exclusive filter blocks matching character', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['test'],
          content: 'Not for Bob.',
          characterFilter: ['Bob'],
          characterFilterIsInclusive: false,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['test'],
        characterName: 'Bob',
      );
      expect(result.isEmpty, true);
    });

    test('empty character filter allows all', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['test'],
          content: 'For everyone.',
          characterFilter: [],
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['test'],
        characterName: 'Anyone',
      );
      expect(result.isNotEmpty, true);
    });
  });

  // ---------------------------------------------------------------------------
  // Inclusion groups
  // ---------------------------------------------------------------------------
  group('Inclusion groups', () {
    test('only highest-weight entry wins within a group', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['battle'],
          content: 'Low priority lore.',
          group: 'combat',
          groupWeight: 50,
          strategy: LorebookStrategy.constant,
        ),
        LorebookEntry(
          id: 2,
          keys: ['battle'],
          content: 'High priority lore.',
          group: 'combat',
          groupWeight: 200,
          strategy: LorebookStrategy.constant,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['A battle begins.'],
      );

      expect(result.all.length, 1);
      expect(result.all.first.id, 2);
    });

    test('ungrouped entries all pass through', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['cat'],
          content: 'Cat lore.',
          group: '',
        ),
        LorebookEntry(
          id: 2,
          keys: ['cat'],
          content: 'More cat lore.',
          group: '',
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['The cat meowed.'],
      );

      expect(result.all.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Position grouping
  // ---------------------------------------------------------------------------
  group('Position grouping', () {
    test('entries are grouped by position in result', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['test'],
          content: 'Before char.',
          position: LorebookPosition.beforeCharDefs,
          strategy: LorebookStrategy.constant,
        ),
        LorebookEntry(
          id: 2,
          keys: ['test'],
          content: 'After char.',
          position: LorebookPosition.afterCharDefs,
          strategy: LorebookStrategy.constant,
        ),
        LorebookEntry(
          id: 3,
          keys: ['test'],
          content: 'At depth.',
          position: LorebookPosition.atDepth,
          strategy: LorebookStrategy.constant,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['test'],
      );

      expect(result.forPosition(LorebookPosition.beforeCharDefs).length, 1);
      expect(result.forPosition(LorebookPosition.afterCharDefs).length, 1);
      expect(result.forPosition(LorebookPosition.atDepth).length, 1);
      expect(result.forPosition(LorebookPosition.anTop), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Recursive scanning
  // ---------------------------------------------------------------------------
  group('Recursive scanning', () {
    test('recursive scan activates entries triggered by other entries content',
        () {
      final lorebook = Lorebook(
        recursionSteps: 1,
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'The dragon guards a treasure in the castle.',
          ),
          LorebookEntry(
            id: 2,
            keys: ['castle'],
            content: 'An ancient fortress.',
          ),
        ],
      );

      // Only "dragon" is in the message, but entry 1's content contains "castle"
      // which should trigger entry 2 via recursion.
      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['A dragon appeared!'],
      );

      expect(result.all.length, 2);
      final ids = result.all.map((e) => e.id).toSet();
      expect(ids, contains(1));
      expect(ids, contains(2));
    });

    test('preventRecursion blocks entry content from recursive scanning', () {
      final lorebook = Lorebook(
        recursionSteps: 1,
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'The dragon guards a castle.',
            preventRecursion: true,
          ),
          LorebookEntry(
            id: 2,
            keys: ['castle'],
            content: 'An ancient fortress.',
          ),
        ],
      );

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['A dragon appeared!'],
      );

      // Entry 1 activates but its content is excluded from recursion,
      // so entry 2 should NOT be triggered.
      expect(result.all.length, 1);
      expect(result.all.first.id, 1);
    });

    test('no recursion when recursionSteps is 0', () {
      final lorebook = Lorebook(
        recursionSteps: 0,
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['dragon'],
            content: 'The dragon guards a castle.',
          ),
          LorebookEntry(
            id: 2,
            keys: ['castle'],
            content: 'An ancient fortress.',
          ),
        ],
      );

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['A dragon appeared!'],
      );

      expect(result.all.length, 1);
      expect(result.all.first.id, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Token budget
  // ---------------------------------------------------------------------------
  group('Token budget', () {
    test('entries are excluded when token budget is exceeded', () {
      // Each entry content ~5 words → ~7 tokens.
      // Budget of 10 should allow 1 entry but not 2.
      final lorebook = Lorebook(
        tokenBudget: 10,
        entries: [
          LorebookEntry(
            id: 1,
            keys: ['test'],
            content: 'This is some lore content here.',
            order: 1,
            strategy: LorebookStrategy.constant,
          ),
          LorebookEntry(
            id: 2,
            keys: ['test'],
            content: 'More lore content to fill budget.',
            order: 2,
            strategy: LorebookStrategy.constant,
          ),
        ],
      );

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['test'],
      );

      expect(result.all.length, 1);
      expect(result.all.first.id, 1); // Lower order wins budget
    });

    test('budget 0 means unlimited', () {
      final lorebook = Lorebook(
        tokenBudget: 0,
        entries: List.generate(
          10,
          (i) => LorebookEntry(
            id: i,
            content: 'Entry $i with some content for tokens.',
            strategy: LorebookStrategy.constant,
          ),
        ),
      );

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['test'],
      );

      expect(result.all.length, 10);
    });
  });

  // ---------------------------------------------------------------------------
  // Ordering
  // ---------------------------------------------------------------------------
  group('Ordering', () {
    test('all() returns entries sorted by insertion order', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          content: 'Second.',
          order: 50,
          strategy: LorebookStrategy.constant,
        ),
        LorebookEntry(
          id: 2,
          content: 'First.',
          order: 10,
          strategy: LorebookStrategy.constant,
        ),
        LorebookEntry(
          id: 3,
          content: 'Third.',
          order: 100,
          strategy: LorebookStrategy.constant,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['anything'],
      );

      expect(result.all.map((e) => e.id).toList(), [2, 1, 3]);
    });
  });

  // ---------------------------------------------------------------------------
  // Empty lorebook
  // ---------------------------------------------------------------------------
  group('Edge cases', () {
    test('empty lorebook returns empty result', () {
      final lorebook = Lorebook(entries: []);
      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['anything'],
      );
      expect(result.isEmpty, true);
      expect(result.estimatedTokens, 0);
    });

    test('empty messages still activates constant entries', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          content: 'Always on.',
          strategy: LorebookStrategy.constant,
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: [],
      );

      expect(result.isNotEmpty, true);
    });

    test('multiple keywords: any match triggers', () {
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['alpha', 'beta', 'gamma'],
          content: 'Multi-key entry.',
        ),
      ]);

      final result = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['The beta version is ready.'],
      );

      expect(result.isNotEmpty, true);
    });
  });

  // ---------------------------------------------------------------------------
  // LorebookSessionState
  // ---------------------------------------------------------------------------
  group('LorebookSessionState', () {
    test('default state has turn 0', () {
      final state = LorebookSessionState(sessionId: 'test');
      expect(state.currentTurn, 0);
    });

    test('advanceTurn increments counter', () {
      final state = LorebookSessionState(sessionId: 'test');
      state.advanceTurn();
      state.advanceTurn();
      expect(state.currentTurn, 2);
    });

    test('delay tracking works', () {
      final state = LorebookSessionState(sessionId: 'test');
      expect(state.hasPassedDelay(1, 3), false);
      state.incrementMatchCount(1);
      state.incrementMatchCount(1);
      expect(state.hasPassedDelay(1, 3), false);
      state.incrementMatchCount(1);
      expect(state.hasPassedDelay(1, 3), true);
    });

    test('sticky window tracking works', () {
      final state = LorebookSessionState(sessionId: 'test');
      state.setStickyWindow(1, 3);
      expect(state.isStickyActive(1, 3), true);
      state.advanceTurn();
      state.advanceTurn();
      state.advanceTurn();
      expect(state.isStickyActive(1, 3), true); // turn 3, expiry 3
      state.advanceTurn();
      expect(state.isStickyActive(1, 3), false); // turn 4, past expiry
    });

    test('cooldown tracking works', () {
      final state = LorebookSessionState(sessionId: 'test');
      state.setStickyWindow(1, 2); // sticky expires at turn 2
      state.setCooldownAfterSticky(1, 3); // cooldown until turn 5
      expect(state.isOnCooldown(1, 3), true); // turn 0 < 5
      state.advanceTurn(); // turn 1
      state.advanceTurn(); // turn 2
      state.advanceTurn(); // turn 3
      state.advanceTurn(); // turn 4
      expect(state.isOnCooldown(1, 3), true); // turn 4 < 5
      state.advanceTurn(); // turn 5
      expect(state.isOnCooldown(1, 3), false); // turn 5 >= 5
    });

    test('recordActivation stores last activation turn', () {
      final state = LorebookSessionState(sessionId: 'test');
      expect(state.lastActivation(1), -1);
      state.recordActivation(1);
      expect(state.lastActivation(1), 0);
      state.advanceTurn();
      state.recordActivation(1);
      expect(state.lastActivation(1), 1);
    });

    test('serialization round-trip preserves all state', () {
      final original = LorebookSessionState(
        sessionId: 'test123',
        currentTurn: 5,
        matchCounts: {1: 3, 2: 7},
        lastActivationTurn: {1: 4},
        stickyExpiry: {1: 8},
        cooldownExpiry: {1: 11},
      );

      final json = original.toJson();
      final restored = LorebookSessionState.fromJson('test123', json);

      expect(restored.currentTurn, 5);
      expect(restored.hasPassedDelay(1, 3), true);
      expect(restored.hasPassedDelay(2, 7), true);
      expect(restored.lastActivation(1), 4);
      expect(restored.isStickyActive(1, 0), true); // expiry 8, turn 5
      expect(restored.isOnCooldown(1, 0), true); // expiry 11, turn 5
    });

    test('save and load via SharedPreferences', () async {
      final state = LorebookSessionState(sessionId: 'persist_test');
      state.advanceTurn();
      state.advanceTurn();
      state.incrementMatchCount(5);
      state.recordActivation(5);
      await state.save();

      final loaded = await LorebookSessionState.load('persist_test');
      expect(loaded.currentTurn, 2);
      expect(loaded.hasPassedDelay(5, 1), true);
      expect(loaded.lastActivation(5), 2);
    });

    test('load returns fresh state for unknown session', () async {
      final state = await LorebookSessionState.load('nonexistent');
      expect(state.currentTurn, 0);
      expect(state.sessionId, 'nonexistent');
    });

    test('clear removes persisted state', () async {
      final state = LorebookSessionState(sessionId: 'to_clear');
      state.advanceTurn();
      await state.save();
      await LorebookSessionState.clear('to_clear');

      final loaded = await LorebookSessionState.load('to_clear');
      expect(loaded.currentTurn, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Integration: timed effects with evaluation
  // ---------------------------------------------------------------------------
  group('Timed effects integration', () {
    test('delay prevents activation until match count threshold', () {
      final state = LorebookSessionState(sessionId: 'delay_test');
      final lorebook = Lorebook(entries: [
        LorebookEntry(
          id: 1,
          keys: ['magic'],
          content: 'Delayed magic lore.',
          delay: 3,
        ),
      ]);

      // First 2 keyword matches — should NOT activate.
      for (int i = 0; i < 2; i++) {
        final r = LorebookService.evaluateEntries(
          lorebook: lorebook,
          recentMessages: ['magic is everywhere'],
          sessionState: state,
        );
        expect(r.isEmpty, true);
        state.advanceTurn();
      }

      // 3rd match — should activate.
      final r = LorebookService.evaluateEntries(
        lorebook: lorebook,
        recentMessages: ['magic is everywhere'],
        sessionState: state,
      );
      expect(r.isNotEmpty, true);
    });
  });
}
