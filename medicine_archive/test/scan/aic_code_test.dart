import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/scan/aic_code.dart';

// 012745093 is a real AIC (Tachipirina 500 mg, 20 compresse). Its barcode on
// the box, the "bollino", is Code 32: the same number written in base 32.
void main() {
  group('from a barcode', () {
    test('reads the Code 32 on the bollino', () {
      expect(AicCode.fromBarcode('0D4YD5'), '012745093');
    });

    test('reads a reader that already decoded it to digits, with or without the A', () {
      expect(AicCode.fromBarcode('012745093'), '012745093');
      expect(AicCode.fromBarcode('A012745093'), '012745093');
    });

    test('reads the AIC inside a GS1 DataMatrix', () {
      const gs = '\u001d';
      expect(AicCode.fromBarcode('0108012745093002${gs}712012745093${gs}17271231'), '012745093');
    });

    test('reads the AIC in GS1 text written with brackets', () {
      expect(AicCode.fromBarcode('(01)08012745093007(712)012745093(17)271231'), '012745093');
    });

    test('rejects codes whose check digit is wrong', () {
      expect(AicCode.fromBarcode('012745094'), isNull);
      expect(AicCode.fromBarcode('0D4YD6'), isNull);
    });

    test('ignores other barcodes', () {
      expect(AicCode.fromBarcode('8001234567890'), isNull);
      expect(AicCode.fromBarcode('HELLO'), isNull);
      expect(AicCode.fromBarcode(''), isNull);
    });
  });

  group('from the label text', () {
    test('reads "A.I.C." followed by the number', () {
      expect(AicCode.fromText('Confezione: A.I.C. n. 012745093'), '012745093');
      expect(AicCode.fromText('AIC 012745093'), '012745093');
      expect(AicCode.fromText('A.I.C. n° 012745093 Lotto 123'), '012745093');
    });

    test('reads the A-number printed under the bollino', () {
      expect(AicCode.fromText('A012745093'), '012745093');
    });

    test('ignores numbers that are not a valid AIC', () {
      expect(AicCode.fromText('Lotto 012745094'), isNull);
      expect(AicCode.fromText('20 compresse'), isNull);
    });
  });

  test('writes an AIC as Code 32, the reverse of reading it', () {
    expect(AicCode.toCode32('012745093'), '0D4YD5');
    expect(AicCode.fromBarcode(AicCode.toCode32('034701021')), '034701021');
  });
}
