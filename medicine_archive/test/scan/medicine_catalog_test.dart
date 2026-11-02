import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/scan/medicine_catalog.dart';

// The fixture has AIFA's column layout, with three made-up rows.
void main() {
  late String tsv;

  setUpAll(() {
    final csv = File('test/fixtures/aifa_confezioni_sample.csv').readAsStringSync();
    tsv = AifaCatalog.tsvFromCsv(csv);
  });

  test('finds a pack by its AIC', () async {
    final entry = await AifaCatalog.fromTsv(tsv).lookup('012745093');
    expect(entry, isNotNull);
    expect(entry!.name, 'Tachipirina');
    expect(entry.strength, '500 mg');
    expect(entry.quantity, 20);
    expect(entry.unit, 'compresse');
  });

  test('keeps the strength that tells packs of the same medicine apart', () async {
    final entry = await AifaCatalog.fromTsv(tsv).lookup('034701021');
    expect(entry!.name, 'Delorazepam Ratiopharm Italia');
    expect(entry.strength, '0,5 mg');
    expect(entry.quantity, 20);
  });

  test('restores leading zeros the spreadsheet dropped', () async {
    expect(await AifaCatalog.fromTsv(tsv).lookup('034701021'), isNotNull);
  });

  test('takes the pack size from after the quoted strength, not from inside it', () async {
    final entry = await AifaCatalog.fromTsv(tsv).lookup('025201017');
    expect(entry!.strength, '120 mg/5 ml');
    expect(entry.quantity, 120);
    expect(entry.unit, 'ml');
  });

  test('returns null for a code it does not know', () async {
    expect(await AifaCatalog.fromTsv(tsv).lookup('012745000'), isNull);
    expect(await AifaCatalog.fromTsv(tsv).lookup('01274509'), isNull);
  });

  test('an empty catalog finds nothing', () async {
    expect(await AifaCatalog.fromTsv('').lookup('012745093'), isNull);
  });

  test('loads lazily, once', () async {
    var loads = 0;
    final catalog = AifaCatalog(() async {
      loads++;
      return tsv;
    });
    expect(loads, 0);
    await catalog.lookup('012745093');
    await catalog.lookup('034701021');
    expect(loads, 1);
  });

  test('a catalog that fails to load finds nothing instead of failing the scan', () async {
    final catalog = AifaCatalog(() async => throw Exception('missing asset'));
    expect(await catalog.lookup('012745093'), isNull);
  });

  test('finds the columns by name, whatever their order and separator', () async {
    const csv =
        'denominazione,descrizione,codice_aic\n'
        'MOMENT,"""200 MG COMPRESSE RIVESTITE"" 12 COMPRESSE",012745093\n';
    final entry = await AifaCatalog.fromTsv(AifaCatalog.tsvFromCsv(csv)).lookup('012745093');
    expect(entry!.name, 'Moment');
    expect(entry.quantity, 12);
  });

  test('rejects a file that does not look like the AIFA list', () {
    expect(() => AifaCatalog.tsvFromCsv('a;b;c\n1;2;3\n'), throwsFormatException);
  });
}
