import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/scale_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/text_diff.dart';

/// Shows what a compaction changed, old text against new.
///
/// This is how a user can tell a chronicle run that revised the old record
/// from one that only added to it: an append shows as green lines with
/// nothing red or edited above them.
Future<void> showCompactDiff(
  BuildContext context, {
  required String title,
  required String before,
  required String after,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        CompactDiffDialog(title: title, before: before, after: after),
  );
}

class CompactDiffDialog extends StatefulWidget {
  final String title;
  final String before;
  final String after;

  const CompactDiffDialog({
    super.key,
    required this.title,
    required this.before,
    required this.after,
  });

  @override
  State<CompactDiffDialog> createState() => _CompactDiffDialogState();
}

class _CompactDiffDialogState extends State<CompactDiffDialog> {
  late final List<DiffLine> _lines = TextDiff.lines(
    widget.before,
    widget.after,
  );
  bool _changesOnly = true;

  static const Color _addColor = Colors.greenAccent;
  static const Color _removeColor = Colors.redAccent;

  int _count(DiffLineKind kind) => _lines.where((l) => l.kind == kind).length;

  static int _words(String text) => RegExp(r'\S+').allMatches(text).length;

  /// The lines to show, with a null standing for a run of hidden unchanged
  /// lines so the reader can see where context was skipped.
  List<DiffLine?> _visible() {
    if (!_changesOnly) return _lines;
    final out = <DiffLine?>[];
    for (final line in _lines) {
      if (line.kind != DiffLineKind.same) {
        out.add(line);
      } else if (line.text.trim().startsWith('#')) {
        // Section headings stay, so each change reads under its section.
        out.add(line);
      } else if (out.isNotEmpty && out.last != null) {
        out.add(null);
      }
    }
    while (out.isNotEmpty && out.last == null) {
      out.removeLast();
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final scale = Provider.of<ScaleProvider>(context);
    final fs = scale.systemFontSize;
    final visible = _visible();
    final added = _count(DiffLineKind.added);
    final changed = _count(DiffLineKind.changed);
    final removed = _count(DiffLineKind.removed);
    final nothingChanged = added + changed + removed == 0;

    return Dialog(
      key: const Key('compact_diff_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: theme.textColor,
                fontSize: fs + 4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip('+$added added', _addColor, theme, fs),
                _chip('~$changed edited', Colors.amberAccent, theme, fs),
                _chip('-$removed removed', _removeColor, theme, fs),
                _chip(
                  '${_words(widget.before)} → ${_words(widget.after)} words',
                  theme.subtitleColor,
                  theme,
                  fs,
                ),
              ],
            ),
            if (widget.before.trim().isNotEmpty &&
                changed + removed == 0 &&
                added > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Nothing already in the old text was revised or condensed; '
                  'this run only added to it.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: fs - 2),
                ),
              ),
            Row(
              children: [
                Text(
                  'Changes only',
                  style: TextStyle(color: theme.textColor, fontSize: fs - 1),
                ),
                Switch(
                  key: const Key('compact_diff_changes_only'),
                  value: _changesOnly,
                  activeThumbColor: theme.textColor,
                  onChanged: (v) => setState(() => _changesOnly = v),
                ),
              ],
            ),
            Divider(color: theme.borderColor, height: 1),
            Expanded(
              child: nothingChanged
                  ? Center(
                      child: Text(
                        'No changes.',
                        style: TextStyle(color: theme.subtitleColor),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: visible.length,
                      itemBuilder: (_, i) => _line(visible[i], theme, fs),
                    ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close', style: TextStyle(fontSize: fs)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color, ThemeProvider theme, double fs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: fs - 3),
      ),
    );
  }

  Widget _line(DiffLine? line, ThemeProvider theme, double fs) {
    final base = TextStyle(
      color: theme.textColor,
      fontSize: fs - 1,
      height: 1.35,
    );
    if (line == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('···', style: base.copyWith(color: theme.subtitleColor)),
      );
    }
    if (line.text.trim().isEmpty) return const SizedBox(height: 6);

    final (Color? tint, String mark) = switch (line.kind) {
      DiffLineKind.added => (_addColor, '+ '),
      DiffLineKind.removed => (_removeColor, '- '),
      DiffLineKind.changed => (Colors.amberAccent, '~ '),
      DiffLineKind.same => (null, '  '),
    };

    TextStyle styleFor(DiffOp op) => switch (op) {
      DiffOp.same => base,
      DiffOp.added => base.copyWith(
        backgroundColor: _addColor.withValues(alpha: 0.28),
      ),
      DiffOp.removed => base.copyWith(
        backgroundColor: _removeColor.withValues(alpha: 0.28),
        decoration: TextDecoration.lineThrough,
        decorationColor: _removeColor,
      ),
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.08),
        border: tint == null
            ? null
            : Border(left: BorderSide(color: tint, width: 3)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: mark,
              style: base.copyWith(color: tint ?? theme.subtitleColor),
            ),
            for (final span in line.spans)
              TextSpan(
                text: span.text,
                style: line.kind == DiffLineKind.same
                    ? base.copyWith(color: theme.subtitleColor)
                    : styleFor(span.op),
              ),
          ],
        ),
      ),
    );
  }
}
