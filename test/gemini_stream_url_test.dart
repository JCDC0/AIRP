import 'package:airp/services/chat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildGeminiStreamUrl', () {
    test('requests SSE framing', () {
      final url = ChatApiService.buildGeminiStreamUrl(
        'models/gemini-3-flash-preview',
        'test-key',
      );

      // Without alt=sse the endpoint returns a pretty-printed JSON array
      // instead of Server-Sent Events. No line then carries the `data: `
      // prefix the parser looks for, every line is skipped, and the stream
      // completes empty behind an HTTP 200. Regression guard for 0.7.27.
      expect(url.queryParameters['alt'], 'sse');
    });

    test('strips the models/ prefix from the model id', () {
      final url = ChatApiService.buildGeminiStreamUrl(
        'models/gemma-3-27b-it',
        'k',
      );
      expect(url.path, '/v1beta/models/gemma-3-27b-it:streamGenerateContent');
    });

    test('accepts a bare model id', () {
      final url = ChatApiService.buildGeminiStreamUrl('gemini-3-pro', 'k');
      expect(url.path, '/v1beta/models/gemini-3-pro:streamGenerateContent');
    });

    test('trims surrounding whitespace from the key', () {
      final url = ChatApiService.buildGeminiStreamUrl('m', '  spaced-key\n');
      expect(url.queryParameters['key'], 'spaced-key');
    });

    test('targets the v1beta generativelanguage host', () {
      final url = ChatApiService.buildGeminiStreamUrl('m', 'k');
      expect(url.scheme, 'https');
      expect(url.host, 'generativelanguage.googleapis.com');
    });
  });

  group('emptyGeminiStreamNotice', () {
    test('attributes a prompt block to its reason', () {
      final notice = ChatApiService.emptyGeminiStreamNotice('SAFETY', null);
      expect(notice, contains('Blocked'));
      expect(notice, contains('SAFETY'));
    });

    test('prefers the block reason over the finish reason', () {
      final notice = ChatApiService.emptyGeminiStreamNotice(
        'OTHER',
        'MAX_TOKENS',
      );
      expect(notice, contains('OTHER'));
      expect(notice, isNot(contains('MAX_TOKENS')));
    });

    test('reports a non-STOP finish reason', () {
      final notice = ChatApiService.emptyGeminiStreamNotice(null, 'RECITATION');
      expect(notice, contains('RECITATION'));
    });

    test('falls back to a generic notice for a clean but empty stop', () {
      final notice = ChatApiService.emptyGeminiStreamNotice(null, 'STOP');
      expect(notice, contains('no content'));
      expect(notice, isNot(contains('STOP')));
    });

    test('falls back to a generic notice when nothing was reported', () {
      expect(
        ChatApiService.emptyGeminiStreamNotice(null, null),
        contains('no content'),
      );
    });
  });
}
