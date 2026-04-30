import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_card.dart';
import '../models/lorebook_models.dart';

/// A focused provider to manage the Per-Subsystem Local Library (Phase 4).
/// Stores assets in SharedPreferences for seamless web-compatible fast-swapping.
class LocalLibraryProvider extends ChangeNotifier {
  List<CharacterCard> _cards = [];
  List<Lorebook> _lorebooks = [];

  List<CharacterCard> get cards => _cards;
  List<Lorebook> get lorebooks => _lorebooks;

  LocalLibraryProvider() {
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    // Load cards
    final cardsStr = prefs.getString('airp_lib_cards');
    if (cardsStr != null) {
      try {
        final list = jsonDecode(cardsStr) as List;
        _cards = list
            .map((e) => CharacterCard.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading cards lib: $e');
      }
    }

    // Load lorebooks
    final lorebooksStr = prefs.getString('airp_lib_lorebooks');
    if (lorebooksStr != null) {
      try {
        final list = jsonDecode(lorebooksStr) as List;
        _lorebooks = list
            .map((e) => Lorebook.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading lorebook lib: $e');
      }
    }

    notifyListeners();
  }

  // --- Cards ---
  Future<void> saveCard(CharacterCard card) async {
    final name = card.name.isNotEmpty ? card.name : 'Unnamed Character';
    final existingIndex = _cards.indexWhere((c) => c.name == name);
    // Use toV3Json to capture state natively including embedded properties
    final serialized = card.toV3Json();
    final cloned = CharacterCard.fromJson(serialized);
    
    if (existingIndex >= 0) {
      _cards[existingIndex] = cloned;
    } else {
      _cards.add(cloned);
    }
    await _persistCards();
  }

  Future<void> deleteCard(CharacterCard card) async {
    _cards.removeWhere((c) => c.name == card.name);
    await _persistCards();
  }

  Future<void> _persistCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'airp_lib_cards', jsonEncode(_cards.map((c) => c.toV3Json()).toList()));
    notifyListeners();
  }

  // --- Lorebooks ---
  Future<void> saveLorebook(Lorebook lorebook) async {
    final name = lorebook.name.isNotEmpty ? lorebook.name : 'Unnamed Lorebook';
    final existingIndex = _lorebooks.indexWhere((l) => l.name == name);
    final cloned = Lorebook.fromJson(lorebook.toJson())..name = name;

    if (existingIndex >= 0) {
      _lorebooks[existingIndex] = cloned;
    } else {
      _lorebooks.add(cloned);
    }
    await _persistLorebooks();
  }

  Future<void> deleteLorebook(Lorebook lorebook) async {
    _lorebooks.removeWhere((l) => l.name == lorebook.name);
    await _persistLorebooks();
  }

  Future<void> _persistLorebooks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('airp_lib_lorebooks',
        jsonEncode(_lorebooks.map((l) => l.toJson()).toList()));
    notifyListeners();
  }
}
