import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:airp/models/chat_models.dart';
import 'package:airp/providers/chat_provider.dart';
import 'package:airp/services/compaction_service.dart';
import 'package:airp/utils/constants.dart';

/// Guards the rule-driven compact system: the shared document the rules edit,
/// the rule list's persistence and legacy migration, and the extraction a
/// multi-conversation merge depends on.
///
/// These are the parts worth testing because they are pure. The request
/// plumbing around them is a thin wrapper over the existing tool-detection
/// path and is only exercisable against a live provider.
void main() {
  group('CompactDocument edits', () {
    test('replace creates a section then overwrites it', () {
      final doc = CompactDocument();
      doc.applyEdit(heading: 'Cast', content: 'Alice.');
      doc.applyEdit(heading: 'Cast', content: 'Alice and Bob.');

      expect(doc.sections.length, 1);
      expect(doc.sections.first.body, 'Alice and Bob.');
    });

    test('append extends what an earlier rule wrote', () {
      final doc = CompactDocument();
      doc.applyEdit(heading: 'Cast', content: 'Alice.');
      doc.applyEdit(
        heading: 'Cast',
        content: 'Bob.',
        mode: DocumentEditMode.append,
      );

      expect(doc.sections.first.body, 'Alice.\n\nBob.');
    });

    test(
      'headings match case-insensitively so rules do not fork a section',
      () {
        final doc = CompactDocument();
        doc.applyEdit(heading: 'Cast', content: 'Alice.');
        doc.applyEdit(heading: '  cast ', content: 'Bob.');

        expect(doc.sections.length, 1);
        expect(doc.sections.first.heading, 'Cast');
        expect(doc.sections.first.body, 'Bob.');
      },
    );

    test('remove deletes a section', () {
      final doc = CompactDocument();
      doc.applyEdit(heading: 'Cast', content: 'Alice.');
      doc.applyEdit(
        heading: 'Cast',
        content: '',
        mode: DocumentEditMode.remove,
      );

      expect(doc.sections, isEmpty);
    });

    test(
      'an empty heading is ignored rather than creating a blank section',
      () {
        final doc = CompactDocument();
        doc.applyEdit(heading: '   ', content: 'orphan');

        expect(doc.sections, isEmpty);
      },
    );
  });

  group('CompactDocument tool arguments', () {
    test('applies a well formed call', () {
      final doc = CompactDocument();
      final heading = doc.applyToolArguments(
        jsonEncode({'heading': 'Story So Far', 'content': 'It began.'}),
      );

      expect(heading, 'Story So Far');
      expect(doc.sections.first.body, 'It began.');
    });

    test('honours the mode field', () {
      final doc = CompactDocument();
      doc.applyEdit(heading: 'Threads', content: 'One.');
      doc.applyToolArguments(
        jsonEncode({'heading': 'Threads', 'content': 'Two.', 'mode': 'append'}),
      );

      expect(doc.sections.first.body, 'One.\n\nTwo.');
    });

    test('malformed JSON is skipped, not thrown', () {
      final doc = CompactDocument();

      expect(doc.applyToolArguments('{not json'), isNull);
      expect(doc.sections, isEmpty);
    });

    test('a missing heading is skipped', () {
      final doc = CompactDocument();

      expect(doc.applyToolArguments(jsonEncode({'content': 'x'})), isNull);
      expect(doc.sections, isEmpty);
    });

    test('a non-string content field does not throw', () {
      final doc = CompactDocument();
      final heading = doc.applyToolArguments(
        jsonEncode({'heading': 'Cast', 'content': 42}),
      );

      expect(heading, 'Cast');
      expect(doc.sections.first.body, '');
    });
  });

  group('CompactDocument round trip', () {
    test('render then parse preserves sections', () {
      final doc = CompactDocument();
      doc.applyEdit(heading: 'Story So Far', content: 'It began.');
      doc.applyEdit(heading: 'Cast', content: 'Alice.');

      final reparsed = CompactDocument.parse(doc.render());

      expect(reparsed.sections.map((s) => s.heading), ['Story So Far', 'Cast']);
      expect(reparsed.sections.last.body, 'Alice.');
    });

    test('text with no headings is kept, not dropped', () {
      final doc = CompactDocument.parse('just some prose with no heading');

      expect(doc.sections.length, 1);
      expect(doc.sections.first.body, 'just some prose with no heading');
    });

    test('empty sections are not rendered', () {
      final doc = CompactDocument();
      doc.applyEdit(heading: 'Cast', content: '   ');

      expect(doc.render(), '');
      expect(doc.isEmpty, isTrue);
    });
  });

  group('rule persistence', () {
    test('encode then decode round-trips a rule list', () {
      final rules = [
        CompactRule(id: 'a', name: 'One', prompt: 'p1'),
        CompactRule(id: 'b', name: 'Two', prompt: 'p2', enabled: false),
      ];

      final decoded = CompactionService.decodeRules(
        CompactionService.encodeRules(rules),
      );

      expect(decoded, isNotNull);
      expect(decoded!.length, 2);
      expect(decoded[1].enabled, isFalse);
      expect(decoded[1].prompt, 'p2');
    });

    test('decode returns null for nothing stored, so migration can run', () {
      expect(CompactionService.decodeRules(null), isNull);
      expect(CompactionService.decodeRules(''), isNull);
      expect(CompactionService.decodeRules('{not json'), isNull);
      expect(CompactionService.decodeRules('[]'), isNull);
    });

    test('duplicate and empty ids are replaced', () {
      // Two rules sharing an id would share one text controller in the drawer,
      // so edits would land in the wrong prompt.
      final decoded = CompactionService.decodeRules(
        jsonEncode([
          {'id': 'same', 'name': 'A', 'prompt': 'a'},
          {'id': 'same', 'name': 'B', 'prompt': 'b'},
          {'name': 'C', 'prompt': 'c'},
        ]),
      );

      expect(decoded!.map((r) => r.id).toSet().length, 3);
    });

    test('legacy migration carries the user edited prompts across', () {
      final rules = CompactionService.migrateLegacyRules(
        compressPrompt: 'MINE A',
        voiceSamplesPrompt: 'MINE B',
        summaryName: 'S',
        voicesName: 'V',
      );

      expect(rules.map((r) => r.prompt), ['MINE A', 'MINE B']);
      expect(rules.map((r) => r.id).toSet().length, 2);
    });
  });

  group('merge extraction', () {
    ChatSessionData session(String title, List<ChatMessage> messages) =>
        ChatSessionData(
          id: title,
          title: title,
          messages: messages,
          modelName: 'm',
          tokenCount: 0,
          systemInstruction: '',
        );

    test('recognises a chronicle block by its flag', () {
      final s = session('A', [
        ChatMessage(text: 'body', isUser: false, isChronicle: true),
      ]);

      expect(ChatProvider.sessionHasCompactBlock(s), isTrue);
      expect(ChatProvider.extractCompactBlocks(s), 'body');
    });

    test('recognises an old summary block by its decorated heading', () {
      // Conversations compacted before isChronicle existed must still merge.
      final s = session('A', [
        ChatMessage(text: '**[Summary]**\n\nIt began.', isUser: false),
      ]);

      expect(ChatProvider.sessionHasCompactBlock(s), isTrue);
      expect(ChatProvider.extractCompactBlocks(s), 'It began.');
    });

    test('joins several blocks from one conversation', () {
      final s = session('A', [
        ChatMessage(text: '**[Summary]**\n\nOne.', isUser: false),
        ChatMessage(text: '**[Voice Samples]**\n\nTwo.', isUser: false),
      ]);

      expect(ChatProvider.extractCompactBlocks(s), 'One.\n\nTwo.');
    });

    test('a plain conversation has nothing to extract', () {
      final s = session('A', [
        ChatMessage(text: 'hello', isUser: true),
        ChatMessage(text: 'hi', isUser: false),
      ]);

      expect(ChatProvider.sessionHasCompactBlock(s), isFalse);
      expect(ChatProvider.extractCompactBlocks(s), isNull);
    });

    test('a user message that merely looks like a block is not extracted', () {
      final s = session('A', [
        ChatMessage(text: '**[Summary]**\n\nnot mine', isUser: true),
      ]);

      expect(ChatProvider.sessionHasCompactBlock(s), isFalse);
    });

    test('transcript skips the chronicle so it is not re-summarised', () {
      final s = session('A', [
        ChatMessage(text: 'standing doc', isUser: false, isChronicle: true),
        ChatMessage(text: 'hello', isUser: true),
        ChatMessage(text: 'hi', isUser: false),
      ]);

      final transcript = ChatProvider.transcriptOfSession(s);

      expect(transcript.contains('standing doc'), isFalse);
      expect(transcript.contains('User: hello'), isTrue);
      expect(transcript.contains('Assistant: hi'), isTrue);
    });

    test('merge prompt labels each source in order', () {
      final prompt = CompactionService.buildMergePrompt(
        instruction: SummarizeDefaults.defaultMergePrompt,
        extracts: [
          (title: 'First', body: 'one'),
          (title: 'Second', body: 'two'),
        ],
      );

      expect(
        prompt.indexOf('SOURCE 1: First') < prompt.indexOf('SOURCE 2: Second'),
        isTrue,
      );
    });
  });

  group('rule prompt assembly', () {
    test('tells the first rule the document is empty', () {
      final prompt = CompactionService.buildRulePrompt(
        rule: CompactRule(id: 'a', name: 'One', prompt: 'do it'),
        document: CompactDocument(),
        transcript: 'User: hi',
      );

      expect(prompt.contains('empty, you are the first rule'), isTrue);
      expect(prompt.contains('do it'), isTrue);
      expect(prompt.contains('User: hi'), isTrue);
    });

    test('hands a later rule the document so it can revise it', () {
      final doc = CompactDocument();
      doc.applyEdit(heading: 'Cast', content: 'Alice.');

      final prompt = CompactionService.buildRulePrompt(
        rule: CompactRule(id: 'b', name: 'Two', prompt: 'revise'),
        document: doc,
        transcript: 'User: hi',
      );

      expect(prompt.contains('## Cast'), isTrue);
      expect(prompt.contains('Alice.'), isTrue);
    });

    test('a nameless rule still gets a usable fallback heading', () {
      expect(
        CompactionService.fallbackHeadingFor(
          CompactRule(id: 'a', name: '  ', prompt: 'p'),
        ),
        'Summary',
      );
    });
  });
}
