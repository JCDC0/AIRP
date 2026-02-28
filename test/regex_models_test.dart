import 'package:flutter_test/flutter_test.dart';
import 'package:airp/models/regex_models.dart';

void main() {
  group('RegexScript', () {
    test('default constructor applies correct defaults', () {
      final script = RegexScript();
      expect(script.id, 0);
      expect(script.scriptName, '');
      expect(script.findRegex, '');
      expect(script.replaceString, '');
      expect(script.trimStrings, isEmpty);
      expect(script.enabled, true);
      expect(script.scope, RegexScope.scoped);
      expect(script.affectsUserInput, false);
      expect(script.affectsAiOutput, true);
      expect(script.affectsWorldInfo, false);
      expect(script.affectsReasoning, false);
      expect(script.displayOnly, false);
      expect(script.promptOnly, false);
      expect(script.minDepth, 0);
      expect(script.maxDepth, -1);
      expect(script.caseInsensitive, false);
      expect(script.dotAll, false);
      expect(script.multiLine, false);
      expect(script.unicode, false);
      expect(script.macroMode, RegexMacroMode.none);
      expect(script.sortOrder, 0);
    });

    test('fromJson parses AIRP-native field names', () {
      final json = {
        'id': 5,
        'scriptName': 'Remove OOC',
        'findRegex': r'\(OOC:.*?\)',
        'replaceString': '',
        'trimStrings': ['trim1', 'trim2'],
        'enabled': true,
        'scope': 'global',
        'affectsUserInput': false,
        'affectsAiOutput': true,
        'affectsWorldInfo': false,
        'affectsReasoning': false,
        'markdownOnly': true,
        'promptOnly': false,
        'minDepth': 0,
        'maxDepth': 10,
        'caseInsensitive': true,
        'dotAll': true,
        'multiLine': false,
        'unicode': false,
        'substituteRegex': 1,
        'sortOrder': 5,
      };

      final script = RegexScript.fromJson(json);
      expect(script.id, 5);
      expect(script.scriptName, 'Remove OOC');
      expect(script.findRegex, r'\(OOC:.*?\)');
      expect(script.replaceString, '');
      expect(script.trimStrings, ['trim1', 'trim2']);
      expect(script.enabled, true);
      expect(script.scope, RegexScope.global);
      expect(script.affectsAiOutput, true);
      expect(script.displayOnly, true);
      expect(script.promptOnly, false);
      expect(script.minDepth, 0);
      expect(script.maxDepth, 10);
      expect(script.caseInsensitive, true);
      expect(script.dotAll, true);
      expect(script.macroMode, RegexMacroMode.raw);
      expect(script.sortOrder, 5);
    });

    test('fromJson handles ST placement array', () {
      final json = {
        'scriptName': 'ST Script',
        'findRegex': 'test',
        'replaceString': 'replaced',
        'placement': [0, 1, 3],
        'disabled': false,
      };

      final script = RegexScript.fromJson(json);
      expect(script.affectsUserInput, true);
      expect(script.affectsAiOutput, true);
      expect(script.affectsWorldInfo, false);
      expect(script.affectsReasoning, true);
      expect(script.enabled, true);
    });

    test('fromJson handles ST disabled flag (inverted)', () {
      final json = {
        'scriptName': 'Disabled Script',
        'findRegex': 'x',
        'replaceString': 'y',
        'disabled': true,
      };

      final script = RegexScript.fromJson(json);
      expect(script.enabled, false);
    });

    test('fromJson handles legacy trimStrings as comma-separated string', () {
      final json = {
        'scriptName': 'Legacy Trim',
        'findRegex': 'a',
        'replaceString': 'b',
        'trimStrings': 'foo, bar, baz',
      };

      final script = RegexScript.fromJson(json);
      expect(script.trimStrings, ['foo', 'bar', 'baz']);
    });

    test('toJson produces correct output', () {
      final script = RegexScript(
        id: 3,
        scriptName: 'Test Script',
        findRegex: r'(\w+)',
        replaceString: r'$1!',
        trimStrings: ['x'],
        enabled: true,
        scope: RegexScope.preset,
        affectsUserInput: true,
        affectsAiOutput: false,
        affectsWorldInfo: true,
        affectsReasoning: false,
        displayOnly: false,
        promptOnly: true,
        minDepth: 1,
        maxDepth: 5,
        caseInsensitive: true,
        dotAll: false,
        multiLine: true,
        unicode: true,
        macroMode: RegexMacroMode.escaped,
        sortOrder: 10,
      );

      final json = script.toJson();
      expect(json['id'], 3);
      expect(json['scriptName'], 'Test Script');
      expect(json['findRegex'], r'(\w+)');
      expect(json['replaceString'], r'$1!');
      expect(json['trimStrings'], ['x']);
      expect(json['enabled'], true);
      expect(json['scope'], 'preset');
      expect(json['placement'], [0, 2]); // user=0, worldInfo=2
      expect(json['markdownOnly'], false);
      expect(json['promptOnly'], true);
      expect(json['minDepth'], 1);
      expect(json['maxDepth'], 5);
      expect(json['caseInsensitive'], true);
      expect(json['dotAll'], false);
      expect(json['multiLine'], true);
      expect(json['unicode'], true);
      expect(json['substituteRegex'], 2); // escaped = 2
      expect(json['sortOrder'], 10);
    });

    test('serialization round-trip preserves all fields', () {
      final original = RegexScript(
        id: 99,
        scriptName: 'Round Trip',
        findRegex: r'hello\s+world',
        replaceString: 'hi earth',
        trimStrings: ['a', 'b'],
        enabled: false,
        scope: RegexScope.global,
        affectsUserInput: true,
        affectsAiOutput: true,
        affectsWorldInfo: true,
        affectsReasoning: true,
        displayOnly: true,
        promptOnly: false,
        minDepth: 2,
        maxDepth: 8,
        caseInsensitive: true,
        dotAll: true,
        multiLine: true,
        unicode: true,
        macroMode: RegexMacroMode.raw,
        sortOrder: 42,
      );

      final json = original.toJson();
      final restored = RegexScript.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.scriptName, original.scriptName);
      expect(restored.findRegex, original.findRegex);
      expect(restored.replaceString, original.replaceString);
      expect(restored.trimStrings, original.trimStrings);
      expect(restored.enabled, original.enabled);
      expect(restored.scope, original.scope);
      expect(restored.affectsUserInput, original.affectsUserInput);
      expect(restored.affectsAiOutput, original.affectsAiOutput);
      expect(restored.affectsWorldInfo, original.affectsWorldInfo);
      expect(restored.affectsReasoning, original.affectsReasoning);
      expect(restored.displayOnly, original.displayOnly);
      expect(restored.promptOnly, original.promptOnly);
      expect(restored.minDepth, original.minDepth);
      expect(restored.maxDepth, original.maxDepth);
      expect(restored.caseInsensitive, original.caseInsensitive);
      expect(restored.dotAll, original.dotAll);
      expect(restored.multiLine, original.multiLine);
      expect(restored.unicode, original.unicode);
      expect(restored.macroMode, original.macroMode);
      expect(restored.sortOrder, original.sortOrder);
    });

    test('copyWith creates independent copy', () {
      final original = RegexScript(
        id: 1,
        scriptName: 'orig',
        trimStrings: ['t1'],
      );
      final copy = original.copyWith(scriptName: 'copy');
      expect(copy.scriptName, 'copy');
      expect(copy.id, 1);
      copy.trimStrings.add('t2');
      expect(original.trimStrings, ['t1']); // original unchanged
    });

    test('all macro modes round-trip', () {
      for (final mode in RegexMacroMode.values) {
        final script = RegexScript(macroMode: mode);
        final json = script.toJson();
        final restored = RegexScript.fromJson(json);
        expect(restored.macroMode, mode,
            reason: 'MacroMode $mode failed round-trip');
      }
    });
  });
}
