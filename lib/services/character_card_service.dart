import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/character_card.dart';

class CharacterCardService {
  CharacterCardService._();

  /// Parses a character card from a file (PNG or JSON).
  static Future<CharacterCard?> parseFile(File file) async {
    final path = file.path.toLowerCase();
    
    if (path.endsWith('.json')) {
      final content = await file.readAsString();
      return parseJson(content);
    } else if (path.endsWith('.png')) {
      final bytes = await file.readAsBytes();
      return parsePng(bytes);
    }
    
    throw FormatException("Unsupported file type. Please provide a .json or .png file.");
  }

  /// Parses a character card from a JSON string.
  static CharacterCard parseJson(String jsonContent) {
    try {
      final Map<String, dynamic> map = jsonDecode(jsonContent);
      return CharacterCard.fromJson(map);
    } catch (e) {
      debugPrint("Error parsing character card JSON: $e");
      throw FormatException("Invalid JSON format");
    }
  }

  /// Extracts character card data from a PNG image.
  ///
  /// Supports both **tEXt** (uncompressed) and **iTXt** (optionally
  /// zlib-compressed) chunks, since SillyTavern V2 cards may use either.
  /// Looks for the 'chara' keyword in both chunk types.
  static CharacterCard? parsePng(Uint8List bytes) {
    try {
      int offset = 8; // Skip PNG signature
      final dataView = ByteData.view(bytes.buffer);

      while (offset < bytes.length) {
        final length = dataView.getUint32(offset);
        offset += 4;

        final type = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        offset += 4;

        final chunkData = bytes.sublist(offset, offset + length);

        if (type == 'tEXt') {
          // tEXt format: keyword\0text
          final nullIndex = chunkData.indexOf(0);
          if (nullIndex != -1) {
            final keyword =
                String.fromCharCodes(chunkData.sublist(0, nullIndex));
            if (keyword == 'chara') {
              final base64Content =
                  utf8.decode(chunkData.sublist(nullIndex + 1));
              final jsonStr = utf8.decode(base64.decode(base64Content));
              return parseJson(jsonStr);
            }
          }
        } else if (type == 'iTXt') {
          // iTXt format:
          //   keyword\0 compressionFlag(1) compressionMethod(1)
          //   languageTag\0 translatedKeyword\0 text
          final nullIndex = chunkData.indexOf(0);
          if (nullIndex != -1) {
            final keyword =
                String.fromCharCodes(chunkData.sublist(0, nullIndex));
            if (keyword == 'chara') {
              int pos = nullIndex + 1;
              final compressionFlag = chunkData[pos];
              pos += 2; // skip compressionFlag + compressionMethod

              // Skip language tag (null-terminated)
              while (pos < chunkData.length && chunkData[pos] != 0) {
                pos++;
              }
              pos++; // skip null

              // Skip translated keyword (null-terminated)
              while (pos < chunkData.length && chunkData[pos] != 0) {
                pos++;
              }
              pos++; // skip null

              final textBytes = chunkData.sublist(pos);
              String textContent;

              if (compressionFlag == 1) {
                // zlib-compressed iTXt
                textContent = utf8.decode(zlib.decode(textBytes));
              } else {
                textContent = utf8.decode(textBytes);
              }

              // Content may be base64-encoded (SillyTavern convention)
              try {
                final jsonStr = utf8.decode(base64.decode(textContent));
                return parseJson(jsonStr);
              } catch (_) {
                // Not base64 — treat as raw JSON
                return parseJson(textContent);
              }
            }
          }
        }

        offset += length;
        offset += 4; // Skip CRC
      }
    } catch (e) {
      debugPrint("Error parsing PNG character card: $e");
    }

    return null;
  }

  /// Validates a character card against the current application capabilities.
  /// Returns a list of warnings, or empty if fully compatible.
  static List<String> validate(CharacterCard card) {
    final warnings = <String>[...card.compatibilityWarnings];
    
    // Check for essential fields
    if (card.name.isEmpty) warnings.add("Card has no name.");
    if (card.description.isEmpty && card.personality.isEmpty) warnings.add("Card has no description or personality.");
    
    return warnings;
  }
}
