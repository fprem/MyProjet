import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/tags.dart';
import 'package:medicine_archive/scan/label_parser.dart';
import 'package:medicine_archive/ui/brand.dart';

import 'fakes.dart';

void main() {
  late ArchiveRepository repo;
  late Profile anna;

  setUp(() async {
    repo = await memoryRepository();
    anna = await repo.createProfile('Anna');
  });

  Future<void> pumpAnna(WidgetTester tester, {LabelResult? scanned}) async {
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: FakeScanner(scanned ?? const LabelResult.empty()),
        takePhoto: () async => '/tmp/photo.jpg',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
  }

  /// The system back, as a back swipe or the back button sends it.
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  group('going back from the form', () {
    testWidgets('after a scan, asks before throwing away what was read', (tester) async {
      await pumpAnna(
        tester,
        scanned: const LabelResult(name: 'Eutirox', strength: '50 mcg'),
      );
      await tester.tap(find.text('Scan box'));
      await tester.pumpAndSettle();

      await back(tester);
      expect(find.text('Discard this medicine?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Check medicine'), findsOneWidget);
      expect(find.text('Eutirox'), findsOneWidget);

      await back(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Check medicine'), findsNothing);
      expect(repo.medicinesOf(anna.id), isEmpty);
    });

    testWidgets('an empty new form closes without asking', (tester) async {
      await pumpAnna(tester);
      await tester.tap(find.byTooltip('Add by hand'));
      await tester.pumpAndSettle();

      await back(tester);
      expect(find.text('Add medicine'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('an unchanged medicine closes without asking, a changed one asks', (tester) async {
      await repo.addMedicine(anna.id, name: 'Eutirox', strength: '50 mcg');
      await pumpAnna(tester);
      await tester.tap(find.text('Eutirox'));
      await tester.pumpAndSettle();
      await back(tester);
      expect(find.text('Edit medicine'), findsNothing);

      await tester.tap(find.text('Eutirox'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Strength (optional)'), '75 mcg');
      await tester.pump();
      await back(tester);
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(repo.medicinesOf(anna.id).single.strength, '50 mcg');
    });
  });

  testWidgets('TalkBack can move a medicine to another group, as dragging does', (tester) async {
    await repo.addMedicine(anna.id, name: 'Eutirox', tags: [MedicineTags.morning]);
    await repo.addMedicine(anna.id, name: 'Aspirina', tags: [MedicineTags.evening]);
    await pumpAnna(tester);

    final semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.text('Eutirox'),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && (w.properties.customSemanticsActions?.isNotEmpty ?? false),
            ),
          )
          .first,
    );
    final actions = semantics.properties.customSemanticsActions!;
    expect(actions.keys.map((a) => a.label), ['Move to Noon', 'Move to Evening', 'Move to No tag']);

    actions.entries.firstWhere((e) => e.key.label == 'Move to Evening').value();
    await tester.pumpAndSettle();
    expect(repo.medicinesOf(anna.id).first.tags, [MedicineTags.evening]);
    expect(find.text('Eutirox moved to Evening'), findsOneWidget);
  });

  test('page changes follow the predictive back swipe on Android', () {
    expect(
      Brand.lightTheme().pageTransitionsTheme.builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
  });

  testWidgets('on a tablet the app stays one readable column', (tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpAnna(tester);
    expect(tester.getSize(find.byType(Scaffold).first).width, maxContentWidth);
  });
}
