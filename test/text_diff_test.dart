import 'package:flutter_test/flutter_test.dart';
import 'package:airp/utils/text_diff.dart';

/// Guards the diff behind the compaction review popup, which is how a user
/// sees whether a chronicle run revised the old text or only added to it.
void main() {
  List<DiffLineKind> kinds(String a, String b) =>
      TextDiff.lines(a, b).map((l) => l.kind).toList();

  test('identical text is all unchanged', () {
    expect(kinds('a\nb', 'a\nb'), [DiffLineKind.same, DiffLineKind.same]);
  });

  test('a run that only appends shows only additions', () {
    expect(
      kinds('## Key Events\n- Day 1.', '## Key Events\n- Day 1.\n- Day 2.'),
      [DiffLineKind.same, DiffLineKind.same, DiffLineKind.added],
    );
  });

  test('a lightly edited line is one changed line with word spans', () {
    final lines = TextDiff.lines(
      '- Schiwi finds a warm black shard near Corpo Plaza.',
      '- Schiwi finds a cold black shard near Corpo Plaza.',
    );
    expect(lines.single.kind, DiffLineKind.changed);
    final spans = lines.single.spans;
    expect(spans.where((s) => s.op == DiffOp.removed).map((s) => s.text), [
      'warm',
    ]);
    expect(spans.where((s) => s.op == DiffOp.added).map((s) => s.text), [
      'cold',
    ]);
  });

  test('word spans reassemble into both versions exactly', () {
    const before = 'They take it to  Old Man Wu.';
    const after = 'They sell it to Old Man Wu, at a loss.';
    final spans = TextDiff.words(before, after);
    String join(DiffOp skip) =>
        spans.where((s) => s.op != skip).map((s) => s.text).join();
    expect(join(DiffOp.added), before);
    expect(join(DiffOp.removed), after);
  });

  test('an unrelated rewrite is a removal plus an addition', () {
    expect(kinds('- The heist went wrong.', '- Wu names his price.'), [
      DiffLineKind.removed,
      DiffLineKind.added,
    ]);
  });

  test('an edit next to an inserted line still pairs with its match', () {
    final lines = TextDiff.lines(
      '- Day 1: they meet at the bar.',
      '- Prologue: a new opening.\n- Day 1: they meet at the club.',
    );
    expect(lines.map((l) => l.kind), [
      DiffLineKind.added,
      DiffLineKind.changed,
    ]);
  });

  test('a run that started from nothing is all additions', () {
    expect(kinds('', 'a\nb'), [DiffLineKind.added, DiffLineKind.added]);
  });
}
