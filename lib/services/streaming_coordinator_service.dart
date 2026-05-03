import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../services/reasoning_utils.dart';

/// Coordinates background streaming operations across multiple chat sessions.
///
/// Handles stream lifecycle, chunk parsing (including usage and thought
/// signatures), and notification management for background completions.
class StreamingCoordinatorService {
  final Map<String, StreamSubscription> _activeStreams = {};
  final Map<String, ValueNotifier<String>> _activeNotifiers = {};
  final Map<String, String> _activeStreamTexts = {};
  final Map<String, String> _activeStreamModels = {};
  final Set<String> _cancelledSessions = {};
  final List<BackgroundNotification> _pendingNotifications = [];

  final VoidCallback onStateChanged;

  StreamingCoordinatorService({required this.onStateChanged});

  /// Whether a specific session currently has an active background stream.
  bool isStreaming(String? sessionId) => _activeStreams.containsKey(sessionId);

  /// Whether a specific session's stream has been cancelled.
  bool isCancelled(String? sessionId) => _cancelledSessions.contains(sessionId);

  /// All session IDs with active streams.
  Set<String> get streamingSessionIds => _activeStreams.keys.toSet();

  /// List of background notifications for streams that finished while inactive.
  List<BackgroundNotification> get pendingNotifications => _pendingNotifications;

  /// Returns the current text for an active stream.
  String? getActiveStreamText(String sessionId) => _activeStreamTexts[sessionId];

  /// Returns the active ValueNotifier for a streaming session.
  ValueNotifier<String>? getActiveNotifier(String sessionId) => _activeNotifiers[sessionId];

  /// Checks if a given notifier is currently active.
  bool isActiveNotifier(ValueNotifier<String>? notifier) {
    if (notifier == null) return false;
    return _activeNotifiers.values.contains(notifier);
  }

  /// Returns the model name used for an active stream.
  String? getActiveStreamModel(String sessionId) => _activeStreamModels[sessionId];

  /// Removes a notification from the pending list.
  void removeNotification(int index) {
    if (index >= 0 && index < _pendingNotifications.length) {
      _pendingNotifications.removeAt(index);
      onStateChanged();
    }
  }

  /// Adds a notification to the pending list.
  void addNotification(BackgroundNotification notification) {
    _pendingNotifications.add(notification);
    onStateChanged();
  }

  /// Registers and starts listening to a new response stream.
  void registerStream({
    required String sessionId,
    required String modelName,
    required ValueNotifier<String> contentNotifier,
    required Stream<String> stream,
    required void Function(String sessionId, String text, Map<String, dynamic>? usage) onUpdate,
    required void Function(String sessionId, String sig) onThoughtSignature,
    required void Function(String sessionId, String errorText) onError,
    required Future<void> Function(String sessionId, String finalText, bool reasoningRecovered) onDone,
  }) {
    _cancelledSessions.remove(sessionId);
    _activeNotifiers[sessionId] = contentNotifier;
    _activeStreamTexts[sessionId] = "";
    _activeStreamModels[sessionId] = modelName;

    String fullText = "";

    final subscription = stream.listen(
      (chunk) {
        if (_cancelledSessions.contains(sessionId)) return;

        if (chunk.startsWith('[[USAGE:')) {
          final usageStr = chunk.substring(8, chunk.length - 2);
          try {
            final usage = jsonDecode(usageStr) as Map<String, dynamic>;
            onUpdate(sessionId, "", usage);
          } catch (_) {}
        } else if (chunk.startsWith('[[THOUGHT_SIG:')) {
          final sig = chunk.substring(14, chunk.length - 2);
          onThoughtSignature(sessionId, sig);
        } else {
          fullText += chunk;
          _activeStreamTexts[sessionId] = fullText;
          contentNotifier.value = fullText;
          onUpdate(sessionId, fullText, null);
        }
      },
      onError: (e) {
        if (!_cancelledSessions.contains(sessionId)) {
          final errorText = "$fullText\n\n**Error:** $e";
          onError(sessionId, errorText);
        }
        _cleanupStream(sessionId);
      },
      onDone: () async {
        if (!_cancelledSessions.contains(sessionId)) {
          final split = ReasoningUtils.split(fullText);
          var recoveredFromReasoning = false;
          if (split.reasoning.isNotEmpty && split.content.trim().isEmpty) {
            fullText = split.reasoning;
            recoveredFromReasoning = true;
          }
          await onDone(sessionId, fullText, recoveredFromReasoning);
        }
        _cleanupStream(sessionId);
      },
    );

    _activeStreams[sessionId] = subscription;
    onStateChanged();
  }

  /// Cancels an active stream for a specific session.
  Future<void> cancelStream(String sessionId) async {
    _cancelledSessions.add(sessionId);
    final sub = _activeStreams.remove(sessionId);
    if (sub != null) {
      await sub.cancel();
    }
    _cleanupStream(sessionId);
  }

  void _cleanupStream(String sessionId) {
    _activeStreams.remove(sessionId);
    _activeNotifiers.remove(sessionId);
    _activeStreamTexts.remove(sessionId);
    _activeStreamModels.remove(sessionId);
    onStateChanged();
  }

  /// Disposes of all active subscriptions.
  void dispose() {
    for (final sub in _activeStreams.values) {
      sub.cancel();
    }
    _activeStreams.clear();
  }
}
