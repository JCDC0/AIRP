import 'dart:convert';
import 'package:airp/models/chat_models.dart';
import 'package:airp/services/chat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ToolDetectionResult', () {
    test('isToolCall / isError flags', () {
      const tc = ToolDetectionResult(type: 'tool_call', toolName: 'web_search');
      expect(tc.isToolCall, isTrue);
      expect(tc.isError, isFalse);

      const txt = ToolDetectionResult(type: 'text', text: 'hi');
      expect(txt.isToolCall, isFalse);
      expect(txt.isError, isFalse);

      const err = ToolDetectionResult(type: 'error', text: 'boom');
      expect(err.isError, isTrue);
      expect(err.isToolCall, isFalse);
    });
  });

  group('geminiToolResultContent', () {
    test('builds a user-role functionResponse part', () {
      final c = ChatApiService.geminiToolResultContent(
        functionName: 'web_search',
        resultText: 'some results',
      );
      expect(c['role'], 'user');
      final parts = c['parts'] as List;
      final fr = (parts.single as Map)['functionResponse'] as Map;
      expect(fr['name'], 'web_search');
      expect((fr['response'] as Map)['result'], 'some results');
    });
  });

  group('requestOpenAiCompatibleWithToolDetection', () {
    final history = <ChatMessage>[
      ChatMessage(text: 'hi', isUser: true),
    ];

    test('parses a tool_call response', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'tool_calls': [
                    {
                      'id': 'call_abc',
                      'type': 'function',
                      'function': {
                        'name': 'web_search',
                        'arguments': '{"query":"Mario"}',
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final res = await ChatApiService.requestOpenAiCompatibleWithToolDetection(
        apiKey: 'k',
        baseUrl: 'https://example.com/chat/completions',
        model: 'm',
        history: history,
        systemInstruction: '',
        userMessage: 'who is Mario?',
        tools: [
          {'type': 'function', 'function': {'name': 'web_search'}}
        ],
        client: client,
      );

      expect(res.isToolCall, isTrue);
      expect(res.toolCallId, 'call_abc');
      expect(res.toolName, 'web_search');
      expect(res.toolArguments, '{"query":"Mario"}');
    });

    test('parses a plain text answer', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'role': 'assistant', 'content': 'Hello!'}},
            ],
          }),
          200,
        );
      });

      final res = await ChatApiService.requestOpenAiCompatibleWithToolDetection(
        apiKey: 'k',
        baseUrl: 'https://example.com/chat/completions',
        model: 'm',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        tools: [],
        client: client,
      );

      expect(res.isToolCall, isFalse);
      expect(res.type, 'text');
      expect(res.text, 'Hello!');
    });

    test('returns an error result on non-200 status', () async {
      final client = MockClient((request) async {
        return http.Response('bad', 500);
      });

      final res = await ChatApiService.requestOpenAiCompatibleWithToolDetection(
        apiKey: 'k',
        baseUrl: 'https://example.com/chat/completions',
        model: 'm',
        history: history,
        systemInstruction: '',
        userMessage: 'hi',
        tools: [],
        client: client,
      );

      expect(res.isError, isTrue);
      expect(res.text, contains('500'));
    });
  });

  group('performGeminiFunctionDetection', () {
    final history = <ChatMessage>[
      ChatMessage(text: 'hi', isUser: true),
    ];

    test('parses a functionCall part into a tool_call', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'web_search',
                        'args': {'query': 'Mario'},
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final res = await ChatApiService.performGeminiFunctionDetection(
        apiKey: 'k',
        model: 'gemini-test',
        history: history,
        userMessage: 'who is Mario?',
        systemInstruction: '',
        functionDeclarations: [],
        client: client,
      );

      expect(res.isToolCall, isTrue);
      expect(res.toolName, 'web_search');
      expect(jsonDecode(res.toolArguments), {'query': 'Mario'});
    });

    test('parses a text part into a text answer', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [{'text': 'Hi there'}],
                },
              },
            ],
          }),
          200,
        );
      });

      final res = await ChatApiService.performGeminiFunctionDetection(
        apiKey: 'k',
        model: 'gemini-test',
        history: history,
        userMessage: 'hi',
        systemInstruction: '',
        functionDeclarations: [],
        client: client,
      );

      expect(res.type, 'text');
      expect(res.text, 'Hi there');
    });
  });
}
