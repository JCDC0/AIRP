import 'dart:convert';
import 'package:airp/models/chat_models.dart';
import 'package:airp/services/chat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Guards the streamed tool-detection path used when web search is enabled.
///
/// The non-streamed detection round it replaces delivered the whole answer,
/// reasoning included, as a single blob, so nothing streamed whenever web
/// search was on.
void main() {
  final history = <ChatMessage>[ChatMessage(text: 'hi', isUser: true)];

  String sse(List<Map<String, dynamic>> chunks) {
    final buf = StringBuffer();
    for (final c in chunks) {
      buf.writeln('data: ${jsonEncode(c)}');
    }
    buf.writeln('data: [DONE]');
    return buf.toString();
  }

  Map<String, dynamic> delta(Map<String, dynamic> d) => {
    'choices': [
      {'delta': d},
    ],
  };

  Future<ToolAwareStream> run(
    String body, {
    int status = 200,
    String baseUrl = 'https://api.example.com/v1/chat/completions',
    void Function(Map<String, dynamic> sentBody)? onRequest,
  }) {
    final client = MockClient((request) async {
      onRequest?.call(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(body, status);
    });
    return ChatApiService.streamOpenAiCompatibleWithToolDetection(
      apiKey: 'k',
      baseUrl: baseUrl,
      model: 'm',
      history: history,
      systemInstruction: 'sys',
      userMessage: 'who won?',
      tools: const [
        {'type': 'function'},
      ],
      client: client,
    );
  }

  group('streamOpenAiCompatibleWithToolDetection', () {
    test('classifies a tool call and streams nothing', () async {
      final result = await run(
        sse([
          delta({
            'tool_calls': [
              {
                'index': 0,
                'id': 'call_abc',
                'function': {
                  'name': 'web_search',
                  'arguments': '{"query":"Mario"}',
                },
              },
            ],
          }),
        ]),
      );

      expect(result.isToolCall, isTrue);
      expect(result.textStream, isNull);
      expect(result.toolCall!.toolName, 'web_search');
      expect(result.toolCall!.toolCallId, 'call_abc');
      expect(result.toolCall!.toolArguments, '{"query":"Mario"}');
    });

    test('reassembles tool arguments split across deltas', () async {
      final result = await run(
        sse([
          delta({
            'tool_calls': [
              {
                'index': 0,
                'id': 'call_1',
                'function': {'name': 'web_search', 'arguments': '{"que'},
              },
            ],
          }),
          delta({
            'tool_calls': [
              {
                'index': 0,
                'function': {'arguments': 'ry":"F1'},
              },
            ],
          }),
          delta({
            'tool_calls': [
              {
                'index': 0,
                'function': {'arguments': ' results"}'},
              },
            ],
          }),
        ]),
      );

      expect(result.isToolCall, isTrue);
      expect(result.toolCall!.toolArguments, '{"query":"F1 results"}');
    });

    test('streams a direct answer instead of buffering it', () async {
      final result = await run(
        sse([
          delta({'content': 'Red '}),
          delta({'content': 'Bull '}),
          delta({'content': 'won.'}),
        ]),
      );

      expect(result.isToolCall, isFalse);
      expect(result.isError, isFalse);
      expect(await result.textStream!.join(), 'Red Bull won.');
    });

    test('wraps streamed reasoning in think tags', () async {
      final result = await run(
        sse([
          delta({'reasoning': 'Let me check. '}),
          delta({'reasoning': 'Season 2024.'}),
          delta({'content': 'Red Bull won.'}),
        ]),
      );

      final text = await result.textStream!.join();
      expect(text, '<think>\nLet me check. Season 2024.\n</think>\nRed Bull won.');
    });

    test('closes an unterminated think block when the stream ends', () async {
      final result = await run(
        sse([
          delta({'reasoning': 'thinking only'}),
        ]),
      );

      final text = await result.textStream!.join();
      expect(text, '<think>\nthinking only\n</think>\n');
    });

    test('reads reasoning_content as well as reasoning', () async {
      final result = await run(
        sse([
          delta({'reasoning_content': 'trace'}),
          delta({'content': 'answer'}),
        ]),
      );

      expect(await result.textStream!.join(), contains('<think>\ntrace'));
    });

    test('surfaces a non-200 as an error, not a stream', () async {
      final result = await run('nope', status: 500);

      expect(result.isError, isTrue);
      expect(result.error, contains('500'));
      expect(result.textStream, isNull);
      expect(result.toolCall, isNull);
    });

    test('requests the reasoning trace on OpenRouter', () async {
      Map<String, dynamic>? sent;
      await run(
        sse([
          delta({'content': 'hi'}),
        ]),
        baseUrl: 'https://openrouter.ai/api/v1/chat/completions',
        onRequest: (b) => sent = b,
      );

      expect(sent!['include_reasoning'], isTrue);
      expect(sent!['stream'], isTrue);
      expect(sent!['tool_choice'], 'auto');
    });

    test('omits include_reasoning for non-OpenRouter endpoints', () async {
      Map<String, dynamic>? sent;
      await run(
        sse([
          delta({'content': 'hi'}),
        ]),
        onRequest: (b) => sent = b,
      );

      expect(sent!.containsKey('include_reasoning'), isFalse);
    });
  });

  group('splitGeminiThoughtParts', () {
    test('separates thought parts from the visible answer', () {
      final split = ChatApiService.splitGeminiThoughtParts([
        {'text': 'weighing the options', 'thought': true},
        {'text': 'The answer is 42.'},
      ]);

      expect(split.reasoning, 'weighing the options');
      expect(split.content, 'The answer is 42.');
    });

    test('leaves content untouched when nothing is marked as thought', () {
      final split = ChatApiService.splitGeminiThoughtParts([
        {'text': 'plain '},
        {'text': 'answer'},
      ]);

      expect(split.reasoning, isEmpty);
      expect(split.content, 'plain answer');
    });

    test('ignores non-text parts', () {
      final split = ChatApiService.splitGeminiThoughtParts([
        {
          'functionCall': {'name': 'web_search'},
        },
        {'text': 'visible'},
      ]);

      expect(split.content, 'visible');
      expect(split.reasoning, isEmpty);
    });
  });
}
