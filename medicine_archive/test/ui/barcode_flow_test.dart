import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/scan/barcode_scan.dart';
import 'package:medicine_archive/scan/label_parser.dart';

import 'fakes.dart';

const _tachipirina = LabelResult(
  name: 'Tachipirina',
  strength: '500 mg',
  quantity: 20,
  unit: 'compresse',
);

void main() {
  late ArchiveRepository repo;
  late List<String> photosTaken;

  setUp(() async {
    repo = await memoryRepository();
    photosTaken = [];
  });

  Future<Profile> pumpProfile(
    WidgetTester tester, {
    required FakeScanner scanner,
    required BarcodeScan? barcode,
  }) async {
    final anna = await repo.createProfile('Anna');
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: scanner,
        scanBarcode: (_) async => barcode,
        takePhoto: () async {
          photosTaken.add('/tmp/photo.jpg');
          return '/tmp/photo.jpg';
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    return anna;
  }

  Future<void> scanBox(WidgetTester tester) async {
    await tester.tap(find.text('Scan box'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, String text) => tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find
        .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .last,
  );

  testWidgets('Scan box reads the barcode first, without taking a photo', (tester) async {
    await pumpProfile(
      tester,
      scanner: FakeScanner(const LabelResult.empty(), catalog: {'012745093': _tachipirina}),
      barcode: const BarcodeRead('012745093'),
    );
    await scanBox(tester);

    expect(photosTaken, isEmpty);
    expect(find.widgetWithText(TextField, 'Tachipirina'), findsOneWidget);
    expect(find.widgetWithText(TextField, '500 mg'), findsOneWidget);
    expect(find.widgetWithText(TextField, '20'), findsOneWidget);
    expect(
      find.text("From the barcode: AIC 012745093, found in AIFA's medicine list."),
      findsOneWidget,
    );
  });

  testWidgets('"No barcode" takes a photo and says the text was read', (tester) async {
    final scanner = FakeScanner(const LabelResult(name: 'Moment', quantity: 12));
    await pumpProfile(tester, scanner: scanner, barcode: const UsePhotoInstead());
    await scanBox(tester);

    expect(scanner.scanned, ['/tmp/photo.jpg']);
    expect(find.widgetWithText(TextField, 'Moment'), findsOneWidget);
    expect(
      find.text('Read from the text in the photo. Check it and fix anything that is wrong.'),
      findsOneWidget,
    );
  });

  testWidgets('closing the barcode scanner does nothing', (tester) async {
    final scanner = FakeScanner(const LabelResult(name: 'Moment'));
    await pumpProfile(tester, scanner: scanner, barcode: null);
    await scanBox(tester);

    expect(photosTaken, isEmpty);
    expect(find.text('Check medicine'), findsNothing);
  });

  testWidgets('a barcode not in the list falls back to the photo, and says so', (tester) async {
    final scanner = FakeScanner(const LabelResult(name: 'Moment'));
    await pumpProfile(tester, scanner: scanner, barcode: const BarcodeRead('034701021'));
    await scanBox(tester);

    expect(scanner.scanned, ['/tmp/photo.jpg']);
    expect(
      find.text(
        "The barcode (AIC 034701021) isn't in AIFA's list, so the text in the photo was read.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('after a barcode, a photo of the box can be added and kept', (tester) async {
    final anna = await pumpProfile(
      tester,
      scanner: FakeScanner(
        const LabelResult.empty(),
        catalog: {'012745093': _tachipirina},
        photo: tinyPng,
      ),
      barcode: const BarcodeRead('012745093'),
    );
    await scanBox(tester);

    await scrollTo(tester, 'Add a photo of the box');
    await tester.tap(find.text('Add a photo of the box'));
    await tester.pumpAndSettle();
    expect(photosTaken, ['/tmp/photo.jpg']);
    expect(find.bySemanticsLabel('Photo of the box'), findsOneWidget);

    await scrollTo(tester, 'Save');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final med = repo.medicinesOf(anna.id).single;
    expect(med.hasPhoto, isTrue);
    expect(await tester.runAsync(() => repo.photoOf(med)), tinyPng);
  });

  testWidgets('a photo can be added later on the medicine page', (tester) async {
    final anna = await pumpProfile(
      tester,
      scanner: FakeScanner(const LabelResult.empty(), photo: tinyPng),
      barcode: null,
    );
    await tester.runAsync(() => repo.addMedicine(anna.id, name: 'Moment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moment'));
    await tester.pumpAndSettle();

    await scrollTo(tester, 'Add a photo of the box');
    await tester.tap(find.text('Add a photo of the box'));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Save');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.medicinesOf(anna.id).single.hasPhoto, isTrue);
  });
}
