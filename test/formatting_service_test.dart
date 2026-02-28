import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/models/formatting_models.dart';
import 'package:airp/services/formatting_service.dart';
import 'package:airp/services/macro_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MacroService.resetVariables();
  });

  // ---------------------------------------------------------------------------
  // applyTemplate — basic behaviour
  // ---------------------------------------------------------------------------
  group('applyTemplate basics', () {
    test('returns text unchanged when template is null', () async {
      final result = await FormattingService.applyTemplate(
        'Hello world',
        template: null,
      );
      expect(result, 'Hello world');
    });

    test('returns text unchanged when template is disabled', () async {
      final template = FormattingTemplate(
        name: 'Disabled',
        enabled: false,
        rules: [
          FormattingRule(
            pattern: 'Hello',
            template: 'REPLACED',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'Hello world',
        template: template,
      );
      expect(result, 'Hello world');
    });

    test('returns text unchanged when all rules are disabled', () async {
      final template = FormattingTemplate(
        name: 'No active rules',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: 'Hello',
            template: 'REPLACED',
            enabled: false,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'Hello world',
        template: template,
      );
      expect(result, 'Hello world');
    });

    test('returns empty string unchanged', () async {
      final template = FormattingTemplate(
        name: 'Active',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: '.',
            template: 'X',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        '',
        template: template,
      );
      expect(result, '');
    });

    test('applies a simple rule', () async {
      final template = FormattingTemplate(
        name: 'Simple',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: 'world',
            template: 'WORLD',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'Hello world',
        template: template,
      );
      expect(result, 'Hello WORLD');
    });
  });

  // ---------------------------------------------------------------------------
  // {{match}} placeholder
  // ---------------------------------------------------------------------------
  group('{{match}} placeholder', () {
    test('{{match}} is replaced with group 1 content', () async {
      final template = FormattingTemplate(
        name: 'Match',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'"([^"]*)"',
            template: '<q>{{match}}</q>',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'She said "hello" to him.',
        template: template,
      );
      expect(result, 'She said <q>hello</q> to him.');
    });

    test('{{match}} falls back to group 0 when no capture group', () async {
      final template = FormattingTemplate(
        name: 'NoGroup',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'\d+',
            template: '[{{match}}]',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'Count: 42 items',
        template: template,
      );
      expect(result, 'Count: [42] items');
    });

    test('multiple matches are all replaced', () async {
      final template = FormattingTemplate(
        name: 'Multi',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'"([^"]*)"',
            template: '<em>{{match}}</em>',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        '"one" and "two"',
        template: template,
      );
      expect(result, '<em>one</em> and <em>two</em>');
    });
  });

  // ---------------------------------------------------------------------------
  // Macro resolution in templates
  // ---------------------------------------------------------------------------
  group('Macro resolution', () {
    test('{{char}} in template is resolved', () async {
      final template = FormattingTemplate(
        name: 'Macro',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'"([^"]*)"',
            template: '{{char}} says: "{{match}}"',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        '"hello"',
        template: template,
        macroContext: const MacroContext(char: 'Alice'),
      );
      expect(result, 'Alice says: "hello"');
    });

    test('{{user}} in template is resolved', () async {
      final template = FormattingTemplate(
        name: 'UserMacro',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'\*([^*]+)\*',
            template: '{{user}} thinks: {{match}}',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        '*something deep*',
        template: template,
        macroContext: const MacroContext(user: 'Bob'),
      );
      expect(result, 'Bob thinks: something deep');
    });

    test('template with no macros passes through literally', () async {
      final template = FormattingTemplate(
        name: 'Literal',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: 'x',
            template: 'X',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'x marks the spot',
        template: template,
      );
      expect(result, 'X marks the spot');
    });
  });

  // ---------------------------------------------------------------------------
  // Sort order
  // ---------------------------------------------------------------------------
  group('Sort order', () {
    test('rules apply in sortOrder ascending', () async {
      final template = FormattingTemplate(
        name: 'Sorted',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: 'a',
            template: 'b',
            enabled: true,
            sortOrder: 2,
          ),
          FormattingRule(
            pattern: 'b',
            template: 'c',
            enabled: true,
            sortOrder: 1,
          ),
        ],
      );

      // sortOrder 1 runs first: 'a' unchanged, no 'b' yet. Wait — text is
      // 'a'. Rule with sortOrder 1 looks for 'b' → no match. Then rule with
      // sortOrder 2 looks for 'a' → replaces with 'b'. Result: 'b'.
      final result = await FormattingService.applyTemplate(
        'a',
        template: template,
      );
      expect(result, 'b');
    });

    test('chained rules: earlier output feeds later input', () async {
      final template = FormattingTemplate(
        name: 'Chain',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: 'cat',
            template: 'dog',
            enabled: true,
            sortOrder: 0,
          ),
          FormattingRule(
            pattern: 'dog',
            template: 'fish',
            enabled: true,
            sortOrder: 1,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'I have a cat',
        template: template,
      );
      expect(result, 'I have a fish');
    });
  });

  // ---------------------------------------------------------------------------
  // Disabled rules
  // ---------------------------------------------------------------------------
  group('Disabled rules', () {
    test('disabled rules are skipped', () async {
      final template = FormattingTemplate(
        name: 'Mixed',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: 'a',
            template: 'A',
            enabled: false,
            sortOrder: 0,
          ),
          FormattingRule(
            pattern: 'b',
            template: 'B',
            enabled: true,
            sortOrder: 1,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'ab',
        template: template,
      );
      expect(result, 'aB');
    });
  });

  // ---------------------------------------------------------------------------
  // Invalid regex
  // ---------------------------------------------------------------------------
  group('Invalid regex', () {
    test('invalid pattern skips the rule silently', () async {
      final template = FormattingTemplate(
        name: 'Bad',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'[invalid',
            template: 'X',
            enabled: true,
            sortOrder: 0,
          ),
          FormattingRule(
            pattern: 'good',
            template: 'GOOD',
            enabled: true,
            sortOrder: 1,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'some good text',
        template: template,
      );
      expect(result, 'some GOOD text');
    });

    test('empty pattern skips the rule', () async {
      final template = FormattingTemplate(
        name: 'Empty',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: '',
            template: 'REPLACED',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'original',
        template: template,
      );
      expect(result, 'original');
    });
  });

  // ---------------------------------------------------------------------------
  // applySingleRule
  // ---------------------------------------------------------------------------
  group('applySingleRule', () {
    test('applies a single rule', () async {
      final rule = FormattingRule(
        pattern: r'"([^"]*)"',
        template: '<b>{{match}}</b>',
        enabled: true,
      );

      final result = await FormattingService.applySingleRule(
        'She said "wow" to him.',
        rule,
      );
      expect(result, 'She said <b>wow</b> to him.');
    });

    test('disabled rule returns text unchanged', () async {
      final rule = FormattingRule(
        pattern: 'a',
        template: 'A',
        enabled: false,
      );

      final result = await FormattingService.applySingleRule('abc', rule);
      expect(result, 'abc');
    });

    test('empty text returns empty', () async {
      final rule = FormattingRule(
        pattern: '.',
        template: 'X',
        enabled: true,
      );

      final result = await FormattingService.applySingleRule('', rule);
      expect(result, '');
    });
  });

  // ---------------------------------------------------------------------------
  // defaultTemplate
  // ---------------------------------------------------------------------------
  group('defaultTemplate', () {
    test('returns a template with expected structure', () {
      final dt = FormattingService.defaultTemplate();
      expect(dt.name, 'Default');
      expect(dt.enabled, false);
      expect(dt.rules.length, 4);
    });

    test('default template has dialogue rule', () {
      final dt = FormattingService.defaultTemplate();
      final dialogue = dt.rules.firstWhere(
        (r) => r.type == FormattingRuleType.dialogue,
      );
      expect(dialogue.label, 'Dialogue');
      expect(dialogue.sortOrder, 0);
    });

    test('default template has thought rule', () {
      final dt = FormattingService.defaultTemplate();
      final thought = dt.rules.firstWhere(
        (r) => r.type == FormattingRuleType.thought,
      );
      expect(thought.label, 'Thought / Action');
      expect(thought.sortOrder, 1);
    });

    test('default template has character name rule', () {
      final dt = FormattingService.defaultTemplate();
      final charName = dt.rules.firstWhere(
        (r) => r.type == FormattingRuleType.characterName,
      );
      expect(charName.label, 'Character Name');
      expect(charName.sortOrder, 2);
    });

    test('default template has narration rule', () {
      final dt = FormattingService.defaultTemplate();
      final narration = dt.rules.firstWhere(
        (r) => r.type == FormattingRuleType.narration,
      );
      expect(narration.label, 'Narration');
      expect(narration.sortOrder, 3);
    });

    test('default dialogue rule wraps quoted text', () async {
      final dt = FormattingService.defaultTemplate();
      dt.enabled = true;
      // Only enable dialogue rule.
      for (final r in dt.rules) {
        r.enabled = r.type == FormattingRuleType.dialogue;
      }

      final result = await FormattingService.applyTemplate(
        'She said "hello" to him.',
        template: dt,
      );
      // The default dialogue template is '"{{match}}"', which wraps the
      // captured content back in quotes — i.e. no visible change by default.
      expect(result, 'She said "hello" to him.');
    });

    test('default thought rule wraps asterisk text', () async {
      final dt = FormattingService.defaultTemplate();
      dt.enabled = true;
      for (final r in dt.rules) {
        r.enabled = r.type == FormattingRuleType.thought;
      }

      final result = await FormattingService.applyTemplate(
        '*thinking deeply*',
        template: dt,
      );
      // Default template is '*{{match}}*' — pass-through.
      expect(result, '*thinking deeply*');
    });

    test('default character name rule with char macro', () async {
      final dt = FormattingService.defaultTemplate();
      dt.enabled = true;
      for (final r in dt.rules) {
        r.enabled = r.type == FormattingRuleType.characterName;
      }

      // The pattern is '^({{char}}):' which needs macro resolution in
      // the pattern itself. Since FormattingService resolves macros in the
      // template but not the pattern, we test with the literal '{{char}}'.
      // The pattern matches at start of line.
      final result = await FormattingService.applyTemplate(
        '{{char}}: Hello there!',
        template: dt,
        macroContext: const MacroContext(char: 'Alice'),
      );
      // The pattern '^({{char}}):' matches '{{char}}:' literally.
      // Group 1 = '{{char}}', template = '**{{match}}**:'.
      // {{match}} → '{{char}}' (the captured text).
      expect(result, '**{{char}}**: Hello there!');
    });
  });

  // ---------------------------------------------------------------------------
  // Roleplay formatting integration
  // ---------------------------------------------------------------------------
  group('Roleplay formatting', () {
    test('dialogue wrapping with custom template', () async {
      final template = FormattingTemplate(
        name: 'RP',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'"([^"]*)"',
            template: '<span class="dialogue">"{{match}}"</span>',
            enabled: true,
            sortOrder: 0,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        '"I am here," she whispered.',
        template: template,
      );
      expect(result,
          '<span class="dialogue">"I am here,"</span> she whispered.');
    });

    test('thought wrapping with italics', () async {
      final template = FormattingTemplate(
        name: 'RP',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'\*([^*]+)\*',
            template: '_{{match}}_',
            enabled: true,
            sortOrder: 0,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        '*she sighed softly*',
        template: template,
      );
      expect(result, '_she sighed softly_');
    });

    test('mixed dialogue and action in one text', () async {
      final template = FormattingTemplate(
        name: 'Mixed',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'"([^"]*)"',
            template: '<q>{{match}}</q>',
            enabled: true,
            sortOrder: 0,
          ),
          FormattingRule(
            pattern: r'\*([^*]+)\*',
            template: '<em>{{match}}</em>',
            enabled: true,
            sortOrder: 1,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        '"Hello!" *she waved*',
        template: template,
      );
      expect(result, '<q>Hello!</q> <em>she waved</em>');
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------
  group('Edge cases', () {
    test('rule with no match returns text unchanged', () async {
      final template = FormattingTemplate(
        name: 'NoMatch',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: 'zzz',
            template: 'ZZZ',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'no match here',
        template: template,
      );
      expect(result, 'no match here');
    });

    test('template without {{match}} replaces entirely', () async {
      final template = FormattingTemplate(
        name: 'Replace',
        enabled: true,
        rules: [
          FormattingRule(
            pattern: r'\d+',
            template: 'NUM',
            enabled: true,
          ),
        ],
      );

      final result = await FormattingService.applyTemplate(
        'Value: 42',
        template: template,
      );
      expect(result, 'Value: NUM');
    });

    test('empty rules list returns text unchanged', () async {
      final template = FormattingTemplate(
        name: 'Empty',
        enabled: true,
        rules: [],
      );

      final result = await FormattingService.applyTemplate(
        'unchanged',
        template: template,
      );
      expect(result, 'unchanged');
    });
  });
}
