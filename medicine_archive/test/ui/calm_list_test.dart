import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/tags.dart';
import 'package:medicine_archive/scan/label_parser.dart';

import 'fakes.dart';

/// The calmer medicine list of 1.3.0: one detail line per medicine, names at
/// full size, the box photo as thumbnail, and every action in one ⋮ menu.
void main() {
  late ArchiveRepository repo;
  late Profile anna;

  setUp(() async {
    repo = await memoryRepository();
    anna = await repo.createProfile('Anna');
  });

  Future<void> pumpAnna(WidgetTester tester, {Locale? locale, Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: FakeScanner(const LabelResult.empty()),
        takePhoto: () async => null,
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
  }

  Finder section(String? tag) => find.byKey(ValueKey('section-${tag ?? 'none'}'));
  Finder inSection(String? tag, String text) =>
      find.descendant(of: section(tag), matching: find.text(text));

  Future<void> openMenu(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('Options for $name').first);
    await tester.pumpAndSettle();
  }

  group('a medicine card', () {
    testWidgets('shows strength and pack size on one line', (tester) async {
      await repo.addMedicine(
        anna.id,
        name: 'Eutirox',
        strength: '50 mcg',
        quantity: 50,
        unit: 'compresse',
      );
      await pumpAnna(tester);
      expect(find.text('50 mcg · 50 compresse'), findsOneWidget);
    });

    testWidgets('says which other groups it is in', (tester) async {
      await repo.addMedicine(
        anna.id,
        name: 'Metformina',
        strength: '500 mg',
        tags: [MedicineTags.morning, MedicineTags.evening],
      );
      await pumpAnna(tester);
      expect(inSection(MedicineTags.morning, '500 mg · also Evening'), findsOneWidget);
      expect(inSection(MedicineTags.evening, '500 mg · also Morning'), findsOneWidget);
    });

    testWidgets('lists its tags where the list is not grouped', (tester) async {
      final m = await repo.addMedicine(
        anna.id,
        name: 'Moment',
        tags: [MedicineTags.morning, 'When needed'],
      );
      await repo.setArchived(m.id, true);
      await pumpAnna(tester);
      await tester.tap(find.text('Archived (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Morning, When needed'), findsOneWidget);
    });

    testWidgets('shows a long name at the same size as a short one', (tester) async {
      await repo.addMedicine(anna.id, name: 'Moment');
      await repo.addMedicine(anna.id, name: 'Amoxicillina e Acido Clavulanico Sandoz');
      await pumpAnna(tester, size: const Size(360, 740));
      double size(String name) =>
          tester.renderObject<RenderParagraph>(find.text(name)).text.style!.fontSize!;
      expect(size('Amoxicillina e Acido Clavulanico Sandoz'), size('Moment'));
    });

    testWidgets('shows the kept box photo, and no icon without one', (tester) async {
      final kept = await repo.addMedicine(anna.id, name: 'Moment', photo: tinyPng);
      await repo.addMedicine(anna.id, name: 'Aspirina');
      await pumpAnna(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('thumb-${kept.id}')), findsOneWidget);
      expect(find.byIcon(Icons.medication_rounded), findsNothing);
    });

    testWidgets('has one options button instead of Archive and Delete icons', (tester) async {
      await repo.addMedicine(anna.id, name: 'Eutirox');
      await pumpAnna(tester);
      expect(find.byTooltip('Archive Eutirox'), findsNothing);
      expect(find.byTooltip('Delete Eutirox'), findsNothing);
      expect(find.byTooltip('Options for Eutirox'), findsOneWidget);
    });
  });

  group('the options menu', () {
    testWidgets('offers Edit, Move to, Archive, and Delete last', (tester) async {
      await repo.addMedicine(anna.id, name: 'Eutirox');
      await pumpAnna(tester);
      await openMenu(tester, 'Eutirox');

      final labels = ['Edit', 'Move to…', 'Archive (stopped taking it)', 'Delete'];
      for (final l in labels) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      final tops = [for (final l in labels) tester.getTopLeft(find.text(l)).dy];
      expect(tops, [...tops]..sort());
    });

    testWidgets('Edit opens the form', (tester) async {
      await repo.addMedicine(anna.id, name: 'Eutirox');
      await pumpAnna(tester);
      await openMenu(tester, 'Eutirox');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit medicine'), findsOneWidget);
    });

    testWidgets('Move to lets you pick the group', (tester) async {
      await repo.addMedicine(anna.id, name: 'Eutirox', tags: [MedicineTags.morning]);
      await pumpAnna(tester);
      await openMenu(tester, 'Eutirox');
      await tester.tap(find.text('Move to…'));
      await tester.pumpAndSettle();

      expect(find.text('Move Eutirox to'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Morning'), findsNothing); // where it is now
      await tester.tap(find.widgetWithText(ListTile, 'Evening'));
      await tester.pumpAndSettle();

      expect(repo.medicinesOf(anna.id).single.tags, [MedicineTags.evening]);
      expect(find.text('Eutirox moved to Evening'), findsOneWidget);
    });

    testWidgets('Move to works on a list without any tags yet', (tester) async {
      await repo.addMedicine(anna.id, name: 'Aspirina');
      await pumpAnna(tester);
      await openMenu(tester, 'Aspirina');
      await tester.tap(find.text('Move to…'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'No tag'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Noon'));
      await tester.pumpAndSettle();
      expect(repo.medicinesOf(anna.id).single.tags, [MedicineTags.noon]);
    });

    testWidgets('Archive archives, with Undo', (tester) async {
      await repo.addMedicine(anna.id, name: 'Eutirox');
      await pumpAnna(tester);
      await openMenu(tester, 'Eutirox');
      await tester.tap(find.text('Archive (stopped taking it)'));
      await tester.pumpAndSettle();
      expect(repo.medicinesOf(anna.id), isEmpty);
      expect(find.text('Eutirox archived'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repo.medicinesOf(anna.id), hasLength(1));
    });

    testWidgets('Delete asks first', (tester) async {
      await repo.addMedicine(anna.id, name: 'Eutirox');
      await pumpAnna(tester);
      await openMenu(tester, 'Eutirox');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Eutirox?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repo.medicinesOf(anna.id), isEmpty);
    });

    testWidgets('on an archived medicine offers Restore and Delete, not Move', (tester) async {
      final m = await repo.addMedicine(anna.id, name: 'Moment');
      await repo.setArchived(m.id, true);
      await pumpAnna(tester);
      await tester.tap(find.text('Archived (1)'));
      await tester.pumpAndSettle();
      await openMenu(tester, 'Moment');

      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Move to…'), findsNothing);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(repo.medicinesOf(anna.id), hasLength(1));
    });
  });

  testWidgets('there are no filter chips; the groups are headings', (tester) async {
    await repo.addMedicine(anna.id, name: 'Eutirox', tags: [MedicineTags.morning]);
    await repo.addMedicine(anna.id, name: 'Aspirina');
    await pumpAnna(tester);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(section(MedicineTags.morning), findsOneWidget);
    expect(section(null), findsOneWidget);
  });

  group('search', () {
    Future<void> addMany(int n) async {
      for (var i = 1; i <= n; i++) {
        await repo.addMedicine(anna.id, name: 'Medicine $i');
      }
    }

    Finder field() => find.widgetWithText(TextField, "Search Anna's medicines");

    testWidgets('is not there for 8 medicines or fewer', (tester) async {
      await addMany(8);
      await pumpAnna(tester);
      expect(field(), findsNothing);
    });

    testWidgets('finds medicines by name, ignoring case', (tester) async {
      await addMany(8);
      await repo.addMedicine(anna.id, name: 'Eutirox');
      await pumpAnna(tester);

      await tester.enterText(field(), 'eUt');
      await tester.pumpAndSettle();
      expect(find.text('Eutirox'), findsOneWidget);
      expect(find.text('Medicine 1'), findsNothing);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await addMany(9);
      await pumpAnna(tester);
      await tester.enterText(field(), 'xyz');
      await tester.pumpAndSettle();
      expect(find.text('No medicine matches "xyz"'), findsOneWidget);
    });
  });

  group('adding by hand', () {
    testWidgets('is a labelled button next to Scan box', (tester) async {
      await pumpAnna(tester);
      expect(find.byTooltip('Add by hand'), findsNothing);
      expect(find.text('Scan box'), findsOneWidget);
      await tester.tap(find.text('Type it in'));
      await tester.pumpAndSettle();
      expect(find.text('Add medicine'), findsOneWidget);
    });

    testWidgets('both buttons fit in Italian at 200% text on a small phone', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await repo.addMedicine(anna.id, name: 'Eutirox');
      await pumpAnna(tester, locale: const Locale('it'), size: const Size(360, 740));
      expect(tester.takeException(), isNull);
      expect(find.text('Scansiona scatola'), findsOneWidget);
      expect(find.text('Scrivi a mano'), findsOneWidget);
    });
  });
}
