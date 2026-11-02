import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/scan/label_parser.dart';

import 'fakes.dart';

const _step1 = 'How many times has someone asked you which medicines you take?';
const _step2 = 'Now that problem is solved';
const _step3 = 'How it works';

void main() {
  late ArchiveRepository repo;

  setUp(() async => repo = await memoryRepository(onboarded: false));

  Future<void> pumpApp(WidgetTester tester, {ThemeMode themeMode = ThemeMode.light}) async {
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: FakeScanner(const LabelResult.empty()),
        takePhoto: () async => null,
        themeMode: themeMode,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the first start walks through three steps, then opens the app', (tester) async {
    await pumpApp(tester);
    expect(find.text(_step1), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text(_step2), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text(_step3), findsOneWidget);
    expect(find.text('Scan the barcode on the box, or take a photo.'), findsOneWidget);

    await tester.tap(find.text('OK, let\'s start'));
    await tester.pumpAndSettle();
    expect(find.text('No profiles yet'), findsOneWidget);
    expect(repo.needsOnboarding, isFalse);
  });

  testWidgets('the steps can be swiped', (tester) async {
    await pumpApp(tester);
    await tester.fling(find.text(_step1), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(_step2), findsOneWidget);
  });

  testWidgets('Skip goes straight to the app', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('No profiles yet'), findsOneWidget);
    expect(repo.needsOnboarding, isFalse);
  });

  testWidgets('the next start goes straight to the app', (tester) async {
    await repo.completeOnboarding();
    await pumpApp(tester);
    expect(find.text(_step1), findsNothing);
    expect(find.text('No profiles yet'), findsOneWidget);
  });

  testWidgets('screen readers hear which step this is', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
    handle.dispose();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('every step meets the Android guidelines (${mode.name})', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, themeMode: mode);
      for (var step = 0; step < 3; step++) {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        if (step < 2) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
      handle.dispose();
    });
  }

  testWidgets('the steps fit at 200% text size', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MedicineArchiveApp(
          repository: repo,
          scanner: FakeScanner(const LabelResult.empty()),
          takePhoto: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var step = 0; step < 2; step++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('OK, let\'s start'), findsOneWidget);
  });
}
