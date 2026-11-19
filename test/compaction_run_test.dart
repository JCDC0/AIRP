import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/providers/settings_provider.dart';
import 'package:airp/services/chat_api_service.dart';
import 'package:airp/services/compaction_service.dart';

/// Drives whole compaction runs through [ChatProvider.compactWithRules] with
/// the network replaced, covering what the unit tests on [CompactDocument]
/// cannot: that Stop ends a run without branching, and that a seeded
/// chronicle run revises the old section and records both versions for the
/// review popup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatProvider chat;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    chat = ChatProvider()..updateSettings(SettingsProvider());
    await Future<void>.delayed(Duration.zero);
  });

  ChatSessionData session(List<ChatMessage> messages) => ChatSessionData(
    id: '100',
    title: 'Story',
    messages: messages,
    modelName: 'm',
    tokenCount: 0,
    systemInstruction: '',
  );

  final rule = CompactRule(
    id: 'r1',
    name: 'Relationships and Dynamics',
    prompt: 'Track who stands where with whom.',
  );

  ToolDetectionResult edit(String heading, String content) =>
      ToolDetectionResult(
        type: 'tool_call',
        toolName: CompactionService.toolName,
        toolArguments: jsonEncode({
          'heading': heading,
          'content': content,
          'mode': 'replace',
        }),
      );

  test('Stop in the chat input ends a run and changes nothing', () async {
    chat.loadSession(
      session([
        ChatMessage(text: 'We meet Wu.', isUser: true),
        ChatMessage(text: 'Wu names his price.', isUser: false),
      ]),
    );
    final pending = Completer<ToolDetectionResult?>();
    chat.oneShotDetectOverride = (_) => pending.future;

    final run = chat.compactWithRules(rules: [rule], asChronicle: true);
    await Future<void>.delayed(Duration.zero);
    expect(chat.isCompacting, isTrue);
    expect(chat.isLoading, isTrue, reason: 'the input shows Stop, not Send');

    chat.cancelGeneration();

    expect(await run, ChatProvider.compactStoppedNotice);
    expect(chat.isCompacting, isFalse);
    expect(chat.currentSessionId, '100', reason: 'no branch was made');
    expect(chat.messages, hasLength(2));
    expect(chat.takePointAtChronicle(), isFalse);
  });

  test(
    'a seeded run revises the old section under a drifted heading',
    () async {
      chat.loadSession(
        session([
          ChatMessage(
            text:
                '**[Chronicle]**\n\n## Relationships and Dynamics\n\n'
                'Schiwi distrusts Wu.',
            isUser: false,
            isChronicle: true,
          ),
          ChatMessage(text: 'Wu saves Schiwi.', isUser: true),
          ChatMessage(text: 'Schiwi thanks him.', isUser: false),
        ]),
      );
      chat.oneShotDetectOverride = (_) async =>
          edit('Relationships & Dynamics', 'Schiwi has come to trust Wu.');

      expect(
        await chat.compactWithRules(
          rules: [rule],
          asChronicle: true,
          blockCount: 0,
        ),
        isNull,
      );

      expect(
        chat.lastCompactBefore,
        '## Relationships and Dynamics\n\nSchiwi distrusts Wu.',
      );
      expect(
        chat.lastCompactAfter,
        '## Relationships and Dynamics\n\nSchiwi has come to trust Wu.',
      );
      expect(chat.currentChronicle!.text, isNot(contains('distrusts')));

      // The new conversation opens pointing at its chronicle, once.
      expect(chat.takePointAtChronicle(), isTrue);
      expect(chat.takePointAtChronicle(), isFalse);
    },
  );
}
