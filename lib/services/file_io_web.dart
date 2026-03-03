import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Stub for web — file path operations are not supported.
/// On web, use `FileIOHelper.pickFileData()` which returns in-memory bytes.

Future<Uint8List> readFileBytes(String path) {
  throw UnsupportedError('File path access is not supported on web.');
}

Future<String> readFileString(String path) {
  throw UnsupportedError('File path access is not supported on web.');
}

Future<bool> fileExists(String path) async {
  return false;
}

Future<void> writeFileBytes(String path, Uint8List bytes) {
  throw UnsupportedError('File path access is not supported on web.');
}

/// Returns a placeholder image provider on web.
ImageProvider fileImageProvider(String path) {
  // On web, file paths are not accessible. Return a memory image placeholder.
  throw UnsupportedError('FileImage is not supported on web.');
}

/// Returns a placeholder widget on web.
Widget imageFileWidget(String path, {BoxFit fit = BoxFit.cover}) {
  return const SizedBox.shrink();
}

/// Stub — not needed on web. Use FileIOHelper.saveFile instead.
Future<String> saveToDownloads({
  required Uint8List bytes,
  required String filename,
}) {
  throw UnsupportedError('saveToDownloads is not supported on web.');
}

/// Stub — zlib decompression not available on web.
List<int> zlibDecode(List<int> data) {
  throw UnsupportedError('zlib decompression is not supported on web.');
}
