import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';

class SessionService {
  static const String sessionsKey = 'airp_sessions';

  List<ChatSessionData> savedSessions = [];
  Timer? _autoSaveTimer;
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
        savedSessions =
            jsonList.map((j) => ChatSessionData.fromJson(j)).toList();
        onStateChanged();
      } catch (e) {
        debugPrint("Error loading sessions: $e");
      }
    }
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
    _autoSaveTimer = Timer(Duration(milliseconds: debounceMs), saveAction);
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
