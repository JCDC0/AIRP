import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/scale_provider.dart';
import '../models/chat_models.dart';

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
  final ImagePicker _picker = ImagePicker();
  late AnimationController _orbitController;
  List<_OrbitLine> _orbitLines = [];
  List<_OrbitLine> _iconOrbitLines = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _orbitLines = _generateOrbitLines(Random(), lineCount: 3);
    _iconOrbitLines = _generateOrbitLines(Random(), lineCount: 2, maxSpeed: 2);
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// Opens the gallery to pick an image.
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _pendingImages.add(image.path);
        });
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
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() {
          _pendingImages.add(path);
        });
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
    final bool useBloom = themeProvider.enableBloom;
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

    chatProvider.sendMessage(messageText, imagesToSend);

    setState(() {
      _pendingImages.clear();
      _textController.clear();
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

  /// Builds a circular button with consistent styling.
  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
    Color backgroundColor = Colors.transparent,
    String? tooltip,
    bool isActive = false,
    ThemeProvider? themeProvider,
    ScaleProvider? scaleProvider,
  }) {
    final bool useBloom = themeProvider?.enableBloom ?? false;
    final double iconScale = scaleProvider?.iconScale ?? 1.0;
    final double containerSize = 40 * iconScale;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: isActive && useBloom && color != null
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8 * iconScale,
                    spreadRadius: 1 * iconScale,
                  ),
                ]
              : [],
          border: isActive
              ? Border.all(
                  color: color ?? themeProvider?.textColor ?? Colors.white,
                  width: 0.5 * iconScale,
                )
              : null,
        ),
        child: IconButton(
          icon: Icon(icon),
          color: color ?? themeProvider?.textColor ?? Colors.white,
          tooltip: tooltip,
          onPressed: onPressed,
          iconSize: 20 * iconScale,
          constraints: BoxConstraints(
            minWidth: containerSize,
            minHeight: containerSize,
            maxWidth: containerSize,
            maxHeight: containerSize,
          ),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  /// Builds a toggle button for AI features with animated border when active & loading.
  Widget _buildFeatureSwitch({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onToggle,
    required ThemeProvider themeProvider,
    required ScaleProvider scaleProvider,
    required bool isLoading,
  }) {
    final bool useBloom = themeProvider.enableBloom;
    final double iconScale = scaleProvider.iconScale;
    final double containerSize = 40 * iconScale;
    final Color iconColor = isActive
        ? activeColor
        : (Colors.grey[400] ?? Colors.grey);

    Widget buttonContent = Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: themeProvider.inputFillColor,
        shape: BoxShape.circle,
        boxShadow: isActive && useBloom
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.6),
                  blurRadius: 8 * iconScale,
                  spreadRadius: 1 * iconScale,
                ),
              ]
            : [],
        border: isActive
            ? Border.all(color: activeColor, width: 0.5 * iconScale)
            : null,
      ),
      child: IconButton(
        icon: Icon(icon),
        color: iconColor,
        onPressed: isLoading ? null : onToggle,
        iconSize: 20 * iconScale,
        constraints: BoxConstraints(
          minWidth: containerSize,
          minHeight: containerSize,
          maxWidth: containerSize,
          maxHeight: containerSize,
        ),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
      ),
    );

    // Wrap with arc animation if active AND loading AND loading animation enabled
    if (isActive && isLoading && themeProvider.enableLoadingAnimation) {
      buttonContent = AnimatedBuilder(
        animation: _orbitController,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _IconArcPainter(
              progress: _orbitController.value,
              lines: _iconOrbitLines,
              color: activeColor,
              strokeWidth: 2.5 * iconScale,
              enableBloom: useBloom,
              bloomColor: themeProvider.bloomGlowColor,
            ),
            child: child,
          );
        },
        child: buttonContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: containerSize,
        height: containerSize,
        child: buttonContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final bool isLoading = chatProvider.isLoading;

    if (isLoading) {
      if (!_orbitController.isAnimating) {
        // Re-randomise lines on every new AI response
        final rng = Random();
        _orbitLines = _generateOrbitLines(rng, lineCount: rng.nextInt(4) + 2);
        _iconOrbitLines = _generateOrbitLines(
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
                if (_pendingImages.isNotEmpty) ...[
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingImages.length,
                      itemBuilder: (context, index) {
                        final path = _pendingImages[index];
                        final ext = path.split('.').last.toLowerCase();
                        final isImage = [
                          'jpg',
                          'jpeg',
                          'png',
                          'webp',
                          'heic',
                        ].contains(ext);

                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: isImage
                                    ? () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding: EdgeInsets.zero,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                InteractiveViewer(
                                                  maxScale: 5.0,
                                                  child: Image.file(File(path)),
                                                ),
                                                Positioned(
                                                  top: 40,
                                                  right: 20,
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 30,
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isImage
                                      ? Image.file(
                                          File(path),
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 50,
                                          height: 50,
                                          color: themeProvider.borderColor,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            ext == 'pdf'
                                                ? Icons.picture_as_pdf
                                                : Icons.insert_drive_file,
                                            color: themeProvider.subtitleColor,
                                            size: 24,
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: InkWell(
                                  onTap: () => setState(
                                    () => _pendingImages.removeAt(index),
                                  ),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.close,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCircularButton(
                        icon: Icons.attach_file,
                        color: themeProvider.textColor,
                        tooltip: "Add Attachment",
                        onPressed: isLoading ? null : _showAttachmentMenu,
                        themeProvider: themeProvider,
                        scaleProvider: scaleProvider,
                      ),
                      _buildFeatureSwitch(
                        icon: Icons.image,
                        isActive: chatProvider.enableImageGen,
                        activeColor: Colors.purpleAccent,
                        isLoading: isLoading,
                        onToggle: () async {
                          chatProvider.setEnableImageGen(
                            !chatProvider.enableImageGen,
                          );
                          await chatProvider.saveSettings(
                            showConfirmation: false,
                          );
                          _showStatusPopup(
                            chatProvider.enableImageGen
                                ? "Image Gen ON"
                                : "Image Gen OFF",
                          );
                        },
                        themeProvider: themeProvider,
                        scaleProvider: scaleProvider,
                      ),
                      if (chatProvider.currentProvider == AiProvider.openRouter)
                        _buildFeatureSwitch(
                          icon: Icons.data_usage,
                          isActive: chatProvider.enableUsage,
                          activeColor: Colors.tealAccent,
                          isLoading: isLoading,
                          onToggle: () async {
                            chatProvider.setEnableUsage(
                              !chatProvider.enableUsage,
                            );
                            await chatProvider.saveSettings(
                              showConfirmation: false,
                            );
                            _showStatusPopup(
                              chatProvider.enableUsage
                                  ? "Usage Stats ON"
                                  : "Usage Stats OFF",
                            );
                          },
                          themeProvider: themeProvider,
                          scaleProvider: scaleProvider,
                        ),
                      _buildFeatureSwitch(
                        icon: Icons.public,
                        isActive: chatProvider.enableGrounding,
                        activeColor: Colors.blueAccent,
                        isLoading: isLoading,
                        onToggle: () async {
                          chatProvider.setEnableGrounding(
                            !chatProvider.enableGrounding,
                          );
                          await chatProvider.saveSettings(
                            showConfirmation: false,
                          );
                          _showStatusPopup(
                            chatProvider.enableGrounding
                                ? "Web Search ON"
                                : "Web Search OFF",
                          );
                        },
                        themeProvider: themeProvider,
                        scaleProvider: scaleProvider,
                      ),
                      Builder(
                        builder: (context) {
                          Color? reasoningColor;
                          bool isActive =
                              chatProvider.reasoningEffort != 'none';

                          if (chatProvider.reasoningEffort == 'low') {
                            reasoningColor = Colors.grey[600];
                          } else if (chatProvider.reasoningEffort == 'medium') {
                            reasoningColor = Colors.grey[400];
                          } else if (chatProvider.reasoningEffort == 'high') {
                            reasoningColor = themeProvider.textColor;
                          }

                          final Color iconColor = isActive
                              ? (reasoningColor ?? Colors.grey[400]!)
                              : (Colors.grey[400] ?? Colors.grey);
                          final double iconScale = scaleProvider.iconScale;
                          final double containerSize = 40 * iconScale;

                          Widget buttonContent = Container(
                            width: containerSize,
                            height: containerSize,
                            decoration: BoxDecoration(
                              color: themeProvider.inputFillColor,
                              shape: BoxShape.circle,
                              boxShadow:
                                  isActive &&
                                      themeProvider.enableBloom &&
                                      reasoningColor != null
                                  ? [
                                      BoxShadow(
                                        color: reasoningColor.withValues(
                                          alpha: 0.6,
                                        ),
                                        blurRadius: 8 * iconScale,
                                        spreadRadius: 1 * iconScale,
                                      ),
                                    ]
                                  : [],
                              border: isActive
                                  ? Border.all(
                                      color:
                                          reasoningColor ??
                                          themeProvider.textColor,
                                      width: 0.5 * iconScale,
                                    )
                                  : null,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.psychology),
                              color: iconColor,
                              tooltip:
                                  "Reasoning Effort: ${chatProvider.reasoningEffort}",
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      String nextState;
                                      String statusMsg;
                                      switch (chatProvider.reasoningEffort) {
                                        case 'none':
                                          nextState = 'low';
                                          statusMsg = "Reasoning: LOW";
                                          break;
                                        case 'low':
                                          nextState = 'medium';
                                          statusMsg = "Reasoning: MEDIUM";
                                          break;
                                        case 'medium':
                                          nextState = 'high';
                                          statusMsg = "Reasoning: HIGH";
                                          break;
                                        case 'high':
                                          nextState = 'none';
                                          statusMsg = "Reasoning: OFF";
                                          break;
                                        default:
                                          nextState = 'low';
                                          statusMsg = "Reasoning: LOW";
                                      }
                                      chatProvider.setReasoningEffort(
                                        nextState,
                                      );
                                      await chatProvider.saveSettings(
                                        showConfirmation: false,
                                      );
                                      _showStatusPopup(statusMsg);
                                    },
                              iconSize: 20 * iconScale,
                              constraints: BoxConstraints(
                                minWidth: containerSize,
                                minHeight: containerSize,
                                maxWidth: containerSize,
                                maxHeight: containerSize,
                              ),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          );

                          // Animate if active, loading, and loading animation enabled
                          if (isActive &&
                              isLoading &&
                              themeProvider.enableLoadingAnimation) {
                            buttonContent = AnimatedBuilder(
                              animation: _orbitController,
                              builder: (context, child) {
                                return CustomPaint(
                                  foregroundPainter: _IconArcPainter(
                                    progress: _orbitController.value,
                                    lines: _iconOrbitLines,
                                    color:
                                        reasoningColor ??
                                        themeProvider.textColor,
                                    strokeWidth: 2.5 * iconScale,
                                    enableBloom: themeProvider.enableBloom,
                                    bloomColor: themeProvider.bloomGlowColor,
                                  ),
                                  child: child,
                                );
                              },
                              child: buttonContent,
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: containerSize,
                              height: containerSize,
                              child: buttonContent,
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 12),
                      Container(width: 1, height: 24, color: Colors.grey[800]),
                      const SizedBox(width: 12),

                      _buildCircularButton(
                        icon: Icons.vertical_align_top,
                        tooltip: "Scroll to Top",
                        onPressed: _scrollToTop,
                        themeProvider: themeProvider,
                        scaleProvider: scaleProvider,
                      ),
                      _buildCircularButton(
                        icon: Icons.vertical_align_bottom,
                        tooltip: "Scroll to Bottom",
                        onPressed: _scrollToBottom,
                        themeProvider: themeProvider,
                        scaleProvider: scaleProvider,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Focus(
                        onKey: (node, event) {
                          // Handle Ctrl+Enter or Cmd+Enter to send message
                          if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
                            final isCtrlOrCmd =
                                HardwareKeyboard.instance.isLogicalKeyPressed(
                                  LogicalKeyboardKey.controlLeft,
                                ) ||
                                HardwareKeyboard.instance.isLogicalKeyPressed(
                                  LogicalKeyboardKey.controlRight,
                                ) ||
                                HardwareKeyboard.instance.isLogicalKeyPressed(
                                  LogicalKeyboardKey.metaLeft,
                                ) ||
                                HardwareKeyboard.instance.isLogicalKeyPressed(
                                  LogicalKeyboardKey.metaRight,
                                );
                            if (isCtrlOrCmd && !isLoading) {
                              _sendMessage();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: AnimatedBuilder(
                          animation: _orbitController,
                          builder: (context, child) {
                            return CustomPaint(
                              foregroundPainter:
                                  isLoading &&
                                      themeProvider.enableLoadingAnimation
                                  ? LineOrbitPainter(
                                      progress: _orbitController.value,
                                      lines: _orbitLines,
                                      color: themeProvider.textColor,
                                      bloomColor: themeProvider.bloomGlowColor,
                                      enableBloom: themeProvider.enableBloom,
                                      borderRadius: 24.0,
                                    )
                                  : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: themeProvider.inputFillColor,
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: TextField(
                            controller: _textController,
                            minLines: 1,
                            maxLines: scaleProvider.inputAreaScale.toInt(),
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: scaleProvider.chatFontSize,
                            ),
                            decoration: InputDecoration(
                              hintText: _pendingImages.isNotEmpty
                                  ? 'Add a caption...'
                                  : (chatProvider.enableGrounding
                                        ? 'Search web...'
                                        : (chatProvider.enableImageGen
                                              ? 'Describe image...'
                                              : 'Message...')),
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: scaleProvider.chatFontSize,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: isLoading
                                      ? Colors.transparent
                                      : Colors.grey[900]!,
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: isLoading
                                      ? Colors.transparent
                                      : Colors.grey[900]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: isLoading
                                      ? Colors.transparent
                                      : themeProvider.textColor.withValues(
                                          alpha: 0.5,
                                        ),
                                  width: 1,
                                ),
                              ),
                              filled: true,
                              fillColor: themeProvider.inputFillColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: isLoading
                            ? themeProvider.textColor.withValues(alpha: 0.2)
                            : (chatProvider.enableGrounding
                                  ? Colors.green
                                  : themeProvider.textColor),
                        fixedSize: Size(
                          40 * scaleProvider.iconScale,
                          40 * scaleProvider.iconScale,
                        ),
                      ),
                      onPressed: isLoading
                          ? chatProvider.cancelGeneration
                          : _sendMessage,
                      icon: Icon(
                        isLoading ? Icons.stop_circle_outlined : Icons.send,
                        color: isLoading
                            ? themeProvider.textColor
                            : themeProvider.onAccentColor,
                        size: 20 * scaleProvider.iconScale,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom painter that draws orbiting lines around the input field.
///
// ---------------------------------------------------------------------------
// Orbit line data & generator
// ---------------------------------------------------------------------------

/// Immutable config for a single orbiting arc/line.
class _OrbitLine {
  final int speed; // Whole-number speed multiplier (1, 2 or 3)
  final double offset; // Starting phase offset [0, 1)
  final double length; // Arc fraction of total path [0.1, 0.35)

  const _OrbitLine({
    required this.speed,
    required this.offset,
    required this.length,
  });
}

/// Generates [lineCount] randomised orbit lines with whole-number speeds so
/// that every arc completes full cycles within one controller period,
/// eliminating stutter at the repeat boundary.
List<_OrbitLine> _generateOrbitLines(
  Random rng, {
  int lineCount = 3,
  int maxSpeed = 3,
}) {
  final int count = lineCount.clamp(2, 5);
  // Assign distinct speeds cycling through 1..maxSpeed
  final List<int> speeds = List.generate(count, (i) => (i % maxSpeed) + 1);
  // Shuffle so order isn't always ascending
  speeds.shuffle(rng);

  return List.generate(count, (i) {
    final double offset = (i / count) + rng.nextDouble() * 0.1;
    final double length = 0.10 + rng.nextDouble() * 0.20; // 10 %–30 %
    return _OrbitLine(speed: speeds[i], offset: offset % 1.0, length: length);
  });
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Draws randomised animated lines orbiting the rounded-rectangle border of the
/// chat text field. This is used as a loading indicator when an AI response is
/// being generated.
class LineOrbitPainter extends CustomPainter {
  final double progress;
  final List<_OrbitLine> lines;
  final Color color;
  final Color bloomColor;
  final bool enableBloom;
  final double borderRadius;

  LineOrbitPainter({
    required this.progress,
    required this.lines,
    required this.color,
    required this.bloomColor,
    required this.enableBloom,
    this.borderRadius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );
    final Path path = Path()..addRRect(rrect);

    final List<ui.PathMetric> metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final ui.PathMetric metric = metrics.first;
    final double pathLength = metric.length;

    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = ui.StrokeCap.round;

    final Paint bloomPaint = Paint()
      ..color = bloomColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..strokeCap = ui.StrokeCap.round;

    for (final line in lines) {
      final double p = (progress * line.speed + line.offset) % 1.0;

      final double startOffset = p * pathLength;
      final double segmentLength = line.length * pathLength;

      Path extract;
      if (startOffset + segmentLength <= pathLength) {
        extract = metric.extractPath(startOffset, startOffset + segmentLength);
      } else {
        extract = metric.extractPath(startOffset, pathLength);
        extract.addPath(
          metric.extractPath(0, (startOffset + segmentLength) % pathLength),
          Offset.zero,
        );
      }

      if (enableBloom) {
        canvas.drawPath(extract, bloomPaint);
      }
      canvas.drawPath(extract, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.enableBloom != enableBloom;
}

/// Draws randomised animated arcs around a circular icon button.
class _IconArcPainter extends CustomPainter {
  final double progress;
  final List<_OrbitLine> lines;
  final Color color;
  final double strokeWidth;
  final bool enableBloom;
  final Color bloomColor;

  _IconArcPainter({
    required this.progress,
    required this.lines,
    required this.color,
    required this.strokeWidth,
    required this.enableBloom,
    required this.bloomColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = strokeWidth / 2;
    final Rect arcRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final Paint arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    Paint? bloomPaint;
    if (enableBloom) {
      bloomPaint = Paint()
        ..color = bloomColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..strokeCap = StrokeCap.round;
    }

    for (final line in lines) {
      // Full circle arc — sweep angle is a fraction of the circle
      final double startAngle =
          ((progress * line.speed + line.offset) % 1.0) * 2 * math.pi;
      // Each line covers ~90°; shorter lines for higher-speed arcs feel snappier
      final double sweepAngle = line.length * 2 * math.pi;

      if (bloomPaint != null) {
        canvas.drawArc(arcRect, startAngle, sweepAngle, false, bloomPaint);
      }
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IconArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
