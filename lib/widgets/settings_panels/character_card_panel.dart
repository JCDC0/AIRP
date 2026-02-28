import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/character_card.dart';
import '../../services/character_card_service.dart';
import '../../services/library_service.dart';

/// A panel for managing the AI character card (SillyTavern V1/V2 compatible).
///
/// Provides import/export of character card files (PNG with tEXt/iTXt chunks
/// or JSON), inline field editing with debounced auto-save, and clipboard
/// helpers for each card field.
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
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

      final updatedCard = chatProvider.characterCard.copyWith(
        name: _cardNameController.text,
        description: _cardDescriptionController.text,
        firstMessage: _cardFirstMesController.text,
        scenario: _cardScenarioController.text,
        personality: _cardPersonalityController.text,
        mesExample: _cardMesExampleController.text,
        systemPrompt: _cardSystemPromptController.text,
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final card = await CharacterCardService.parseFile(file);

        if (card != null) {
          final warnings = CharacterCardService.validate(card);
          if (warnings.isNotEmpty) {
            if (!mounted) return;
            final themeProvider =
                Provider.of<ThemeProvider>(context, listen: false);
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Import Warnings",
                    style: TextStyle(color: Colors.orangeAccent)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: warnings
                      .map((w) => Text("• $w",
                          style:
                              TextStyle(color: themeProvider.subtitleColor)))
                      .toList(),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("OK")),
                ],
                backgroundColor: themeProvider.dropdownColor,
              ),
            );
          }

          if (!mounted) return;
          final chatProvider =
              Provider.of<ChatProvider>(context, listen: false);
          chatProvider.setCharacterCard(card);
          _updateCardControllers(card);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text("Imported '${card.name}' successfully!")),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Import failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import failed: $e")),
        );
      }
    }
  }

  /// Exports the current character card to a .json file.
  ///
  /// FIX: Previously called LibraryService.exportCharacterCard twice — once to
  /// generate bytes for FilePicker, and again inside the `if (outputFile)`
  /// block. Now only serialises once and reuses the result.
  Future<void> _handleExportCharacterCard() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final card = chatProvider.characterCard;

    if (card.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Character card is empty. Add a name first.")),
      );
      return;
    }

    try {
      // Serialise once and reuse for both the picker hint and file write.
      final jsonStr = await LibraryService.exportCharacterCard(card);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Character Card',
        fileName:
            '${card.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: bytes,
      );

      if (outputFile != null) {
        // On desktop, FilePicker may not write bytes — write manually.
        final file = File(outputFile);
        await file.writeAsString(jsonStr);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Exported to $outputFile")),
          );
        }
      }
    } catch (e) {
      debugPrint("Export failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    }
  }

  /// Resets the character card to an empty state.
  void _clearCharacterCard() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final emptyCard = CharacterCard();
    chatProvider.setCharacterCard(emptyCard);
    _updateCardControllers(emptyCard);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Character card cleared.")),
    );
  }

  // ---------------------------------------------------------------------------
  // Clipboard helpers
  // ---------------------------------------------------------------------------

  void _copyCardFieldToClipboard(
      TextEditingController controller, String fieldName) {
    final text = controller.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Copied $fieldName to Clipboard!"),
          duration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  Future<void> _pasteToCardField(
      TextEditingController controller, String fieldName) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        controller.text = data!.text!;
      });
      _syncCardFromControllers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pasted to $fieldName"),
          duration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Opacity(
      opacity: chatProvider.enableCharacterCard ? 1.0 : 0.5,
      child: AbsorbPointer(
        absorbing: !chatProvider.enableCharacterCard,
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
                        backgroundColor: Colors.blueAccent),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _handleExportCharacterCard,
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text("Export JSON"),
                  ),
                  TextButton(
                    onPressed: _clearCharacterCard,
                    child: const Text("Clear Card",
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
              Divider(color: themeProvider.borderColor),

              // Card fields
              _buildCardField("Name", _cardNameController),
              const SizedBox(height: 8),
              _buildCardField(
                  "Description / Persona", _cardDescriptionController,
                  maxLines: 3),
              const SizedBox(height: 8),
              _buildCardField("First Message", _cardFirstMesController,
                  maxLines: 3),
              const SizedBox(height: 8),

              // Collapsible secondary fields
              ExpansionTile(
                title: Text(
                  "More Fields (Scenario, Examples, etc.)",
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.85,
                    color: themeProvider.subtitleColor,
                  ),
                ),
                dense: true,
                children: [
                  _buildCardField("Scenario", _cardScenarioController,
                      maxLines: 2),
                  const SizedBox(height: 8),
                  _buildCardField("Personality", _cardPersonalityController,
                      maxLines: 2),
                  const SizedBox(height: 8),
                  _buildCardField(
                      "Example Dialogue (Mes Example)", _cardMesExampleController,
                      maxLines: 4),
                  const SizedBox(height: 8),
                  _buildCardField(
                      "Character System Prompt", _cardSystemPromptController,
                      maxLines: 2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a labelled text field for one character card property with
  /// copy/paste helper buttons underneath.
  Widget _buildCardField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: (_) => _syncCardFromControllers(),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.copy_rounded,
                    size: 16, color: themeProvider.textColor),
                onPressed: () =>
                    _copyCardFieldToClipboard(controller, label),
                tooltip: 'Copy $label',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.paste,
                    size: 16, color: Colors.greenAccent),
                onPressed: () => _pasteToCardField(controller, label),
                tooltip: 'Paste to $label',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
