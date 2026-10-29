import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
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

  testWidgets('Archive moves a medicine to the Archived tab', (tester) async {
    await repo.addMedicine(anna.id, name: 'Moment');
    await repo.addMedicine(anna.id, name: 'Aspirina');
    await pumpAnna(tester);

    await tester.tap(find.byTooltip('Archive Moment'));
    await tester.pumpAndSettle();

    expect(find.text('Moment'), findsNothing);
    expect(find.text('Aspirina'), findsOneWidget);
    expect(repo.medicinesOf(anna.id, archived: true).single.name, 'Moment');

    await tester.tap(find.text('Archived (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Moment'), findsOneWidget);
    expect(find.text('Aspirina'), findsNothing);
  });

  testWidgets('Restore moves it back to the medicines being taken', (tester) async {
    final moment = await repo.addMedicine(anna.id, name: 'Moment');
    await repo.setArchived(moment.id, true);
    await pumpAnna(tester);

    await tester.tap(find.text('Archived (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restore Moment'));
    await tester.pumpAndSettle();

    expect(repo.medicinesOf(anna.id).single.name, 'Moment');
    await tester.tap(find.text('Taking (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Moment'), findsOneWidget);
  });

  testWidgets('archiving can be undone', (tester) async {
    await repo.addMedicine(anna.id, name: 'Moment');
    await pumpAnna(tester);

    await tester.tap(find.byTooltip('Archive Moment'));
    await tester.pumpAndSettle();
    expect(find.text('Moment archived'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repo.medicinesOf(anna.id).single.name, 'Moment');
  });

  testWidgets('the Archived tab explains itself when empty', (tester) async {
    await repo.addMedicine(anna.id, name: 'Moment');
    await pumpAnna(tester);
    await tester.tap(find.text('Archived (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No archived medicines'), findsOneWidget);
  });

  testWidgets('the profile counts only the medicines being taken', (tester) async {
    final moment = await repo.addMedicine(anna.id, name: 'Moment');
    await repo.addMedicine(anna.id, name: 'Aspirina');
    await repo.setArchived(moment.id, true);
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: FakeScanner(const LabelResult.empty()),
        takePhoto: () async => null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 medicine'), findsOneWidget);
  });
}
