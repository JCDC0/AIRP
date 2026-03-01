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
import '../../models/lorebook_models.dart';
import '../../services/character_card_service.dart';
import '../../services/library_service.dart';

/// A panel for managing the AI character card (SillyTavern V1/V2 compatible).
///
/// Provides import/export of character card files (PNG with tEXt/iTXt chunks
/// or JSON), inline field editing with debounced auto-save, and clipboard
/// helpers for each card field.
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
  // Alternate Greetings helpers
  // ---------------------------------------------------------------------------

  void _addAlternateGreeting() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text('Add Alternate Greeting',
            style: TextStyle(
                color: themeProvider.textColor,
                fontSize: scaleProvider.systemFontSize)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          style: TextStyle(
              color: themeProvider.textColor,
              fontSize: scaleProvider.systemFontSize * 0.85),
          decoration: InputDecoration(
            hintText: 'Alternate first message...',
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              child: Text('Cancel',
                  style: TextStyle(
                      fontSize: scaleProvider.systemFontSize * 0.8)),
              onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: Text('Add',
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: scaleProvider.systemFontSize * 0.8)),
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    final card = chatProvider.characterCard;
    if (index >= card.alternateGreetings.length) return;

    final ctrl =
        TextEditingController(text: card.alternateGreetings[index]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        title: Text('Edit Greeting #${index + 1}',
            style: TextStyle(
                color: themeProvider.textColor,
                fontSize: scaleProvider.systemFontSize)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          style: TextStyle(
              color: themeProvider.textColor,
              fontSize: scaleProvider.systemFontSize * 0.85),
          decoration: InputDecoration(
            filled: true,
            fillColor: themeProvider.containerFillDarkColor,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              child: Text('Cancel',
                  style: TextStyle(
                      fontSize: scaleProvider.systemFontSize * 0.8)),
              onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: Text('Save',
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: scaleProvider.systemFontSize * 0.8)),
            onPressed: () {
              final greetings = List<String>.from(card.alternateGreetings);
              greetings[index] = ctrl.text.trim();
              chatProvider
                  .setCharacterCard(card.copyWith(alternateGreetings: greetings));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _removeAlternateGreeting(int index) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final card = chatProvider.characterCard;
    final greetings = List<String>.from(card.alternateGreetings);
    greetings.removeAt(index);
    chatProvider
        .setCharacterCard(card.copyWith(alternateGreetings: greetings));
  }

  // ---------------------------------------------------------------------------
  // Depth prompt role setter
  // ---------------------------------------------------------------------------

  void _setDepthPromptRole(LorebookRole role) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final card = chatProvider.characterCard;
    chatProvider.setCharacterCard(card.copyWith(depthPromptRole: role));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final card = chatProvider.characterCard;

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

              // --- Primary Card Fields ---
              _buildCardField("Name", _cardNameController),
              const SizedBox(height: 8),
              _buildCardField(
                  "Description / Persona", _cardDescriptionController,
                  maxLines: 3),
              const SizedBox(height: 8),
              _buildCardField("First Message", _cardFirstMesController,
                  maxLines: 3),
              const SizedBox(height: 8),

              // --- More Fields (collapsible) ---
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
                  const SizedBox(height: 8),
                  _buildCardField("Post-History Instructions",
                      _cardPostHistoryController,
                      maxLines: 2),
                ],
              ),

              // --- V2 Extended Fields (collapsible) ---
              ExpansionTile(
                title: Text(
                  "V2 Extended Fields",
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.85,
                    color: themeProvider.subtitleColor,
                  ),
                ),
                dense: true,
                children: [
                  _buildCardField(
                      "Creator Notes", _cardCreatorNotesController,
                      maxLines: 3),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _buildCardField(
                              "Creator", _cardCreatorController)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildCardField(
                              "Version", _cardVersionController)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- Tags ---
                  if (card.tags.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tags',
                          style: TextStyle(
                              color: themeProvider.subtitleColor,
                              fontSize:
                                  scaleProvider.systemFontSize * 0.8)),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: card.tags
                          .map((t) => Chip(
                                label: Text(t,
                                    style: TextStyle(
                                        fontSize: scaleProvider
                                                .systemFontSize *
                                            0.7,
                                        color: themeProvider.textColor)),
                                backgroundColor:
                                    themeProvider.containerFillColor,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),

              // --- Alternate Greetings (collapsible) ---
              ExpansionTile(
                title: Text(
                  "Alternate Greetings (${card.alternateGreetings.length})",
                  style: TextStyle(
                    fontSize: scaleProvider.systemFontSize * 0.85,
                    color: themeProvider.subtitleColor,
                  ),
                ),
                dense: true,
                children: [
                  ...card.alternateGreetings.asMap().entries.map((e) {
                    return ListTile(
                      dense: true,
                      title: Text(
                        e.value.length > 80
                            ? '${e.value.substring(0, 80)}...'
                            : e.value,
                        style: TextStyle(
                            color: themeProvider.textColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.8),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Greeting #${e.key + 1}',
                        style: TextStyle(
                            color: themeProvider.faintColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.65),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close,
                            color: themeProvider.faintestColor,
                            size: 16),
                        onPressed: () =>
                            _removeAlternateGreeting(e.key),
                      ),
                      onTap: () => _editAlternateGreeting(e.key),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: OutlinedButton.icon(
                      onPressed: _addAlternateGreeting,
                      icon: const Icon(Icons.add, size: 14),
                      label: Text('Add Greeting',
                          style: TextStyle(
                              fontSize:
                                  scaleProvider.systemFontSize * 0.8)),
                    ),
                  ),
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
                        _buildCardField("Depth Prompt Text",
                            _cardDepthPromptTextController,
                            maxLines: 3),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCardField("Depth (int)",
                                  _cardDepthPromptDepthController,
                                  keyboardType: TextInputType.number),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Role',
                                      style: TextStyle(
                                          color: themeProvider
                                              .subtitleColor,
                                          fontSize: scaleProvider
                                                  .systemFontSize *
                                              0.8)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: themeProvider
                                          .containerFillDarkColor,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                          color:
                                              themeProvider.borderColor),
                                    ),
                                    child: DropdownButton<LorebookRole>(
                                      value: card.depthPromptRole,
                                      isExpanded: true,
                                      dropdownColor:
                                          themeProvider.dropdownColor,
                                      underline: const SizedBox(),
                                      style: TextStyle(
                                          color:
                                              themeProvider.textColor,
                                          fontSize: scaleProvider
                                                  .systemFontSize *
                                              0.8),
                                      items: LorebookRole.values
                                          .map((r) =>
                                              DropdownMenuItem<
                                                  LorebookRole>(
                                                value: r,
                                                child: Text(r.name),
                                              ))
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
                      ],
                    ),
                  ),
                ],
              ),

              // --- Lorebook Sub-section (collapsible) ---
              _buildLorebookSection(card, themeProvider, scaleProvider),
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
  ) {
    final book = card.characterBook;
    final entryCount = book?.entries.length ?? 0;

    return ExpansionTile(
      title: Text(
        'Lorebook ($entryCount entries)',
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
                Icon(Icons.auto_stories,
                    size: 36, color: themeProvider.faintColor),
                const SizedBox(height: 8),
                Text(
                  'No embedded lorebook.',
                  style: TextStyle(
                      color: themeProvider.faintColor,
                      fontSize: scaleProvider.systemFontSize * 0.85),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Import a character card with a lorebook to see entries here.',
                  style: TextStyle(
                      color: themeProvider.faintestColor,
                      fontSize: scaleProvider.systemFontSize * 0.7),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (book != null && book.entries.isNotEmpty) ...[
          // Lorebook metadata
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    Text(book.name,
                        style: TextStyle(
                            color: themeProvider.textColor,
                            fontSize:
                                scaleProvider.systemFontSize * 0.85,
                            fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Scan: ${book.scanDepth}  \u2022  '
                    'Budget: ${book.tokenBudget} tok  \u2022  '
                    'Recursion: ${book.recursionSteps}',
                    style: TextStyle(
                        color: themeProvider.faintColor,
                        fontSize:
                            scaleProvider.systemFontSize * 0.7),
                  ),
                ],
              ),
            ),
          ),
          // Entry list
          ...book.entries.asMap().entries.map((e) {
            final entry = e.value;
            final keywords = entry.keys.isNotEmpty
                ? entry.keys.join(', ')
                : '(no keywords)';
            final snippet = entry.content.length > 100
                ? '${entry.content.substring(0, 100)}...'
                : entry.content;

            return ListTile(
              dense: true,
              leading: Icon(
                entry.enabled
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                size: 16,
                color: entry.enabled
                    ? Colors.blueAccent
                    : themeProvider.faintestColor,
              ),
              title: Text(
                entry.comment.isNotEmpty
                    ? entry.comment
                    : 'Entry ${e.key + 1}',
                style: TextStyle(
                    color: themeProvider.subtitleColor,
                    fontSize: scaleProvider.systemFontSize * 0.8),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keywords,
                    style: TextStyle(
                        color: Colors.orangeAccent.withAlpha(180),
                        fontSize:
                            scaleProvider.systemFontSize * 0.65),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (snippet.isNotEmpty)
                    Text(
                      snippet,
                      style: TextStyle(
                          color: themeProvider.faintColor,
                          fontSize:
                              scaleProvider.systemFontSize * 0.6),
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
  Widget _buildCardField(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType? keyboardType}) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
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
