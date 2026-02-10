import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A service for securely storing sensitive data like API keys.
///
/// This class wraps the [FlutterSecureStorage] plugin to provide a simple
/// interface for encrypted key-value persistence.
class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Reads a value from secure storage.
  static Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  /// Writes an encrypted value to secure storage.
  static Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  /// Deletes a value from secure storage.
  static Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}
