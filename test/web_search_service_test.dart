import 'package:airp/services/web_search_service.dart';
import 'package:airp/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'searchDDG uses the HTML endpoint and returns parsed results',
    () async {
      final client = MockClient((request) async {
        if (request.url.host == 'html.duckduckgo.com') {
          expect(request.method, 'GET');
          return http.Response(
            '''
<html>
  <body>
    <a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fstory&rut=abc">Example Story</a>
    <td class="result__snippet">Snippet <b>text</b></td>
  </body>
</html>
''',
            200,
          );
        }

        fail('Unexpected host ${request.url.host}');
      });

      final results = await WebSearchService.searchDDG(
        'airp web search',
        resultCount: 5,
        client: client,
      );

      expect(results, hasLength(1));
      expect(results.single.title, 'Example Story');
      expect(results.single.url, 'https://example.com/story');
      expect(results.single.snippet, 'Snippet text');
    },
  );

  test('searchDDG returns an empty list when the HTML endpoint has no results', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'html.duckduckgo.com');
      expect(request.method, 'GET');
      return http.Response('<html><body>captcha challenge</body></html>', 200);
    });

    final results = await WebSearchService.searchDDG(
      'airp web search',
      resultCount: 5,
      client: client,
    );

    expect(results, isEmpty);
  });

  group('buildWebSearchToolSpec', () {
    test('exposes an OpenAI-style function spec named web_search', () {
      final spec = WebSearchService.buildWebSearchToolSpec();
      expect(spec['type'], 'function');
      final fn = spec['function'] as Map<String, dynamic>;
      expect(fn['name'], WebSearchService.toolName);
      expect(fn['name'], 'web_search');
      final params = fn['parameters'] as Map<String, dynamic>;
      expect(params['type'], 'object');
      expect((params['required'] as List).single, 'query');
      expect((params['properties'] as Map).containsKey('query'), isTrue);
    });
  });

  group('buildGeminiFunctionDeclarations', () {
    test('returns a list with a single function declaration using OBJECT type', () {
      final decls = WebSearchService.buildGeminiFunctionDeclarations();
      expect(decls, hasLength(1));
      expect(decls.single['name'], 'web_search');
      final params = decls.single['parameters'] as Map<String, dynamic>;
      expect(params['type'], 'OBJECT');
    });
  });

  group('buildWebSearchSystemHint', () {
    test('mentions the tool name and the configured round limit', () {
      final hint = WebSearchService.buildWebSearchSystemHint(maxRounds: 3);
      expect(hint, contains('web_search'));
      expect(hint, contains('3 time(s)'));
    });

    test('uses the default round limit when none is provided', () {
      final hint = WebSearchService.buildWebSearchSystemHint();
      expect(hint, contains('${ApiConstants.defaultMaxSearchRounds} time(s)'));
    });
  });

  group('extractQueryFromToolArgs', () {
    test('parses a JSON object string', () {
      final q = WebSearchService.extractQueryFromToolArgs('{"query":"Mario"}');
      expect(q, 'Mario');
    });

    test('parses a Map directly', () {
      final q = WebSearchService.extractQueryFromToolArgs({'query': 'Luigi'});
      expect(q, 'Luigi');
    });

    test('returns null for missing query field', () {
      expect(WebSearchService.extractQueryFromToolArgs('{"other":1}'), isNull);
    });

    test('returns null for empty/blank query', () {
      expect(WebSearchService.extractQueryFromToolArgs('{"query":"  "}'), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(WebSearchService.extractQueryFromToolArgs('not json'), isNull);
    });

    test('returns null for null input', () {
      expect(WebSearchService.extractQueryFromToolArgs(null), isNull);
    });
  });

  group('executeSearch', () {
    test('returns a failure notice when the BYOK API key is empty', () async {
      final out = await WebSearchService.executeSearch(
        provider: SearchProvider.brave,
        query: 'test',
        braveApiKey: '',
        tavilyApiKey: '',
        serperApiKey: '',
        searxngUrl: '',
      );
      expect(out, contains('Brave API key not set'));
    });

    test('returns a failure notice when SearXNG URL is empty', () async {
      final out = await WebSearchService.executeSearch(
        provider: SearchProvider.searxng,
        query: 'test',
        braveApiKey: '',
        tavilyApiKey: '',
        serperApiKey: '',
        searxngUrl: '',
      );
      expect(out, contains('SearXNG instance URL not set'));
    });

    test('returns a failure notice for the provider (native) backend', () async {
      final out = await WebSearchService.executeSearch(
        provider: SearchProvider.provider,
        query: 'test',
        braveApiKey: 'k',
        tavilyApiKey: 'k',
        serperApiKey: 'k',
        searxngUrl: 'http://x:8080',
      );
      expect(out, contains('No BYOK search backend configured'));
    });
  });
}
