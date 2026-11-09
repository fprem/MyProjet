import 'package:flutter/gestures.dart';
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
    // A tall phone, so every group fits on screen.
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

  Finder section(String? tag) => find.byKey(ValueKey('section-${tag ?? 'none'}'));
  Finder filter(String? tag) => find.byKey(ValueKey('filter-${tag ?? 'none'}'));
  Finder inSection(String? tag, String text) =>
      find.descendant(of: section(tag), matching: find.text(text));

  /// Long-presses [from], drags it onto [to] and lets go.
  Future<void> drag(WidgetTester tester, Finder from, Finder to) async {
    final gesture = await tester.startGesture(tester.getCenter(from));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(to) + const Offset(0, 4));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(to));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> addDay() async {
    await repo.addMedicine(anna.id, name: 'Eutirox', tags: [MedicineTags.morning]);
    await repo.addMedicine(
      anna.id,
      name: 'Metformina',
      tags: [MedicineTags.morning, MedicineTags.evening],
    );
    await repo.addMedicine(anna.id, name: 'Pantoprazolo', tags: [MedicineTags.noon]);
    await repo.addMedicine(anna.id, name: 'Tachipirina', tags: ['When needed']);
    await repo.addMedicine(anna.id, name: 'Aspirina');
  }

  testWidgets('the list is grouped by tag: day first, then own tags, then No tag', (tester) async {
    await addDay();
    await pumpAnna(tester);

    final order = [
      MedicineTags.morning,
      MedicineTags.noon,
      MedicineTags.evening,
      'When needed',
      null,
    ];
    final tops = [for (final t in order) tester.getTopLeft(section(t)).dy];
    expect(tops, [...tops]..sort());

    expect(inSection(MedicineTags.morning, 'Eutirox'), findsOneWidget);
    expect(inSection(MedicineTags.noon, 'Pantoprazolo'), findsOneWidget);
    expect(inSection('When needed', 'Tachipirina'), findsOneWidget);
    expect(inSection(null, 'Aspirina'), findsOneWidget);
  });

  testWidgets('a medicine with two tags is in both groups, with a hint of the other', (
    tester,
  ) async {
    await addDay();
    await pumpAnna(tester);

    expect(inSection(MedicineTags.morning, 'Metformina'), findsOneWidget);
    expect(inSection(MedicineTags.evening, 'Metformina'), findsOneWidget);
    expect(inSection(MedicineTags.morning, '+ Evening'), findsOneWidget);
    expect(inSection(MedicineTags.evening, '+ Morning'), findsOneWidget);
  });

  testWidgets('without any tags the list stays a plain list', (tester) async {
    await repo.addMedicine(anna.id, name: 'Aspirina');
    await repo.addMedicine(anna.id, name: 'Moment');
    await pumpAnna(tester);

    expect(section(null), findsNothing);
    expect(find.text('Aspirina'), findsOneWidget);
    expect(find.text('Moment'), findsOneWidget);
  });

  testWidgets('filter chips show counts, and a chip shows only its group', (tester) async {
    await addDay();
    await pumpAnna(tester);

    expect(find.text('All (5)'), findsOneWidget);
    expect(find.text('Morning (2)'), findsOneWidget);
    expect(find.text('Noon (1)'), findsOneWidget);
    expect(find.text('Evening (1)'), findsOneWidget);
    expect(find.text('When needed (1)'), findsOneWidget);
    expect(find.text('No tag (1)'), findsOneWidget);

    await tester.tap(filter(MedicineTags.evening));
    await tester.pumpAndSettle();
    expect(find.text('Metformina'), findsOneWidget);
    expect(find.text('Eutirox'), findsNothing);
    expect(find.text('Aspirina'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Eutirox'), findsOneWidget);
  });

  testWidgets('the fixed chips are there even when empty, to drop medicines on', (tester) async {
    await repo.addMedicine(anna.id, name: 'Aspirina');
    await pumpAnna(tester);
    expect(find.text('Morning (0)'), findsOneWidget);
    expect(find.text('Noon (0)'), findsOneWidget);
    expect(find.text('Evening (0)'), findsOneWidget);
  });

  testWidgets('dragging a medicine to another group changes its tag', (tester) async {
    await addDay();
    await pumpAnna(tester);

    await drag(tester, inSection(MedicineTags.noon, 'Pantoprazolo'), section(MedicineTags.evening));

    expect(repo.medicinesOf(anna.id).firstWhere((m) => m.name == 'Pantoprazolo').tags, [
      MedicineTags.evening,
    ]);
    expect(inSection(MedicineTags.evening, 'Pantoprazolo'), findsOneWidget);
    expect(section(MedicineTags.noon), findsNothing);
    expect(find.text('Pantoprazolo moved to Evening'), findsOneWidget);
  });

  testWidgets('a moved medicine keeps its other tags', (tester) async {
    await addDay();
    await pumpAnna(tester);

    await drag(tester, inSection(MedicineTags.morning, 'Metformina'), section(MedicineTags.noon));

    expect(repo.medicinesOf(anna.id).firstWhere((m) => m.name == 'Metformina').tags, [
      MedicineTags.noon,
      MedicineTags.evening,
    ]);
  });

  testWidgets('a move can be undone', (tester) async {
    await addDay();
    await pumpAnna(tester);

    await drag(tester, inSection(MedicineTags.noon, 'Pantoprazolo'), section(MedicineTags.evening));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repo.medicinesOf(anna.id).firstWhere((m) => m.name == 'Pantoprazolo').tags, [
      MedicineTags.noon,
    ]);
  });

  testWidgets('dropping on a chip moves it there, also from a filtered list', (tester) async {
    await addDay();
    await pumpAnna(tester);

    await tester.tap(filter(MedicineTags.morning));
    await tester.pumpAndSettle();
    await drag(tester, find.text('Eutirox'), filter(MedicineTags.noon));

    expect(repo.medicinesOf(anna.id).firstWhere((m) => m.name == 'Eutirox').tags, [
      MedicineTags.noon,
    ]);
    expect(find.text('Eutirox moved to Noon'), findsOneWidget);
  });

  testWidgets('dropping on No tag removes only the tag it came from', (tester) async {
    await addDay();
    await pumpAnna(tester);

    await drag(tester, inSection(MedicineTags.evening, 'Metformina'), section(null));

    expect(repo.medicinesOf(anna.id).firstWhere((m) => m.name == 'Metformina').tags, [
      MedicineTags.morning,
    ]);
    expect(find.text('Metformina moved to No tag'), findsOneWidget);
  });

  testWidgets('an untagged medicine in a plain list can be dropped on a chip', (tester) async {
    await repo.addMedicine(anna.id, name: 'Aspirina');
    await pumpAnna(tester);

    await drag(tester, find.text('Aspirina'), filter(MedicineTags.evening));

    expect(repo.medicinesOf(anna.id).single.tags, [MedicineTags.evening]);
    expect(inSection(MedicineTags.evening, 'Aspirina'), findsOneWidget);
  });

  testWidgets('dropping back on its own group changes nothing', (tester) async {
    await addDay();
    await pumpAnna(tester);

    await drag(tester, inSection(MedicineTags.noon, 'Pantoprazolo'), filter(MedicineTags.noon));

    expect(repo.medicinesOf(anna.id).firstWhere((m) => m.name == 'Pantoprazolo').tags, [
      MedicineTags.noon,
    ]);
    expect(find.textContaining('moved to'), findsNothing);
  });

  testWidgets('the Archived tab is not grouped', (tester) async {
    final m = await repo.addMedicine(anna.id, name: 'Moment', tags: [MedicineTags.morning]);
    await repo.setArchived(m.id, true);
    await pumpAnna(tester);

    await tester.tap(find.text('Archived (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Moment'), findsOneWidget);
    expect(section(MedicineTags.morning), findsNothing);
  });
}
