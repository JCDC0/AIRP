import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

// Conditionally import dart:io — this import is a no-op on web.
// All dart:io usage is guarded behind `!kIsWeb`.
import 'file_io_native.dart' if (dart.library.html) 'file_io_web.dart'
    as platform_io;

/// A record type returned by [FileIOHelper.pickFileData].
///
/// Contains the file [name] (with extension), raw [bytes], and optionally
/// the decoded UTF-8 [text] content.
typedef PickedFileData = ({String name, Uint8List bytes, String? text});

/// Centralised, web-safe file I/O helper.
///
/// On native platforms, uses `dart:io` `File` for reading/writing.
/// On web, uses `FilePicker`'s in-memory `bytes` and browser downloads.
/// All callers should use this instead of `dart:io` directly.
class FileIOHelper {
  FileIOHelper._();

  // ─── Pick & Read ────────────────────────────────────────────────────────

  /// Picks a single file and returns its text content as a [String].
  ///
  /// Returns `null` if the user cancels or the file cannot be read.
  static Future<String?> pickAndReadString({
    List<String>? extensions,
    String? dialogTitle,
  }) async {
    final data = await pickFileData(
      extensions: extensions,
      dialogTitle: dialogTitle,
    );
    return data?.text;
  }

  /// Picks a single file and returns its [name], [bytes], and decoded [text].
  ///
  /// On web, bytes come from `PlatformFile.bytes`.
  /// On native, bytes are read from disk via `File(path).readAsBytes()`.
  static Future<PickedFileData?> pickFileData({
    List<String>? extensions,
    String? dialogTitle,
  }) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        type: extensions != null ? FileType.custom : FileType.any,
        allowedExtensions: extensions,
        allowMultiple: false,
        withData: kIsWeb, // On web, ensure bytes are loaded.
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.single;
      final String name = file.name;

      Uint8List? bytes;
      String? text;

      if (kIsWeb) {
        // On web, `path` is always null — use in-memory bytes.
        bytes = file.bytes;
        if (bytes == null) return null;
        try {
          text = utf8.decode(bytes);
        } catch (_) {
          // Binary file — text stays null.
        }
      } else {
        // On native platforms, read from the file path.
        final path = file.path;
        if (path == null) return null;
        bytes = await platform_io.readFileBytes(path);
        try {
          text = utf8.decode(bytes);
        } catch (_) {
          // Binary file — text stays null.
        }
      }

      return (name: name, bytes: bytes, text: text);
    } catch (e) {
      debugPrint('FileIOHelper.pickFileData failed: $e');
      return null;
    }
  }

  // ─── Save / Export ──────────────────────────────────────────────────────

  /// Saves [bytes] to a file, showing a save dialog.
  ///
  /// On web, the browser handles the download via `FilePicker.saveFile`.
  /// On native desktop, `FilePicker.saveFile` may not write bytes
  /// automatically, so we write manually afterwards.
  ///
  /// Returns `true` if the file was saved (or download triggered on web).
  static Future<bool> saveFile({
    required Uint8List bytes,
    required String fileName,
    List<String>? extensions,
    String? dialogTitle,
  }) async {
    try {
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle ?? 'Save File',
        fileName: fileName,
        type: extensions != null ? FileType.custom : FileType.any,
        allowedExtensions: extensions,
        bytes: bytes,
      );

      if (kIsWeb) {
        // On web, `saveFile` with bytes triggers a browser download.
        // `outputPath` is always null — success is implicit.
        return true;
      }

      if (outputPath == null) return false; // User cancelled.

      // On native desktop, write the bytes to the chosen path.
      await platform_io.writeFileBytes(outputPath, bytes);
      return true;
    } catch (e) {
      debugPrint('FileIOHelper.saveFile failed: $e');
      return false;
    }
  }

  /// Convenience: saves a JSON string to a file.
  static Future<bool> saveString({
    required String content,
    required String fileName,
    List<String>? extensions,
    String? dialogTitle,
  }) {
    return saveFile(
      bytes: Uint8List.fromList(utf8.encode(content)),
      fileName: fileName,
      extensions: extensions,
      dialogTitle: dialogTitle,
    );
  }

  // ─── Direct read (for paths already stored) ─────────────────────────────

  /// Saves bytes directly to the downloads (or documents) folder
  /// on native platforms. Returns the saved file path.
  /// On web, throws — use [saveFile] which triggers a browser download.
  static Future<String> saveToDownloads({
    required Uint8List bytes,
    required String filename,
  }) {
    if (kIsWeb) {
      throw UnsupportedError(
        'FileIOHelper.saveToDownloads is not supported on web. '
        'Use saveFile instead.',
      );
    }
    return platform_io.saveToDownloads(bytes: bytes, filename: filename);
  }

  /// Reads bytes from a path on native platforms.
  /// On web this throws — callers must pass bytes directly.
  static Future<Uint8List> readBytes(String path) {
    if (kIsWeb) {
      throw UnsupportedError(
        'FileIOHelper.readBytes is not supported on web. '
        'Pass bytes directly instead of file paths.',
      );
    }
    return platform_io.readFileBytes(path);
  }

  /// Reads a string from a path on native platforms.
  /// On web this throws — callers must pass bytes directly.
  static Future<String> readString(String path) {
    if (kIsWeb) {
      throw UnsupportedError(
        'FileIOHelper.readString is not supported on web. '
        'Pass content directly instead of file paths.',
      );
    }
    return platform_io.readFileString(path);
  }

  /// Checks if a file exists at [path] on native platforms.
  /// On web, always returns `false`.
  static Future<bool> fileExists(String path) {
    if (kIsWeb) return Future.value(false);
    return platform_io.fileExists(path);
  }

  /// Writes [bytes] to [path] on native platforms.
  /// On web this throws.
  static Future<void> writeBytes(String path, Uint8List bytes) {
    if (kIsWeb) {
      throw UnsupportedError(
        'FileIOHelper.writeBytes is not supported on web.',
      );
    }
    return platform_io.writeFileBytes(path, bytes);
  }

  // ─── Image helpers ──────────────────────────────────────────────────────

  /// Returns an [ImageProvider] for a file at [path].
  /// On web, returns `null` — caller should use `Image.memory` instead.
  static ImageProvider? imageProviderFromPath(String path) {
    if (kIsWeb) return null;
    return platform_io.fileImageProvider(path);
  }

  /// Returns a widget displaying the image at [path].
  /// On web, returns an empty [SizedBox] — caller should provide a
  /// fallback or use bytes directly.
  static Widget imageWidgetFromPath(String path, {BoxFit fit = BoxFit.cover}) {
    if (kIsWeb) return const SizedBox.shrink();
    return platform_io.imageFileWidget(path, fit: fit);
  }
}
