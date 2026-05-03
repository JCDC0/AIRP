import 'dart:math' show Random;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/theme_provider.dart';
import '../models/lorebook_models.dart';
import 'chat_input/orbit_animations.dart';
import 'chat_input/chat_attachment_list.dart';
import 'chat_input/chat_action_bar.dart';
import 'chat_input/chat_input_field.dart';

/// A widget that provides the input interface for the chat.
///
/// This includes the text field, attachment buttons, feature toggles
/// (image gen, web search, reasoning), and the send/stop button.
class ChatInputArea extends StatefulWidget {
  /// Controller for the chat message list scroll position.
  final ScrollController scrollController;

  const ChatInputArea({super.key, required this.scrollController});

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final List<String> _pendingImages = [];

  /// On web, file paths are unavailable. This map stores the raw bytes
  /// keyed by the pseudo-path stored in [_pendingImages].
  final Map<String, Uint8List> _pendingImageBytes = {};
  final ImagePicker _picker = ImagePicker();
  late AnimationController _orbitController;
  List<OrbitLine> _orbitLines = [];
  List<OrbitLine> _iconOrbitLines = [];
  bool _isSending = false;
  LorebookEntry? _recognizedLorePreview;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _orbitLines = generateOrbitLines(Random(), lineCount: 3);
    _iconOrbitLines = generateOrbitLines(Random(), lineCount: 2, maxSpeed: 2);
    _textController.addListener(_updateLoreRecognitionPreview);
  }

  @override
  void dispose() {
    _textController.removeListener(_updateLoreRecognitionPreview);
    _orbitController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _updateLoreRecognitionPreview() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final next = chatProvider.previewRecognizedLoreEntry(_textController.text);
    final currentId = _recognizedLorePreview?.id;
    final nextId = next?.id;
    if (currentId != nextId) {
      if (!mounted) return;
      setState(() {
        _recognizedLorePreview = next;
      });
    }
  }

  /// Opens the gallery to pick an image.
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final key =
              'web_img_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
          _pendingImageBytes[key] = bytes;
          setState(() {
            _pendingImages.add(key);
          });
        } else {
          setState(() {
            _pendingImages.add(image.path);
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  /// Opens the file picker to attach a document.
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'pdf',
          'txt',
          'md',
          'doc',
          'docx',
        ],
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (kIsWeb) {
          final bytes = file.bytes;
          if (bytes != null) {
            final key =
                'web_file_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            _pendingImageBytes[key] = bytes;
            setState(() {
              _pendingImages.add(key);
            });
          }
        } else if (file.path != null) {
          setState(() {
            _pendingImages.add(file.path!);
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error picking file: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Displays a menu for selecting attachment types.
  void _showAttachmentMenu() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final vfxProvider = Provider.of<VfxProvider>(context, listen: false);
    final bool useBloom = vfxProvider.enableBloom;
    final Color themeColor = themeProvider.textColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.surfaceColor,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: themeColor,
                  shadows: useBloom
                      ? [Shadow(color: themeColor, blurRadius: 10)]
                      : [],
                ),
                title: Text(
                  'Image from Gallery',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    shadows: useBloom
                        ? [Shadow(color: themeColor, blurRadius: 8)]
                        : [],
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.description,
                  color: Colors.orangeAccent,
                  shadows: useBloom
                      ? [
                          const Shadow(
                            color: Colors.orangeAccent,
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                title: Text(
                  'Document / File',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    shadows: useBloom
                        ? [Shadow(color: themeColor, blurRadius: 8)]
                        : [],
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Sends the current message text and attachments to the provider.
  void _sendMessage() {
    // Prevent double sends
    if (_isSending) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final messageText = _textController.text;

    if (messageText.isEmpty && _pendingImages.isEmpty) return;

    _isSending = true;

    final List<String> imagesToSend = List.from(_pendingImages);

    // On web, pass the in-memory bytes alongside the pseudo-paths.
    final Map<String, Uint8List>? bytesToSend =
        kIsWeb && _pendingImageBytes.isNotEmpty
        ? Map.from(_pendingImageBytes)
        : null;

    chatProvider.sendMessage(
      messageText,
      imagesToSend,
      attachmentBytes: bytesToSend,
    );

    setState(() {
      _pendingImages.clear();
      _pendingImageBytes.clear();
      _textController.clear();
      _recognizedLorePreview = null;
    });

    _scrollToBottom();

    // Reset the sending flag after a short delay to allow the state to update
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    });
  }

  /// Scrolls the chat list to the top.
  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Scrolls the chat list to the bottom.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Displays a floating status popup.
  void _showStatusPopup(String message) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: themeProvider.overlayDarkColor,
        duration: const Duration(milliseconds: 800),
        margin: const EdgeInsets.only(bottom: 80, left: 60, right: 60),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final bool isLoading = chatProvider.isLoading;

    if (isLoading) {
      if (!_orbitController.isAnimating) {
        // Re-randomise lines on every new AI response
        final rng = Random();
        _orbitLines = generateOrbitLines(rng, lineCount: rng.nextInt(4) + 2);
        _iconOrbitLines = generateOrbitLines(
          Random(),
          lineCount: rng.nextInt(2) + 2,
          maxSpeed: 2,
        );
        _orbitController.repeat();
      }
    } else {
      if (_orbitController.isAnimating) {
        _orbitController.stop();
      }
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatAttachmentList(
                  pendingImages: _pendingImages,
                  pendingImageBytes: _pendingImageBytes,
                  onRemove: (index) {
                    setState(() {
                      final removed = _pendingImages.removeAt(index);
                      _pendingImageBytes.remove(removed);
                    });
                  },
                ),
                ChatActionBar(
                  isLoading: isLoading,
                  onShowAttachmentMenu: _showAttachmentMenu,
                  onScrollToTop: _scrollToTop,
                  onScrollToBottom: _scrollToBottom,
                  onShowStatusPopup: _showStatusPopup,
                  orbitController: _orbitController,
                  iconOrbitLines: _iconOrbitLines,
                ),
                const SizedBox(height: 12),
                ChatInputField(
                  textController: _textController,
                  hasPendingImages: _pendingImages.isNotEmpty,
                  isLoading: isLoading,
                  onSend: _sendMessage,
                  onCancel: chatProvider.cancelGeneration,
                  recognizedLorePreview: _recognizedLorePreview,
                  orbitController: _orbitController,
                  orbitLines: _orbitLines,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}