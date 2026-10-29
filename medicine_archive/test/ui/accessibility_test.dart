import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/scan/photo_scanner.dart';

import 'fakes.dart';

class SlowScanner implements MedicineScanner {
  final completer = Completer<ScanResult>();

  @override
  Future<ScanResult> scan(String imagePath) => completer.future;

  @override
  Future<ScanResult> lookup(String aic) async => ScanResult(const LabelResult.empty(), aic: aic);

  @override
  Future<Uint8List?> readPhoto(String imagePath) async => null;
}

void main() {
  late ArchiveRepository repo;

  setUp(() async => repo = await memoryRepository());

  Future<void> pumpApp(
    WidgetTester tester, {
    MedicineScanner? scanner,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: scanner ?? FakeScanner(const LabelResult.empty()),
        takePhoto: () async => '/tmp/photo.jpg',
        themeMode: themeMode,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> meetsAll(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme meets Android guidelines', () {
      testWidgets('profiles, empty', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester, themeMode: mode);
        await meetsAll(tester);
        handle.dispose();
      });

      testWidgets('profiles and medicines lists', (tester) async {
        final handle = tester.ensureSemantics();
        final anna = await repo.createProfile('Anna');
        await repo.addMedicine(anna.id, name: 'Aspirina', quantity: 10, unit: 'compresse');
        await pumpApp(tester, themeMode: mode);
        await meetsAll(tester);
        await tester.tap(find.text('Anna'));
        await tester.pumpAndSettle();
        await meetsAll(tester);
        handle.dispose();
      });

      testWidgets('check medicine form', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          themeMode: mode,
          scanner: FakeScanner(const LabelResult(name: 'Moment', quantity: 12)),
        );
        await repo.createProfile('Anna');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Anna'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Scan box'));
        await tester.pumpAndSettle();
        await meetsAll(tester);
        handle.dispose();
      });

      testWidgets('check medicine form with the box photo kept', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          themeMode: mode,
          scanner: FakeScanner(const LabelResult(name: 'Moment'), photo: tinyPng),
        );
        await repo.createProfile('Anna');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Anna'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Scan box'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep the box photo'));
        await tester.pumpAndSettle();
        await meetsAll(tester);
        handle.dispose();
      });
    });
  }

  testWidgets('screen readers hear the name once, not the avatar letter', (tester) async {
    final handle = tester.ensureSemantics();
    await repo.createProfile('Anna');
    await pumpApp(tester);
    final label = tester.getSemantics(find.byType(ListTile)).label;
    expect(label, startsWith('Anna'));
    handle.dispose();
  });

  testWidgets('the reading state is announced', (tester) async {
    final handle = tester.ensureSemantics();
    final scanner = SlowScanner();
    await pumpApp(tester, scanner: scanner);
    await repo.createProfile('Anna');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan box'));
    await tester.pump();

    expect(
      tester.getSemantics(find.text('Reading the label…')),
      containsSemantics(isLiveRegion: true),
    );

    scanner.completer.complete(const ScanResult(LabelResult.empty()));
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('the form says which fields are required', (tester) async {
    await repo.createProfile('Anna');
    await pumpApp(tester);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add by hand'));
    await tester.pumpAndSettle();
    // Only the name is required; strength and quantity are optional.
    expect(find.text('Required'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Aspirina');
    await tester.pump();
    expect(find.text('Required'), findsNothing);
  });

  testWidgets('the menu button has a clear name', (tester) async {
    await repo.createProfile('Anna');
    await pumpApp(tester);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('More options'), findsOneWidget);
  });

  testWidgets('layout holds at 200% text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final anna = await repo.createProfile('Anna');
    await repo.addMedicine(anna.id, name: 'Tachipirina 1000 mg', quantity: 16, unit: 'compresse');
    await pumpApp(tester);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tachipirina 1000 mg'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
