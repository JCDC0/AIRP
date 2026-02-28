import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/models/regex_models.dart';
import 'package:airp/services/regex_service.dart';
import 'package:airp/services/macro_service.dart';

void main() {
  // Ensure Flutter binding for SharedPreferences in tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MacroService.resetVariables();
  });

  // ---------------------------------------------------------------------------
  // Basic application
  // ---------------------------------------------------------------------------
  group('Basic regex application', () {
    test('simple find-and-replace', () async {
      final scripts = [
        RegexScript(
          findRegex: 'world',
          replaceString: 'earth',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'Hello world!',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );

      expect(result, 'Hello earth!');
    });

    test('replaces all occurrences (not just first)', () async {
      final scripts = [
        RegexScript(
          findRegex: 'a',
          replaceString: 'b',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'banana',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );

      expect(result, 'bbnbnb');
    });

    test('empty find regex skips the script', () async {
      final scripts = [
        RegexScript(
          findRegex: '',
          replaceString: 'REPLACED',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'original text',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );

      expect(result, 'original text');
    });

    test('no matching scripts returns text unchanged', () async {
      final result = await RegexService.apply(
        text: 'hello',
        scripts: [],
        target: RegexTarget.aiOutput,
      );

      expect(result, 'hello');
    });

    test('regex with capture groups and back-references', () async {
      final scripts = [
        RegexScript(
          findRegex: r'(\w+)\s(\w+)',
          replaceString: r'$2 $1',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'Hello World',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );

      expect(result, 'World Hello');
    });

    test('back-reference with \${n} syntax', () async {
      final scripts = [
        RegexScript(
          findRegex: r'(\w+) (\w+)',
          replaceString: r'${2}-${1}',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'foo bar',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );

      expect(result, 'bar-foo');
    });

    test('\$0 refers to full match', () async {
      final scripts = [
        RegexScript(
          findRegex: r'\d+',
          replaceString: r'[$0]',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'count: 42',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );

      expect(result, 'count: [42]');
    });

    test('\$\$ literal dollar sign', () async {
      final scripts = [
        RegexScript(
          findRegex: 'price',
          replaceString: r'$$5',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'The price is here',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );

      expect(result, r'The $5 is here');
    });
  });

  // ---------------------------------------------------------------------------
  // Filtering: enabled
  // ---------------------------------------------------------------------------
  group('Enabled filtering', () {
    test('disabled scripts are skipped', () async {
      final scripts = [
        RegexScript(
          findRegex: 'hello',
          replaceString: 'bye',
          enabled: false,
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'hello world',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );

      expect(result, 'hello world');
    });
  });

  // ---------------------------------------------------------------------------
  // Filtering: target
  // ---------------------------------------------------------------------------
  group('Target filtering', () {
    test('script only applies to matching target', () async {
      final scripts = [
        RegexScript(
          findRegex: 'text',
          replaceString: 'TEXT',
          affectsUserInput: true,
          affectsAiOutput: false,
        ),
      ];

      // Should NOT apply to aiOutput
      final aiResult = await RegexService.apply(
        text: 'some text',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(aiResult, 'some text');

      // Should apply to userInput
      final userResult = await RegexService.apply(
        text: 'some text',
        scripts: scripts,
        target: RegexTarget.userInput,
      );
      expect(userResult, 'some TEXT');
    });

    test('script affecting worldInfo only applies there', () async {
      final scripts = [
        RegexScript(
          findRegex: 'lore',
          replaceString: 'LORE',
          affectsAiOutput: false,
          affectsWorldInfo: true,
        ),
      ];

      final wiResult = await RegexService.apply(
        text: 'lore entry',
        scripts: scripts,
        target: RegexTarget.worldInfo,
      );
      expect(wiResult, 'LORE entry');

      final aiResult = await RegexService.apply(
        text: 'lore entry',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(aiResult, 'lore entry');
    });

    test('script affecting reasoning only applies there', () async {
      final scripts = [
        RegexScript(
          findRegex: 'think',
          replaceString: 'THINK',
          affectsAiOutput: false,
          affectsReasoning: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'I think therefore',
        scripts: scripts,
        target: RegexTarget.reasoning,
      );
      expect(result, 'I THINK therefore');
    });

    test('script with multiple targets applies to all of them', () async {
      final scripts = [
        RegexScript(
          findRegex: 'x',
          replaceString: 'X',
          affectsUserInput: true,
          affectsAiOutput: true,
          affectsWorldInfo: false,
          affectsReasoning: false,
        ),
      ];

      for (final target in [RegexTarget.userInput, RegexTarget.aiOutput]) {
        final result = await RegexService.apply(
          text: 'x marks',
          scripts: scripts,
          target: target,
        );
        expect(result, 'X marks', reason: 'Failed for $target');
      }

      for (final target in [RegexTarget.worldInfo, RegexTarget.reasoning]) {
        final result = await RegexService.apply(
          text: 'x marks',
          scripts: scripts,
          target: target,
        );
        expect(result, 'x marks', reason: 'Should not apply to $target');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Filtering: depth range
  // ---------------------------------------------------------------------------
  group('Depth range filtering', () {
    test('script within depth range applies', () async {
      final scripts = [
        RegexScript(
          findRegex: 'old',
          replaceString: 'new',
          affectsAiOutput: true,
          minDepth: 0,
          maxDepth: 5,
        ),
      ];

      final result = await RegexService.apply(
        text: 'old text',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        messageDepth: 3,
      );
      expect(result, 'new text');
    });

    test('script outside depth range does not apply', () async {
      final scripts = [
        RegexScript(
          findRegex: 'old',
          replaceString: 'new',
          affectsAiOutput: true,
          minDepth: 0,
          maxDepth: 5,
        ),
      ];

      final result = await RegexService.apply(
        text: 'old text',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        messageDepth: 6,
      );
      expect(result, 'old text');
    });

    test('below minDepth does not apply', () async {
      final scripts = [
        RegexScript(
          findRegex: 'x',
          replaceString: 'y',
          affectsAiOutput: true,
          minDepth: 3,
          maxDepth: -1,
        ),
      ];

      final result = await RegexService.apply(
        text: 'x',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        messageDepth: 2,
      );
      expect(result, 'x');
    });

    test('maxDepth -1 means unlimited', () async {
      final scripts = [
        RegexScript(
          findRegex: 'a',
          replaceString: 'b',
          affectsAiOutput: true,
          minDepth: 0,
          maxDepth: -1,
        ),
      ];

      final result = await RegexService.apply(
        text: 'a',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        messageDepth: 9999,
      );
      expect(result, 'b');
    });

    test('exact boundary depths apply', () async {
      final scripts = [
        RegexScript(
          findRegex: 'x',
          replaceString: 'y',
          affectsAiOutput: true,
          minDepth: 2,
          maxDepth: 5,
        ),
      ];

      // At minDepth
      var result = await RegexService.apply(
        text: 'x',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        messageDepth: 2,
      );
      expect(result, 'y');

      // At maxDepth
      result = await RegexService.apply(
        text: 'x',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        messageDepth: 5,
      );
      expect(result, 'y');
    });
  });

  // ---------------------------------------------------------------------------
  // Ephemerality modes
  // ---------------------------------------------------------------------------
  group('Ephemerality modes', () {
    test('permanent mode selects only non-ephemeral scripts', () async {
      final scripts = [
        RegexScript(
          findRegex: 'a',
          replaceString: 'A',
          affectsAiOutput: true,
          displayOnly: false,
          promptOnly: false,
        ),
        RegexScript(
          findRegex: 'b',
          replaceString: 'B',
          affectsAiOutput: true,
          displayOnly: true,
        ),
        RegexScript(
          findRegex: 'c',
          replaceString: 'C',
          affectsAiOutput: true,
          promptOnly: true,
        ),
      ];

      final result = await RegexService.applyPermanent(
        text: 'abc',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      // Only 'a' → 'A' should apply
      expect(result, 'Abc');
    });

    test('displayOnly mode selects only display-only scripts', () async {
      final scripts = [
        RegexScript(
          findRegex: 'a',
          replaceString: 'A',
          affectsAiOutput: true,
          displayOnly: false,
          promptOnly: false,
        ),
        RegexScript(
          findRegex: 'b',
          replaceString: 'B',
          affectsAiOutput: true,
          displayOnly: true,
        ),
        RegexScript(
          findRegex: 'c',
          replaceString: 'C',
          affectsAiOutput: true,
          promptOnly: true,
        ),
      ];

      final result = await RegexService.applyDisplayOnly(
        text: 'abc',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      // Only 'b' → 'B' should apply
      expect(result, 'aBc');
    });

    test('promptOnly mode selects only prompt-only scripts', () async {
      final scripts = [
        RegexScript(
          findRegex: 'a',
          replaceString: 'A',
          affectsAiOutput: true,
          displayOnly: false,
          promptOnly: false,
        ),
        RegexScript(
          findRegex: 'b',
          replaceString: 'B',
          affectsAiOutput: true,
          displayOnly: true,
        ),
        RegexScript(
          findRegex: 'c',
          replaceString: 'C',
          affectsAiOutput: true,
          promptOnly: true,
        ),
      ];

      final result = await RegexService.applyPromptOnly(
        text: 'abc',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      // Only 'c' → 'C' should apply
      expect(result, 'abC');
    });
  });

  // ---------------------------------------------------------------------------
  // Sort order
  // ---------------------------------------------------------------------------
  group('Sort order', () {
    test('scripts execute in sortOrder ascending', () async {
      final scripts = [
        RegexScript(
          findRegex: 'x',
          replaceString: 'y',
          affectsAiOutput: true,
          sortOrder: 2,
        ),
        RegexScript(
          findRegex: 'y',
          replaceString: 'z',
          affectsAiOutput: true,
          sortOrder: 1,
        ),
      ];

      // sortOrder 1 runs first: 'x' stays 'x' (no match for 'y' → 'z').
      // sortOrder 2 runs second: 'x' → 'y'.
      // Result: 'y'
      final result = await RegexService.apply(
        text: 'x',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'y');
    });

    test('chained scripts: earlier output feeds later input', () async {
      final scripts = [
        RegexScript(
          findRegex: 'cat',
          replaceString: 'dog',
          affectsAiOutput: true,
          sortOrder: 0,
        ),
        RegexScript(
          findRegex: 'dog',
          replaceString: 'fish',
          affectsAiOutput: true,
          sortOrder: 1,
        ),
      ];

      // cat → dog → fish
      final result = await RegexService.apply(
        text: 'I have a cat',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'I have a fish');
    });
  });

  // ---------------------------------------------------------------------------
  // Trim strings
  // ---------------------------------------------------------------------------
  group('Trim strings', () {
    test('trim strings are removed before regex matching', () async {
      final scripts = [
        RegexScript(
          findRegex: 'HelloWorld',
          replaceString: 'MATCHED',
          affectsAiOutput: true,
          trimStrings: [' '],
        ),
      ];

      // Spaces removed → "HelloWorld" matches.
      final result = await RegexService.apply(
        text: 'Hello World',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'MATCHED');
    });

    test('multiple trim strings all removed', () async {
      final scripts = [
        RegexScript(
          findRegex: 'ac',
          replaceString: 'MATCHED',
          affectsAiOutput: true,
          trimStrings: ['b', '-'],
        ),
      ];

      // 'a-b-c' → remove 'b' → 'a--c' → remove '-' → 'ac' → matches
      final result = await RegexService.apply(
        text: 'a-b-c',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'MATCHED');
    });

    test('empty trim strings are ignored', () async {
      final scripts = [
        RegexScript(
          findRegex: 'hello',
          replaceString: 'HI',
          affectsAiOutput: true,
          trimStrings: ['', ''],
        ),
      ];

      final result = await RegexService.apply(
        text: 'hello',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'HI');
    });
  });

  // ---------------------------------------------------------------------------
  // Regex flags
  // ---------------------------------------------------------------------------
  group('Regex flags', () {
    test('case-insensitive matching', () async {
      final scripts = [
        RegexScript(
          findRegex: 'hello',
          replaceString: 'HI',
          affectsAiOutput: true,
          caseInsensitive: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'HELLO World',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'HI World');
    });

    test('case-sensitive matching (default)', () async {
      final scripts = [
        RegexScript(
          findRegex: 'hello',
          replaceString: 'HI',
          affectsAiOutput: true,
          caseInsensitive: false,
        ),
      ];

      final result = await RegexService.apply(
        text: 'HELLO World',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      // Should NOT match because case doesn't match.
      expect(result, 'HELLO World');
    });

    test('dotAll flag makes . match newlines', () async {
      final scripts = [
        RegexScript(
          findRegex: 'start(.*)end',
          replaceString: 'REPLACED',
          affectsAiOutput: true,
          dotAll: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'start\nmiddle\nend',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'REPLACED');
    });

    test('without dotAll, . does not match newlines', () async {
      final scripts = [
        RegexScript(
          findRegex: 'start(.*)end',
          replaceString: 'REPLACED',
          affectsAiOutput: true,
          dotAll: false,
        ),
      ];

      final result = await RegexService.apply(
        text: 'start\nmiddle\nend',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      // Should NOT match since . doesn't cross newlines.
      expect(result, 'start\nmiddle\nend');
    });

    test('multiLine flag makes ^ and \$ match line boundaries', () async {
      final scripts = [
        RegexScript(
          findRegex: r'^line',
          replaceString: 'LINE',
          affectsAiOutput: true,
          multiLine: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'line one\nline two',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'LINE one\nLINE two');
    });
  });

  // ---------------------------------------------------------------------------
  // Invalid regex
  // ---------------------------------------------------------------------------
  group('Invalid regex handling', () {
    test('invalid regex pattern returns original text', () async {
      final scripts = [
        RegexScript(
          findRegex: r'[invalid',
          replaceString: 'X',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'some text',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'some text');
    });

    test('invalid regex does not block subsequent scripts', () async {
      final scripts = [
        RegexScript(
          findRegex: r'[bad',
          replaceString: 'X',
          affectsAiOutput: true,
          sortOrder: 0,
        ),
        RegexScript(
          findRegex: 'good',
          replaceString: 'GREAT',
          affectsAiOutput: true,
          sortOrder: 1,
        ),
      ];

      final result = await RegexService.apply(
        text: 'good text',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'GREAT text');
    });
  });

  // ---------------------------------------------------------------------------
  // Macro resolution in replacement strings
  // ---------------------------------------------------------------------------
  group('Macro resolution', () {
    test('macroMode none does not resolve macros', () async {
      final scripts = [
        RegexScript(
          findRegex: 'NAME',
          replaceString: '{{char}}',
          affectsAiOutput: true,
          macroMode: RegexMacroMode.none,
        ),
      ];

      final result = await RegexService.apply(
        text: 'Hello NAME',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        macroContext: const MacroContext(char: 'Alice'),
      );
      // Should NOT resolve the macro.
      expect(result, 'Hello {{char}}');
    });

    test('macroMode raw resolves macros in replacement', () async {
      final scripts = [
        RegexScript(
          findRegex: 'NAME',
          replaceString: '{{char}}',
          affectsAiOutput: true,
          macroMode: RegexMacroMode.raw,
        ),
      ];

      final result = await RegexService.apply(
        text: 'Hello NAME',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        macroContext: const MacroContext(char: 'Alice'),
      );
      expect(result, 'Hello Alice');
    });

    test('macroMode escaped resolves macros and escapes dollar signs',
        () async {
      final scripts = [
        RegexScript(
          findRegex: r'(\w+) PRICE',
          replaceString: r'{{char}} costs $1',
          affectsAiOutput: true,
          macroMode: RegexMacroMode.escaped,
        ),
      ];

      // In escaped mode, the resolved replacement has $ escaped as $$.
      // So '$1' becomes '$$1' which outputs literal '$1'.
      final result = await RegexService.apply(
        text: 'item PRICE',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        macroContext: const MacroContext(char: 'Alice'),
      );
      // The macro resolves {{char}} to 'Alice'.
      // Then escaping turns '$1' into '$$1' → literal '$1'.
      expect(result, r'Alice costs $1');
    });
  });

  // ---------------------------------------------------------------------------
  // Convenience wrappers
  // ---------------------------------------------------------------------------
  group('Convenience wrappers', () {
    test('applyPermanent selects permanent scripts', () async {
      final scripts = [
        RegexScript(
          findRegex: 'x',
          replaceString: 'X',
          affectsAiOutput: true,
        ),
        RegexScript(
          findRegex: 'y',
          replaceString: 'Y',
          affectsAiOutput: true,
          displayOnly: true,
        ),
      ];

      final result = await RegexService.applyPermanent(
        text: 'xy',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'Xy');
    });

    test('applyDisplayOnly selects display-only scripts', () async {
      final scripts = [
        RegexScript(
          findRegex: 'x',
          replaceString: 'X',
          affectsAiOutput: true,
        ),
        RegexScript(
          findRegex: 'y',
          replaceString: 'Y',
          affectsAiOutput: true,
          displayOnly: true,
        ),
      ];

      final result = await RegexService.applyDisplayOnly(
        text: 'xy',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'xY');
    });

    test('applyPromptOnly selects prompt-only scripts', () async {
      final scripts = [
        RegexScript(
          findRegex: 'x',
          replaceString: 'X',
          affectsAiOutput: true,
        ),
        RegexScript(
          findRegex: 'z',
          replaceString: 'Z',
          affectsAiOutput: true,
          promptOnly: true,
        ),
      ];

      final result = await RegexService.applyPromptOnly(
        text: 'xz',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'xZ');
    });
  });

  // ---------------------------------------------------------------------------
  // Combined filtering
  // ---------------------------------------------------------------------------
  group('Combined filtering', () {
    test('script must pass all filters to apply', () async {
      // This script targets userInput, depth 0-3, permanent mode.
      final scripts = [
        RegexScript(
          findRegex: 'x',
          replaceString: 'X',
          affectsUserInput: true,
          affectsAiOutput: false,
          minDepth: 0,
          maxDepth: 3,
          displayOnly: false,
          promptOnly: false,
        ),
      ];

      // Wrong target
      var result = await RegexService.apply(
        text: 'x',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        messageDepth: 0,
        mode: RegexApplyMode.permanent,
      );
      expect(result, 'x');

      // Wrong depth
      result = await RegexService.apply(
        text: 'x',
        scripts: scripts,
        target: RegexTarget.userInput,
        messageDepth: 5,
        mode: RegexApplyMode.permanent,
      );
      expect(result, 'x');

      // Wrong mode
      result = await RegexService.apply(
        text: 'x',
        scripts: scripts,
        target: RegexTarget.userInput,
        messageDepth: 0,
        mode: RegexApplyMode.displayOnly,
      );
      expect(result, 'x');

      // All correct
      result = await RegexService.apply(
        text: 'x',
        scripts: scripts,
        target: RegexTarget.userInput,
        messageDepth: 2,
        mode: RegexApplyMode.permanent,
      );
      expect(result, 'X');
    });

    test('multiple scripts, mixed eligibility', () async {
      final scripts = [
        // Eligible: permanent, aiOutput, depth 0-10
        RegexScript(
          findRegex: 'aaa',
          replaceString: 'AAA',
          affectsAiOutput: true,
          sortOrder: 0,
        ),
        // Not eligible: disabled
        RegexScript(
          findRegex: 'bbb',
          replaceString: 'BBB',
          enabled: false,
          affectsAiOutput: true,
          sortOrder: 1,
        ),
        // Not eligible: wrong target
        RegexScript(
          findRegex: 'ccc',
          replaceString: 'CCC',
          affectsUserInput: true,
          affectsAiOutput: false,
          sortOrder: 2,
        ),
        // Eligible: permanent, aiOutput, depth 0-unlimited
        RegexScript(
          findRegex: 'ddd',
          replaceString: 'DDD',
          affectsAiOutput: true,
          sortOrder: 3,
        ),
      ];

      final result = await RegexService.apply(
        text: 'aaa bbb ccc ddd',
        scripts: scripts,
        target: RegexTarget.aiOutput,
        messageDepth: 0,
      );
      // Only aaa → AAA and ddd → DDD should apply.
      expect(result, 'AAA bbb ccc DDD');
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------
  group('Edge cases', () {
    test('empty text returns empty', () async {
      final scripts = [
        RegexScript(
          findRegex: '.',
          replaceString: 'X',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: '',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, '');
    });

    test('no-match regex returns text unchanged', () async {
      final scripts = [
        RegexScript(
          findRegex: 'zzz',
          replaceString: 'aaa',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'hello world',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'hello world');
    });

    test('replacement with empty string removes matches', () async {
      final scripts = [
        RegexScript(
          findRegex: r'\(OOC:.*?\)',
          replaceString: '',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'Hello (OOC: testing) World',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'Hello  World');
    });

    test('regex special chars in find pattern work', () async {
      final scripts = [
        RegexScript(
          findRegex: r'\[bold\](.+?)\[/bold\]',
          replaceString: r'**$1**',
          affectsAiOutput: true,
        ),
      ];

      final result = await RegexService.apply(
        text: 'This is [bold]important[/bold] text',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      expect(result, 'This is **important** text');
    });

    test('back-reference beyond group count outputs empty', () async {
      final scripts = [
        RegexScript(
          findRegex: r'(\w+)',
          replaceString: r'$9',
          affectsAiOutput: true,
        ),
      ];

      // $9 is beyond groupCount (1), so should be literal '$9'.
      final result = await RegexService.apply(
        text: 'hello',
        scripts: scripts,
        target: RegexTarget.aiOutput,
      );
      // Since groupNum 9 > match.groupCount (1), it writes literal '$9'.
      expect(result, r'$9');
    });
  });

  // ---------------------------------------------------------------------------
  // Enum coverage
  // ---------------------------------------------------------------------------
  group('Enums', () {
    test('RegexTarget has four values', () {
      expect(RegexTarget.values.length, 4);
      expect(RegexTarget.values, contains(RegexTarget.userInput));
      expect(RegexTarget.values, contains(RegexTarget.aiOutput));
      expect(RegexTarget.values, contains(RegexTarget.worldInfo));
      expect(RegexTarget.values, contains(RegexTarget.reasoning));
    });

    test('RegexApplyMode has three values', () {
      expect(RegexApplyMode.values.length, 3);
      expect(RegexApplyMode.values, contains(RegexApplyMode.permanent));
      expect(RegexApplyMode.values, contains(RegexApplyMode.displayOnly));
      expect(RegexApplyMode.values, contains(RegexApplyMode.promptOnly));
    });
  });
}
