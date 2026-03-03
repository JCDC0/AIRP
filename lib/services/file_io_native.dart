import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Reads file bytes from the given [path] (native platforms only).
Future<Uint8List> readFileBytes(String path) async {
  return await File(path).readAsBytes();
}

/// Reads file content as a string from the given [path].
Future<String> readFileString(String path) async {
  return await File(path).readAsString();
}

/// Checks whether a file exists at [path].
Future<bool> fileExists(String path) async {
  return await File(path).exists();
}

/// Writes [bytes] to the file at [path].
Future<void> writeFileBytes(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes);
}

/// Returns a [FileImage] provider for the given [path].
ImageProvider fileImageProvider(String path) => FileImage(File(path));

/// Returns an [Image.file] widget for the given [path].
Widget imageFileWidget(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.file(File(path), fit: fit);
}

/// Saves [bytes] to the downloads (or documents) directory with the given
/// [filename] and returns the full path of the saved file.
Future<String> saveToDownloads({
  required Uint8List bytes,
  required String filename,
}) async {
  final dir =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Decompresses zlib-compressed data (wrapper around dart:io's zlib codec).
List<int> zlibDecode(List<int> data) => zlib.decode(data);
