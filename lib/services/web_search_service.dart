import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

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
      final List<dynamic> results = (data['results'] as List<dynamic>?) ?? [];

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
            headers: {'X-API-KEY': apiKey, 'Content-Type': 'application/json'},
            body: jsonEncode({'q': query, 'num': resultCount}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[WebSearch] Serper returned ${response.statusCode}: ${response.body}',
        );
        return [];
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> results = (data['organic'] as List<dynamic>?) ?? [];

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
      final List<dynamic> results = (data['results'] as List<dynamic>?) ?? [];

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

  /// Scrapes DuckDuckGo's main HTML endpoint for [query].
  ///
  /// This is a best-effort, free approach that requires no API key. Results
  /// quality and availability may be inconsistent — DDG may block scraping.
  ///
  /// Returns up to [resultCount] results, or an empty list on failure.
  static Future<List<WebSearchResult>> searchDDG(
    String query, {
    int resultCount = 5,
    http.Client? client,
  }) async {
    final http.Client activeClient = client ?? http.Client();
    final bool ownsClient = client == null;

    try {
      final uri = Uri.https('html.duckduckgo.com', '/html/', {
        'q': query,
      });

      final response = await activeClient
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'text/html',
            },
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
    } finally {
      if (ownsClient) {
        activeClient.close();
      }
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

  // ─────────────────────────────────────────────────────────────────────────
  // AI Tool-Call Support
  // ─────────────────────────────────────────────────────────────────────────

  /// The function name exposed to the LLM.
  static const String toolName = 'web_search';

  /// Builds the OpenAI-style function tool specification that is sent to the
  /// LLM so it can decide to call [`toolName`] with its own query.
  ///
  /// This spec is provider-agnostic (OpenAI-compatible); Gemini uses a
  /// transformed version of it via [buildGeminiFunctionDeclarations].
  static Map<String, dynamic> buildWebSearchToolSpec() {
    return {
      'type': 'function',
      'function': {
        'name': toolName,
        'description':
            'Search the public web for up-to-date information that is outside '
            'your training data. Use this when the user asks about a specific '
            'person, character, event, product, or fact you are not confident '
            'about, or when the user explicitly requests current/web '
            'information. Do NOT use this for creative writing, opinions, '
            'math, or anything you already know well. Provide a concise, '
            'search-engine-friendly query string.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description':
                  'The search query. Keep it concise and keyword-focused. '
                  'Prefer the most distinctive noun phrase (e.g. a character '
                  'or entity name).',
            },
          },
          'required': ['query'],
        },
      },
    };
  }

  /// Builds the Gemini-style `functionDeclarations` tool payload equivalent to
  /// [buildWebSearchToolSpec] (used for BYOK backends on Gemini).
  static List<Map<String, dynamic>> buildGeminiFunctionDeclarations() {
    return [
      {
        'name': toolName,
        'description':
            'Search the public web for up-to-date information that is outside '
            'your training data. Use this when the user asks about a specific '
            'person, character, event, product, or fact you are not confident '
            'about, or when the user explicitly requests current/web '
            'information. Do NOT use this for creative writing, opinions, '
            'math, or anything you already know well. Provide a concise, '
            'search-engine-friendly query string.',
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            'query': {
              'type': 'STRING',
              'description':
                  'The search query. Keep it concise and keyword-focused. '
                  'Prefer the most distinctive noun phrase (e.g. a character '
                  'or entity name).',
            },
          },
          'required': ['query'],
        },
      },
    ];
  }

  /// The "secret" system-prompt block appended to the system instruction when
  /// the web_search tool is enabled. This tells the LLM the tool exists and
  /// how/when to use it — without surfacing it to the user.
  static String buildWebSearchSystemHint({int? maxRounds}) {
    final rounds = maxRounds ?? ApiConstants.defaultMaxSearchRounds;
    return '''

--- Web Search Tool (system) ---
You have access to a `web_search` tool. You MAY call it when:
- The user asks about a specific character, person, franchise, product, or entity you are NOT confident is in your training data.
- The user asks for current/recent events, prices, releases, or live data.
- The user explicitly asks you to look something up or verify a fact.

Rules:
- Issue the tool call FIRST, before answering, when you need it. Do not answer from memory if you are unsure and the tool is available.
- Provide a concise, keyword-focused query (e.g. a character or entity name). Do not include conversational filler.
- Do NOT call the tool for creative writing, roleplay, opinions, math, or anything you already know well.
- You may call the tool up to $rounds time(s) per user message if the first results are insufficient; otherwise answer directly from the results.
- After receiving results, synthesize a natural answer for the user. Do not dump raw JSON. Cite sources inline as plain text when relevant.
--- End Web Search Tool ---''';
  }

  /// Dispatches a single `web_search` tool call against the configured BYOK
  /// backend and returns a formatted context block (or a failure notice).
  ///
  /// [provider] selects the backend; [apiKey]/[searxngUrl] supply credentials.
  /// [query] is the LLM-generated search query. [resultCount] caps the number
  /// of results returned.
  ///
  /// Returns the formatted context string suitable for injection as a tool
  /// result message. On failure or empty results, returns a short notice so
  /// the LLM can fall back to its own knowledge.
  static Future<String> executeSearch({
    required SearchProvider provider,
    required String query,
    required String braveApiKey,
    required String tavilyApiKey,
    required String serperApiKey,
    required String searxngUrl,
    int resultCount = 5,
  }) async {
    List<WebSearchResult> results = [];

    switch (provider) {
      case SearchProvider.brave:
        if (braveApiKey.isEmpty) {
          return _toolFailureNotice(query, 'Brave API key not set.');
        }
        results = await searchBrave(query, braveApiKey, resultCount: resultCount);
      case SearchProvider.tavily:
        if (tavilyApiKey.isEmpty) {
          return _toolFailureNotice(query, 'Tavily API key not set.');
        }
        results = await searchTavily(query, tavilyApiKey, resultCount: resultCount);
      case SearchProvider.serper:
        if (serperApiKey.isEmpty) {
          return _toolFailureNotice(query, 'Serper API key not set.');
        }
        results = await searchSerper(query, serperApiKey, resultCount: resultCount);
      case SearchProvider.searxng:
        if (searxngUrl.isEmpty) {
          return _toolFailureNotice(query, 'SearXNG instance URL not set.');
        }
        results = await searchSearXNG(query, searxngUrl, resultCount: resultCount);
      case SearchProvider.duckduckgo:
        results = await searchDDG(query, resultCount: resultCount);
      case SearchProvider.provider:
        return _toolFailureNotice(query, 'No BYOK search backend configured.');
    }

    if (results.isEmpty) {
      return _toolFailureNotice(
        query,
        'The search returned 0 results or was blocked by the provider.',
      );
    }
    return formatResultsAsContextBlock(results, query: query);
  }

  /// Parses the JSON arguments string emitted by an OpenAI-compatible tool
  /// call and returns the `query` field, or `null` if it cannot be parsed.
  static String? extractQueryFromToolArgs(dynamic arguments) {
    try {
      if (arguments == null) return null;
      final Map<String, dynamic> args;
      if (arguments is String) {
        if (arguments.trim().isEmpty) return null;
        args = jsonDecode(arguments) as Map<String, dynamic>;
      } else if (arguments is Map) {
        args = Map<String, dynamic>.from(arguments);
      } else {
        return null;
      }
      final q = args['query']?.toString().trim();
      return (q == null || q.isEmpty) ? null : q;
    } catch (_) {
      return null;
    }
  }

  static String _toolFailureNotice(String query, String reason) {
    return 'Web search for "$query" failed: $reason '
        'Answer from your own knowledge if possible.';
  }
}
