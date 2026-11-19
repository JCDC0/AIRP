import 'dart:typed_data';

/// Whether a piece of text is shared, new, or gone.
enum DiffOp { same, added, removed }

/// A run of text with one [DiffOp].
class DiffSpan {
  final DiffOp op;
  final String text;

  const DiffSpan(this.op, this.text);
}

/// How one displayed line differs between two versions.
enum DiffLineKind { same, added, removed, changed }

/// One line of a line diff. A [DiffLineKind.changed] line holds a word level
/// diff in [spans]; every other kind holds a single span.
class DiffLine {
  final DiffLineKind kind;
  final List<DiffSpan> spans;

  const DiffLine(this.kind, this.spans);

  String get text => spans.map((s) => s.text).join();
}

/// Line and word diffs for showing what a compaction changed.
///
/// A plain longest common subsequence, which is all a chronicle of a few
/// thousand words needs. The shared head and tail are trimmed before the table
/// is built, and a pair too large for a table is reported as a whole
/// replacement rather than allocating one.
class TextDiff {
  TextDiff._();

  /// Lines that differ by less than this share of their words are shown as
  /// one edited line; below it, as one line removed and another added.
  static const double changedLineSimilarity = 0.5;

  static const int _maxTableCells = 4000000;

  /// Diffs [before] against [after] line by line, pairing a removed line with
  /// the added line that most resembles it so an edit reads as an edit.
  static List<DiffLine> lines(String before, String after) {
    final a = before.isEmpty ? <String>[] : before.split('\n');
    final b = after.isEmpty ? <String>[] : after.split('\n');
    final ops = _diff(a, b);

    final out = <DiffLine>[];
    final removed = <String>[];
    final added = <String>[];

    void flush() {
      var next = 0;
      for (final r in removed) {
        var match = -1;
        List<DiffSpan>? spans;
        for (var j = next; j < added.length; j++) {
          final candidate = words(r, added[j]);
          if (_similarity(candidate) >= changedLineSimilarity) {
            match = j;
            spans = candidate;
            break;
          }
        }
        if (match < 0) {
          out.add(
            DiffLine(DiffLineKind.removed, [DiffSpan(DiffOp.removed, r)]),
          );
          continue;
        }
        for (var j = next; j < match; j++) {
          out.add(
            DiffLine(DiffLineKind.added, [DiffSpan(DiffOp.added, added[j])]),
          );
        }
        out.add(DiffLine(DiffLineKind.changed, spans!));
        next = match + 1;
      }
      for (var j = next; j < added.length; j++) {
        out.add(
          DiffLine(DiffLineKind.added, [DiffSpan(DiffOp.added, added[j])]),
        );
      }
      removed.clear();
      added.clear();
    }

    for (final (op, line) in ops) {
      switch (op) {
        case DiffOp.same:
          flush();
          out.add(DiffLine(DiffLineKind.same, [DiffSpan(DiffOp.same, line)]));
        case DiffOp.removed:
          removed.add(line);
        case DiffOp.added:
          added.add(line);
      }
    }
    flush();
    return out;
  }

  /// Word level diff of two lines, with whitespace kept so the spans
  /// reassemble into either line exactly.
  static List<DiffSpan> words(String before, String after) {
    final token = RegExp(r'\s+|\S+');
    final a = token.allMatches(before).map((m) => m[0]!).toList();
    final b = token.allMatches(after).map((m) => m[0]!).toList();

    final spans = <DiffSpan>[];
    for (final (op, word) in _diff(a, b)) {
      if (spans.isNotEmpty && spans.last.op == op) {
        spans[spans.length - 1] = DiffSpan(op, spans.last.text + word);
      } else {
        spans.add(DiffSpan(op, word));
      }
    }
    return spans;
  }

  static double _similarity(List<DiffSpan> spans) {
    int count(DiffOp op) => spans
        .where((s) => s.op == op)
        .map((s) => RegExp(r'\S+').allMatches(s.text).length)
        .fold(0, (a, b) => a + b);
    final same = count(DiffOp.same);
    final longer = same + _max(count(DiffOp.added), count(DiffOp.removed));
    return longer == 0 ? 1 : same / longer;
  }

  static int _max(int a, int b) => a > b ? a : b;

  static List<(DiffOp, String)> _diff(List<String> a, List<String> b) {
    var head = 0;
    while (head < a.length && head < b.length && a[head] == b[head]) {
      head++;
    }
    var tail = 0;
    while (tail < a.length - head &&
        tail < b.length - head &&
        a[a.length - 1 - tail] == b[b.length - 1 - tail]) {
      tail++;
    }

    final x = a.sublist(head, a.length - tail);
    final y = b.sublist(head, b.length - tail);
    final out = <(DiffOp, String)>[
      for (var i = 0; i < head; i++) (DiffOp.same, a[i]),
    ];

    final n = x.length;
    final m = y.length;
    if ((n + 1) * (m + 1) > _maxTableCells) {
      out.addAll(x.map((s) => (DiffOp.removed, s)));
      out.addAll(y.map((s) => (DiffOp.added, s)));
    } else {
      // table[i][j] is the LCS length of x[i..] and y[j..].
      final w = m + 1;
      final table = Int32List((n + 1) * w);
      for (var i = n - 1; i >= 0; i--) {
        for (var j = m - 1; j >= 0; j--) {
          table[i * w + j] = x[i] == y[j]
              ? table[(i + 1) * w + j + 1] + 1
              : _max(table[(i + 1) * w + j], table[i * w + j + 1]);
        }
      }
      var i = 0;
      var j = 0;
      while (i < n && j < m) {
        if (x[i] == y[j]) {
          out.add((DiffOp.same, x[i]));
          i++;
          j++;
        } else if (table[(i + 1) * w + j] >= table[i * w + j + 1]) {
          out.add((DiffOp.removed, x[i++]));
        } else {
          out.add((DiffOp.added, y[j++]));
        }
      }
      while (i < n) {
        out.add((DiffOp.removed, x[i++]));
      }
      while (j < m) {
        out.add((DiffOp.added, y[j++]));
      }
    }

    for (var i = a.length - tail; i < a.length; i++) {
      out.add((DiffOp.same, a[i]));
    }
    return out;
  }
}
