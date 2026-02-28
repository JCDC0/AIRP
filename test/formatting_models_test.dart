import 'package:flutter_test/flutter_test.dart';
import 'package:airp/models/formatting_models.dart';

void main() {
  group('FormattingTemplate', () {
    test('default constructor applies correct defaults', () {
      final template = FormattingTemplate();
      expect(template.name, '');
      expect(template.enabled, false);
      expect(template.description, '');
      expect(template.rules, isEmpty);
      expect(template.extensions, isEmpty);
    });

    test('fromJson round-trips through toJson', () {
      final json = {
        'name': 'Roleplay Style',
        'enabled': true,
        'description': 'Wraps dialogue and thoughts',
        'rules': [
          {
            'id': 1,
            'label': 'Dialogue',
            'type': 'dialogue',
            'pattern': r'"(.*?)"',
            'template': '**"{{match}}"**',
            'enabled': true,
            'sortOrder': 0,
          },
          {
            'id': 2,
            'label': 'Thought',
            'type': 'thought',
            'pattern': r'\*(.*?)\*',
            'template': '*{{match}}*',
            'enabled': false,
            'sortOrder': 1,
          }
        ],
        'extensions': {'author': 'test'},
      };

      final template = FormattingTemplate.fromJson(json);
      expect(template.name, 'Roleplay Style');
      expect(template.enabled, true);
      expect(template.description, 'Wraps dialogue and thoughts');
      expect(template.rules.length, 2);
      expect(template.rules[0].label, 'Dialogue');
      expect(template.rules[0].type, FormattingRuleType.dialogue);
      expect(template.rules[1].enabled, false);
      expect(template.extensions['author'], 'test');

      final out = template.toJson();
      expect(out['name'], 'Roleplay Style');
      expect(out['enabled'], true);
      expect((out['rules'] as List).length, 2);
      expect(out['extensions']['author'], 'test');
    });

    test('copyWith creates independent copy', () {
      final template = FormattingTemplate(
        name: 'Original',
        rules: [FormattingRule(id: 1, label: 'r1')],
      );
      final copy = template.copyWith(name: 'Copy');
      expect(copy.name, 'Copy');
      expect(copy.rules.length, 1);
      copy.rules[0].label = 'modified';
      expect(template.rules[0].label, 'r1'); // unchanged
    });
  });

  group('FormattingRule', () {
    test('default constructor applies correct defaults', () {
      final rule = FormattingRule();
      expect(rule.id, 0);
      expect(rule.label, '');
      expect(rule.type, FormattingRuleType.custom);
      expect(rule.pattern, '');
      expect(rule.template, '{{match}}');
      expect(rule.enabled, true);
      expect(rule.sortOrder, 0);
    });

    test('fromJson parses all fields', () {
      final json = {
        'id': 3,
        'label': 'Character Name',
        'type': 'characterName',
        'pattern': r'^(\w+):',
        'template': '**{{match}}:**',
        'enabled': true,
        'sortOrder': 5,
      };

      final rule = FormattingRule.fromJson(json);
      expect(rule.id, 3);
      expect(rule.label, 'Character Name');
      expect(rule.type, FormattingRuleType.characterName);
      expect(rule.pattern, r'^(\w+):');
      expect(rule.template, '**{{match}}:**');
      expect(rule.enabled, true);
      expect(rule.sortOrder, 5);
    });

    test('toJson produces correct output', () {
      final rule = FormattingRule(
        id: 10,
        label: 'Narration',
        type: FormattingRuleType.narration,
        pattern: r'(?<=\n)(?!["\*])(.+)',
        template: '_{{match}}_',
        enabled: true,
        sortOrder: 2,
      );

      final json = rule.toJson();
      expect(json['id'], 10);
      expect(json['label'], 'Narration');
      expect(json['type'], 'narration');
      expect(json['template'], '_{{match}}_');
      expect(json['sortOrder'], 2);
    });

    test('all rule types round-trip through name', () {
      for (final type in FormattingRuleType.values) {
        final rule = FormattingRule(type: type);
        final json = rule.toJson();
        final restored = FormattingRule.fromJson(json);
        expect(restored.type, type,
            reason: 'Type $type failed round-trip');
      }
    });

    test('unknown type falls back to custom', () {
      final json = {
        'type': 'nonexistent_type',
        'pattern': 'x',
      };
      final rule = FormattingRule.fromJson(json);
      expect(rule.type, FormattingRuleType.custom);
    });

    test('copyWith preserves all fields', () {
      final rule = FormattingRule(
        id: 7,
        label: 'orig',
        type: FormattingRuleType.thought,
        pattern: 'pat',
        template: 'tpl',
        enabled: false,
        sortOrder: 99,
      );
      final copy = rule.copyWith(label: 'changed');
      expect(copy.label, 'changed');
      expect(copy.id, 7);
      expect(copy.type, FormattingRuleType.thought);
      expect(copy.pattern, 'pat');
      expect(copy.template, 'tpl');
      expect(copy.enabled, false);
      expect(copy.sortOrder, 99);
    });
  });
}
