import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/tags.dart';
import 'package:medicine_archive/scan/label_parser.dart';

import 'fakes.dart';

void main() {
  late ArchiveRepository repo;
  late Profile anna;

  setUp(() async {
    repo = await memoryRepository();
    anna = await repo.createProfile('Anna');
  });

  Future<void> pumpAnna(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: FakeScanner(const LabelResult.empty()),
        takePhoto: () async => null,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
  }

  Finder chip(String label) => find.widgetWithText(FilterChip, label);
  bool selected(WidgetTester tester, String label) =>
      tester.widget<FilterChip>(chip(label)).selected;

  Future<void> addByHand(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('Add by hand'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('the form offers Morning, Noon and Evening, and several can be picked', (
    tester,
  ) async {
    await pumpAnna(tester);
    await addByHand(tester, 'Metformina');

    expect(find.text('When you take it'), findsOneWidget);
    await tester.tap(chip('Morning'));
    await tester.tap(chip('Evening'));
    await tester.pump();
    expect(selected(tester, 'Morning'), isTrue);
    expect(selected(tester, 'Noon'), isFalse);
    expect(selected(tester, 'Evening'), isTrue);
    await save(tester);

    expect(repo.medicinesOf(anna.id).single.tags, [MedicineTags.morning, MedicineTags.evening]);
  });

  testWidgets('a new tag can be typed in, and it is picked', (tester) async {
    await pumpAnna(tester);
    await addByHand(tester, 'Tachipirina');

    await tester.enterText(find.widgetWithText(TextField, 'Add a tag'), 'When needed');
    await tester.tap(find.byTooltip('Add tag'));
    await tester.pump();
    expect(selected(tester, 'When needed'), isTrue);
    await save(tester);

    expect(repo.medicinesOf(anna.id).single.tags, ['When needed']);
  });

  testWidgets('the done key on the keyboard adds the tag too', (tester) async {
    await pumpAnna(tester);
    await addByHand(tester, 'Tachipirina');

    await tester.enterText(find.widgetWithText(TextField, 'Add a tag'), 'Holiday');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(selected(tester, 'Holiday'), isTrue);
  });

  testWidgets("the profile's own tags are offered, and typing one again reuses it", (tester) async {
    await repo.addMedicine(anna.id, name: 'Tachipirina', tags: ['When needed']);
    await pumpAnna(tester);
    await addByHand(tester, 'Brufen');

    expect(find.text('Your tags'), findsOneWidget);
    expect(selected(tester, 'When needed'), isFalse);

    await tester.enterText(find.widgetWithText(TextField, 'Add a tag'), 'when needed ');
    await tester.tap(find.byTooltip('Add tag'));
    await tester.pump();
    expect(chip('When needed'), findsOneWidget);
    expect(selected(tester, 'When needed'), isTrue);
    await save(tester);

    expect(repo.medicinesOf(anna.id).firstWhere((m) => m.name == 'Brufen').tags, ['When needed']);
  });

  testWidgets('editing shows the tags it has and can change them', (tester) async {
    await repo.addMedicine(anna.id, name: 'Pantoprazolo', tags: [MedicineTags.noon]);
    await pumpAnna(tester);

    await tester.tap(find.text('Pantoprazolo'));
    await tester.pumpAndSettle();
    expect(selected(tester, 'Noon'), isTrue);

    await tester.tap(chip('Noon'));
    await tester.tap(chip('Evening'));
    await tester.pump();
    await save(tester);

    expect(repo.medicinesOf(anna.id).single.tags, [MedicineTags.evening]);
  });
}
