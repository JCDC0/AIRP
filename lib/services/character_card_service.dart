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

  /// Extracts character card data from a PNG image (tEXt chunks).
  /// 
  /// This is a basic implementation looking for the 'chara' keyword in tEXt chunks,
  /// which is valid for V2 spec.
  static CharacterCard? parsePng(Uint8List bytes) {
    try {
      // Basic PNG parsing to find tEXt chunks
      // This is a simplified parser. For production, a robust PNG library is recommended,
      // but this avoids adding heavy dependencies if we only need tEXt chunks.
      
      int offset = 8; // Skip PNG signature
      final dataView = ByteData.view(bytes.buffer);

      while (offset < bytes.length) {
        final length = dataView.getUint32(offset);
        offset += 4;
        
        final type = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        offset += 4;

        if (type == 'tEXt') {
          final chunkData = bytes.sublist(offset, offset + length);
          // tEXt format: keyword + null separator + text
          final nullIndex = chunkData.indexOf(0);
          if (nullIndex != -1) {
            final keyword = String.fromCharCodes(chunkData.sublist(0, nullIndex));
            
            if (keyword == 'chara') {
              // Found character data!
              final base64Content = utf8.decode(chunkData.sublist(nullIndex + 1));
              final jsonStr = utf8.decode(base64.decode(base64Content));
              return parseJson(jsonStr);
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
