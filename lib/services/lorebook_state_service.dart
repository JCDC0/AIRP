import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks per-session timed-effect state for lorebook entries.
///
/// Manages:
/// - **Delay**: how many keyword matches an entry has accumulated before
///   its first activation.
/// - **Sticky**: how many turns an entry remains force-activated after its
///   initial trigger.
/// - **Cooldown**: how many turns must elapse after a sticky window before
///   the entry can re-activate.
/// - **Activation history**: which entries were activated on which turn.
///
/// State is persisted to SharedPreferences keyed by session ID so it
/// survives app restarts within the same chat session.
class LorebookSessionState {
  /// SharedPreferences key prefix.
  static const String _keyPrefix = 'airp_lorebook_state_';

  /// The chat session this state belongs to.
  final String sessionId;

  /// Current turn counter (incremented each time the user sends a message).
  int _currentTurn;

  /// Per-entry match count for delay tracking.
  /// Key = entry ID, value = number of keyword matches seen.
  final Map<int, int> _matchCounts;

  /// Per-entry last activation turn.
  /// Key = entry ID, value = turn number of most recent activation.
  final Map<int, int> _lastActivationTurn;

  /// Per-entry sticky expiry turn.
  /// Key = entry ID, value = turn after which sticky expires.
  final Map<int, int> _stickyExpiry;

  /// Per-entry cooldown expiry turn.
  /// Key = entry ID, value = turn after which cooldown expires.
  final Map<int, int> _cooldownExpiry;

  LorebookSessionState({
    required this.sessionId,
    int currentTurn = 0,
    Map<int, int>? matchCounts,
    Map<int, int>? lastActivationTurn,
    Map<int, int>? stickyExpiry,
    Map<int, int>? cooldownExpiry,
  })  : _currentTurn = currentTurn,
        _matchCounts = matchCounts ?? {},
        _lastActivationTurn = lastActivationTurn ?? {},
        _stickyExpiry = stickyExpiry ?? {},
        _cooldownExpiry = cooldownExpiry ?? {};

  /// Current turn number.
  int get currentTurn => _currentTurn;

  // ---------------------------------------------------------------------------
  // Turn management
  // ---------------------------------------------------------------------------

  /// Advances the turn counter by one.  Call this once per user message.
  void advanceTurn() {
    _currentTurn++;
  }

  // ---------------------------------------------------------------------------
  // Delay
  // ---------------------------------------------------------------------------

  /// Increments the keyword-match counter for [entryId].
  void incrementMatchCount(int entryId) {
    _matchCounts[entryId] = (_matchCounts[entryId] ?? 0) + 1;
  }

  /// Returns true if [entryId] has accumulated enough matches to satisfy
  /// its [requiredDelay] (i.e. match count ≥ delay).
  bool hasPassedDelay(int entryId, int requiredDelay) {
    return (_matchCounts[entryId] ?? 0) >= requiredDelay;
  }

  // ---------------------------------------------------------------------------
  // Sticky
  // ---------------------------------------------------------------------------

  /// Returns true if [entryId] is still within its sticky window.
  bool isStickyActive(int entryId, int stickyDuration) {
    final expiry = _stickyExpiry[entryId];
    if (expiry == null) return false;
    return _currentTurn <= expiry;
  }

  // ---------------------------------------------------------------------------
  // Cooldown
  // ---------------------------------------------------------------------------

  /// Returns true if [entryId] is currently on cooldown (cannot activate).
  bool isOnCooldown(int entryId, int cooldownDuration) {
    final expiry = _cooldownExpiry[entryId];
    if (expiry == null) return false;
    return _currentTurn < expiry;
  }

  // ---------------------------------------------------------------------------
  // Activation recording
  // ---------------------------------------------------------------------------

  /// Records that [entryId] was activated on the current turn.
  ///
  /// Updates sticky and cooldown expiry windows if the entry is not already
  /// in a sticky window.
  void recordActivation(int entryId) {
    final previousExpiry = _stickyExpiry[entryId];
    final alreadySticky =
        previousExpiry != null && _currentTurn <= previousExpiry;

    _lastActivationTurn[entryId] = _currentTurn;

    if (!alreadySticky) {
      // Start a new sticky window.
      // Sticky and cooldown durations will be applied from the model, but we
      // store expiry turns here based on reasonable defaults if the caller
      // doesn't provide them.  The actual durations are checked in
      // LorebookService which passes them through.
      // We'll set sticky expiry; cooldown is set when sticky expires.
    }
  }

  /// Sets the sticky expiry for [entryId] to [currentTurn + duration].
  void setStickyWindow(int entryId, int duration) {
    _stickyExpiry[entryId] = _currentTurn + duration;
    // When sticky expires, cooldown begins.
  }

  /// Sets the cooldown expiry for [entryId] to
  /// [stickyExpiry + cooldownDuration].
  void setCooldownAfterSticky(int entryId, int cooldownDuration) {
    final stickyEnd = _stickyExpiry[entryId] ?? _currentTurn;
    _cooldownExpiry[entryId] = stickyEnd + cooldownDuration;
  }

  /// Returns the turn when [entryId] was last activated, or -1 if never.
  int lastActivation(int entryId) => _lastActivationTurn[entryId] ?? -1;

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Saves this state to SharedPreferences.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = toJson();
    await prefs.setString('$_keyPrefix$sessionId', jsonEncode(json));
  }

  /// Loads state for [sessionId] from SharedPreferences.
  /// Returns a fresh state if none exists.
  static Future<LorebookSessionState> load(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$sessionId');
    if (raw == null) {
      return LorebookSessionState(sessionId: sessionId);
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LorebookSessionState.fromJson(sessionId, json);
    } catch (_) {
      return LorebookSessionState(sessionId: sessionId);
    }
  }

  /// Removes persisted state for [sessionId].
  static Future<void> clear(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$sessionId');
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'currentTurn': _currentTurn,
      'matchCounts': _intMapToStringKeys(_matchCounts),
      'lastActivationTurn': _intMapToStringKeys(_lastActivationTurn),
      'stickyExpiry': _intMapToStringKeys(_stickyExpiry),
      'cooldownExpiry': _intMapToStringKeys(_cooldownExpiry),
    };
  }

  factory LorebookSessionState.fromJson(
    String sessionId,
    Map<String, dynamic> json,
  ) {
    return LorebookSessionState(
      sessionId: sessionId,
      currentTurn: json['currentTurn'] as int? ?? 0,
      matchCounts: _stringKeysToIntMap(json['matchCounts']),
      lastActivationTurn: _stringKeysToIntMap(json['lastActivationTurn']),
      stickyExpiry: _stringKeysToIntMap(json['stickyExpiry']),
      cooldownExpiry: _stringKeysToIntMap(json['cooldownExpiry']),
    );
  }

  /// Converts `Map<int, int>` to `Map<String, int>` for JSON encoding.
  static Map<String, int> _intMapToStringKeys(Map<int, int> map) {
    return map.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Converts `Map<String, dynamic>` back to `Map<int, int>`.
  static Map<int, int> _stringKeysToIntMap(dynamic raw) {
    if (raw is! Map) return {};
    return Map<int, int>.fromEntries(
      (raw as Map<String, dynamic>).entries.map(
        (e) => MapEntry(int.tryParse(e.key) ?? 0, e.value as int? ?? 0),
      ),
    );
  }
}
