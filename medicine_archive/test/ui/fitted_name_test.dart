import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/ui/fitted_name.dart';

const _base = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

Future<RenderParagraph> pumpName(WidgetTester tester, String name, {double width = 200}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: FittedName(name, style: _base),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderParagraph>(find.text(name));
}

/// The text each rendered line starts with.
List<String> lineStarts(RenderParagraph p, String text) => [
  for (final line in p.computeLineMetrics())
    text.substring(
      p.getPositionForOffset(Offset(0, line.baseline - line.ascent + 1)).offset,
    ),
];

void main() {
  testWidgets('a short name keeps the full size', (tester) async {
    final p = await pumpName(tester, 'Moment');
    expect(p.text.style!.fontSize, 22);
    expect(p.computeLineMetrics(), hasLength(1));
  });

  testWidgets('a name a little too long shrinks to stay on one line', (tester) async {
    // At 22 this wraps; a smaller size fits it on one line.
    const name = 'Delorazepam ratiopharm';
    final p = await pumpName(tester, name, width: 230);
    expect(p.computeLineMetrics(), hasLength(1));
    expect(p.text.style!.fontSize, lessThan(22));
    expect(p.text.style!.fontSize, greaterThanOrEqualTo(16));
  });

  testWidgets('one long word is never split, with letters left on a new line', (tester) async {
    const name = 'Paracetamolocodeina';
    final p = await pumpName(tester, name, width: 180);
    expect(p.computeLineMetrics(), hasLength(1));
  });

  testWidgets('a very long name wraps between words only', (tester) async {
    const name = 'Amoxicillina e acido clavulanico Sandoz GmbH';
    final p = await pumpName(tester, name, width: 200);
    final starts = lineStarts(p, name);
    expect(starts.length, greaterThan(1));
    for (final start in starts) {
      final at = name.length - start.length;
      expect(at == 0 || name[at - 1] == ' ', isTrue, reason: 'line starts mid-word: "$start"');
    }
    // The last line is a real word, not a stray letter or two.
    expect(starts.last.trim().length, greaterThan(2));
  });

  testWidgets('never gets too small to read', (tester) async {
    const name = 'Supercalifragilistichespiralidoso';
    final p = await pumpName(tester, name, width: 120);
    expect(p.text.style!.fontSize, greaterThanOrEqualTo(14));
  });
}
