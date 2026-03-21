import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_card.dart';
import '../models/lorebook_models.dart';
import '../models/regex_models.dart';
import '../models/formatting_models.dart';

/// Represents a collection of named RegexScripts.
class RegexSet {
  String name;
  List<RegexScript> scripts;

  RegexSet({required this.name, required this.scripts});

  factory RegexSet.fromJson(Map<String, dynamic> json) {
    var scriptsData = json['scripts'] as List? ?? [];
    return RegexSet(
      name: json['name'] as String? ?? 'Unnamed',
      scripts: scriptsData
          .map((e) => RegexScript.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'scripts': scripts.map((e) => e.toJson()).toList(),
      };
}

/// A focused provider to manage the Per-Subsystem Local Library (Phase 4).
/// Stores assets in SharedPreferences for seamless web-compatible fast-swapping.
class LocalLibraryProvider extends ChangeNotifier {
  List<CharacterCard> _cards = [];
  List<Lorebook> _lorebooks = [];
  List<RegexSet> _regexSets = [];
  List<FormattingTemplate> _formattingSets = [];

  List<CharacterCard> get cards => _cards;
  List<Lorebook> get lorebooks => _lorebooks;
  List<RegexSet> get regexSets => _regexSets;
  List<FormattingTemplate> get formattingSets => _formattingSets;

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

    // Load regex sets
    final regexStr = prefs.getString('airp_lib_regex_sets');
    if (regexStr != null) {
      try {
        final list = jsonDecode(regexStr) as List;
        _regexSets = list
            .map((e) => RegexSet.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading regex lib: $e');
      }
    }

    // Load formatting sets
    final fmtStr = prefs.getString('airp_lib_formatting_sets');
    if (fmtStr != null) {
      try {
        final list = jsonDecode(fmtStr) as List;
        _formattingSets = list
            .map((e) => FormattingTemplate.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading formatting lib: $e');
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

  // --- Regex Sets ---
  Future<void> saveRegexSet(String name, List<RegexScript> scripts) async {
    final safeName = name.isNotEmpty ? name : 'Unnamed Regex Set';
    final existingIndex = _regexSets.indexWhere((r) => r.name == safeName);
    final clonedScripts =
        scripts.map((s) => RegexScript.fromJson(s.toJson())).toList();
    final set = RegexSet(name: safeName, scripts: clonedScripts);
    if (existingIndex >= 0) {
      _regexSets[existingIndex] = set;
    } else {
      _regexSets.add(set);
    }
    await _persistRegexSets();
  }

  Future<void> deleteRegexSet(RegexSet set) async {
    _regexSets.removeWhere((r) => r.name == set.name);
    await _persistRegexSets();
  }

  Future<void> _persistRegexSets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('airp_lib_regex_sets',
        jsonEncode(_regexSets.map((r) => r.toJson()).toList()));
    notifyListeners();
  }

  // --- Formatting ---
  Future<void> saveFormatting(FormattingTemplate template) async {
    final name = template.name.isNotEmpty ? template.name : 'Unnamed Format';
    final existingIndex = _formattingSets.indexWhere((f) => f.name == name);
    final cloned = FormattingTemplate.fromJson(template.toJson())..name = name;
    if (existingIndex >= 0) {
      _formattingSets[existingIndex] = cloned;
    } else {
      _formattingSets.add(cloned);
    }
    await _persistFormatting();
  }

  Future<void> deleteFormatting(FormattingTemplate template) async {
    _formattingSets.removeWhere((f) => f.name == template.name);
    await _persistFormatting();
  }

  Future<void> _persistFormatting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('airp_lib_formatting_sets',
        jsonEncode(_formattingSets.map((f) => f.toJson()).toList()));
    notifyListeners();
  }
}
