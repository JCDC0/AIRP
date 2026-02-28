import 'package:airp/models/regex_models.dart';
import 'package:airp/services/macro_service.dart';

// ---------------------------------------------------------------------------
// Target enum
// ---------------------------------------------------------------------------

/// Identifies which text target a regex pipeline is processing.
///
/// Used to filter [RegexScript]s by their `affects*` flags so that only
/// scripts relevant to the current target are applied.
enum RegexTarget {
  /// User input before it is sent to the AI.
  userInput,

  /// AI response text.
  aiOutput,

  /// World Info / lorebook content.
  worldInfo,

  /// Reasoning / thinking output.
  reasoning,
}

// ---------------------------------------------------------------------------
// Apply mode enum
// ---------------------------------------------------------------------------

/// Determines which ephemerality class of scripts to apply.
enum RegexApplyMode {
  /// Scripts that are neither display-only nor prompt-only.
  /// Their result permanently replaces the stored text.
  permanent,

  /// Scripts where [RegexScript.displayOnly] is true.
  /// Only affects rendered text — the stored text is unchanged.
  displayOnly,

  /// Scripts where [RegexScript.promptOnly] is true.
  /// Only affects the prompt sent to the AI — the stored text is unchanged.
  promptOnly,
}

// ---------------------------------------------------------------------------
// RegexService
// ---------------------------------------------------------------------------

/// Static post-processing pipeline that applies [RegexScript] lists to text.
///
/// ## Three application modes
///
/// | Mode | Stored text | Displayed text | Sent prompt |
/// |------|-------------|----------------|-------------|
/// | [RegexApplyMode.permanent] | modified | modified | modified |
/// | [RegexApplyMode.displayOnly] | unchanged | modified | unchanged |
/// | [RegexApplyMode.promptOnly] | unchanged | unchanged | modified |
///
/// ## Pipeline steps (per script, in [RegexScript.sortOrder])
///
/// 1. **Filter** — skip disabled scripts, wrong target, wrong depth, wrong
///    ephemerality mode.
/// 2. **Trim strings** — remove each [RegexScript.trimStrings] from the input
///    text before matching.
/// 3. **Build RegExp** — compile [RegexScript.findRegex] with the script's
///    flag configuration (caseSensitive, dotAll, multiLine, unicode).
/// 4. **Resolve macros** — if [RegexScript.macroMode] is not `none`, resolve
///    `{{macro}}` tokens in the replacement string via [MacroService].
/// 5. **Apply** — replace all matches using [String.replaceAllMapped] so that
///    capture-group back-references (`$1`, `$2`, …) work correctly.
class RegexService {
  RegexService._();

  // -------------------------------------------------------------------------
  // Convenience wrappers
  // -------------------------------------------------------------------------

  /// Applies scripts that permanently modify [text].
  ///
  /// Selects only scripts where both `displayOnly` and `promptOnly` are false.
  static Future<String> applyPermanent({
    required String text,
    required List<RegexScript> scripts,
    required RegexTarget target,
    int messageDepth = 0,
    MacroContext macroContext = const MacroContext(),
  }) {
    return apply(
      text: text,
      scripts: scripts,
      target: target,
      messageDepth: messageDepth,
      mode: RegexApplyMode.permanent,
      macroContext: macroContext,
    );
  }

  /// Applies display-only scripts to [text].
  ///
  /// The caller should use the returned text for rendering only; the stored
  /// message text must remain untouched.
  static Future<String> applyDisplayOnly({
    required String text,
    required List<RegexScript> scripts,
    required RegexTarget target,
    int messageDepth = 0,
    MacroContext macroContext = const MacroContext(),
  }) {
    return apply(
      text: text,
      scripts: scripts,
      target: target,
      messageDepth: messageDepth,
      mode: RegexApplyMode.displayOnly,
      macroContext: macroContext,
    );
  }

  /// Applies prompt-only scripts to [text].
  ///
  /// The caller should use the returned text when building the prompt; the
  /// stored message text and display text must remain untouched.
  static Future<String> applyPromptOnly({
    required String text,
    required List<RegexScript> scripts,
    required RegexTarget target,
    int messageDepth = 0,
    MacroContext macroContext = const MacroContext(),
  }) {
    return apply(
      text: text,
      scripts: scripts,
      target: target,
      messageDepth: messageDepth,
      mode: RegexApplyMode.promptOnly,
      macroContext: macroContext,
    );
  }

  // -------------------------------------------------------------------------
  // Core API
  // -------------------------------------------------------------------------

  /// Applies all matching [scripts] to [text] and returns the result.
  ///
  /// Scripts are filtered by [target], [messageDepth], [mode], and their own
  /// `enabled` flag, then sorted by [RegexScript.sortOrder] (ascending —
  /// lower runs first). Each surviving script is applied sequentially so that
  /// earlier scripts' output feeds into later scripts.
  static Future<String> apply({
    required String text,
    required List<RegexScript> scripts,
    required RegexTarget target,
    int messageDepth = 0,
    RegexApplyMode mode = RegexApplyMode.permanent,
    MacroContext macroContext = const MacroContext(),
  }) async {
    // 1. Filter and sort.
    final applicable = _filterAndSort(scripts, target, messageDepth, mode);

    if (applicable.isEmpty) return text;

    // 2. Apply each script sequentially.
    String result = text;
    for (final script in applicable) {
      result = await _applyScript(result, script, macroContext);
    }

    return result;
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// Filters [scripts] by enabled, target, depth, and ephemerality mode, then
  /// returns them sorted by [RegexScript.sortOrder] ascending.
  static List<RegexScript> _filterAndSort(
    List<RegexScript> scripts,
    RegexTarget target,
    int messageDepth,
    RegexApplyMode mode,
  ) {
    final filtered = scripts.where((s) {
      // Must be enabled.
      if (!s.enabled) return false;

      // Must affect the requested target.
      if (!_matchesTarget(s, target)) return false;

      // Must match the requested ephemerality mode.
      if (!_matchesMode(s, mode)) return false;

      // Must be within depth range.
      if (!_inDepthRange(s, messageDepth)) return false;

      return true;
    }).toList();

    // Stable sort by sortOrder (lower = first).
    filtered.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return filtered;
  }

  /// Returns true if [script] targets [target].
  static bool _matchesTarget(RegexScript script, RegexTarget target) {
    switch (target) {
      case RegexTarget.userInput:
        return script.affectsUserInput;
      case RegexTarget.aiOutput:
        return script.affectsAiOutput;
      case RegexTarget.worldInfo:
        return script.affectsWorldInfo;
      case RegexTarget.reasoning:
        return script.affectsReasoning;
    }
  }

  /// Returns true if [script]'s ephemerality flags match [mode].
  ///
  /// A script with both `displayOnly` and `promptOnly` set to false is a
  /// permanent script. If both are true, the script is treated as permanent
  /// (ambiguous; SillyTavern treats this as display-only but we include it in
  /// permanent for safety).
  static bool _matchesMode(RegexScript script, RegexApplyMode mode) {
    switch (mode) {
      case RegexApplyMode.permanent:
        return !script.displayOnly && !script.promptOnly;
      case RegexApplyMode.displayOnly:
        return script.displayOnly;
      case RegexApplyMode.promptOnly:
        return script.promptOnly;
    }
  }

  /// Returns true if [messageDepth] falls within the script's depth range.
  ///
  /// `maxDepth == -1` means unlimited (always in range).
  static bool _inDepthRange(RegexScript script, int messageDepth) {
    if (messageDepth < script.minDepth) return false;
    if (script.maxDepth >= 0 && messageDepth > script.maxDepth) return false;
    return true;
  }

  /// Applies a single [script] to [text].
  ///
  /// Steps:
  /// 1. Apply trim strings to the subject text.
  /// 2. Build a [RegExp] from the find pattern with the script's flags.
  /// 3. Resolve macros in the replacement string (if macro mode is not `none`).
  /// 4. Replace all matches, preserving capture-group back-references.
  static Future<String> _applyScript(
    String text,
    RegexScript script,
    MacroContext macroContext,
  ) async {
    if (script.findRegex.isEmpty) return text;

    // 1. Trim strings — remove each substring from the subject.
    String subject = text;
    for (final trim in script.trimStrings) {
      if (trim.isNotEmpty) {
        subject = subject.replaceAll(trim, '');
      }
    }

    // 2. Build RegExp.
    final RegExp regex;
    try {
      regex = RegExp(
        script.findRegex,
        caseSensitive: !script.caseInsensitive,
        dotAll: script.dotAll,
        multiLine: script.multiLine,
        unicode: script.unicode,
      );
    } catch (_) {
      // Invalid regex pattern — skip this script silently.
      return text;
    }

    // 3. Resolve macros in the replacement string.
    String replacement = script.replaceString;
    if (script.macroMode != RegexMacroMode.none) {
      replacement = await MacroService.resolve(
        replacement,
        context: macroContext,
      );

      // In escaped mode, escape regex special characters in the resolved
      // macro values so they are treated as literal text within the
      // replacement string. We only escape the portion that came from
      // macro resolution — but since we don't track boundaries, we
      // escape the entire replacement. This is consistent with ST
      // behaviour where `escaped` means "safe for embedding in regex
      // replacement".
      if (script.macroMode == RegexMacroMode.escaped) {
        replacement = _escapeReplacement(replacement);
      }
    }

    // 4. Apply the regex.
    if (!regex.hasMatch(subject)) return subject;

    try {
      final result = subject.replaceAllMapped(regex, (match) {
        return _expandBackReferences(replacement, match);
      });
      return result;
    } catch (_) {
      // Replacement failure — return text unchanged.
      return text;
    }
  }

  /// Expands `$0`–`$9` (and `${n}`) back-references in [replacement] using
  /// values from [match].
  ///
  /// Dart's [String.replaceAllMapped] does not auto-expand `$1` etc. in a
  /// plain string return value — we must do it manually.
  static String _expandBackReferences(String replacement, Match match) {
    // Fast path: no dollar signs at all.
    if (!replacement.contains('\$')) return replacement;

    final buffer = StringBuffer();
    int i = 0;
    while (i < replacement.length) {
      if (replacement[i] == '\$') {
        // Check for escaped dollar: $$
        if (i + 1 < replacement.length && replacement[i + 1] == '\$') {
          buffer.write('\$');
          i += 2;
          continue;
        }

        // Check for ${n} syntax.
        if (i + 1 < replacement.length && replacement[i + 1] == '{') {
          final closeIdx = replacement.indexOf('}', i + 2);
          if (closeIdx != -1) {
            final numStr = replacement.substring(i + 2, closeIdx);
            final groupNum = int.tryParse(numStr);
            if (groupNum != null &&
                groupNum >= 0 &&
                groupNum <= match.groupCount) {
              buffer.write(match.group(groupNum) ?? '');
              i = closeIdx + 1;
              continue;
            }
          }
        }

        // Check for $n syntax (single digit).
        if (i + 1 < replacement.length) {
          final digit = replacement[i + 1];
          final groupNum = int.tryParse(digit);
          if (groupNum != null &&
              groupNum >= 0 &&
              groupNum <= match.groupCount) {
            buffer.write(match.group(groupNum) ?? '');
            i += 2;
            continue;
          }
        }

        // Lone dollar sign — write it literally.
        buffer.write('\$');
        i++;
      } else {
        buffer.write(replacement[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  /// Escapes `$` signs in [replacement] so they are not interpreted as
  /// back-references.
  ///
  /// Used when [RegexMacroMode.escaped] is active to prevent macro-resolved
  /// text from accidentally being treated as capture group references.
  static String _escapeReplacement(String replacement) {
    return replacement.replaceAll('\$', '\$\$');
  }
}
