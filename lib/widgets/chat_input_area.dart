import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/scale_provider.dart';
import '../models/chat_models.dart';

class ChatInputArea extends StatefulWidget {
  final ScrollController scrollController;

  const ChatInputArea({super.key, required this.scrollController});

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final List<String> _pendingImages = [];
  final ImagePicker _picker = ImagePicker();
  late AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _textController.dispose();
    super.dispose();
  }

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

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'txt', 'md', 'doc', 'docx'],
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
          SnackBar(content: Text("Error picking file: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAttachmentMenu() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool useBloom = themeProvider.enableBloom;
    final Color themeColor = themeProvider.appThemeColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: themeColor,
                  shadows: useBloom ? [Shadow(color: themeColor, blurRadius: 10)] : [],
                ),
                title: Text(
                  'Image from Gallery',
                  style: TextStyle(
                    color: Colors.white,
                    shadows: useBloom ? [Shadow(color: themeColor, blurRadius: 8)] : [],
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
                  shadows: useBloom ? [const Shadow(color: Colors.orangeAccent, blurRadius: 10)] : [],
                ),
                title: Text(
                  'Document / File',
                  style: TextStyle(
                    color: Colors.white,
                    shadows: useBloom ? [Shadow(color: themeColor, blurRadius: 8)] : [],
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

  void _sendMessage() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final messageText = _textController.text;
    
    if (messageText.isEmpty && _pendingImages.isEmpty) return;

    final List<String> imagesToSend = List.from(_pendingImages);
    
    chatProvider.sendMessage(messageText, imagesToSend);
    
    setState(() {
      _pendingImages.clear();
      _textController.clear();
    });
    
    _scrollToBottom();
  }

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

  void _showStatusPopup(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.black87,
        duration: const Duration(milliseconds: 800),
        margin: const EdgeInsets.only(bottom: 80, left: 60, right: 60),
      )
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
    Color backgroundColor = Colors.black,
    String? tooltip,
    bool isActive = false,
    ThemeProvider? themeProvider,
    ScaleProvider? scaleProvider,
  }) {
    final bool useBloom = themeProvider?.enableBloom ?? false;
    final double iconScale = scaleProvider?.iconScale ?? 1.0;
    final double containerSize = 40 * iconScale;

    return Container(
      width: containerSize,
      height: containerSize,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: isActive && useBloom && color != null
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8 * iconScale, spreadRadius: 1 * iconScale)]
            : [],
        border: isActive ? Border.all(color: color ?? Colors.white, width: 1.5 * iconScale) : null,
      ),
      child: IconButton(
        icon: Icon(icon),
        color: color ?? Colors.white,
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
    );
  }

  Widget _buildFeatureSwitch({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onToggle,
    required ThemeProvider themeProvider,
    required ScaleProvider scaleProvider,
    required bool isLoading,
  }) {
    return _buildCircularButton(
      icon: icon,
      onPressed: isLoading ? null : onToggle,
      color: isActive ? activeColor : Colors.grey[400],
      isActive: isActive,
      themeProvider: themeProvider,
      scaleProvider: scaleProvider,
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
                // ROW 0: ATTACHMENTS LIST
                if (_pendingImages.isNotEmpty) ...[
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingImages.length,
                      itemBuilder: (context, index) {
                        final path = _pendingImages[index];
                        final ext = path.split('.').last.toLowerCase();
                        final isImage = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);

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
                                                          icon: const Icon(Icons.close,
                                                              color: Colors.white, size: 30),
                                                          onPressed: () => Navigator.pop(context),
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ));
                                      }
                                    : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isImage
                                      ? Image.file(File(path),
                                          width: 50, height: 50, fit: BoxFit.cover)
                                      : Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.white12,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            ext == 'pdf'
                                                ? Icons.picture_as_pdf
                                                : Icons.insert_drive_file,
                                            color: Colors.white70,
                                            size: 24,
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: InkWell(
                                  onTap: () => setState(() => _pendingImages.removeAt(index)),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close, size: 10, color: Colors.white),
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

                // ROW 1: Icons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCircularButton(
                        icon: Icons.attach_file,
                        color: themeProvider.appThemeColor,
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
                          chatProvider.setEnableImageGen(!chatProvider.enableImageGen);
                          await chatProvider.saveSettings(showConfirmation: false);
                          _showStatusPopup(chatProvider.enableImageGen ? "Image Gen ON" : "Image Gen OFF");
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
                            chatProvider.setEnableUsage(!chatProvider.enableUsage);
                            await chatProvider.saveSettings(showConfirmation: false);
                            _showStatusPopup(chatProvider.enableUsage ? "Usage Stats ON" : "Usage Stats OFF");
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
                          chatProvider.setEnableGrounding(!chatProvider.enableGrounding);
                          await chatProvider.saveSettings(showConfirmation: false);
                          _showStatusPopup(chatProvider.enableGrounding ? "Web Search ON" : "Web Search OFF");
                        },
                        themeProvider: themeProvider,
                        scaleProvider: scaleProvider,
                      ),
                      // REASONING BUTTON
                      Builder(
                        builder: (context) {
                          Color? reasoningColor;
                          bool isActive = chatProvider.reasoningEffort != 'none';
                          
                          if (chatProvider.reasoningEffort == 'low') {
                            reasoningColor = Colors.grey[600];
                          } else if (chatProvider.reasoningEffort == 'medium') {
                            reasoningColor = Colors.grey[400];
                          } else if (chatProvider.reasoningEffort == 'high') {
                            reasoningColor = Colors.white;
                          }

                          return _buildCircularButton(
                            icon: Icons.psychology,
                            color: isActive ? reasoningColor : Colors.grey[400],
                            isActive: isActive,
                            tooltip: "Reasoning Effort: ${chatProvider.reasoningEffort}",
                            onPressed: isLoading ? null : () async {
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
                              chatProvider.setReasoningEffort(nextState);
                              await chatProvider.saveSettings(showConfirmation: false);
                              _showStatusPopup(statusMsg);
                            },
                            themeProvider: themeProvider,
                            scaleProvider: scaleProvider,
                          );
                        }
                      ),

                      // SCROLL BUTTONS
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

                // ROW 2: Input + Send Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 3. INPUT FIELD
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _orbitController,
                        builder: (context, child) {
                          return CustomPaint(
                            foregroundPainter: isLoading ? LineOrbitPainter(
                              progress: _orbitController.value,
                              color: Colors.white,
                              bloomColor: themeProvider.appThemeColor,
                              enableBloom: themeProvider.enableBloom,
                            ) : null,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: Colors.black,
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: scaleProvider.inputAreaScale.toInt(),
                          style: TextStyle(color: Colors.white, fontSize: scaleProvider.chatFontSize),
                          decoration: InputDecoration(
                            hintText: _pendingImages.isNotEmpty
                                ? 'Add a caption...'
                                : (chatProvider.enableGrounding
                                    ? 'Search web...'
                                    : (chatProvider.enableImageGen ? 'Describe image...' : 'Message...')),
                            hintStyle: TextStyle(color: Colors.grey[500], fontSize: scaleProvider.chatFontSize),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isLoading ? Colors.transparent : Colors.grey[900]!,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isLoading ? Colors.transparent : Colors.grey[900]!,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isLoading ? Colors.transparent : themeProvider.appThemeColor.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.black,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // 4. SEND BUTTON
                    IconButton.filled(
                      style: IconButton.styleFrom(
                          backgroundColor: isLoading
                              ? themeProvider.appThemeColor.withValues(alpha: 0.2)
                              : (chatProvider.enableGrounding ? Colors.green : themeProvider.appThemeColor),
                          fixedSize: Size(40 * scaleProvider.iconScale, 40 * scaleProvider.iconScale)),
                      onPressed: isLoading ? chatProvider.cancelGeneration : _sendMessage,
                      icon: Icon(isLoading ? Icons.stop_circle_outlined : Icons.send,
                          color: isLoading ? themeProvider.appThemeColor : Colors.black, size: 20 * scaleProvider.iconScale),
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

class LineOrbitPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bloomColor;
  final bool enableBloom;

  LineOrbitPainter({
    required this.progress,
    required this.color,
    required this.bloomColor,
    required this.enableBloom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));
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

    // Define 3 lines with unique curves and properties for organic "randomness"
    final List<Map<String, dynamic>> lines = [
      {'speed': 1.0, 'offset': 0.15, 'length': 0.2, 'curve': Curves.easeInOutSine},
      {'speed': 1.5, 'offset': 0.45, 'length': 0.15, 'curve': Curves.fastOutSlowIn},
      {'speed': 0.8, 'offset': 0.75, 'length': 0.25, 'curve': Curves.slowMiddle},
    ];

    for (var line in lines) {
      // Apply unique curve per line
      double p = (progress * (line['speed'] as double) + (line['offset'] as double)) % 1.0;
      double curvedP = (line['curve'] as Curve).transform(p);
      
      double startOffset = curvedP * pathLength;
      double segmentLength = (line['length'] as double) * pathLength;
      
      Path extract;
      if (startOffset + segmentLength <= pathLength) {
        extract = metric.extractPath(startOffset, startOffset + segmentLength);
      } else {
        extract = metric.extractPath(startOffset, pathLength);
        extract.addPath(metric.extractPath(0, (startOffset + segmentLength) % pathLength), Offset.zero);
      }

      if (enableBloom) {
        canvas.drawPath(extract, bloomPaint);
      }
      canvas.drawPath(extract, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineOrbitPainter oldDelegate) => 
    oldDelegate.progress != progress || oldDelegate.enableBloom != enableBloom;
}