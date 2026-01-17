import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../models/chat_models.dart';

class ChatInputArea extends StatefulWidget {
  final ScrollController scrollController;

  const ChatInputArea({super.key, required this.scrollController});

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _textController = TextEditingController();
  final List<String> _pendingImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
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
    Color backgroundColor = const Color(0x99000000),
    String? tooltip,
    bool isActive = false,
    ThemeProvider? themeProvider,
  }) {
    final bool useBloom = themeProvider?.enableBloom ?? false;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: isActive && useBloom && color != null
            ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)]
            : [],
        border: isActive ? Border.all(color: color ?? Colors.white, width: 1.5) : null,
      ),
      child: IconButton(
        icon: Icon(icon),
        color: color ?? Colors.white,
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 20,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    );
  }

  Widget _buildFeatureSwitch({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onToggle,
    required ThemeProvider themeProvider,
    required bool isLoading,
  }) {
    return _buildCircularButton(
      icon: icon,
      onPressed: isLoading ? null : onToggle,
      color: isActive ? activeColor : Colors.grey[400],
      isActive: isActive,
      themeProvider: themeProvider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final bool isLoading = chatProvider.isLoading;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            LinearProgressIndicator(color: themeProvider.appThemeColor, minHeight: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ROW 1: Icons + Attachments
                Row(
                  children: [
                    // 1. ICONS ROW
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCircularButton(
                          icon: Icons.attach_file,
                          color: themeProvider.appThemeColor,
                          tooltip: "Add Attachment",
                          onPressed: isLoading ? null : _showAttachmentMenu,
                          themeProvider: themeProvider,
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
                        ),
                      ],
                    ),

                    // 2. ATTACHMENTS LIST (Scrollable)
                    if (_pendingImages.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
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
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // ROW 2: Input + Send Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 3. INPUT FIELD
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 6,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _pendingImages.isNotEmpty
                              ? 'Add a caption...'
                              : (chatProvider.enableGrounding
                                  ? 'Search web...'
                                  : (chatProvider.enableImageGen ? 'Describe image...' : 'Message...')),
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: const Color(0x99000000),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: isLoading ? null : (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // 4. SEND BUTTON
                    IconButton.filled(
                      style: IconButton.styleFrom(
                          backgroundColor: isLoading
                              ? themeProvider.appThemeColor.withOpacity(0.2)
                              : (chatProvider.enableGrounding ? Colors.green : themeProvider.appThemeColor),
                          fixedSize: const Size(40, 40)),
                      onPressed: isLoading ? chatProvider.cancelGeneration : _sendMessage,
                      icon: Icon(isLoading ? Icons.stop_circle_outlined : Icons.send,
                          color: isLoading ? themeProvider.appThemeColor : Colors.black, size: 20),
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
