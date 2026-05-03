import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/character_card.dart';
import '../../models/lorebook_models.dart';
import '../../providers/local_library_provider.dart';
import '../../services/character_card_service.dart';
import '../../services/library_service.dart';
import '../../services/file_io_helper.dart';
import '../../services/lorebook_service.dart';
import 'settings_color_picker.dart';

/// A panel for managing the AI character card (SillyTavern V1/V2 compatible).
class CharacterCardPanel extends StatefulWidget {
  const CharacterCardPanel({super.key});

  @override
  State<CharacterCardPanel> createState() => _CharacterCardPanelState();
}

class _CharacterCardPanelState extends State<CharacterCardPanel> {
  late TextEditingController _cardNameController;
  late TextEditingController _cardDescriptionController;
  late TextEditingController _cardPersonalityController;
  late TextEditingController _cardScenarioController;
  late TextEditingController _cardFirstMesController;
  late TextEditingController _cardMesExampleController;
  late TextEditingController _cardSystemPromptController;
  late TextEditingController _cardPostHistoryController;
  late TextEditingController _cardCreatorNotesController;
  late TextEditingController _cardCreatorController;
  late TextEditingController _cardVersionController;
  late TextEditingController _cardDepthPromptTextController;
  late TextEditingController _cardDepthPromptDepthController;

  Timer? _cardSaveTimer;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final card = chatProvider.characterCard;

    _cardNameController = TextEditingController(text: card.name);
    _cardDescriptionController = TextEditingController(text: card.description);
    _cardPersonalityController = TextEditingController(text: card.personality);
    _cardScenarioController = TextEditingController(text: card.scenario);
    _cardFirstMesController = TextEditingController(text: card.firstMessage);
    _cardMesExampleController = TextEditingController(text: card.mesExample);
    _cardSystemPromptController = TextEditingController(text: card.systemPrompt);
    _cardPostHistoryController = TextEditingController(text: card.postHistoryInstructions);
    _cardCreatorNotesController = TextEditingController(text: card.creatorNotes);
    _cardCreatorController = TextEditingController(text: card.creator);
    _cardVersionController = TextEditingController(text: card.characterVersion);
    _cardDepthPromptTextController = TextEditingController(text: card.depthPromptText);
    _cardDepthPromptDepthController = TextEditingController(text: card.depthPromptDepth.toString());
  }

  @override
  void dispose() {
    _cardSaveTimer?.cancel();
    _cardNameController.dispose();
    _cardDescriptionController.dispose();
    _cardPersonalityController.dispose();
    _cardScenarioController.dispose();
    _cardFirstMesController.dispose();
    _cardMesExampleController.dispose();
    _cardSystemPromptController.dispose();
    _cardPostHistoryController.dispose();
    _cardCreatorNotesController.dispose();
    _cardCreatorController.dispose();
    _cardVersionController.dispose();
    _cardDepthPromptTextController.dispose();
    _cardDepthPromptDepthController.dispose();
    super.dispose();
  }

  void _updateCardControllers(CharacterCard card) {
    if (_cardNameController.text != card.name) _cardNameController.text = card.name;
    if (_cardDescriptionController.text != card.description) _cardDescriptionController.text = card.description;
    if (_cardPersonalityController.text != card.personality) _cardPersonalityController.text = card.personality;
    if (_cardScenarioController.text != card.scenario) _cardScenarioController.text = card.scenario;
    if (_cardFirstMesController.text != card.firstMessage) _cardFirstMesController.text = card.firstMessage;
    if (_cardMesExampleController.text != card.mesExample) _cardMesExampleController.text = card.mesExample;
    if (_cardSystemPromptController.text != card.systemPrompt) _cardSystemPromptController.text = card.systemPrompt;
    if (_cardPostHistoryController.text != card.postHistoryInstructions) _cardPostHistoryController.text = card.postHistoryInstructions;
    if (_cardCreatorNotesController.text != card.creatorNotes) _cardCreatorNotesController.text = card.creatorNotes;
    if (_cardCreatorController.text != card.creator) _cardCreatorController.text = card.creator;
    if (_cardVersionController.text != card.characterVersion) _cardVersionController.text = card.characterVersion;
    if (_cardDepthPromptTextController.text != card.depthPromptText) _cardDepthPromptTextController.text = card.depthPromptText;
    if (_cardDepthPromptDepthController.text != card.depthPromptDepth.toString()) {
      _cardDepthPromptDepthController.text = card.depthPromptDepth.toString();
    }
  }

  void _syncCardFromControllers() {
    _cardSaveTimer?.cancel();
    _cardSaveTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      final updatedCard = chatProvider.characterCard.copyWith(
        name: _cardNameController.text,
        description: _cardDescriptionController.text,
        firstMessage: _cardFirstMesController.text,
        scenario: _cardScenarioController.text,
        personality: _cardPersonalityController.text,
        mesExample: _cardMesExampleController.text,
        systemPrompt: _cardSystemPromptController.text,
        postHistoryInstructions: _cardPostHistoryController.text,
        creatorNotes: _cardCreatorNotesController.text,
        creator: _cardCreatorController.text,
        characterVersion: _cardVersionController.text,
        depthPromptText: _cardDepthPromptTextController.text,
        depthPromptDepth: int.tryParse(_cardDepthPromptDepthController.text) ?? 4,
      );

      chatProvider.setCharacterCard(updatedCard);
    });
  }

  Future<void> _handleImportCharacterCard() async {
    try {
      final data = await FileIOHelper.pickFileData(extensions: ['png', 'json']);
      if (data != null) {
        final card = await CharacterCardService.parseFileData(data.name, data.bytes);
        if (card != null) {
          if (!mounted) return;
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          chatProvider.setCharacterCard(card);
          _updateCardControllers(card);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Imported '${card.name}' successfully!")),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import failed: $e")));
    }
  }

  Future<void> _handleExportCharacterCard() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final card = chatProvider.characterCard;
    if (card.name.isEmpty) return;
    try {
      final jsonStr = await LibraryService.exportCharacterCard(card);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      await FileIOHelper.saveFile(
        bytes: bytes,
        fileName: '${card.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.json',
        extensions: ['json'],
        dialogTitle: 'Export Character Card',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e")));
    }
  }

  void _clearCharacterCard() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final emptyCard = CharacterCard();
    chatProvider.setCharacterCard(emptyCard);
    _updateCardControllers(emptyCard);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Character card cleared.")));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final card = chatProvider.characterCard;

    _updateCardControllers(card);

    return Opacity(
      opacity: settingsProvider.enableCharacterCard ? 1.0 : 0.5,
      child: AbsorbPointer(
        absorbing: !settingsProvider.enableCharacterCard,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _handleImportCharacterCard,
                    icon: const Icon(Icons.file_open, size: 16),
                    label: const Text("Import Card"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _handleExportCharacterCard,
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text("Export JSON"),
                  ),
                  TextButton(
                    onPressed: _clearCharacterCard,
                    child: const Text("Clear Card", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
              Divider(color: themeProvider.borderColor),
              _buildLocalLibrarySection(context),
              const SizedBox(height: 16),
              _buildCardField("Name", _cardNameController, readOnly: false),
              const SizedBox(height: 8),
              ExpansionTile(
                title: Text("Description", style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.85, color: themeProvider.subtitleColor)),
                dense: true,
                children: [
                  _buildCardField("Description / Persona", _cardDescriptionController, maxLines: 3, readOnly: false),
                  const SizedBox(height: 8),
                  _buildCardField("First Message", _cardFirstMesController, maxLines: 3, readOnly: false),
                  const SizedBox(height: 12),
                  _buildCardField("Scenario", _cardScenarioController, maxLines: 2, readOnly: false),
                  const SizedBox(height: 8),
                  _buildCardField("Personality", _cardPersonalityController, maxLines: 2, readOnly: false),
                  const SizedBox(height: 8),
                  _buildCardField("Example Dialogue", _cardMesExampleController, maxLines: 4, readOnly: false),
                  const SizedBox(height: 8),
                  _buildCardField("Character Prompt", _cardSystemPromptController, maxLines: 2, readOnly: false),
                  const SizedBox(height: 8),
                  _buildCardField("Post-History", _cardPostHistoryController, maxLines: 2, readOnly: false),
                  const SizedBox(height: 12),
                  _buildCardField("Creator Notes", _cardCreatorNotesController, maxLines: 3, readOnly: false),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _buildCardField("Creator", _cardCreatorController, readOnly: false)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCardField("Version", _cardVersionController, readOnly: false)),
                  ]),
                  const SizedBox(height: 8),
                  if (card.tags.isNotEmpty) Wrap(spacing: 6, runSpacing: 4, children: card.tags.map((t) => Chip(label: Text(t, style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.7, color: themeProvider.textColor)), backgroundColor: themeProvider.containerFillColor, visualDensity: VisualDensity.compact)).toList()),
                  const SizedBox(height: 12),
                  ...card.alternateGreetings.asMap().entries.map((e) => ListTile(dense: true, title: Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: themeProvider.textColor, fontSize: scaleProvider.systemFontSize * 0.8)), trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _removeAlternateGreeting(e.key)))),
                  OutlinedButton.icon(onPressed: _addAlternateGreeting, icon: const Icon(Icons.add, size: 14), label: const Text('Add Greeting')),
                ],
              ),
              ExpansionTile(
                title: Text("Depth Prompt", style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.85, color: themeProvider.subtitleColor)),
                dense: true,
                children: [
                  _buildCardField("Depth Prompt Text", _cardDepthPromptTextController, maxLines: 3, readOnly: false),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _buildCardField("Depth", _cardDepthPromptDepthController, keyboardType: TextInputType.number, readOnly: false)),
                    const SizedBox(width: 12),
                    Expanded(child: DropdownButton<LorebookRole>(value: card.depthPromptRole, isExpanded: true, dropdownColor: themeProvider.dropdownColor, items: LorebookRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.name))).toList(), onChanged: (v) => _setDepthPromptRole(v!))),
                  ]),
                  SettingsColorPicker(label: 'Recognizer Glow', color: chatProvider.loreRecognizerGlowColor, onSave: (color) { chatProvider.setLoreRecognizerGlowColor(color); chatProvider.saveSettings(showConfirmation: false); }),
                ],
              ),
              _buildLorebookSection(card, themeProvider, scaleProvider, chatProvider.lastLorebookEvalResult.traceByEntryId),
            ],
          ),
        ),
      ),
    );
  }

  void _addAlternateGreeting() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Add Greeting'), content: TextField(controller: ctrl), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () { if (ctrl.text.isNotEmpty) { final c = chatProvider.characterCard; chatProvider.setCharacterCard(c.copyWith(alternateGreetings: [...c.alternateGreetings, ctrl.text.trim()])); } Navigator.pop(ctx); }, child: const Text('Add'))]));
  }

  void _removeAlternateGreeting(int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final c = chatProvider.characterCard;
    final g = List<String>.from(c.alternateGreetings)..removeAt(index);
    chatProvider.setCharacterCard(c.copyWith(alternateGreetings: g));
  }

  void _setDepthPromptRole(LorebookRole role) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.setCharacterCard(chatProvider.characterCard.copyWith(depthPromptRole: role));
  }

  Widget _buildCardField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType, bool readOnly = true}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onChanged: readOnly ? null : (_) => _syncCardFromControllers(),
      decoration: InputDecoration(labelText: label, isDense: true, filled: true, fillColor: themeProvider.containerFillDarkColor, border: const OutlineInputBorder()),
      style: TextStyle(fontSize: 13, color: themeProvider.textColor),
    );
  }

  Widget _buildLocalLibrarySection(BuildContext context) {
    final library = Provider.of<LocalLibraryProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    return library.cards.isEmpty ? const SizedBox.shrink() : SizedBox(height: 100, child: ListView.builder(itemCount: library.cards.length, itemBuilder: (context, index) { final c = library.cards[index]; return ListTile(dense: true, title: Text(c.name, style: TextStyle(color: theme.textColor)), trailing: IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.blueAccent), onPressed: () { final chat = Provider.of<ChatProvider>(context, listen: false); chat.setCharacterCard(CharacterCard.fromJson(c.toV3Json())); _updateCardControllers(chat.characterCard); })); }));
  }

  Widget _buildLorebookSection(CharacterCard card, ThemeProvider tp, ScaleProvider sp, Map<int, LorebookActivationTrace> traces) {
    final book = card.characterBook;
    if (book == null || book.entries.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(title: Text('World Lore (${book.entries.length})', style: TextStyle(color: tp.subtitleColor)), children: book.entries.map((e) => ListTile(dense: true, title: Text(e.comment, style: TextStyle(color: tp.textColor)), subtitle: Text(e.keys.join(', '), style: TextStyle(color: tp.faintColor)))).toList());
  }
}
