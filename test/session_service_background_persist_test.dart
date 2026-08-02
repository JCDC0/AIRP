import 'dart:convert';

import 'package:airp/models/chat_models.dart';
import 'package:airp/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards that background stream results reach disk.
///
/// Both mutators used to update `savedSessions` in memory and return, so a
/// reply that landed while its conversation was not the active one was lost on
/// restart, leaving the prompt with a blank turn under it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  SessionService serviceWith(List<ChatMessage> messages) {
    final service = SessionService(onStateChanged: () {});
    service.savedSessions = [
      ChatSessionData(
        id: 's1',
        title: 'Conversation',
        messages: messages,
        modelName: 'model-a',
        tokenCount: 0,
        systemInstruction: 'sys',
      ),
    ];
    return service;
  }

  Future<List<dynamic>> readPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(SessionService.sessionsKey);
    expect(raw, isNotNull, reason: 'nothing was written to disk');
    return jsonDecode(raw!) as List<dynamic>;
  }

  test('finalizeBackgroundSession persists the completed reply', () async {
    final service = serviceWith([
      ChatMessage(text: 'Q1', isUser: true),
      ChatMessage(text: '', isUser: false),
    ]);

    service.finalizeBackgroundSession('s1', 'the full answer', false);
    await Future<void>.delayed(Duration.zero);

    final sessions = await readPersisted();
    final messages = (sessions.single as Map)['messages'] as List;
    expect(messages, hasLength(2));
    expect((messages.last as Map)['text'], 'the full answer');
  });

  test('addMessageToSavedSession persists the appended reply', () async {
    final service = serviceWith([ChatMessage(text: 'Q1', isUser: true)]);

    service.addMessageToSavedSession(
      's1',
      ChatMessage(text: 'grounded answer', isUser: false),
    );
    await Future<void>.delayed(Duration.zero);

    final sessions = await readPersisted();
    final messages = (sessions.single as Map)['messages'] as List;
    expect(messages, hasLength(2));
    expect((messages.last as Map)['text'], 'grounded answer');
    expect((messages.last as Map)['isUser'], isFalse);
  });

  test('flushPendingSave runs a debounced save immediately', () async {
    final service = SessionService(onStateChanged: () {});
    var saved = 0;

    service.scheduleAutoSave(60000, () {
      saved++;
      service.savedSessions = [
        ChatSessionData(
          id: 's1',
          title: 'Conversation',
          messages: [ChatMessage(text: 'Q1', isUser: true)],
          modelName: 'model-a',
          tokenCount: 0,
          systemInstruction: 'sys',
        ),
      ];
    });

    expect(saved, 0, reason: 'the debounce should not have fired yet');
    await service.flushPendingSave();

    expect(saved, 1);
    final sessions = await readPersisted();
    expect(sessions, hasLength(1));

    service.dispose();
  });

  test('flushPendingSave is a no-op with nothing pending', () async {
    final service = SessionService(onStateChanged: () {});

    await service.flushPendingSave();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SessionService.sessionsKey), isNull);
  });

  test('a fired debounce is not run twice by a later flush', () async {
    final service = SessionService(onStateChanged: () {});
    var saved = 0;

    service.scheduleAutoSave(1, () => saved++);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(saved, 1);

    await service.flushPendingSave();
    expect(saved, 1);

    service.dispose();
  });
}
