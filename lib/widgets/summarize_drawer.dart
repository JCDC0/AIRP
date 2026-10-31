import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/scale_provider.dart';
import '../services/compaction_service.dart';
import '../utils/constants.dart';
import 'settings_panels/settings_slider.dart';

/// Drawer that compacts the current conversation and branches a fresh one.
///
/// Two modes, chosen by the selector in the fixed footer:
///
/// * **Simple Compact to New Conversation** runs an ordered list of user
///   editable rules against ONE shared document and carries the result as a
///   single block. It used to be exactly two prompts producing two separate
///   messages; rules are now addable, renameable and removable, and compose
///   through the `edit_document` tool so a later rule can revise an earlier
///   one's section.
/// * **Compact to Chronicle** does the same but seeds the document from the
///   conversation's existing chronicle and writes the result back as the
///   pinned chronicle block, so the narrative accumulates across conversations.
///
/// While a run is in flight the drawer names the rule currently executing and
/// shows the shared document in an editable box. Edits to that box win over
/// what the rules produced.
class SummarizeDrawer extends StatefulWidget {
  /// Callback triggered when the drawer should be closed.
  final VoidCallback? onClose;

  const SummarizeDrawer({super.key, this.onClose});

  @override
  State<SummarizeDrawer> createState() => _SummarizeDrawerState();
}

class _SummarizeDrawerState extends State<SummarizeDrawer> {
  /// One controller per rule, keyed by rule id.
  ///
  /// Never one shared controller: a single field standing in for several values
  /// is the API-key-box bug, where the box kept showing the previous
  /// provider's key while the new provider's slot was empty.
  final Map<String, TextEditingController> _ruleControllers = {};
  final Map<String, TextEditingController> _ruleNameControllers = {};
  late TextEditingController _documentController;

  /// The document text the box last received from the provider.
  ///
  /// Compared against instead of guarding on focus: a focus guard also drops
  /// external writes, which here would mean the next rule's output never
  /// reaching a box the user happens to be editing.
  String _observedDocument = '';

  List<CompactRule> _rules = [];
  int _blockCount = SummarizeDefaults.defaultBlocks;
  String _mode = SummarizeDefaults.modeSimple;
  bool _showLiveDocument = true;
  bool _compressing = false;
  String? _status;
  bool _loaded = false;

  bool get _isChronicleMode => _mode == SummarizeDefaults.modeChronicle;

  @override
  void initState() {
    super.initState();
    _documentController = TextEditingController();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    var rules = CompactionService.decodeRules(
      prefs.getString(SummarizeDefaults.prefCompactRules),
    );
    rules ??= CompactionService.migrateLegacyRules(
      compressPrompt:
          prefs.getString(SummarizeDefaults.prefCompressPrompt) ??
          SummarizeDefaults.defaultCompressPrompt,
      voiceSamplesPrompt:
          prefs.getString(SummarizeDefaults.prefVoiceSamplesPrompt) ??
          SummarizeDefaults.defaultVoiceSamplesPrompt,
      summaryName: SummarizeDefaults.ruleNameSummary,
      voicesName: SummarizeDefaults.ruleNameVoices,
    );

    setState(() {
      _rules = rules!;
      _blockCount =
          prefs.getInt(SummarizeDefaults.prefBlockCount) ??
          prefs.getInt(SummarizeDefaults.prefPairCount) ??
          SummarizeDefaults.defaultBlocks;
      _mode =
          prefs.getString(SummarizeDefaults.prefCompactMode) ??
          SummarizeDefaults.modeSimple;
      _showLiveDocument =
          prefs.getBool(SummarizeDefaults.prefShowLiveDocument) ?? true;
      _loaded = true;
    });
  }

  TextEditingController _controllerFor(CompactRule rule) => _ruleControllers
      .putIfAbsent(rule.id, () => TextEditingController(text: rule.prompt));

  TextEditingController _nameControllerFor(CompactRule rule) =>
      _ruleNameControllers.putIfAbsent(
        rule.id,
        () => TextEditingController(text: rule.name),
      );

  Future<void> _persistRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SummarizeDefaults.prefCompactRules,
      CompactionService.encodeRules(_rules),
    );
  }

  Future<void> _saveBlockCount(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SummarizeDefaults.prefBlockCount, v);
    await prefs.setInt(SummarizeDefaults.prefPairCount, v);
  }

  Future<void> _saveMode(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SummarizeDefaults.prefCompactMode, v);
  }

  Future<void> _saveShowLiveDocument(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SummarizeDefaults.prefShowLiveDocument, v);
  }

  void _addRule() {
    // Millisecond ids collide when two rules are added inside the same
    // millisecond, and a collision makes two rules share one controller.
    final id = 'rule_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _rules = [
        ..._rules,
        CompactRule(id: id, name: 'Rule ${_rules.length + 1}', prompt: ''),
      ];
    });
    _persistRules();
  }

  void _removeRule(CompactRule rule) {
    setState(() {
      _rules = _rules.where((r) => r.id != rule.id).toList();
    });
    _ruleControllers.remove(rule.id)?.dispose();
    _ruleNameControllers.remove(rule.id)?.dispose();
    _persistRules();
  }

  void _moveRule(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _rules.length) return;
    final next = [..._rules];
    final moved = next.removeAt(index);
    next.insert(target, moved);
    setState(() => _rules = next);
    _persistRules();
  }

  /// Writes one field of a rule, leaving the rest of it alone.
  ///
  /// Rebuilds from the stored rule, never from [rule]: this runs on every
  /// keystroke without a setState, so the card's captured [rule] still holds
  /// whatever the rule looked like at the last build. Copying from it restored
  /// the name while the prompt was being typed, and the prompt while the name
  /// was being typed, silently and only when nothing else had forced a
  /// rebuild in between.
  void _updateRule(CompactRule rule, {String? name, String? prompt}) {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index < 0) return;
    final next = [..._rules];
    next[index] = next[index].copyWith(name: name, prompt: prompt);
    _rules = next;
    _persistRules();
  }

  void _toggleRule(CompactRule rule, bool enabled) {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index < 0) return;
    setState(() {
      final next = [..._rules];
      next[index] = rule.copyWith(enabled: enabled);
      _rules = next;
    });
    _persistRules();
  }

  /// Pushes a provider-side document write into the box without stamping over
  /// what the user is typing.
  void _syncDocument(String incoming) {
    if (incoming == _observedDocument) return;
    _observedDocument = incoming;
    // Assigning .text collapses the selection to the end, so only do it when
    // the value genuinely changed upstream.
    _documentController.text = incoming;
  }

  @override
  void dispose() {
    for (final c in _ruleControllers.values) {
      c.dispose();
    }
    for (final c in _ruleNameControllers.values) {
      c.dispose();
    }
    _documentController.dispose();
    super.dispose();
  }

  Future<void> _runCompact() async {
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (chat.messages.isEmpty) {
      setState(() => _status = "Nothing to compact — chat is empty.");
      return;
    }
    setState(() {
      _compressing = true;
      _status = null;
    });
    try {
      final err = await chat.compactWithRules(
        blockCount: _blockCount,
        rules: _rules,
        asChronicle: _isChronicleMode,
      );
      if (!mounted) return;
      if (err == null) {
        setState(
          () => _status = _isChronicleMode
              ? "Chronicle updated. Switched to new conversation."
              : "Compacted. Switched to new conversation.",
        );
        widget.onClose?.call();
      } else {
        setState(() => _status = err);
      }
    } catch (e) {
      if (mounted) setState(() => _status = "Error: $e");
    } finally {
      if (mounted) setState(() => _compressing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final vfx = Provider.of<VfxProvider>(context);
    final scale = Provider.of<ScaleProvider>(context);
    final chat = Provider.of<ChatProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final targetWidth = scale.drawerWidth + (scale.systemFontSize - 12) * 10;
    final drawerWidth = math.min(
      math.max(300.0, targetWidth),
      screenWidth * 0.95,
    );

    return Material(
      elevation: vfx.enableBloom ? 20 : 16,
      shadowColor: vfx.enableBloom
          ? theme.bloomGlowColor.withValues(alpha: 0.3)
          : null,
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        width: drawerWidth,
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      if (!_loaded)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              "Loading rules…",
                              style: TextStyle(color: theme.subtitleColor),
                            ),
                          ),
                        )
                      else ...[
                        _progressReadout(theme, scale, chat),
                        _documentBox(theme, scale, chat),
                        _sectionLabel(theme, scale, "Compaction rules"),
                        const SizedBox(height: 2),
                        Text(
                          "Each rule edits one shared document, in order. A "
                          "later rule can revise what an earlier one wrote.",
                          style: TextStyle(
                            color: theme.subtitleColor,
                            fontSize: scale.systemFontSize - 3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < _rules.length; i++)
                          _ruleCard(theme, vfx, scale, _rules[i], i),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          key: const Key('add_rule_button'),
                          onPressed: _compressing ? null : _addRule,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add another rule"),
                        ),
                        const SizedBox(height: 18),
                        SettingsSlider(
                          title: "Chat blocks to carry",
                          value: _blockCount.toDouble(),
                          min: SummarizeDefaults.minBlocks.toDouble(),
                          max: SummarizeDefaults.maxBlocks.toDouble(),
                          divisions:
                              SummarizeDefaults.maxBlocks -
                              SummarizeDefaults.minBlocks,
                          activeColor: theme.textColor,
                          isInt: true,
                          fontSize: scale.systemFontSize,
                          titleColor: theme.subtitleColor,
                          titleFontWeight: FontWeight.bold,
                          onChanged: (v) {
                            setState(() => _blockCount = v.round());
                            _saveBlockCount(v.round());
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _showLiveDocument,
                          title: Text(
                            "Show live document",
                            style: TextStyle(
                              color: theme.subtitleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: scale.systemFontSize,
                            ),
                          ),
                          subtitle: Text(
                            "Watch the document build and edit it in place.",
                            style: TextStyle(
                              color: theme.subtitleColor,
                              fontSize: scale.systemFontSize - 3,
                            ),
                          ),
                          onChanged: (v) {
                            setState(() => _showLiveDocument = v);
                            _saveShowLiveDocument(v);
                          },
                        ),
                        const SizedBox(height: 8),
                        if (_status != null)
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
                    ],
                  ),
                ),
                _footer(theme, vfx, scale),
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

  /// Names the rule currently running, so a long compaction is legible rather
  /// than an anonymous spinner.
  Widget _progressReadout(
    ThemeProvider theme,
    ScaleProvider scale,
    ChatProvider chat,
  ) {
    if (chat.compactRuleTotal == 0) return const SizedBox.shrink();
    final label = chat.compactProgress;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.containerFillColor,
        border: Border.all(color: theme.markdownLinkColor),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Rule ${chat.compactRuleIndex} of ${chat.compactRuleTotal}"
              "${label.isEmpty ? '' : ': $label'}",
              style: TextStyle(
                color: theme.textColor,
                fontSize: scale.systemFontSize - 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The shared document, editable while it builds.
  Widget _documentBox(
    ThemeProvider theme,
    ScaleProvider scale,
    ChatProvider chat,
  ) {
    if (!_showLiveDocument) return const SizedBox.shrink();
    return ValueListenableBuilder<String>(
      valueListenable: chat.compactDocumentNotifier,
      builder: (context, value, _) {
        _syncDocument(value);
        if (value.isEmpty && !_compressing) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(theme, scale, "Shared document"),
            const SizedBox(height: 4),
            TextField(
              key: const Key('compact_document_box'),
              controller: _documentController,
              maxLines: 14,
              minLines: 6,
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
              // Trim on read, never here: feeding a changed string back through
              // the provider into this box jumps the caret mid-edit.
              onChanged: chat.overrideCompactDocument,
            ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _ruleCard(
    ThemeProvider theme,
    VfxProvider vfx,
    ScaleProvider scale,
    CompactRule rule,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.containerFillColor,
        border: Border.all(
          color: rule.enabled
              ? theme.borderColor
              : theme.borderColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "${index + 1}.",
                style: TextStyle(
                  color: theme.subtitleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: scale.systemFontSize - 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _nameControllerFor(rule),
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: scale.systemFontSize - 1,
                  ),
                  cursorColor: theme.textColor,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: "Rule name",
                  ),
                  onChanged: (v) => _updateRule(rule, name: v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 16),
                color: theme.dimTextColor,
                tooltip: "Move up",
                onPressed: (_compressing || index == 0)
                    ? null
                    : () => _moveRule(index, -1),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 16),
                color: theme.dimTextColor,
                tooltip: "Move down",
                onPressed: (_compressing || index == _rules.length - 1)
                    ? null
                    : () => _moveRule(index, 1),
              ),
              Switch(
                value: rule.enabled,
                onChanged: _compressing ? null : (v) => _toggleRule(rule, v),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.redAccent,
                tooltip: "Remove rule",
                onPressed: _compressing ? null : () => _removeRule(rule),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _controllerFor(rule),
            maxLines: null,
            minLines: 4,
            style: TextStyle(
              color: theme.textColor,
              fontSize: scale.systemFontSize - 1,
              fontFamily: 'monospace',
            ),
            cursorColor: theme.textColor,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              hintText: "What this rule should contribute…",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: theme.borderColor),
              ),
              contentPadding: const EdgeInsets.all(8),
            ),
            onChanged: (v) => _updateRule(rule, prompt: v),
          ),
        ],
      ),
    );
  }

  /// The drawer's fixed bottom bar: compaction mode on the left, run button on
  /// the right.
  ///
  /// A Column sibling after the Expanded, deliberately not a Positioned in the
  /// Stack (it would float over the list) and not inside the ListView (it would
  /// scroll out of reach, which is the thing this replaces).
  Widget _footer(ThemeProvider theme, VfxProvider vfx, ScaleProvider scale) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: theme.containerFillColor,
        border: Border(top: BorderSide(color: theme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: vfx.enableBloom
                        ? theme.bloomGlowColor.withValues(alpha: 0.5)
                        : theme.borderColor,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('compact_mode_dropdown'),
                    isExpanded: true,
                    value: _mode,
                    dropdownColor: theme.dropdownColor,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: scale.systemFontSize - 1,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SummarizeDefaults.modeSimple,
                        child: Text("Simple Compact to New Conversation"),
                      ),
                      DropdownMenuItem(
                        value: SummarizeDefaults.modeChronicle,
                        child: Text("Compact to Chronicle"),
                      ),
                    ],
                    onChanged: _compressing
                        ? null
                        : (v) {
                            if (v == null || v == _mode) return;
                            setState(() {
                              _mode = v;
                              _status = null;
                            });
                            _saveMode(v);
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _compressing ? null : _runCompact,
              icon: _compressing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isChronicleMode ? Icons.auto_stories : Icons.compress,
                    ),
              label: Text(_isChronicleMode ? "Chronicle" : "Compact"),
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
}
