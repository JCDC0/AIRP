import 'package:airp/services/web_search_service.dart';
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
}