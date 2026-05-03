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
///
/// Provides import/export of character card files (PNG with tEXt/iTXt chunks
/// or JSON), display-first fields with dialog-based editing, and debounced
/// auto-save for direct editable fields.
///
/// V2 fields supported: name, description, personality, scenario, firstMessage,
/// mesExample, systemPrompt, postHistoryInstructions, creatorNotes, creator,
/// characterVersion, alternateGreetings, tags, depthPrompt (text/depth/role),
/// and an embedded lorebook sub-section.
class CharacterCardPanel extends StatefulWidget {
  const CharacterCardPanel({super.key});

  @override
  State<CharacterCardPanel> createState() => _CharacterCardPanelState();
}

class _CharacterCardPanelState extends State<CharacterCardPanel> {
  // Character Card Controllers — one per editable field.
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

  /// Debounce timer for auto-saving card edits back to ChatProvider.
  Timer? _cardSaveTimer;

  @override
  void initState() {
    super.initState();
    _cardNameController = TextEditingController();
    _cardDescriptionController = TextEditingController();
    _cardPersonalityController = TextEditingController();
    _cardScenarioController = TextEditingController();
    _cardFirstMesController = TextEditingController();
    _cardMesExampleController = TextEditingController();
    _cardSystemPromptController = TextEditingController();
    _cardPostHistoryController = TextEditingController();
    _cardCreatorNotesController = TextEditingController();
    _cardCreatorController = TextEditingController();
    _cardVersionController = TextEditingController();
    _cardDepthPromptTextController = TextEditingController();
    _cardDepthPromptDepthController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      _updateCardControllers(chatProvider.characterCard);
    });
  }

  @override
  void dispose() {
    // Cancel any pending save timer to prevent post-dispose access.
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

  /// Populates all card text controllers from the given [card].
  void _updateCardControllers(CharacterCard card) {
    _cardNameController.text = card.name;
    _cardDescriptionController.text = card.description;
    _cardPersonalityController.text = card.personality;
    _cardScenarioController.text = card.scenario;
    _cardFirstMesController.text = card.firstMessage;
    _cardMesExampleController.text = card.mesExample;
    _cardSystemPromptController.text = card.systemPrompt;
    _cardPostHistoryController.text = card.postHistoryInstructions;
    _cardCreatorNotesController.text = card.creatorNotes;
    _cardCreatorController.text = card.creator;
    _cardVersionController.text = card.characterVersion;
    _cardDepthPromptTextController.text = card.depthPromptText;
    _cardDepthPromptDepthController.text = card.depthPromptDepth.toString();
  }

  /// Debounced sync from controllers back to ChatProvider's character card.
  ///
  /// Waits 1 second after the last keystroke before writing, to avoid
  /// excessive rebuilds during rapid typing.
  void _syncCardFromControllers() {
    _cardSaveTimer?.cancel();
    _cardSaveTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

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
        depthPromptDepth:
            int.tryParse(_cardDepthPromptDepthController.text) ?? 4,
      );

      chatProvider.setCharacterCard(updatedCard);
    });
  }

  // ---------------------------------------------------------------------------
  // Import / Export / Clear
  // ---------------------------------------------------------------------------

  /// Lets the user pick a .png or .json file and imports it as a character card.
  Future<void> _handleImportCharacterCard() async {
    try {
      final data = await FileIOHelper.pickFileData(extensions: ['png', 'json']);

      if (data != null) {
        final card = await CharacterCardService.parseFileData(
          data.name,
          data.bytes,
        );

        if (card != null) {
          final warnings = CharacterCardService.validate(card);
          if (warnings.isNotEmpty) {
            if (!mounted) return;
            final themeProvider = Provider.of<ThemeProvider>(
              context,
              listen: false,
            );
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text(
                  "Import Warnings",
                  style: TextStyle(color: Colors.orangeAccent),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: warnings
                      .map(
                        (w) => Text(
                          "• $w",
                          style: TextStyle(color: themeProvider.subtitleColor),
                        ),
                      )
                      .toList(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("OK"),
                  ),
                ],
                backgroundColor: themeProvider.dropdownColor,
              ),
            );
          }

          if (!mounted) return;
          final chatProvider = Provider.of<ChatProvider>(
            context,
            listen: false,
          );
          chatProvider.setCharacterCard(card);
          _updateCardControllers(card);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Imported '${card.name}' successfully!")),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Import failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Import failed: $e")));
      }
    }
  }

  /// Exports the current character card to a .json file.
  Future<void> _handleExportCharacterCard() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final card = chatProvider.characterCard;

    if (card.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Character card is empty. Add a name first."),
        ),
      );
      return;
    }

    try {
      // Serialise once and reuse for both the picker hint and file write.
      final jsonStr = await LibraryService.exportCharacterCard(card);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final saved = await FileIOHelper.saveFile(
        bytes: bytes,
        fileName: '${card.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.json',
        extensions: ['json'],
        dialogTitle: 'Export Character Card',
      );

      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Character card exported!")),
        );
      }
    } catch (e) {
      debugPrint("Export failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    }
  }

  /// Resets the character card to an empty state.
  void _clearCharacterCard() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final emptyCard = CharacterCard();
    chatProvider.setCharacterCard(emptyCard);
    _updateCardControllers(emptyCard);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Character card cleared.")));
  }

  // ---------------------------------------------------------------------------
  // Local Library View
  // ---------------------------------------------------------------------------

  Widget _buildLocalLibrarySection(BuildContext context) {
    final library = Provider.of<LocalLibraryProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final sp = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Local Library",
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: sp.systemFontSize * 0.9,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
              tooltip: 'Save Current Card to Library',
              onPressed: () {
                final currentCard =
                    Provider.of<ChatProvider>(context, listen: false)
                        .characterCard;
                if (currentCard.name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Cannot save a card without a Name!")),
                  );
                  return;
                }
                library.saveCard(currentCard);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Saved '${currentCard.name}' to Library!")),
                );
              },
            ),
          ],
        ),
        if (library.cards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "No character cards saved yet.",
              style: TextStyle(
                color: theme.faintColor,
                fontSize: sp.systemFontSize * 0.8,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: theme.containerFillDarkColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.borderColor),
            ),
            child: ListView.builder(
              itemCount: library.cards.length,
              itemBuilder: (context, index) {
                final c = library.cards[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    c.name,
                    style: TextStyle(
                        color: theme.textColor, fontSize: sp.systemFontSize * 0.85),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline,
                            size: 20, color: Colors.blueAccent),
                        tooltip: 'Load Card',
                        onPressed: () {
                          final chat =
                              Provider.of<ChatProvider>(context, listen: false);
                          chat.setCharacterCard(CharacterCard.fromJson(c.toV3Json()));
                          _updateCardControllers(chat.characterCard);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Loaded '${c.name}'")),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.redAccent),
                        tooltip: 'Delete Card',
                        onPressed: () => library.deleteCard(c),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Alternate Greetings helpers
  // ---------------------------------------------------------------------------

  void _addAlternateGreeting() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text(
          'Add Alternate Greeting',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize * 0.85,
          ),
          decoration: InputDecoration(
            hintText: 'Alternate first message...',
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text(
              'Add',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: scaleProvider.systemFontSize * 0.8,
              ),
            ),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                final card = chatProvider.characterCard;
                final updated = card.copyWith(
                  alternateGreetings: [...card.alternateGreetings, val],
                );
                chatProvider.setCharacterCard(updated);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _editAlternateGreeting(int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final card = chatProvider.characterCard;
    if (index >= card.alternateGreetings.length) return;

    final ctrl = TextEditingController(text: card.alternateGreetings[index]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text(
          'Edit Greeting #${index + 1}',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize * 0.85,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text(
              'Save',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: scaleProvider.systemFontSize * 0.8,
              ),
            ),
            onPressed: () {
              final greetings = List<String>.from(card.alternateGreetings);
              greetings[index] = ctrl.text.trim();
              chatProvider.setCharacterCard(
                card.copyWith(alternateGreetings: greetings),
              );
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _removeAlternateGreeting(int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final card = chatProvider.characterCard;
    final greetings = List<String>.from(card.alternateGreetings);
    greetings.removeAt(index);
    chatProvider.setCharacterCard(card.copyWith(alternateGreetings: greetings));
  }

  // ---------------------------------------------------------------------------
  // Depth prompt role setter
  // ---------------------------------------------------------------------------

  void _setDepthPromptRole(LorebookRole role) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final card = chatProvider.characterCard;
    chatProvider.setCharacterCard(card.copyWith(depthPromptRole: role));
  }

  void _applyCardUpdate(CharacterCard updatedCard) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    chatProvider.setCharacterCard(updatedCard);
    _updateCardControllers(updatedCard);
  }

  Future<void> _editCardField({
    required String title,
    required String initialValue,
    required ValueChanged<String> onSave,
    int minLines = 1,
    int maxLines = 6,
    TextInputType? keyboardType,
  }) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final ctrl = TextEditingController(text: initialValue);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text(
          title,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: scaleProvider.systemFontSize * 0.85,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: scaleProvider.systemFontSize * 0.8),
            ),
          ),
          TextButton(
            onPressed: () {
              onSave(ctrl.text);
              Navigator.pop(ctx);
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: scaleProvider.systemFontSize * 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final card = chatProvider.characterCard;

    return Opacity(
      opacity: settingsProvider.enableCharacterCard ? 1.0 : 0.5,
      child: AbsorbPointer(
        absorbing: !settingsProvider.enableCharacterCard,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Import / Export / Clear buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _handleImportCharacterCard,
                    icon: const Icon(Icons.file_open, size: 16),
                    label: const Text("Import Card"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _handleExportCharacterCard,
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text("Export JSON"),
                  ),
                  TextButton(
                    onPressed: _clearCharacterCard,
                    child: const Text(
                      "Clear Card",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
              Divider(color: themeProvider.borderColor),

              // Local Library
              _buildLocalLibrarySection(context),
              const SizedBox(height: 16),

              // --- Primary Card Fields ---
              _buildCardField(
                "Name",
                _cardNameController,
                readOnly: false,
              ),
              const SizedBox(height: 8),

              // --- Description (collapsible grouped fields) ---
              ExpansionTile(
                title: Text(
                  "Description",
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.85,
                    color: themeProvider.subtitleColor,
                  ),
                ),
                subtitle: settingsProvider.enableDeveloperMode
                    ? Text(
                        'Developer Mode: tap field body to open editor',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: scaleProvider.systemFontSize * 0.68,
                        ),
                      )
                    : null,
                dense: true,
                children: [
                  _buildCardField(
                    "Description / Persona",
                    _cardDescriptionController,
                    maxLines: 3,
                    onEdit: () => _editCardField(
                      title: 'Description / Persona',
                      initialValue: card.description,
                      minLines: 3,
                      maxLines: 10,
                      onSave: (val) => _applyCardUpdate(
                        card.copyWith(description: val.trim()),
                      ),
                    ),
                    allowTapToEdit: settingsProvider.enableDeveloperMode,
                  ),
                  const SizedBox(height: 8),
                  _buildCardField(
                    "First Message",
                    _cardFirstMesController,
                    maxLines: 3,
                    onEdit: () => _editCardField(
                      title: 'First Message',
                      initialValue: card.firstMessage,
                      minLines: 3,
                      maxLines: 10,
                      onSave: (val) => _applyCardUpdate(
                        card.copyWith(firstMessage: val.trim()),
                      ),
                    ),
                    allowTapToEdit: settingsProvider.enableDeveloperMode,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      'More Fields',
                      style: TextStyle(
                        color: themeProvider.subtitleColor,
                        fontSize: scaleProvider.systemFontSize * 0.78,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildCardField(
                    "Scenario",
                    _cardScenarioController,
                    maxLines: 2,
                    onEdit: () => _editCardField(
                      title: 'Scenario',
                      initialValue: card.scenario,
                      minLines: 2,
                      maxLines: 8,
                      onSave: (val) => _applyCardUpdate(
                        card.copyWith(scenario: val.trim()),
                      ),
                    ),
                    allowTapToEdit: settingsProvider.enableDeveloperMode,
                  ),
                  const SizedBox(height: 8),
                  _buildCardField(
                    "Personality",
                    _cardPersonalityController,
                    maxLines: 2,
                    onEdit: () => _editCardField(
                      title: 'Personality',
                      initialValue: card.personality,
                      minLines: 2,
                      maxLines: 8,
                      onSave: (val) => _applyCardUpdate(
                        card.copyWith(personality: val.trim()),
                      ),
                    ),
                    allowTapToEdit: settingsProvider.enableDeveloperMode,
                  ),
                  const SizedBox(height: 8),
                  _buildCardField(
                    "Example Dialogue (Mes Example)",
                    _cardMesExampleController,
                    maxLines: 4,
                    onEdit: () => _editCardField(
                      title: 'Example Dialogue (Mes Example)',
                      initialValue: card.mesExample,
                      minLines: 3,
                      maxLines: 10,
                      onSave: (val) => _applyCardUpdate(
                        card.copyWith(mesExample: val.trim()),
                      ),
                    ),
                    allowTapToEdit: settingsProvider.enableDeveloperMode,
                  ),
                  const SizedBox(height: 8),
                  _buildCardField(
                    "Character System Prompt",
                    _cardSystemPromptController,
                    maxLines: 2,
                    onEdit: () => _editCardField(
                      title: 'Character System Prompt',
                      initialValue: card.systemPrompt,
                      minLines: 2,
                      maxLines: 8,
                      onSave: (val) => _applyCardUpdate(
                        card.copyWith(systemPrompt: val.trim()),
                      ),
                    ),
                    allowTapToEdit: settingsProvider.enableDeveloperMode,
                  ),
                  const SizedBox(height: 8),
                  _buildCardField(
                    "Post-History Instructions",
                    _cardPostHistoryController,
                    maxLines: 2,
                    onEdit: () => _editCardField(
                      title: 'Post-History Instructions',
                      initialValue: card.postHistoryInstructions,
                      minLines: 2,
                      maxLines: 8,
                      onSave: (val) => _applyCardUpdate(
                        card.copyWith(postHistoryInstructions: val.trim()),
                      ),
                    ),
                    allowTapToEdit: settingsProvider.enableDeveloperMode,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      'V2 Extended Fields',
                      style: TextStyle(
                        color: themeProvider.subtitleColor,
                        fontSize: scaleProvider.systemFontSize * 0.78,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildCardField(
                    "Creator Notes",
                    _cardCreatorNotesController,
                    maxLines: 3,
                    onEdit: () => _editCardField(
                      title: 'Creator Notes',
                      initialValue: card.creatorNotes,
                      minLines: 3,
                      maxLines: 10,
                      onSave: (val) => _applyCardUpdate(
                        card.copyWith(creatorNotes: val.trim()),
                      ),
                    ),
                    allowTapToEdit: settingsProvider.enableDeveloperMode,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCardField(
                          "Creator",
                          _cardCreatorController,
                          onEdit: () => _editCardField(
                            title: 'Creator',
                            initialValue: card.creator,
                            onSave: (val) => _applyCardUpdate(
                              card.copyWith(creator: val.trim()),
                            ),
                          ),
                          allowTapToEdit: settingsProvider.enableDeveloperMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCardField(
                          "Version",
                          _cardVersionController,
                          onEdit: () => _editCardField(
                            title: 'Version',
                            initialValue: card.characterVersion,
                            onSave: (val) => _applyCardUpdate(
                              card.copyWith(characterVersion: val.trim()),
                            ),
                          ),
                          allowTapToEdit: settingsProvider.enableDeveloperMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- Tags ---
                  if (card.tags.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tags',
                        style: TextStyle(
                          color: themeProvider.subtitleColor,
                          fontSize: scaleProvider.systemFontSize * 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: card.tags
                          .map(
                            (t) => Chip(
                              label: Text(
                                t,
                                style: TextStyle(
                                  fontSize: scaleProvider.systemFontSize * 0.7,
                                  color: themeProvider.textColor,
                                ),
                              ),
                              backgroundColor: themeProvider.containerFillColor,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      'Alternate Greetings (${card.alternateGreetings.length})',
                      style: TextStyle(
                        color: themeProvider.subtitleColor,
                        fontSize: scaleProvider.systemFontSize * 0.78,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...card.alternateGreetings.asMap().entries.map((e) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        e.value.length > 80
                            ? '${e.value.substring(0, 80)}...'
                            : e.value,
                        style: TextStyle(
                          color: themeProvider.textColor,
                          fontSize: scaleProvider.systemFontSize * 0.8,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Greeting #${e.key + 1}',
                        style: TextStyle(
                          color: themeProvider.faintColor,
                          fontSize: scaleProvider.systemFontSize * 0.65,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: themeProvider.subtitleColor,
                              size: 16,
                            ),
                            onPressed: () => _editAlternateGreeting(e.key),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: themeProvider.faintestColor,
                              size: 16,
                            ),
                            onPressed: () => _removeAlternateGreeting(e.key),
                          ),
                        ],
                      ),
                      onTap: settingsProvider.enableDeveloperMode
                          ? () => _editAlternateGreeting(e.key)
                          : null,
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: _addAlternateGreeting,
                      icon: const Icon(Icons.add, size: 14),
                      label: Text(
                        'Add Greeting',
                        style: TextStyle(
                          fontSize: scaleProvider.systemFontSize * 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),

              // --- Depth Prompt (collapsible) ---
              ExpansionTile(
                title: Text(
                  "Depth Prompt",
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.85,
                    color: themeProvider.subtitleColor,
                  ),
                ),
                dense: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCardField(
                          "Depth Prompt Text",
                          _cardDepthPromptTextController,
                          maxLines: 3,
                          onEdit: () => _editCardField(
                            title: 'Depth Prompt Text',
                            initialValue: card.depthPromptText,
                            minLines: 2,
                            maxLines: 8,
                            onSave: (val) => _applyCardUpdate(
                              card.copyWith(depthPromptText: val.trim()),
                            ),
                          ),
                          allowTapToEdit: settingsProvider.enableDeveloperMode,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCardField(
                                "Depth (int)",
                                _cardDepthPromptDepthController,
                                keyboardType: TextInputType.number,
                                onEdit: () => _editCardField(
                                  title: 'Depth (int)',
                                  initialValue: card.depthPromptDepth.toString(),
                                  keyboardType: TextInputType.number,
                                  onSave: (val) {
                                    final parsed = int.tryParse(val.trim()) ??
                                        card.depthPromptDepth;
                                    _applyCardUpdate(
                                      card.copyWith(depthPromptDepth: parsed),
                                    );
                                  },
                                ),
                                allowTapToEdit:
                                    settingsProvider.enableDeveloperMode,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Role',
                                    style: TextStyle(
                                      color: themeProvider.subtitleColor,
                                      fontSize:
                                          scaleProvider.systemFontSize * 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          themeProvider.containerFillDarkColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: themeProvider.borderColor,
                                      ),
                                    ),
                                    child: DropdownButton<LorebookRole>(
                                      value: card.depthPromptRole,
                                      isExpanded: true,
                                      dropdownColor:
                                          themeProvider.dropdownColor,
                                      underline: const SizedBox(),
                                      style: TextStyle(
                                        color: themeProvider.textColor,
                                        fontSize:
                                            scaleProvider.systemFontSize * 0.8,
                                      ),
                                      items: LorebookRole.values
                                          .map(
                                            (r) =>
                                                DropdownMenuItem<LorebookRole>(
                                                  value: r,
                                                  child: Text(r.name),
                                                ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          _setDepthPromptRole(v);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SettingsColorPicker(
                          label: 'Recognizer Glow',
                          color: chatProvider.loreRecognizerGlowColor,
                          onSave: (color) {
                            chatProvider.setLoreRecognizerGlowColor(color);
                            chatProvider.saveSettings(showConfirmation: false);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),

              // --- Lorebook Sub-section (collapsible) ---
              _buildLorebookSection(
                card,
                themeProvider,
                scaleProvider,
                chatProvider.lastLorebookEvalResult.traceByEntryId,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lorebook sub-section
  // ---------------------------------------------------------------------------

  Widget _buildLorebookSection(
    CharacterCard card,
    ThemeProvider themeProvider,
    ScaleProvider scaleProvider,
    Map<int, LorebookActivationTrace> traceByEntryId,
  ) {
    final book = card.characterBook;
    final entryCount = book?.entries.length ?? 0;

    return ExpansionTile(
      title: Text(
        'World Lore ($entryCount entries)',
        style: TextStyle(
          fontSize: scaleProvider.systemFontSize * 0.85,
          color: themeProvider.subtitleColor,
        ),
      ),
      dense: true,
      children: [
        if (book == null || book.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.auto_stories,
                  size: 36,
                  color: themeProvider.faintColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'No embedded world lore.',
                  style: TextStyle(
                    color: themeProvider.faintColor,
                    fontSize: scaleProvider.systemFontSize * 0.85,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Import a character card with world lore to see entries here.',
                  style: TextStyle(
                    color: themeProvider.faintestColor,
                    fontSize: scaleProvider.systemFontSize * 0.7,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (book != null && book.entries.isNotEmpty) ...[
          // Lorebook metadata
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeProvider.containerFillDarkColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (book.name.isNotEmpty)
                    Text(
                      book.name,
                      style: TextStyle(
                        color: themeProvider.textColor,
                        fontSize: scaleProvider.systemFontSize * 0.85,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Scan: ${book.scanDepth}  \u2022  '
                    'Budget: ${book.tokenBudget} tok  \u2022  '
                    'Recursion: ${book.recursionSteps}',
                    style: TextStyle(
                      color: themeProvider.faintColor,
                      fontSize: scaleProvider.systemFontSize * 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (traceByEntryId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ExpansionTile(
                dense: true,
                title: Text(
                  'Activation Debug (${traceByEntryId.length})',
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.72,
                    color: themeProvider.faintColor,
                  ),
                ),
                children: traceByEntryId.values.map((trace) {
                  final statusColor = trace.activated
                      ? Colors.greenAccent
                      : themeProvider.faintColor;
                  final statusLabel = trace.activated ? 'ACTIVE' : 'SKIPPED';
                  final reason = trace.blockedBy ?? trace.reason.name;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      trace.activated ? Icons.check_circle : Icons.info_outline,
                      size: 14,
                      color: statusColor,
                    ),
                    title: Text(
                      trace.entryLabel,
                      style: TextStyle(
                        color: themeProvider.subtitleColor,
                        fontSize: scaleProvider.systemFontSize * 0.68,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$statusLabel · $reason'
                      '${trace.matchedKey != null ? ' · key: ${trace.matchedKey}' : ''}',
                      style: TextStyle(
                        color: statusColor.withAlpha(220),
                        fontSize: scaleProvider.systemFontSize * 0.6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
          // Entry list
          ...book.entries.asMap().entries.map((e) {
            final entry = e.value;
            final trace = traceByEntryId[entry.id];
            final isActive = trace?.activated == true;
            final matchedKey = trace?.matchedKey;
            final keywords = entry.keys.isNotEmpty
                ? entry.keys.join(', ')
                : '(no keywords)';
            final snippet = entry.content.length > 100
                ? '${entry.content.substring(0, 100)}...'
                : entry.content;

            return ListTile(
              dense: true,
              leading: Icon(
                isActive
                  ? Icons.check_circle
                  : (entry.enabled ? Icons.bookmark : Icons.bookmark_border),
                size: 16,
                color: isActive
                  ? Colors.greenAccent
                  : (entry.enabled
                      ? Colors.blueAccent
                      : themeProvider.faintestColor),
              ),
              title: Text(
                entry.comment.isNotEmpty ? entry.comment : 'Entry ${e.key + 1}',
                style: TextStyle(
                  color: themeProvider.subtitleColor,
                  fontSize: scaleProvider.systemFontSize * 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keywords,
                    style: TextStyle(
                      color: matchedKey != null
                          ? Colors.greenAccent
                          : Colors.orangeAccent.withAlpha(180),
                      fontSize: scaleProvider.systemFontSize * 0.65,
                      fontWeight: matchedKey != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (matchedKey != null)
                    Text(
                      'Matched key: $matchedKey',
                      style: TextStyle(
                        color: Colors.greenAccent.withAlpha(220),
                        fontSize: scaleProvider.systemFontSize * 0.58,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (snippet.isNotEmpty)
                    Text(
                      snippet,
                      style: TextStyle(
                        color: themeProvider.faintColor,
                        fontSize: scaleProvider.systemFontSize * 0.6,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable card field builder
  // ---------------------------------------------------------------------------

  /// Builds a labelled text field for one character card property with
  /// copy/paste helper buttons underneath.
  Widget _buildCardField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = true,
    VoidCallback? onEdit,
    bool allowTapToEdit = false,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          enableInteractiveSelection: true,
          onTap: allowTapToEdit ? onEdit : null,
          onChanged: readOnly ? null : (_) => _syncCardFromControllers(),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
            border: const OutlineInputBorder(),
            suffixIcon: readOnly && onEdit != null
                ? IconButton(
                    tooltip: 'Edit $label',
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: themeProvider.subtitleColor,
                    ),
                    onPressed: onEdit,
                  )
                : null,
          ),
          style: TextStyle(
            fontSize: 13,
            color: readOnly ? themeProvider.textColor : null,
          ),
        ),
      ],
    );
  }
}
