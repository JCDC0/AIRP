import 'dart:math';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Context bag passed to [MacroService.resolve] providing the character and
/// user values needed by core macros.
///
/// All fields are optional; macros referencing missing fields resolve to empty
/// strings.
class MacroContext {
  /// Character name — resolves `{{char}}`.
  final String char;

  /// User / player name — resolves `{{user}}`.
  final String user;

  /// Character description — resolves `{{description}}` / `{{persona}}`.
  final String description;

  /// Character personality summary — resolves `{{personality}}`.
  final String personality;

  /// Current scenario — resolves `{{scenario}}`.
  final String scenario;

  /// Example dialogue block — resolves `{{mesExamples}}`.
  final String mesExamples;

  /// Current model name — resolves `{{model}}`.
  final String model;

  /// Total message count — resolves `{{lastMessageId}}`.
  final int lastMessageId;

  /// Message currently being processed (if applicable) — resolves `{{lastMessage}}`.
  final String lastMessage;

  /// Arbitrary extra values that shadow built-in macros.  Useful for
  /// injecting custom per-call overrides.
  final Map<String, String> extras;

  const MacroContext({
    this.char = '',
    this.user = 'User',
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.mesExamples = '',
    this.model = '',
    this.lastMessageId = 0,
    this.lastMessage = '',
    this.extras = const {},
  });
}

/// Shared macro engine used by the lorebook, regex, formatting, and prompt
/// subsystems to resolve `{{macro}}` tokens in text.
///
/// ## Supported macros
///
/// ### Core identity
/// `{{char}}`, `{{user}}`, `{{description}}`, `{{persona}}` (alias for
/// description), `{{personality}}`, `{{scenario}}`, `{{mesExamples}}`,
/// `{{model}}`, `{{lastMessageId}}`, `{{lastMessage}}`.
///
/// ### Time / date
/// `{{time}}`, `{{date}}`, `{{weekday}}`, `{{isotime}}`, `{{isodate}}`,
/// `{{datetimeformat::FORMAT}}` (uses [DateFormat] pattern).
///
/// ### Random / dice
/// `{{random::a::b}}` — random integer in [a, b].
/// `{{roll::NdM}}` — roll N M-sided dice and sum.
/// `{{pick::a::b::c}}` — pick one option at random.
///
/// ### Variables (persisted via SharedPreferences)
/// `{{getvar::name}}`, `{{setvar::name::value}}`,
/// `{{addvar::name::delta}}` (alias `{{incvar}}`),
/// `{{subvar::name::delta}}` (alias `{{decvar}}`).
///
/// ### Utility
/// `{{newline}}`, `{{trim}}` (trims the final resolved string),
/// `{{input}}` (alias for user's last message).
///
/// ### Legacy aliases
/// `<USER>` → `{{user}}`, `<BOT>` → `{{char}}`.
///
/// ## Recursion
/// Macros may expand to text containing further macros.  Resolution loops
/// up to [maxDepth] times (default 20) before returning the remaining text
/// un-resolved.
class MacroService {
  /// Maximum recursive resolution passes.
  static const int maxDepth = 20;

  /// SharedPreferences key prefix for macro variables.
  static const String _varPrefix = 'airp_macro_var_';

  // In-memory variable cache (synced to SharedPreferences on write).
  static final Map<String, String> _variables = {};
  static bool _variablesLoaded = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Resolves all macro tokens in [input] using the supplied [context].
  ///
  /// Legacy aliases (`<USER>`, `<BOT>`) are normalised before token parsing.
  /// Resolution iterates up to [maxDepth] passes so that macros may expand
  /// into further macros.
  ///
  /// If [trimResult] is true the final string is trimmed of leading/trailing
  /// whitespace (this is also triggered by a `{{trim}}` token in the input).
  static Future<String> resolve(
    String input, {
    MacroContext context = const MacroContext(),
    bool trimResult = false,
  }) async {
    if (input.isEmpty) return input;

    // Ensure variables are loaded from SharedPreferences.
    await _ensureVariablesLoaded();

    // Normalise legacy aliases before entering the loop.
    String text = _normaliseLegacy(input);

    bool shouldTrim = trimResult;
    bool changed = true;
    int depth = 0;

    while (changed && depth < maxDepth) {
      final result = await _resolvePass(text, context);
      changed = result.text != text;
      if (result.shouldTrim) shouldTrim = true;
      text = result.text;
      depth++;
    }

    return shouldTrim ? text.trim() : text;
  }

  /// Clears the in-memory variable cache.  Useful for testing.
  static void resetVariables() {
    _variables.clear();
    _variablesLoaded = false;
  }

  /// Loads all persisted macro variables into the in-memory cache.
  static Future<void> loadVariables() async {
    final prefs = await SharedPreferences.getInstance();
    _variables.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_varPrefix)) {
        final name = key.substring(_varPrefix.length);
        _variables[name] = prefs.getString(key) ?? '';
      }
    }
    _variablesLoaded = true;
  }

  /// Returns a read-only snapshot of the current variable store.
  static Map<String, String> get variables => Map.unmodifiable(_variables);

  // ---------------------------------------------------------------------------
  // Legacy aliases
  // ---------------------------------------------------------------------------

  static final RegExp _legacyUser = RegExp(r'<USER>', caseSensitive: false);
  static final RegExp _legacyBot = RegExp(r'<BOT>', caseSensitive: false);

  static String _normaliseLegacy(String input) {
    return input
        .replaceAll(_legacyUser, '{{user}}')
        .replaceAll(_legacyBot, '{{char}}');
  }

  // ---------------------------------------------------------------------------
  // Single resolution pass
  // ---------------------------------------------------------------------------

  /// Pattern matching `{{...}}` tokens — non-greedy.
  static final RegExp _tokenPattern = RegExp(r'\{\{(.+?)\}\}');

  /// Result of a single resolution pass.
  static Future<_PassResult> _resolvePass(
    String text,
    MacroContext ctx,
  ) async {
    bool shouldTrim = false;

    final buffer = StringBuffer();
    int lastEnd = 0;

    for (final match in _tokenPattern.allMatches(text)) {
      buffer.write(text.substring(lastEnd, match.start));

      final raw = match.group(1)!;
      final resolved = await _resolveToken(raw, ctx);

      if (resolved != null) {
        if (resolved.isTrim) {
          shouldTrim = true;
        } else {
          buffer.write(resolved.value);
        }
      } else {
        // Unrecognised macro — leave as-is.
        buffer.write(match.group(0));
      }

      lastEnd = match.end;
    }

    buffer.write(text.substring(lastEnd));
    return _PassResult(buffer.toString(), shouldTrim);
  }

  // ---------------------------------------------------------------------------
  // Token dispatch
  // ---------------------------------------------------------------------------

  /// Resolves a single macro token (the text between `{{` and `}}`).
  /// Returns `null` if the token is not recognised (left as-is).
  static Future<_TokenResult?> _resolveToken(
    String raw,
    MacroContext ctx,
  ) async {
    // Check extras first — they override everything.
    if (ctx.extras.containsKey(raw)) {
      return _TokenResult(ctx.extras[raw]!);
    }

    // Split on `::` for parameterised macros.
    final parts = raw.split('::');
    final name = parts[0].toLowerCase();

    // --- Core identity ---
    switch (name) {
      case 'char':
        return _TokenResult(ctx.char);
      case 'user':
        return _TokenResult(ctx.user);
      case 'description':
      case 'persona':
        return _TokenResult(ctx.description);
      case 'personality':
        return _TokenResult(ctx.personality);
      case 'scenario':
        return _TokenResult(ctx.scenario);
      case 'mesexamples':
      case 'mes_examples':
        return _TokenResult(ctx.mesExamples);
      case 'model':
        return _TokenResult(ctx.model);
      case 'lastmessageid':
      case 'last_message_id':
        return _TokenResult(ctx.lastMessageId.toString());
      case 'lastmessage':
      case 'last_message':
        return _TokenResult(ctx.lastMessage);
      case 'input':
        return _TokenResult(ctx.lastMessage);

      // --- Time / date ---
      case 'time':
        return _TokenResult(DateFormat.jm().format(DateTime.now()));
      case 'date':
        return _TokenResult(DateFormat.yMMMd().format(DateTime.now()));
      case 'weekday':
        return _TokenResult(DateFormat.EEEE().format(DateTime.now()));
      case 'isotime':
        return _TokenResult(DateFormat.Hms().format(DateTime.now()));
      case 'isodate':
        return _TokenResult(
            DateFormat('yyyy-MM-dd').format(DateTime.now()));
      case 'datetimeformat':
        if (parts.length >= 2) {
          try {
            return _TokenResult(
                DateFormat(parts[1]).format(DateTime.now()));
          } catch (_) {
            return _TokenResult('[invalid format: ${parts[1]}]');
          }
        }
        return _TokenResult(DateTime.now().toIso8601String());

      // --- Random / dice ---
      case 'random':
        return _resolveRandom(parts);
      case 'roll':
        return _resolveRoll(parts);
      case 'pick':
        return _resolvePick(parts);

      // --- Variables ---
      case 'getvar':
        return _resolveGetVar(parts);
      case 'setvar':
        return await _resolveSetVar(parts);
      case 'addvar':
      case 'incvar':
        return await _resolveAddVar(parts, 1);
      case 'subvar':
      case 'decvar':
        return await _resolveAddVar(parts, -1);

      // --- Utility ---
      case 'newline':
        return _TokenResult('\n');
      case 'trim':
        return _TokenResult.trim();

      // --- Conditionals ---
      case 'ifeq':
        return _resolveIfEq(parts, ctx);
      case 'ifneq':
        return _resolveIfNeq(parts, ctx);
    }

    return null; // unrecognised
  }

  // ---------------------------------------------------------------------------
  // Random / dice
  // ---------------------------------------------------------------------------

  static final Random _rng = Random();

  /// `{{random::a::b}}` → random integer in [a, b] inclusive.
  static _TokenResult? _resolveRandom(List<String> parts) {
    if (parts.length < 3) return _TokenResult('0');
    final a = int.tryParse(parts[1]);
    final b = int.tryParse(parts[2]);
    if (a == null || b == null) return _TokenResult('0');
    final lo = a < b ? a : b;
    final hi = a < b ? b : a;
    return _TokenResult((_rng.nextInt(hi - lo + 1) + lo).toString());
  }

  /// `{{roll::NdM}}` — roll N M-sided dice and sum.
  static _TokenResult? _resolveRoll(List<String> parts) {
    if (parts.length < 2) return _TokenResult('0');
    final diceMatch = RegExp(r'^(\d+)[dD](\d+)$').firstMatch(parts[1]);
    if (diceMatch == null) return _TokenResult('0');
    final n = int.parse(diceMatch.group(1)!);
    final m = int.parse(diceMatch.group(2)!);
    if (n <= 0 || m <= 0) return _TokenResult('0');
    int total = 0;
    for (int i = 0; i < n; i++) {
      total += _rng.nextInt(m) + 1;
    }
    return _TokenResult(total.toString());
  }

  /// `{{pick::a::b::c}}` — randomly pick one of the options.
  static _TokenResult? _resolvePick(List<String> parts) {
    if (parts.length < 2) return _TokenResult('');
    final options = parts.sublist(1);
    return _TokenResult(options[_rng.nextInt(options.length)]);
  }

  // ---------------------------------------------------------------------------
  // Variables
  // ---------------------------------------------------------------------------

  static Future<void> _ensureVariablesLoaded() async {
    if (!_variablesLoaded) {
      await loadVariables();
    }
  }

  /// `{{getvar::name}}` — returns the stored value (empty string if unset).
  static _TokenResult? _resolveGetVar(List<String> parts) {
    if (parts.length < 2) return _TokenResult('');
    return _TokenResult(_variables[parts[1]] ?? '');
  }

  /// `{{setvar::name::value}}` — stores a value and expands to empty string.
  static Future<_TokenResult> _resolveSetVar(List<String> parts) async {
    if (parts.length < 3) return _TokenResult('');
    final name = parts[1];
    final value = parts.sublist(2).join('::'); // allow :: in values
    _variables[name] = value;
    await _persistVariable(name, value);
    return _TokenResult('');
  }

  /// `{{addvar::name::delta}}` / `{{subvar::name::delta}}`.
  /// [sign] is 1 for add, -1 for subtract.
  static Future<_TokenResult> _resolveAddVar(
      List<String> parts, int sign) async {
    if (parts.length < 3) return _TokenResult('0');
    final name = parts[1];
    final delta = int.tryParse(parts[2]) ?? 0;
    final current = int.tryParse(_variables[name] ?? '0') ?? 0;
    final result = current + (delta * sign);
    _variables[name] = result.toString();
    await _persistVariable(name, result.toString());
    return _TokenResult(result.toString());
  }

  static Future<void> _persistVariable(String name, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_varPrefix$name', value);
  }

  // ---------------------------------------------------------------------------
  // Conditionals
  // ---------------------------------------------------------------------------

  /// `{{ifeq::a::b::then}}` — if a == b, return then; else empty.
  /// `{{ifeq::a::b::then::else}}` — if a == b, return then; else return else.
  static _TokenResult? _resolveIfEq(List<String> parts, MacroContext ctx) {
    if (parts.length < 4) return _TokenResult('');
    final a = parts[1];
    final b = parts[2];
    final thenVal = parts[3];
    final elseVal = parts.length >= 5 ? parts[4] : '';
    return _TokenResult(a == b ? thenVal : elseVal);
  }

  /// `{{ifneq::a::b::then}}` — if a != b, return then; else empty.
  /// `{{ifneq::a::b::then::else}}` — if a != b, return then; else return else.
  static _TokenResult? _resolveIfNeq(List<String> parts, MacroContext ctx) {
    if (parts.length < 4) return _TokenResult('');
    final a = parts[1];
    final b = parts[2];
    final thenVal = parts[3];
    final elseVal = parts.length >= 5 ? parts[4] : '';
    return _TokenResult(a != b ? thenVal : elseVal);
  }
}

// ---------------------------------------------------------------------------
// Internal result types
// ---------------------------------------------------------------------------

class _PassResult {
  final String text;
  final bool shouldTrim;
  const _PassResult(this.text, this.shouldTrim);
}

class _TokenResult {
  final String value;
  final bool isTrim;

  const _TokenResult(this.value) : isTrim = false;
  const _TokenResult.trim()
      : value = '',
        isTrim = true;
}
