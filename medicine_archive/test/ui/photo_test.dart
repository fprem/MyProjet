import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/scan/label_parser.dart';

import 'fakes.dart';

void main() {
  late ArchiveRepository repo;

  setUp(() async => repo = await memoryRepository());

  Future<Profile> pumpProfile(WidgetTester tester, FakeScanner scanner) async {
    final anna = await repo.createProfile('Anna');
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: scanner,
        takePhoto: () async => '/tmp/photo.jpg',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    return anna;
  }

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.text('Scan box'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollToSave(WidgetTester tester) => tester.scrollUntilVisible(
    find.text('Save'),
    200,
    scrollable: find
        .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .last,
  );

  Finder keepSwitch() => find.widgetWithText(SwitchListTile, 'Keep the box photo');

  testWidgets('the photo is not kept unless the person chooses to', (tester) async {
    final anna = await pumpProfile(
      tester,
      FakeScanner(const LabelResult(name: 'Moment'), photo: tinyPng),
    );
    await scan(tester);

    expect(tester.widget<SwitchListTile>(keepSwitch()).value, isFalse);
    expect(find.text('The photo is deleted when you save, unless you keep it.'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final med = repo.medicinesOf(anna.id).single;
    expect(med.hasPhoto, isFalse);
    expect(await tester.runAsync(() => repo.photoOf(med)), isNull);
  });

  testWidgets('a kept photo is saved and shown on the medicine page', (tester) async {
    final anna = await pumpProfile(
      tester,
      FakeScanner(const LabelResult(name: 'Moment'), photo: tinyPng),
    );
    await scan(tester);

    await tester.tap(keepSwitch());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Photo of the box'), findsOneWidget);
    await scrollToSave(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final med = repo.medicinesOf(anna.id).single;
    expect(med.hasPhoto, isTrue);
    expect(await tester.runAsync(() => repo.photoOf(med)), tinyPng);

    await tester.tap(find.text('Moment'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Photo of the box'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(keepSwitch()).value, isTrue);
  });

  testWidgets('turning the switch off on the medicine page deletes the photo', (tester) async {
    final anna = await pumpProfile(tester, FakeScanner(const LabelResult.empty()));
    await tester.runAsync(() => repo.addMedicine(anna.id, name: 'Moment', photo: tinyPng));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moment'));
    await tester.pumpAndSettle();

    await tester.tap(keepSwitch());
    await tester.pumpAndSettle();
    await scrollToSave(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.medicinesOf(anna.id).single.hasPhoto, isFalse);
  });

  testWidgets('without a photo there is nothing to keep', (tester) async {
    await pumpProfile(tester, FakeScanner(const LabelResult(name: 'Moment')));
    await scan(tester);
    expect(keepSwitch(), findsNothing);
    expect(find.text('The photo has been deleted.'), findsOneWidget);
  });

  testWidgets('says when the medicine was found from its barcode', (tester) async {
    await pumpProfile(
      tester,
      FakeScanner(const LabelResult(name: 'Tachipirina'), fromCatalog: true),
    );
    await scan(tester);
    expect(find.text("Found from the barcode in AIFA's medicine list."), findsOneWidget);
  });
}
