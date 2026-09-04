import 'package:flutter_test/flutter_test.dart';

import 'package:airp/services/chat_api_service.dart';

void main() {
  group('describeCredential', () {
    test('names an empty slot rather than leaving the 401 to speak for it', () {
      final note = ChatApiService.describeCredential('');
      expect(note, contains('sent no API key'));
    });

    test('a whitespace-only key is reported as such', () {
      expect(
        ChatApiService.describeCredential('   '),
        contains('entirely whitespace'),
      );
    });

    test('a real key is described by length, never by value', () {
      const key = 'sk-or-v1-0123456789abcdef';
      final note = ChatApiService.describeCredential(key);

      expect(note, contains('${key.length} characters long'));
      expect(note, isNot(contains(key)));
      expect(note, isNot(contains('0123456789')));
    });

    test('an embedded space is called out, since it truncates the token', () {
      final note = ChatApiService.describeCredential('sk-or-v1 abcdef');
      expect(note, contains('containing a space'));
      expect(note, isNot(contains('abcdef')));
    });

    test('surrounding whitespace is reported without the key', () {
      final note = ChatApiService.describeCredential('  sk-or-v1-abc  ');
      expect(note, contains('surrounding whitespace'));
      expect(note, contains('12 characters long'));
      expect(note, isNot(contains('sk-or-v1-abc')));
    });
  });
}
