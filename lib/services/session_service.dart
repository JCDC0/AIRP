import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';

class SessionService {
  static const String sessionsKey = 'airp_sessions';

  List<ChatSessionData> savedSessions = [];
  Timer? _autoSaveTimer;
  VoidCallback? _pendingSave;
  final VoidCallback onStateChanged;

  SessionService({required this.onStateChanged});

  void dispose() {
    _autoSaveTimer?.cancel();
  }

  Future<void> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(sessionsKey);
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        savedSessions = jsonList
            .map((j) => dropEmptyAssistantPlaceholders(ChatSessionData.fromJson(j)))
            .toList();
        onStateChanged();
      } catch (e) {
        debugPrint("Error loading sessions: $e");
      }
    }
  }

  /// Removes assistant messages that carry no content of any kind.
  ///
  /// A streaming response is seeded as an empty assistant message and filled in
  /// as chunks arrive. If the app is killed mid-stream, or a completion lands
  /// while the conversation is not the active one and never reaches disk, that
  /// empty seed is what gets persisted. On reload it renders as a blank bubble
  /// between a user turn and the next one, so every later reply appears to sit
  /// one slot below the message that prompted it.
  ///
  /// Only messages with no text, no images, no usage and no regeneration
  /// history are dropped; anything a user could still read or restore is kept.
  @visibleForTesting
  static ChatSessionData dropEmptyAssistantPlaceholders(
    ChatSessionData session,
  ) {
    final kept = session.messages.where((m) {
      if (m.isUser) return true;
      return m.text.trim().isNotEmpty ||
          m.imagePaths.isNotEmpty ||
          m.usage != null ||
          m.regenerationVersions.isNotEmpty;
    }).toList();

    if (kept.length == session.messages.length) return session;

    return ChatSessionData(
      id: session.id,
      title: session.title,
      messages: kept,
      modelName: session.modelName,
      tokenCount: session.tokenCount,
      systemInstruction: session.systemInstruction,
      backgroundImage: session.backgroundImage,
      provider: session.provider,
      isBookmarked: session.isBookmarked,
    );
  }

  String _encodeSessionsPayload(List<ChatSessionData> sessions) {
    return jsonEncode(sessions.map((s) => s.toJson()).toList());
  }

  Future<bool> _tryPersistSessionsSnapshot(
    SharedPreferences prefs,
    String payload,
  ) async {
    try {
      return await prefs.setString(sessionsKey, payload);
    } catch (e) {
      debugPrint('Session persistence failed: $e');
      return false;
    }
  }

  Future<void> persistSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final originalPayload = _encodeSessionsPayload(savedSessions);
    if (await _tryPersistSessionsSnapshot(prefs, originalPayload)) {
      return;
    }

    final strippedRegenerationCount = savedSessions
        .expand((session) => session.messages)
        .where(ChatMessage.hasRegenerationHistory)
        .length;
    if (strippedRegenerationCount == 0) {
      debugPrint(
        'Unable to persist sessions. Browser/app storage quota may be exhausted.',
      );
      return;
    }

    final compacted = compactSessionsForStorage(savedSessions);
    final compactedPayload = _encodeSessionsPayload(compacted);
    final compactedWritten = await _tryPersistSessionsSnapshot(
      prefs,
      compactedPayload,
    );
    if (compactedWritten) {
      debugPrint(
        'Sessions persisted after compacting regeneration history due to storage limits '
        '(size ${originalPayload.length} -> ${compactedPayload.length}, '
        'sessions=${compacted.length}, strippedMessages=$strippedRegenerationCount).',
      );
      return;
    }

    debugPrint(
      'Unable to persist sessions. Browser/app storage quota may be exhausted.',
    );
  }

  @visibleForTesting
  static List<ChatSessionData> compactSessionsForStorage(
    List<ChatSessionData> sessions,
  ) {
    return sessions.map((session) {
      final compactMessages = session.messages
          .map(ChatMessage.stripRegenerationHistory)
          .toList();
      return ChatSessionData(
        id: session.id,
        title: session.title,
        messages: compactMessages,
        modelName: session.modelName,
        tokenCount: session.tokenCount,
        systemInstruction: session.systemInstruction,
        backgroundImage: session.backgroundImage,
        provider: session.provider,
        isBookmarked: session.isBookmarked,
      );
    }).toList();
  }

  void mergeSessions(List<ChatSessionData> incoming) {
    final existingIds = savedSessions.map((s) => s.id).toSet();
    for (final session in incoming) {
      if (!existingIds.contains(session.id)) {
        savedSessions.add(session);
        existingIds.add(session.id);
      }
    }
    onStateChanged();
    persistSessions();
  }

  Future<void> bookmarkSession(String sessionId, bool isBookmarked) async {
    final index = savedSessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;

    final session = savedSessions[index];
    final updatedSession = ChatSessionData(
      id: session.id,
      title: session.title,
      messages: session.messages,
      modelName: session.modelName,
      tokenCount: session.tokenCount,
      systemInstruction: session.systemInstruction,
      backgroundImage: session.backgroundImage,
      provider: session.provider,
      isBookmarked: isBookmarked,
    );

    savedSessions[index] = updatedSession;
    onStateChanged();
    await persistSessions();
  }

  Future<void> deleteSession(String id) async {
    savedSessions.removeWhere((s) => s.id == id);
    onStateChanged();
    await persistSessions();
  }

  void scheduleAutoSave(int debounceMs, VoidCallback saveAction) {
    _autoSaveTimer?.cancel();
    _pendingSave = saveAction;
    _autoSaveTimer = Timer(Duration(milliseconds: debounceMs), () {
      _pendingSave = null;
      saveAction();
    });
  }

  /// Runs a debounced save immediately instead of waiting out the timer.
  ///
  /// Autosave is debounced, and nothing flushes it when the process goes away,
  /// so a close within the debounce window drops the most recent turn. Call
  /// this when the app is backgrounded or detached.
  Future<void> flushPendingSave() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    final pending = _pendingSave;
    _pendingSave = null;
    if (pending == null) return;
    pending();
    await persistSessions();
  }

  void addMessageToSavedSession(String sessionId, ChatMessage message) {
    final idx = savedSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;

    final session = savedSessions[idx];
    final messages = List<ChatMessage>.from(session.messages);
    messages.add(message);

    savedSessions[idx] = ChatSessionData(
      id: session.id,
      title: session.title,
      messages: messages,
      modelName: session.modelName,
      tokenCount: session.tokenCount,
      systemInstruction: session.systemInstruction,
      backgroundImage: session.backgroundImage,
      provider: session.provider,
      isBookmarked: session.isBookmarked,
    );

    onStateChanged();
    persistSessions();
  }

  void finalizeBackgroundSession(
    String sessionId,
    String finalText,
    bool reasoningRecovered,
  ) {
    final idx = savedSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;

    final session = savedSessions[idx];
    if (session.messages.isEmpty) return;

    final messages = List<ChatMessage>.from(session.messages);
    if (messages.isNotEmpty && !messages.last.isUser) {
      final String textToSave = finalText;
      final lastMessage = messages.last;
      final updatedVersions = List<String>.from(
        lastMessage.regenerationVersions,
      );
      if (updatedVersions.isNotEmpty &&
          textToSave.isNotEmpty &&
          !updatedVersions.contains(textToSave)) {
        updatedVersions.add(textToSave);
      }
      messages[messages.length - 1] = lastMessage.copyWith(
        text: textToSave,
        reasoningRecovered: reasoningRecovered,
        clearContentNotifier: true,
        regenerationVersions: updatedVersions,
        currentVersionIndex: updatedVersions.isNotEmpty
            ? updatedVersions.length - 1
            : lastMessage.currentVersionIndex,
      );
    }

    savedSessions[idx] = ChatSessionData(
      id: session.id,
      title: session.title,
      messages: messages,
      modelName: session.modelName,
      tokenCount: session.tokenCount,
      systemInstruction: session.systemInstruction,
      backgroundImage: session.backgroundImage,
      provider: session.provider,
      isBookmarked: session.isBookmarked,
    );

    onStateChanged();
    persistSessions();
  }

  void saveCurrentSessionData(ChatSessionData sessionData) {
    savedSessions.removeWhere((s) => s.id == sessionData.id);
    savedSessions.insert(0, sessionData);
    onStateChanged();
    persistSessions();
  }

  String? getSessionBackgroundImage(String sessionId) {
    final existingIndex = savedSessions.indexWhere((s) => s.id == sessionId);
    if (existingIndex != -1) {
      return savedSessions[existingIndex].backgroundImage;
    }
    return null;
  }

  bool getSessionIsBookmarked(String sessionId) {
    final existingIndex = savedSessions.indexWhere((s) => s.id == sessionId);
    if (existingIndex != -1) {
      return savedSessions[existingIndex].isBookmarked;
    }
    return false;
  }

  void prependSession(ChatSessionData session) {
    savedSessions.insert(0, session);
    onStateChanged();
    persistSessions();
  }
}
