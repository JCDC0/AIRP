import 'package:airp/models/formatting_models.dart';
import 'package:airp/services/macro_service.dart';

// ---------------------------------------------------------------------------
// FormattingService
// ---------------------------------------------------------------------------

/// Applies [FormattingTemplate] rules to AI output text for styled rendering.
///
/// ## How it works
///
/// 1. The caller provides a [FormattingTemplate] and the raw output text.
/// 2. Enabled rules are sorted by [FormattingRule.sortOrder] ascending.
/// 3. Each rule's [FormattingRule.pattern] is compiled as a [RegExp] and
///    matched against the text.
/// 4. For every match, the rule's [FormattingRule.template] is used to build
///    the replacement. The special placeholder `{{match}}` is replaced with
///    the captured content (group 1 if present, otherwise the full match).
/// 5. Macro tokens in the template (e.g. `{{char}}`, `{{user}}`) are
///    resolved via [MacroService].
///
/// Rules are applied sequentially — earlier rule output feeds into later
/// rules — so order matters.
///
/// ## Built-in defaults
///
/// [FormattingService.defaultTemplate] provides a starter template with
/// rules for dialogue, thought/action, narration, and character name
/// formatting. These can be customised or replaced entirely by the user.
class FormattingService {
  FormattingService._();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Applies all enabled rules from [template] to [text].
  ///
  /// If [template] is null or not enabled, returns [text] unchanged.
  /// Macro tokens in rule templates are resolved using [macroContext].
  static Future<String> applyTemplate(
    String text, {
    FormattingTemplate? template,
    MacroContext macroContext = const MacroContext(),
  }) async {
    if (text.isEmpty) return text;
    if (template == null || !template.enabled) return text;

    final rules = _enabledSorted(template.rules);
    if (rules.isEmpty) return text;

    String result = text;
    for (final rule in rules) {
      result = await _applyRule(result, rule, macroContext);
    }

    return result;
  }

  /// Applies a single [FormattingRule] to [text].
  ///
  /// Useful when the caller wants fine-grained control or is testing
  /// individual rules outside of a full template.
  static Future<String> applySingleRule(
    String text,
    FormattingRule rule, {
    MacroContext macroContext = const MacroContext(),
  }) async {
    if (text.isEmpty || !rule.enabled) return text;
    return _applyRule(text, rule, macroContext);
  }

  // -------------------------------------------------------------------------
  // Default template
  // -------------------------------------------------------------------------

  /// Returns a starter [FormattingTemplate] with common roleplay rules.
  ///
  /// Rules included:
  /// - **Dialogue** — text inside `"double quotes"` is wrapped.
  /// - **Thought / action** — text inside `*asterisks*` is wrapped.
  /// - **Narration** — plain text lines not matching dialogue or thought.
  /// - **Character name** — `{{char}}:` at the start of a line is wrapped.
  ///
  /// All rules use `{{match}}` as the content placeholder and pass through
  /// unchanged by default (`template: '{{match}}'`). Override the template
  /// strings to apply actual styling (e.g. HTML spans, Markdown wrappers).
  static FormattingTemplate defaultTemplate() {
    return FormattingTemplate(
      name: 'Default',
      enabled: false,
      description: 'Starter template with dialogue, thought, narration, '
          'and character name rules.',
      rules: [
        FormattingRule(
          id: 1,
          label: 'Dialogue',
          type: FormattingRuleType.dialogue,
          pattern: r'"([^"]*)"',
          template: '"{{match}}"',
          sortOrder: 0,
        ),
        FormattingRule(
          id: 2,
          label: 'Thought / Action',
          type: FormattingRuleType.thought,
          pattern: r'\*([^*]+)\*',
          template: '*{{match}}*',
          sortOrder: 1,
        ),
        FormattingRule(
          id: 3,
          label: 'Character Name',
          type: FormattingRuleType.characterName,
          pattern: r'^({{char}}):',
          template: '**{{match}}**:',
          sortOrder: 2,
        ),
        FormattingRule(
          id: 4,
          label: 'Narration',
          type: FormattingRuleType.narration,
          pattern: r'^(?!["\*])(.+)$',
          template: '{{match}}',
          sortOrder: 3,
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// Filters to enabled rules and sorts by [FormattingRule.sortOrder].
  static List<FormattingRule> _enabledSorted(List<FormattingRule> rules) {
    final filtered = rules.where((r) => r.enabled).toList();
    filtered.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return filtered;
  }

  /// Applies a single [rule] to [text], resolving macros in the template.
  static Future<String> _applyRule(
    String text,
    FormattingRule rule,
    MacroContext macroContext,
  ) async {
    if (rule.pattern.isEmpty) return text;

    // Build the RegExp.
    final RegExp regex;
    try {
      regex = RegExp(rule.pattern, multiLine: true);
    } catch (_) {
      // Invalid regex — skip silently.
      return text;
    }

    if (!regex.hasMatch(text)) return text;

    // Resolve macros in the template once (macro values don't change
    // per-match within a single call).
    final resolvedTemplate = await MacroService.resolve(
      rule.template,
      context: macroContext,
    );

    // Replace each match.
    try {
      final result = text.replaceAllMapped(regex, (match) {
        // Use group 1 if it exists (the content inside delimiters),
        // otherwise fall back to the full match (group 0).
        final captured = match.groupCount >= 1
            ? (match.group(1) ?? match.group(0) ?? '')
            : (match.group(0) ?? '');

        return resolvedTemplate.replaceAll('{{match}}', captured);
      });
      return result;
    } catch (_) {
      return text;
    }
  }
}
