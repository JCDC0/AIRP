import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/services/macro_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MacroService.resetVariables();
  });

  // ---------------------------------------------------------------------------
  // Core identity macros
  // ---------------------------------------------------------------------------
  group('Core identity macros', () {
    test('{{char}} resolves to character name', () async {
      final result = await MacroService.resolve(
        'Hello, my name is {{char}}.',
        context: const MacroContext(char: 'Aria'),
      );
      expect(result, 'Hello, my name is Aria.');
    });

    test('{{user}} resolves to user name', () async {
      final result = await MacroService.resolve(
        '{{user}} enters the room.',
        context: const MacroContext(user: 'John'),
      );
      expect(result, 'John enters the room.');
    });

    test('{{user}} defaults to User when not provided', () async {
      final result = await MacroService.resolve('Hi {{user}}!');
      expect(result, 'Hi User!');
    });

    test('{{description}} and {{persona}} are aliases', () async {
      const ctx = MacroContext(description: 'A brave knight');
      final r1 = await MacroService.resolve('{{description}}', context: ctx);
      final r2 = await MacroService.resolve('{{persona}}', context: ctx);
      expect(r1, 'A brave knight');
      expect(r2, 'A brave knight');
    });

    test('{{personality}} resolves', () async {
      final result = await MacroService.resolve(
        '{{personality}}',
        context: const MacroContext(personality: 'Bold and cheerful'),
      );
      expect(result, 'Bold and cheerful');
    });

    test('{{scenario}} resolves', () async {
      final result = await MacroService.resolve(
        '{{scenario}}',
        context: const MacroContext(scenario: 'A medieval tavern'),
      );
      expect(result, 'A medieval tavern');
    });

    test('{{mesExamples}} resolves', () async {
      final result = await MacroService.resolve(
        '{{mesExamples}}',
        context: const MacroContext(mesExamples: '<START>\nHello!'),
      );
      expect(result, '<START>\nHello!');
    });

    test('{{model}} resolves', () async {
      final result = await MacroService.resolve(
        '{{model}}',
        context: const MacroContext(model: 'gpt-4o'),
      );
      expect(result, 'gpt-4o');
    });

    test('{{lastMessageId}} resolves to integer string', () async {
      final result = await MacroService.resolve(
        '{{lastMessageId}}',
        context: const MacroContext(lastMessageId: 42),
      );
      expect(result, '42');
    });

    test('{{lastMessage}} and {{input}} are aliases', () async {
      const ctx = MacroContext(lastMessage: 'Hey there');
      final r1 = await MacroService.resolve('{{lastMessage}}', context: ctx);
      final r2 = await MacroService.resolve('{{input}}', context: ctx);
      expect(r1, 'Hey there');
      expect(r2, 'Hey there');
    });
  });

  // ---------------------------------------------------------------------------
  // Legacy aliases
  // ---------------------------------------------------------------------------
  group('Legacy aliases', () {
    test('<USER> normalizes to {{user}}', () async {
      final result = await MacroService.resolve(
        '<USER> said hello.',
        context: const MacroContext(user: 'Alice'),
      );
      expect(result, 'Alice said hello.');
    });

    test('<BOT> normalizes to {{char}}', () async {
      final result = await MacroService.resolve(
        '<BOT> responds.',
        context: const MacroContext(char: 'Miku'),
      );
      expect(result, 'Miku responds.');
    });

    test('legacy aliases are case-insensitive', () async {
      final result = await MacroService.resolve(
        '<user> and <bot>',
        context: const MacroContext(char: 'C', user: 'U'),
      );
      expect(result, 'U and C');
    });
  });

  // ---------------------------------------------------------------------------
  // Time / date macros
  // ---------------------------------------------------------------------------
  group('Time / date macros', () {
    test('{{time}} returns a non-empty string', () async {
      final result = await MacroService.resolve('{{time}}');
      expect(result.isNotEmpty, true);
    });

    test('{{date}} returns a non-empty string', () async {
      final result = await MacroService.resolve('{{date}}');
      expect(result.isNotEmpty, true);
    });

    test('{{weekday}} returns a full day name', () async {
      final result = await MacroService.resolve('{{weekday}}');
      const days = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ];
      expect(days.contains(result), true);
    });

    test('{{isodate}} returns yyyy-MM-dd format', () async {
      final result = await MacroService.resolve('{{isodate}}');
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(result), true);
    });

    test('{{isotime}} returns a time string', () async {
      final result = await MacroService.resolve('{{isotime}}');
      expect(result.isNotEmpty, true);
    });

    test('{{datetimeformat::yyyy}} returns current year', () async {
      final result = await MacroService.resolve('{{datetimeformat::yyyy}}');
      final year = DateTime.now().year.toString();
      expect(result, year);
    });

    test('{{datetimeformat}} without format returns ISO string', () async {
      final result = await MacroService.resolve('{{datetimeformat}}');
      expect(result.isNotEmpty, true);
    });
  });

  // ---------------------------------------------------------------------------
  // Random / dice macros
  // ---------------------------------------------------------------------------
  group('Random / dice macros', () {
    test('{{random::1::10}} returns integer in range', () async {
      for (int i = 0; i < 20; i++) {
        final result = await MacroService.resolve('{{random::1::10}}');
        final val = int.parse(result);
        expect(val, inInclusiveRange(1, 10));
      }
    });

    test('{{random::5::5}} always returns 5', () async {
      final result = await MacroService.resolve('{{random::5::5}}');
      expect(result, '5');
    });

    test('{{random}} with too few args returns 0', () async {
      final result = await MacroService.resolve('{{random::5}}');
      expect(result, '0');
    });

    test('{{roll::2d6}} returns value in [2, 12]', () async {
      for (int i = 0; i < 20; i++) {
        final result = await MacroService.resolve('{{roll::2d6}}');
        final val = int.parse(result);
        expect(val, inInclusiveRange(2, 12));
      }
    });

    test('{{roll::1d1}} always returns 1', () async {
      final result = await MacroService.resolve('{{roll::1d1}}');
      expect(result, '1');
    });

    test('{{roll}} with no dice spec returns 0', () async {
      final result = await MacroService.resolve('{{roll}}');
      expect(result, '0');
    });

    test('{{pick::a::b::c}} returns one of the options', () async {
      for (int i = 0; i < 20; i++) {
        final result = await MacroService.resolve('{{pick::a::b::c}}');
        expect(['a', 'b', 'c'].contains(result), true);
      }
    });

    test('{{pick::only}} returns the only option', () async {
      final result = await MacroService.resolve('{{pick::only}}');
      expect(result, 'only');
    });
  });

  // ---------------------------------------------------------------------------
  // Variable macros
  // ---------------------------------------------------------------------------
  group('Variable macros', () {
    test('{{setvar::x::42}} stores, {{getvar::x}} retrieves', () async {
      await MacroService.resolve('{{setvar::x::42}}');
      final result = await MacroService.resolve('{{getvar::x}}');
      expect(result, '42');
    });

    test('{{getvar}} of unset variable returns empty', () async {
      final result = await MacroService.resolve('{{getvar::missing}}');
      expect(result, '');
    });

    test('{{addvar::counter::5}} increments', () async {
      await MacroService.resolve('{{setvar::counter::10}}');
      final result = await MacroService.resolve('{{addvar::counter::5}}');
      expect(result, '15');
    });

    test('{{incvar}} is alias for {{addvar}}', () async {
      await MacroService.resolve('{{setvar::n::0}}');
      final result = await MacroService.resolve('{{incvar::n::3}}');
      expect(result, '3');
    });

    test('{{subvar::counter::3}} decrements', () async {
      await MacroService.resolve('{{setvar::counter::10}}');
      final result = await MacroService.resolve('{{subvar::counter::3}}');
      expect(result, '7');
    });

    test('{{decvar}} is alias for {{subvar}}', () async {
      await MacroService.resolve('{{setvar::n::10}}');
      final result = await MacroService.resolve('{{decvar::n::4}}');
      expect(result, '6');
    });

    test('setvar with :: in value preserves the colons', () async {
      await MacroService.resolve('{{setvar::url::https://example.com}}');
      final result = await MacroService.resolve('{{getvar::url}}');
      expect(result, 'https://example.com');
    });

    test('variables persist to SharedPreferences', () async {
      await MacroService.resolve('{{setvar::persist_test::hello}}');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('airp_macro_var_persist_test'), 'hello');
    });

    test('variables load from SharedPreferences on init', () async {
      SharedPreferences.setMockInitialValues({
        'airp_macro_var_preloaded': 'world',
      });
      MacroService.resetVariables();
      final result = await MacroService.resolve('{{getvar::preloaded}}');
      expect(result, 'world');
    });
  });

  // ---------------------------------------------------------------------------
  // Utility macros
  // ---------------------------------------------------------------------------
  group('Utility macros', () {
    test('{{newline}} inserts line break', () async {
      final result = await MacroService.resolve('line1{{newline}}line2');
      expect(result, 'line1\nline2');
    });

    test('{{trim}} trims the final output', () async {
      final result = await MacroService.resolve('  hello  {{trim}}');
      expect(result, 'hello');
    });

    test('trimResult parameter works', () async {
      final result = await MacroService.resolve(
        '  padded  ',
        trimResult: true,
      );
      expect(result, 'padded');
    });
  });

  // ---------------------------------------------------------------------------
  // Conditionals
  // ---------------------------------------------------------------------------
  group('Conditionals', () {
    test('{{ifeq::a::a::yes}} returns yes', () async {
      final result = await MacroService.resolve('{{ifeq::a::a::yes}}');
      expect(result, 'yes');
    });

    test('{{ifeq::a::b::yes}} returns empty', () async {
      final result = await MacroService.resolve('{{ifeq::a::b::yes}}');
      expect(result, '');
    });

    test('{{ifeq::a::b::yes::no}} returns no', () async {
      final result = await MacroService.resolve('{{ifeq::a::b::yes::no}}');
      expect(result, 'no');
    });

    test('{{ifneq::a::b::different}} returns different', () async {
      final result = await MacroService.resolve('{{ifneq::a::b::different}}');
      expect(result, 'different');
    });

    test('{{ifneq::a::a::yes::no}} returns no', () async {
      final result = await MacroService.resolve('{{ifneq::a::a::yes::no}}');
      expect(result, 'no');
    });
  });

  // ---------------------------------------------------------------------------
  // Multiple macros in one string
  // ---------------------------------------------------------------------------
  group('Multiple macros', () {
    test('multiple macros resolve in single pass', () async {
      final result = await MacroService.resolve(
        '{{char}} greets {{user}} in {{scenario}}.',
        context: const MacroContext(
          char: 'Aria',
          user: 'John',
          scenario: 'the tavern',
        ),
      );
      expect(result, 'Aria greets John in the tavern.');
    });

    test('unrecognised macros are left as-is', () async {
      final result = await MacroService.resolve('{{unknown_macro}}');
      expect(result, '{{unknown_macro}}');
    });
  });

  // ---------------------------------------------------------------------------
  // Recursive resolution
  // ---------------------------------------------------------------------------
  group('Recursive resolution', () {
    test('legacy alias resolves to macro which then resolves', () async {
      // <BOT> → {{char}} → "Miku" in two passes.
      final result = await MacroService.resolve(
        'Hello <BOT>!',
        context: const MacroContext(char: 'Miku'),
      );
      expect(result, 'Hello Miku!');
    });

    test('variable containing plain text resolves in one pass', () async {
      await MacroService.resolve('{{setvar::greeting::Hello world!}}');
      final result = await MacroService.resolve('{{getvar::greeting}}');
      expect(result, 'Hello world!');
    });

    test('recursion terminates even with unresolvable macros', () async {
      // An unrecognised macro stays as-is and stops changing → loop exits.
      final result = await MacroService.resolve('{{totally_bogus}}');
      expect(result, '{{totally_bogus}}');
    });
  });

  // ---------------------------------------------------------------------------
  // Extras override
  // ---------------------------------------------------------------------------
  group('Extras override', () {
    test('extras shadow built-in macros', () async {
      final result = await MacroService.resolve(
        '{{char}}',
        context: const MacroContext(
          char: 'Original',
          extras: {'char': 'Overridden'},
        ),
      );
      expect(result, 'Overridden');
    });
  });

  // ---------------------------------------------------------------------------
  // Empty / edge cases
  // ---------------------------------------------------------------------------
  group('Edge cases', () {
    test('empty input returns empty', () async {
      final result = await MacroService.resolve('');
      expect(result, '');
    });

    test('no macros returns input unchanged', () async {
      final result = await MacroService.resolve('Just plain text.');
      expect(result, 'Just plain text.');
    });

    test('macro names are case-insensitive', () async {
      final result = await MacroService.resolve(
        '{{CHAR}} {{User}} {{Personality}}',
        context: const MacroContext(
          char: 'A',
          user: 'B',
          personality: 'C',
        ),
      );
      expect(result, 'A B C');
    });

    test('variables snapshot is read-only', () {
      final vars = MacroService.variables;
      expect(() => (vars as Map)['test'] = 'x', throwsA(anything));
    });
  });
}
