import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A result from any web search backend.
class WebSearchResult {
  final String title;
  final String url;
  final String snippet;

  const WebSearchResult({
    required this.title,
    required this.url,
    required this.snippet,
  });
}

/// Provides static helpers for querying BYOK web search backends and
/// formatting their results into a context block prepended to the user message.
class WebSearchService {
  static const Duration _timeout = Duration(seconds: 10);

  // ─────────────────────────────────────────────────────────────────────────
  // Brave Search
  // ─────────────────────────────────────────────────────────────────────────

  /// Queries the [Brave Search API](https://api.search.brave.com) with the
  /// given [query] using a BYOK [apiKey].
  ///
  /// Returns up to [resultCount] results, or an empty list on failure.
  static Future<List<WebSearchResult>> searchBrave(
    String query,
    String apiKey, {
    int resultCount = 5,
  }) async {
    try {
      final uri = Uri.https('api.search.brave.com', '/res/v1/web/search', {
        'q': query,
        'count': resultCount.toString(),
      });

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Accept-Encoding': 'gzip',
              'X-Subscription-Token': apiKey,
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[WebSearch] Brave returned ${response.statusCode}: ${response.body}',
        );
        return [];
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> results =
          (data['web']?['results'] as List<dynamic>?) ?? [];

      return results
          .take(resultCount)
          .map(
            (r) => WebSearchResult(
              title: (r['title'] as String?) ?? '',
              url: (r['url'] as String?) ?? '',
              snippet: (r['description'] as String?) ?? '',
            ),
          )
          .where((r) => r.url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[WebSearch] Brave error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tavily  (AI-optimised search)
  // ─────────────────────────────────────────────────────────────────────────

  /// Queries the [Tavily Search API](https://tavily.com). Tavily returns
  /// results that are pre-summarised and optimised for LLM context injection.
  ///
  /// Returns up to [resultCount] results, or an empty list on failure.
  static Future<List<WebSearchResult>> searchTavily(
    String query,
    String apiKey, {
    int resultCount = 5,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.tavily.com/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'api_key': apiKey,
              'query': query,
              'max_results': resultCount,
              'search_depth': 'basic',
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[WebSearch] Tavily returned ${response.statusCode}: ${response.body}',
        );
        return [];
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> results =
          (data['results'] as List<dynamic>?) ?? [];

      return results
          .take(resultCount)
          .map(
            (r) => WebSearchResult(
              title: (r['title'] as String?) ?? '',
              url: (r['url'] as String?) ?? '',
              snippet: (r['content'] as String?) ?? '',
            ),
          )
          .where((r) => r.url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[WebSearch] Tavily error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Serper.dev  (Google Search results)
  // ─────────────────────────────────────────────────────────────────────────

  /// Queries the [Serper.dev API](https://serper.dev) which returns Google
  /// Search results in a clean JSON format.
  ///
  /// Returns up to [resultCount] results, or an empty list on failure.
  static Future<List<WebSearchResult>> searchSerper(
    String query,
    String apiKey, {
    int resultCount = 5,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://google.serper.dev/search'),
            headers: {
              'X-API-KEY': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'q': query,
              'num': resultCount,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[WebSearch] Serper returned ${response.statusCode}: ${response.body}',
        );
        return [];
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> results =
          (data['organic'] as List<dynamic>?) ?? [];

      return results
          .take(resultCount)
          .map(
            (r) => WebSearchResult(
              title: (r['title'] as String?) ?? '',
              url: (r['link'] as String?) ?? '',
              snippet: (r['snippet'] as String?) ?? '',
            ),
          )
          .where((r) => r.url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[WebSearch] Serper error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SearXNG
  // ─────────────────────────────────────────────────────────────────────────

  /// Queries a self-hosted SearXNG instance at [instanceUrl].
  ///
  /// [instanceUrl] may be either `IP:port` (e.g. `192.168.1.10:8080`) or a
  /// full URL (e.g. `http://192.168.1.10:8080`). The method normalises it.
  ///
  /// Returns up to [resultCount] results, or an empty list on failure.
  static Future<List<WebSearchResult>> searchSearXNG(
    String query,
    String instanceUrl, {
    int resultCount = 5,
  }) async {
    try {
      final base = _normaliseUrl(instanceUrl);
      final uri = Uri.parse(
        '$base/search?q=${Uri.encodeComponent(query)}&format=json',
      );

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[WebSearch] SearXNG returned ${response.statusCode}: ${response.body}',
        );
        return [];
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> results =
          (data['results'] as List<dynamic>?) ?? [];

      return results
          .take(resultCount)
          .map(
            (r) => WebSearchResult(
              title: (r['title'] as String?) ?? '',
              url: (r['url'] as String?) ?? '',
              snippet: (r['content'] as String?) ?? '',
            ),
          )
          .where((r) => r.url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[WebSearch] SearXNG error: $e');
      return [];
    }
  }

  /// Attempts to reach the SearXNG instance and verify it returns JSON search
  /// results. Returns `true` if the instance responded successfully.
  static Future<bool> validateSearXNGInstance(String instanceUrl) async {
    try {
      final base = _normaliseUrl(instanceUrl);
      final uri = Uri.parse('$base/search?q=test&format=json');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data.containsKey('results');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DuckDuckGo  (HTML scraping fallback)
  // ─────────────────────────────────────────────────────────────────────────

  /// Scrapes DuckDuckGo's HTML-lite endpoint for [query].
  ///
  /// This is a best-effort, free approach that requires no API key. Results
  /// quality and availability may be inconsistent — DDG may block scraping.
  ///
  /// Returns up to [resultCount] results, or an empty list on failure.
  static Future<List<WebSearchResult>> searchDDG(
    String query, {
    int resultCount = 5,
  }) async {
    try {
      final uri = Uri.https('lite.duckduckgo.com', '/lite/', {});

      final response = await http
          .post(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'text/html',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: 'q=$query',
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[WebSearch] DDG returned ${response.statusCode}');
        return [];
      }

      return _parseDDGHtml(response.body, resultCount);
    } catch (e) {
      debugPrint('[WebSearch] DDG error: $e');
      return [];
    }
  }

  /// Parses DDG HTML-lite results. Handles both `<a>` and `<td>` snippet
  /// containers, and extracts real URLs from DDG's redirect wrapper.
  static List<WebSearchResult> _parseDDGHtml(String html, int limit) {
    final List<WebSearchResult> results = [];

    // Title + URL: <a class="result__a" href="...">title</a>
    final titleLinkRe = RegExp(
      r'<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    // Snippet: <a class="result__snippet"...>...</a>  OR
    //          <td class="result__snippet"...>...</td>
    final snippetRe = RegExp(
      r'class="result__snippet"[^>]*>(.*?)</(?:a|td)>',
      dotAll: true,
    );

    final titleMatches = titleLinkRe.allMatches(html).toList();
    final snippetMatches = snippetRe.allMatches(html).toList();

    for (int i = 0; i < titleMatches.length && results.length < limit; i++) {
      String rawUrl = titleMatches[i].group(1) ?? '';

      // DDG wraps URLs in a redirect: //duckduckgo.com/l/?uddg=ACTUAL_URL&...
      final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(rawUrl);
      if (uddgMatch != null) {
        rawUrl = Uri.decodeComponent(uddgMatch.group(1) ?? rawUrl);
      }

      final url = _decodeHtmlEntities(rawUrl);
      final title = _stripHtmlTags(titleMatches[i].group(2) ?? '');
      final snippet = i < snippetMatches.length
          ? _stripHtmlTags(snippetMatches[i].group(1) ?? '')
          : '';

      if (url.startsWith('http')) {
        results.add(WebSearchResult(title: title, url: url, snippet: snippet));
      }
    }

    debugPrint('[WebSearch] DDG scraped ${results.length} results');
    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  static String _stripHtmlTags(String input) =>
      input.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  static String _decodeHtmlEntities(String input) => input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&nbsp;', ' ');

  /// Normalises a user-supplied URL so that it always has a scheme and no
  /// trailing slash.
  static String _normaliseUrl(String raw) {
    String trimmed = raw.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Context Formatting
  // ─────────────────────────────────────────────────────────────────────────

  /// Formats a list of [results] into a structured context block that is
  /// prepended to the user message before sending to the AI.
  ///
  /// Example output:
  /// ```
  /// [WEB_CONTEXT — 3 results for "dart flutter"]
  /// 1. Flutter - Build apps for any screen
  ///    URL: https://flutter.dev
  ///    flutter.dev is Google's UI toolkit for building...
  ///
  /// 2. ...
  /// [/WEB_CONTEXT]
  /// ```
  static String formatResultsAsContextBlock(
    List<WebSearchResult> results, {
    String? query,
  }) {
    if (results.isEmpty) return '';

    final header = query != null
        ? '[WEB_CONTEXT — ${results.length} result${results.length == 1 ? '' : 's'} for "$query"]'
        : '[WEB_CONTEXT — ${results.length} result${results.length == 1 ? '' : 's'}]';

    final buffer = StringBuffer()..writeln(header);
    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      buffer.writeln('${i + 1}. ${r.title}');
      buffer.writeln('   URL: ${r.url}');
      if (r.snippet.isNotEmpty) buffer.writeln('   ${r.snippet}');
      if (i < results.length - 1) buffer.writeln();
    }
    buffer.write('[/WEB_CONTEXT]');

    return buffer.toString();
  }
}
