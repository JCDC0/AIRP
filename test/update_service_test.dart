import 'package:flutter_test/flutter_test.dart';
import 'package:airp/services/update_service.dart';

void main() {
  group('UpdateService version comparison', () {
    test('detects newer major version', () {
      expect(UpdateService.isNewerVersion('1.0.0', '0.8.0'), isTrue);
    });

    test('detects newer minor version', () {
      expect(UpdateService.isNewerVersion('0.9.0', '0.8.0'), isTrue);
    });

    test('detects newer patch version', () {
      expect(UpdateService.isNewerVersion('0.8.1', '0.8.0'), isTrue);
    });

    test('returns false for same version', () {
      expect(UpdateService.isNewerVersion('0.8.0', '0.8.0'), isFalse);
    });

    test('returns false for older version', () {
      expect(UpdateService.isNewerVersion('0.7.30', '0.8.0'), isFalse);
    });

    test('handles different length version strings', () {
      expect(UpdateService.isNewerVersion('0.8.1', '0.8'), isTrue);
      expect(UpdateService.isNewerVersion('0.8', '0.8.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.8.0.1', '0.8.0'), isTrue);
    });

    test('handles four-component versions', () {
      expect(UpdateService.isNewerVersion('0.7.30.9', '0.7.30.8'), isTrue);
      expect(UpdateService.isNewerVersion('0.7.30.8', '0.7.30.8'), isFalse);
      expect(UpdateService.isNewerVersion('0.7.30.7', '0.7.30.8'), isFalse);
    });

    test('handles non-numeric parts gracefully', () {
      expect(UpdateService.isNewerVersion('0.8.0', '0.8.beta'), isTrue);
    });
  });
}
