import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/scan/label_parser.dart';

import 'fakes.dart';

void main() {
  late ArchiveRepository repo;

  setUp(() async => repo = await memoryRepository());

  Future<void> pumpApp(
    WidgetTester tester, {
    FakeScanner? scanner,
    Future<String?> Function()? takePhoto,
  }) async {
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: scanner ?? FakeScanner(const LabelResult.empty()),
        takePhoto: takePhoto ?? () async => '/tmp/photo.jpg',
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openProfile(WidgetTester tester, String name) async {
    await repo.createProfile(name);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  group('profiles', () {
    testWidgets('shows an empty state when there are no profiles', (tester) async {
      await pumpApp(tester);
      expect(find.text('No profiles yet'), findsOneWidget);
    });

    testWidgets('creates a new profile by name', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Anna');
      await tester.pump();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Anna'), findsOneWidget);
      expect(repo.profiles.single.name, 'Anna');
    });

    testWidgets('Create is disabled until a name is typed', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New profile'));
      await tester.pumpAndSettle();
      final create = find.widgetWithText(FilledButton, 'Create');
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
    });

    testWidgets('shows how many medicines each profile has', (tester) async {
      final anna = await repo.createProfile('Anna');
      await repo.addMedicine(anna.id, name: 'Aspirina', quantity: 10);
      await pumpApp(tester);
      expect(find.text('1 medicine'), findsOneWidget);
    });
  });

  group('medicines', () {
    testWidgets('shows an empty state for a new profile', (tester) async {
      await pumpApp(tester);
      await openProfile(tester, 'Anna');
      expect(find.text('No medicines yet'), findsOneWidget);
    });

    testWidgets('scans a box, lets the user check it, and saves it', (tester) async {
      final scanner = FakeScanner(
        const LabelResult(name: 'Tachipirina 500 mg', quantity: 20, unit: 'compresse'),
      );
      await pumpApp(tester, scanner: scanner);
      await openProfile(tester, 'Anna');

      await tester.tap(find.text('Scan box'));
      await tester.pumpAndSettle();

      expect(scanner.scanned, ['/tmp/photo.jpg']);
      expect(find.widgetWithText(TextField, 'Tachipirina 500 mg'), findsOneWidget);
      expect(find.widgetWithText(TextField, '20'), findsOneWidget);
      expect(find.text('The photo has been deleted.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '20'), '18');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Tachipirina 500 mg'), findsOneWidget);
      expect(find.text('18 compresse'), findsOneWidget);
      final med = repo.medicinesOf(repo.profiles.single.id).single;
      expect(med.quantity, 18);
    });

    testWidgets('does nothing when the camera is cancelled', (tester) async {
      final scanner = FakeScanner(const LabelResult.empty());
      await pumpApp(tester, scanner: scanner, takePhoto: () async => null);
      await openProfile(tester, 'Anna');
      await tester.tap(find.text('Scan box'));
      await tester.pumpAndSettle();
      expect(scanner.scanned, isEmpty);
      expect(find.text('No medicines yet'), findsOneWidget);
    });

    testWidgets('falls back to typing when the label cannot be read', (tester) async {
      await pumpApp(tester, scanner: FakeScanner(const LabelResult.empty(), fail: true));
      await openProfile(tester, 'Anna');
      await tester.tap(find.text('Scan box'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't read the label. Please type it in."), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('adds a medicine by hand', (tester) async {
      await pumpApp(tester);
      await openProfile(tester, 'Anna');
      await tester.tap(find.byTooltip('Add by hand'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Aspirina');
      await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '10');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Aspirina'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('Save is disabled while the name is empty', (tester) async {
      await pumpApp(tester);
      await openProfile(tester, 'Anna');
      await tester.tap(find.byTooltip('Add by hand'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets('deletes a medicine after confirming', (tester) async {
      final anna = await repo.createProfile('Anna');
      await repo.addMedicine(anna.id, name: 'Aspirina', quantity: 10);
      await pumpApp(tester);
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete Aspirina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('No medicines yet'), findsOneWidget);
      expect(repo.medicinesOf(anna.id), isEmpty);
    });
  });
}
