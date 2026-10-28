import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/scan/label_parser.dart';

LabelLine line(String text, double height, [double? top]) => LabelLine(text, height, top: top);

void main() {
  const parser = LabelParser();

  test('takes the largest text as the name and finds the quantity', () {
    final result = parser.parse([
      line('Medicinale da banco', 10),
      line('TACHIPIRINA', 40),
      line('500 mg', 20),
      line('20 compresse', 14),
    ]);
    expect(result.name, 'Tachipirina');
    expect(result.strength, '500 mg');
    expect(result.quantity, 20);
    expect(result.unit, 'compresse');
  });

  test('reads English pack sizes', () {
    final result = parser.parse([
      line('Ibuprofen', 30),
      line('200 mg', 18),
      line('24 tablets', 12),
    ]);
    expect(result.name, 'Ibuprofen');
    expect(result.strength, '200 mg');
    expect(result.quantity, 24);
    expect(result.unit, 'tablets');
  });

  test('understands abbreviations and an x before the number', () {
    expect(parser.parse([line('Brufen', 30), line('30 cpr riv.', 10)]).quantity, 30);
    expect(parser.parse([line('Brufen', 30), line('cpr x 12', 10)]).quantity, 12);
    expect(parser.parse([line('Brufen', 30), line('12 x', 10)]).quantity, isNull);
  });

  test('reads liquid volumes as quantity', () {
    final result = parser.parse([line('Bentelan', 30), line('flacone 100 ml', 12)]);
    expect(result.quantity, 100);
    expect(result.unit, 'ml');
  });

  test('does not mistake a dosage for the quantity', () {
    final result = parser.parse([line('Aspirina', 30), line('500 mg', 12)]);
    expect(result.quantity, isNull);
    expect(result.name, 'Aspirina');
    expect(result.strength, '500 mg');
  });

  test('ignores lines that are only numbers or codes for the name', () {
    final result = parser.parse([line('034567890', 50), line('Moment', 30)]);
    expect(result.name, 'Moment');
  });

  test('returns an empty result when nothing was read', () {
    final result = parser.parse(const []);
    expect(result.name, isEmpty);
    expect(result.quantity, isNull);
    expect(result.isEmpty, isTrue);
  });

  group('strength', () {
    // The Delorazepam box (test/fixtures/delorazepam_box.jpg), as the phone's
    // text reader returns it: sizes and positions in pixels of the photo.
    final delorazepam = [
      line('Delorazepam', 92, 810),
      line('ratiopharm Italia', 88, 940),
      line('0,5', 100, 985),
      line('mg', 52, 1090),
      line('0,5 mg compresse', 46, 1040),
      line('Medicinale equivalente', 28, 1165),
      line('Uso orale', 26, 1215),
      line('20 compresse', 30, 1295),
      line('teva', 82, 1300),
    ];

    test('keeps the 0,5 mg on the real Delorazepam box', () {
      final result = parser.parse(delorazepam);
      expect(result.name, 'Delorazepam ratiopharm Italia');
      expect(result.strength, '0,5 mg');
      expect(result.quantity, 20);
      expect(result.unit, 'compresse');
    });

    test('does not depend on the order the lines come in', () {
      final result = parser.parse(delorazepam.reversed.toList());
      expect(result.name, 'Delorazepam ratiopharm Italia');
      expect(result.strength, '0,5 mg');
      expect(result.quantity, 20);
    });

    test('does not take a logo for the name', () {
      final result = parser.parse([
        line('Delorazepam', 60, 800),
        line('teva', 90, 1300),
        line('0,5 mg compresse', 40, 1000),
      ]);
      expect(result.name, 'Delorazepam');
    });

    test('keeps strengths other than 0,5 mg apart', () {
      for (final (printed, expected) in [
        ('1 mg compresse', '1 mg'),
        ('2,5 mg', '2,5 mg'),
        ('0.25mg', '0.25 mg'),
        ('500 mcg', '500 mcg'),
        ('100 µg', '100 µg'),
        ('1 g', '1 g'),
        ('5 mg/ml', '5 mg/ml'),
        ('500 mg/5 ml', '500 mg/5 ml'),
        ('1000 UI', '1000 UI'),
        ('2%', '2 %'),
      ]) {
        final result = parser.parse([line('Farmaco', 40), line(printed, 20)]);
        expect(result.strength, expected, reason: printed);
        expect(result.name, 'Farmaco', reason: printed);
      }
    });

    test('finds the strength when it is on the same line as the name', () {
      final result = parser.parse([line('Tachipirina 500 mg compresse', 40), line('20 compresse', 14)]);
      expect(result.name, 'Tachipirina');
      expect(result.strength, '500 mg');
      expect(result.quantity, 20);
    });

    test('joins a number and its unit printed on separate lines', () {
      final result = parser.parse([line('Delorazepam', 60), line('0,5', 100), line('mg', 50)]);
      expect(result.strength, '0,5 mg');
      expect(result.name, 'Delorazepam');
    });

    test('a volume is a quantity, not a strength', () {
      final result = parser.parse([line('Bentelan', 32), line('flacone 100 ml', 12)]);
      expect(result.strength, isEmpty);
      expect(result.quantity, 100);
      expect(result.unit, 'ml');
    });

    test('a pack size is not a strength', () {
      final result = parser.parse([line('Moment', 36), line('12 compresse', 12)]);
      expect(result.strength, isEmpty);
    });

    test('a label with only a strength is not empty', () {
      expect(parser.parse([line('0,5 mg', 30)]).isEmpty, isFalse);
    });
  });
}
