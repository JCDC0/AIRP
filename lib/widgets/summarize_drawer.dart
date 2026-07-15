import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/scale_provider.dart';
import '../utils/constants.dart';

/// A drawer that produces a narrative summary + voice samples of the current
/// conversation and branches a fresh, compressed conversation.
///
/// Both prompts (`Compress prompt`, `Voice samples prompt`) are editable;
/// edits persist via SharedPreferences so they survive across sessions.
/// A 1–20 slider chooses how many assistant/user pairs to carry into the
/// new branch. Pressing **Compress** issues two one-shot LLM calls, appends
/// the results as AI messages to the current chat, then switches to the new
/// branched session seeded with [summary]+[voices]+[last N pairs].
class SummarizeDrawer extends StatefulWidget {
  /// Callback triggered when the drawer should be closed.
  final VoidCallback? onClose;

  const SummarizeDrawer({super.key, this.onClose});

  @override
  State<SummarizeDrawer> createState() => _SummarizeDrawerState();
}

class _SummarizeDrawerState extends State<SummarizeDrawer> {
  late TextEditingController _compressController;
  late TextEditingController _voicesController;
  int _pairCount = SummarizeDefaults.defaultPairs;
  bool _loadingPrefs = true;
  bool _compressing = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _compressController = TextEditingController(
      text: SummarizeDefaults.defaultCompressPrompt,
    );
    _voicesController = TextEditingController(
      text: SummarizeDefaults.defaultVoiceSamplesPrompt,
    );
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _compressController.text =
          prefs.getString(SummarizeDefaults.prefCompressPrompt) ??
          SummarizeDefaults.defaultCompressPrompt;
      _voicesController.text =
          prefs.getString(SummarizeDefaults.prefVoiceSamplesPrompt) ??
          SummarizeDefaults.defaultVoiceSamplesPrompt;
      _pairCount =
          prefs.getInt(SummarizeDefaults.prefPairCount) ??
          SummarizeDefaults.defaultPairs;
      _loadingPrefs = false;
    });
  }

  Future<void> _saveCompressPrompt(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SummarizeDefaults.prefCompressPrompt, v);
  }

  Future<void> _saveVoicesPrompt(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SummarizeDefaults.prefVoiceSamplesPrompt, v);
  }

  Future<void> _savePairCount(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SummarizeDefaults.prefPairCount, v);
  }

  @override
  void dispose() {
    _compressController.dispose();
    _voicesController.dispose();
    super.dispose();
  }

  Future<void> _runCompress() async {
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (chat.messages.isEmpty) {
      setState(() => _status = "Nothing to summarize — chat is empty.");
      return;
    }
    setState(() {
      _compressing = true;
      _status = "Compressing…";
    });
    try {
      final err = await chat.compressAndBranch(
        pairCount: _pairCount,
        compressPrompt: _compressController.text,
        voiceSamplesPrompt: _voicesController.text,
      );
      if (err == null) {
        setState(() {
          _status = "Compressed + branched. Switched to new conversation.";
        });
        widget.onClose?.call();
      } else {
        setState(() => _status = err);
      }
    } catch (e) {
      setState(() => _status = "Error: $e");
    } finally {
      setState(() => _compressing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final vfx = Provider.of<VfxProvider>(context);
    final scale = Provider.of<ScaleProvider>(context);

    return Material(
      elevation: vfx.enableBloom ? 20 : 16,
      shadowColor: vfx.enableBloom
          ? theme.bloomGlowColor.withValues(alpha: 0.3)
          : null,
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        width: scale.drawerWidth,
        height: double.infinity,
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
                  color: theme.containerFillColor,
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Summarize / Context",
                        style: TextStyle(
                          fontSize: scale.systemFontSize + 8,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                          shadows: vfx.enableBloom
                              ? [
                                  Shadow(
                                    color: theme.bloomGlowColor,
                                    blurRadius: 10,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Expanded(
                  child: _loadingPrefs
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          children: [
                            _sectionLabel(theme, scale, "Compress prompt"),
                            const SizedBox(height: 4),
                            _promptField(
                              controller: _compressController,
                              theme: theme,
                              scale: scale,
                              onChanged: _saveCompressPrompt,
                              minLines: 6,
                            ),
                            const SizedBox(height: 18),
                            _sectionLabel(theme, scale, "Voice samples prompt"),
                            const SizedBox(height: 4),
                            _promptField(
                              controller: _voicesController,
                              theme: theme,
                              scale: scale,
                              onChanged: _saveVoicesPrompt,
                              minLines: 6,
                            ),
                            const SizedBox(height: 18),
                            _sectionLabel(
                              theme,
                              scale,
                              "Pairs to carry into branch: $_pairCount",
                            ),
                            Slider(
                              value: _pairCount.toDouble(),
                              min: SummarizeDefaults.minPairs.toDouble(),
                              max: SummarizeDefaults.maxPairs.toDouble(),
                              divisions:
                                  SummarizeDefaults.maxPairs -
                                  SummarizeDefaults.minPairs,
                              label: "$_pairCount",
                              onChanged: (v) {
                                setState(() => _pairCount = v.round());
                                _savePairCount(v.round());
                              },
                            ),
                            const SizedBox(height: 8),
                            if (_status != null) ...[
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: theme.containerFillColor,
                                  border: Border.all(color: theme.borderColor),
                                ),
                                child: Text(
                                  _status!,
                                  style: TextStyle(
                                    color: theme.subtitleColor,
                                    fontSize: scale.systemFontSize - 2,
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _compressing ? null : _runCompress,
                                icon: _compressing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.compress),
                                label: const Text("Compress"),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: theme.textColor,
                  size: scale.iconScale * 22,
                ),
                tooltip: "Close",
                onPressed: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(ThemeProvider theme, ScaleProvider scale, String text) {
    return Text(
      text,
      style: TextStyle(
        color: theme.subtitleColor,
        fontWeight: FontWeight.bold,
        fontSize: scale.systemFontSize,
      ),
    );
  }

  Widget _promptField({
    required TextEditingController controller,
    required ThemeProvider theme,
    required ScaleProvider scale,
    required ValueChanged<String> onChanged,
    int minLines = 4,
  }) {
    return TextField(
      controller: controller,
      maxLines: null,
      minLines: minLines,
      style: TextStyle(
        color: theme.textColor,
        fontSize: scale.systemFontSize - 1,
        fontFamily: 'monospace',
      ),
      cursorColor: theme.textColor,
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.containerFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.borderColor),
        ),
        contentPadding: const EdgeInsets.all(10),
      ),
      onChanged: onChanged,
    );
  }
}
