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

/// The paragraph laid out again, to read its lines.
TextPainter linesOf(RenderParagraph p) =>
    TextPainter(text: p.text, textDirection: TextDirection.ltr, textScaler: p.textScaler)
      ..layout(maxWidth: p.size.width);

/// The text each rendered line starts with.
List<String> lineStarts(RenderParagraph p, String text) {
  final tp = linesOf(p);
  return [
    for (final line in tp.computeLineMetrics())
      text.substring(tp.getPositionForOffset(Offset(1, line.baseline - line.ascent + 1)).offset),
  ];
}

void main() {
  testWidgets('a short name keeps the full size', (tester) async {
    final p = await pumpName(tester, 'Moment');
    expect(p.text.style!.fontSize, 22);
    expect(linesOf(p).computeLineMetrics(), hasLength(1));
  });

  testWidgets('a name a little too long shrinks to stay on one line', (tester) async {
    // Test glyphs are as wide as the font size: at 22 this needs 484 px.
    const name = 'Delorazepam ratiopharm';
    final p = await pumpName(tester, name, width: 400);
    expect(linesOf(p).computeLineMetrics(), hasLength(1));
    expect(p.text.style!.fontSize, lessThan(22));
    expect(p.text.style!.fontSize, greaterThanOrEqualTo(16));
  });

  testWidgets('one long word is never split, with letters left on a new line', (tester) async {
    const name = 'Paracetamolocodeina';
    final p = await pumpName(tester, name, width: 300);
    expect(linesOf(p).computeLineMetrics(), hasLength(1));
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

  testWidgets('shrinks a little to use fewer lines', (tester) async {
    // At 22 this needs three lines, at 20 it fits in two.
    const name = 'Sali di ferro e acido folico';
    final p = await pumpName(tester, name, width: 300);
    expect(linesOf(p).computeLineMetrics(), hasLength(2));
    expect(p.text.style!.fontSize, greaterThanOrEqualTo(18));
  });

  testWidgets('never gets too small to read', (tester) async {
    const name = 'Supercalifragilistichespiralidoso';
    final p = await pumpName(tester, name, width: 120);
    expect(p.text.style!.fontSize, greaterThanOrEqualTo(14));
  });
}
