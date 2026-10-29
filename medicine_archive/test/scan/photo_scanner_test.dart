import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/scan/medicine_catalog.dart';
import 'package:medicine_archive/scan/photo_scanner.dart';

class FakeReader implements LabelReader {
  FakeReader(this.lines, {this.fail = false});
  final List<LabelLine> lines;
  final bool fail;
  String? readPath;

  @override
  Future<List<LabelLine>> read(String imagePath) async {
    readPath = imagePath;
    if (fail) throw Exception('ocr failed');
    return lines;
  }
}

class FakeBarcodes implements BarcodeReader {
  FakeBarcodes(this.codes, {this.fail = false});
  final List<String> codes;
  final bool fail;

  @override
  Future<List<String>> read(String imagePath) async {
    if (fail) throw Exception('barcode failed');
    return codes;
  }
}

// Tachipirina 500 mg, 20 compresse: AIC 012745093, Code 32 "0D4YD5".
final _catalog = AifaCatalog.fromTsv('012745093\tTachipirina\t500 mg\t20\tcompresse\n');

void main() {
  late Directory dir;
  late File photo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('scan_test');
    photo = File('${dir.path}/photo.jpg');
    await photo.writeAsBytes([1, 2, 3]);
  });

  tearDown(() => dir.delete(recursive: true));

  test('reads the photo and returns the parsed label', () async {
    final reader = FakeReader([LabelLine('Moment', 30), LabelLine('12 compresse', 10)]);
    final scanner = PhotoScanner(reader: reader);
    final result = await scanner.scan(photo.path);
    expect(reader.readPath, photo.path);
    expect(result.label.name, 'Moment');
    expect(result.label.quantity, 12);
    expect(result.fromCatalog, isFalse);
  });

  test('deletes the photo file after reading it, keeping only a copy in memory', () async {
    final scanner = PhotoScanner(reader: FakeReader([LabelLine('Moment', 30)]));
    final result = await scanner.scan(photo.path);
    expect(photo.existsSync(), isFalse);
    expect(result.photo, [1, 2, 3]);
  });

  test('deletes the photo even when reading fails', () async {
    final scanner = PhotoScanner(reader: FakeReader(const [], fail: true));
    await expectLater(scanner.scan(photo.path), throwsException);
    expect(photo.existsSync(), isFalse);
  });

  group('barcode', () {
    test('a known AIC barcode fills the form from the AIFA list', () async {
      final scanner = PhotoScanner(
        reader: FakeReader([LabelLine('TACHIPIRINA', 40), LabelLine('Paracetamolo', 12)]),
        barcodes: FakeBarcodes(['0D4YD5']),
        catalog: _catalog,
      );
      final result = await scanner.scan(photo.path);
      expect(result.fromCatalog, isTrue);
      expect(result.aic, '012745093');
      expect(result.label.name, 'Tachipirina');
      expect(result.label.strength, '500 mg');
      expect(result.label.quantity, 20);
      expect(result.label.unit, 'compresse');
    });

    test('other barcodes on the box are skipped', () async {
      final scanner = PhotoScanner(
        reader: FakeReader(const []),
        barcodes: FakeBarcodes(['8001234567890', '0D4YD5']),
        catalog: _catalog,
      );
      expect((await scanner.scan(photo.path)).label.name, 'Tachipirina');
    });

    test('the AIC printed as text is used when the barcode is not readable', () async {
      final scanner = PhotoScanner(
        reader: FakeReader([LabelLine('TACHIPIRINA', 40), LabelLine('A.I.C. n. 012745093', 8)]),
        barcodes: FakeBarcodes(const []),
        catalog: _catalog,
      );
      final result = await scanner.scan(photo.path);
      expect(result.fromCatalog, isTrue);
      expect(result.label.quantity, 20);
    });

    test('falls back to reading the text when the AIC is not in the list', () async {
      final scanner = PhotoScanner(
        reader: FakeReader([LabelLine('Moment', 30), LabelLine('12 compresse', 10)]),
        barcodes: FakeBarcodes([AicCodeSamples.unknown]),
        catalog: _catalog,
      );
      final result = await scanner.scan(photo.path);
      expect(result.fromCatalog, isFalse);
      expect(result.label.name, 'Moment');
      expect(result.label.quantity, 12);
    });

    test('falls back to reading the text when the barcode reader fails', () async {
      final scanner = PhotoScanner(
        reader: FakeReader([LabelLine('Moment', 30)]),
        barcodes: FakeBarcodes(const [], fail: true),
        catalog: _catalog,
      );
      expect((await scanner.scan(photo.path)).label.name, 'Moment');
    });

    test('a found barcode is enough even when the text cannot be read', () async {
      final scanner = PhotoScanner(
        reader: FakeReader(const [], fail: true),
        barcodes: FakeBarcodes(['0D4YD5']),
        catalog: _catalog,
      );
      expect((await scanner.scan(photo.path)).label.name, 'Tachipirina');
      expect(photo.existsSync(), isFalse);
    });

    test('what the list lacks is filled in from the label text', () async {
      final scanner = PhotoScanner(
        reader: FakeReader([LabelLine('Tachipirina', 40), LabelLine('20 compresse', 10)]),
        barcodes: FakeBarcodes(['0D4YD5']),
        catalog: AifaCatalog.fromTsv('012745093\tTachipirina\t500 mg\t\t\n'),
      );
      final label = (await scanner.scan(photo.path)).label;
      expect(label.strength, '500 mg');
      expect(label.quantity, 20);
      expect(label.unit, 'compresse');
    });
  });
}

abstract final class AicCodeSamples {
  /// A valid AIC (check digit right) that is not in [_catalog], as Code 32.
  static const unknown = '112ZQX'; // 034701021
}
