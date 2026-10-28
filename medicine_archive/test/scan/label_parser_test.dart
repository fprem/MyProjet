import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/scan/label_parser.dart';

LabelLine line(String text, double height) => LabelLine(text, height);

void main() {
  const parser = LabelParser();

  test('takes the largest text as the name and finds the quantity', () {
    final result = parser.parse([
      line('Medicinale da banco', 10),
      line('TACHIPIRINA', 40),
      line('500 mg', 20),
      line('20 compresse', 14),
    ]);
    expect(result.name, 'Tachipirina 500 mg');
    expect(result.quantity, 20);
    expect(result.unit, 'compresse');
  });

  test('reads English pack sizes', () {
    final result = parser.parse([
      line('Ibuprofen', 30),
      line('200 mg', 18),
      line('24 tablets', 12),
    ]);
    expect(result.name, 'Ibuprofen 200 mg');
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
    expect(result.name, 'Aspirina 500 mg');
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
}
