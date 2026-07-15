import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';

/// A single search match: the index of the message that contains the match.
///
/// One [ChatSearchMatch] is produced per occurrence (in document order), so the
/// list of matches reflects the total number of occurrences across the chat
/// and the navigation order follows the reading direction.
class ChatSearchMatch {
  /// Index of the matching message within [ChatProvider.messages].
  final int messageIndex;

  const ChatSearchMatch(this.messageIndex);
}

/// State for the in-chat find bar (ctrl+F).
///
/// Holds the active query, the computed list of matches (one per occurrence),
/// and the current-match pointer. Consumers read [currentMatchMessageIndex]
/// / [matchMessageIndices] to highlight messages and [matchCount] /
/// [currentMatchNumber] for the "x / y" indicator. Matches are recomputed
/// from a messages list supplied by the host (so the provider stays free of
/// hard service dependencies).
class ChatSearchProvider extends ChangeNotifier {
  bool _isOpen = false;
  String _query = '';
  List<ChatSearchMatch> _matches = const [];
  int _current = -1;

  bool get isOpen => _isOpen;
  String get query => _query;
  List<ChatSearchMatch> get matches => _matches;
  int get matchCount => _matches.length;
  int get currentMatchNumber => _current < 0 ? 0 : _current + 1;
  bool get hasMatches => _matches.isNotEmpty;

  int? get currentMatchMessageIndex =>
      (_current >= 0 && _current < _matches.length)
      ? _matches[_current].messageIndex
      : null;

  /// Set of all message indices that contain at least one match.
  Set<int> get matchMessageIndices =>
      _matches.map((m) => m.messageIndex).toSet();

  /// Open the find bar (idempotent).
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  /// Close the find bar and clear the query + matches.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    _query = '';
    _matches = const [];
    _current = -1;
    notifyListeners();
  }

  /// Update the query and recompute matches, resetting the pointer to the
  /// first match (standard find-as-you-type behavior).
  void setQuery(String q, List<ChatMessage> messages) {
    _query = q;
    _recompute(messages);
    _current = _matches.isEmpty ? -1 : 0;
    notifyListeners();
  }

  /// Recompute matches from the current query without resetting the pointer's
  /// target message when possible (used when the message list changes while a
  /// search is active, e.g. during streaming).
  void recompute(List<ChatMessage> messages) {
    if (_query.isEmpty) {
      _matches = const [];
      _current = -1;
      notifyListeners();
      return;
    }
    final int prevMsg = (_current >= 0 && _current < _matches.length)
        ? _matches[_current].messageIndex
        : -1;
    _recompute(messages);
    if (prevMsg >= 0) {
      final idx = _matches.indexWhere((m) => m.messageIndex == prevMsg);
      _current = idx >= 0 ? idx : (_matches.isEmpty ? -1 : 0);
    } else {
      _current = _matches.isEmpty ? -1 : 0;
    }
    notifyListeners();
  }

  void _recompute(List<ChatMessage> messages) {
    final List<ChatSearchMatch> result = [];
    if (_query.isEmpty) {
      _matches = const [];
      return;
    }
    for (int i = 0; i < messages.length; i++) {
      final int n = _countOccurrences(messages[i].text, _query);
      for (int o = 0; o < n; o++) {
        result.add(ChatSearchMatch(i));
      }
    }
    _matches = List.unmodifiable(result);
  }

  /// Advance to the next match (wraps around).
  void next() {
    if (_matches.isEmpty) return;
    _current = (_current + 1) % _matches.length;
    notifyListeners();
  }

  /// Go to the previous match (wraps around).
  void previous() {
    if (_matches.isEmpty) return;
    _current = (_current - 1 + _matches.length) % _matches.length;
    notifyListeners();
  }

  static int _countOccurrences(String text, String query) {
    if (query.isEmpty) return 0;
    final String t = text.toLowerCase();
    final String q = query.toLowerCase();
    int count = 0;
    int idx = 0;
    while ((idx = t.indexOf(q, idx)) != -1) {
      count++;
      idx += q.length;
    }
    return count;
  }
}
