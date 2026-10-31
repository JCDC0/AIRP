import 'package:flutter_test/flutter_test.dart';
import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/services/session_service.dart';
import 'package:airp/services/compaction_service.dart';

/// Guards the chronicle: a long-term narrative block pinned into a
/// conversation, carried across compactions, and refused by every delete and
/// overwrite path.
///
/// The repo's own warning applies here: a flag plus a provider guard passes
/// every unit test while the chronicle still falls out of the outbound history
/// and never reaches the wire. The `pinChronicle` group below is the one that
/// matters most, because it tests the window the request is actually built
/// from.
void main() {
  ChatMessage chronicle([String text = 'The story so far.']) =>
      ChatMessage(text: text, isUser: false, isChronicle: true);

  List<ChatMessage> conversation(int turns) => [
    for (var t = 1; t <= turns; t++) ...[
      ChatMessage(text: 'User$t', isUser: true),
      ChatMessage(text: 'AI$t', isUser: false),
    ],
  ];

  List<String> labels(List<ChatMessage> messages) =>
      messages.map((m) => m.text).toList();

  group('isChronicle survives serialization and copyWith', () {
    test('round-trips through JSON', () {
      final restored = ChatMessage.fromJson(chronicle().toJson());
      expect(restored.isChronicle, isTrue);
    });

    test('defaults to false for sessions written before the field existed', () {
      final restored = ChatMessage.fromJson({'text': 'hi', 'isUser': false});
      expect(restored.isChronicle, isFalse);
    });

    test('survives copyWith, which is how carried blocks are rebuilt', () {
      final copied = chronicle().copyWith(clearContentNotifier: true);
      expect(copied.isChronicle, isTrue);
    });

    test('survives stripRegenerationHistory', () {
      final withHistory = chronicle().copyWith(
        regenerationVersions: const ['a', 'b'],
        currentVersionIndex: 1,
      );
      final stripped = ChatMessage.stripRegenerationHistory(withHistory);
      expect(stripped.isChronicle, isTrue);
    });

    test('a malformed timestamp does not throw the whole decode away', () {
      final restored = ChatMessage.fromJson({
        'text': 'hi',
        'isUser': false,
        'timestamp': 'not-a-date',
      });
      expect(restored.text, 'hi');
    });
  });

  group('pinChronicle keeps the block in the outbound window', () {
    test('prepends a chronicle that fell before the window', () {
      final messages = [chronicle(), ...conversation(3)];

      // historyLimit 2: the window would start at index 5 and contain only the
      // last two messages, leaving the chronicle out of the request.
      final pinned = ChatProvider.pinChronicle(messages, 5);

      expect(labels(pinned), ['The story so far.', 'User3', 'AI3']);
    });

    test('still sends the chronicle when history is off entirely', () {
      final messages = [chronicle(), ...conversation(3)];

      // enableMsgHistory == false zeroes the limit, so startIndex is the whole
      // length and the window is empty. This is the case that made the feature
      // silently do nothing.
      final pinned = ChatProvider.pinChronicle(messages, messages.length);

      expect(labels(pinned), ['The story so far.']);
    });

    test('does not duplicate a chronicle already inside the window', () {
      final messages = [chronicle(), ...conversation(1)];

      final pinned = ChatProvider.pinChronicle(messages, 0);

      expect(labels(pinned), ['The story so far.', 'User1', 'AI1']);
    });

    test('is a plain tail window when there is no chronicle', () {
      // conversation(3) is six messages, so the window starts at index 4.
      final pinned = ChatProvider.pinChronicle(conversation(3), 4);

      expect(labels(pinned), ['User3', 'AI3']);
    });
  });

  group('collectTrailingMessages seeding a branch', () {
    test('never carries a chronicle as an ordinary block', () {
      final messages = [chronicle(), ...conversation(2)];

      final carried = ChatProvider.collectTrailingMessages(messages, 10);

      expect(carried.any((m) => m.isChronicle), isFalse);
      expect(labels(carried), ['User1', 'AI1', 'User2', 'AI2']);
    });

    test('counts blocks after excluding the chronicle', () {
      final messages = [chronicle(), ...conversation(3)];

      final carried = ChatProvider.collectTrailingMessages(messages, 2);

      expect(labels(carried), ['User3', 'AI3']);
    });

    test('drops stale usage so the context meter does not re-anchor', () {
      final messages = [
        ChatMessage(text: 'User1', isUser: true),
        ChatMessage(
          text: 'AI1',
          isUser: false,
          usage: const {'prompt_tokens': 90000},
        ),
      ];

      final carried = ChatProvider.collectTrailingMessages(messages, 2);

      expect(carried.every((m) => m.usage == null), isTrue);
    });

    test('returns nothing when the conversation is only a chronicle', () {
      final carried = ChatProvider.collectTrailingMessages([chronicle()], 6);

      expect(carried, isEmpty);
    });
  });

  group('a chronicle is not mistaken for a stranded placeholder', () {
    ChatSessionData sessionWith(List<ChatMessage> messages) => ChatSessionData(
      id: 's1',
      title: 'T',
      messages: messages,
      modelName: 'm',
      tokenCount: 0,
      systemInstruction: '',
    );

    test('an emptied chronicle is kept on load', () {
      final cleaned = SessionService.dropEmptyAssistantPlaceholders(
        sessionWith([chronicle(''), ChatMessage(text: 'User1', isUser: true)]),
      );

      expect(cleaned.messages.any((m) => m.isChronicle), isTrue);
    });

    test('a genuine empty placeholder is still dropped', () {
      final cleaned = SessionService.dropEmptyAssistantPlaceholders(
        sessionWith([
          ChatMessage(text: 'User1', isUser: true),
          ChatMessage(text: '', isUser: false),
        ]),
      );

      expect(cleaned.messages.length, 1);
    });
  });

  group('documentForNextRule folds a live edit back in', () {
    CompactDocument docWith(String heading, String body) => CompactDocument(
      sections: [DocumentSection(heading: heading, body: body)],
    );

    test('passes the document through when nothing is pending', () {
      final doc = docWith('Cast', 'Alice.');

      expect(ChatProvider.documentForNextRule(doc, null), same(doc));
    });

    test('a pending edit becomes the base the next rule revises', () {
      // The bug this guards: the edit used to sit pending until the run
      // finished, then replace everything the later rules had written.
      final next = ChatProvider.documentForNextRule(
        docWith('Cast', 'Alice.'),
        '''
## Cast

Alice, and Bob.

## Threads

The locked door.''',
      );

      expect(next.sections.map((s) => s.heading), ['Cast', 'Threads']);
      expect(next.sections.first.body, 'Alice, and Bob.');
    });

    test('a later rule still revises a section the user edited', () {
      final next = ChatProvider.documentForNextRule(CompactDocument(), '''
## Cast

Alice.''');

      next.applyEdit(heading: 'cast', content: 'Alice and Bob.');

      expect(next.sections.length, 1);
      expect(next.sections.single.body, 'Alice and Bob.');
    });

    test('an emptied box clears the document rather than being ignored', () {
      final next = ChatProvider.documentForNextRule(
        docWith('Cast', 'Alice.'),
        '',
      );

      expect(next.isEmpty, isTrue);
    });
  });

  group('orderForMerge reads sources in story order', () {
    ChatSessionData session(String id, String title) => ChatSessionData(
      id: id,
      title: title,
      messages: [],
      modelName: 'm',
      tokenCount: 0,
      systemInstruction: '',
    );

    test('sorts by creation time, not by what was opened last', () {
      // savedSessions is ordered by last autosave, so merely opening the
      // middle generation to see what it is used to make the merge treat it as
      // the newest source and prefer it when reconciling contradictions.
      final ordered = ChatProvider.orderForMerge([
        session('1700000002000', 'Gen 2'),
        session('1700000003000', 'Gen 3'),
        session('1700000001000', 'Gen 1'),
      ]);

      expect(ordered.map((s) => s.title), ['Gen 1', 'Gen 2', 'Gen 3']);
    });

    test('an id that is not a timestamp sorts first', () {
      final ordered = ChatProvider.orderForMerge([
        session('1700000001000', 'Numbered'),
        session('legacy', 'Legacy'),
      ]);

      expect(ordered.first.title, 'Legacy');
    });
  });
}
