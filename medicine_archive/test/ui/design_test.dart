import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/scan/photo_scanner.dart';
import 'package:medicine_archive/ui/brand.dart';

import 'fakes.dart';

class _SlowScanner implements MedicineScanner {
  final completer = Completer<LabelResult>();

  @override
  Future<LabelResult> scan(String imagePath) => completer.future;
}

void main() {
  late ArchiveRepository repo;

  setUp(() async => repo = await memoryRepository());

  Future<void> pumpApp(WidgetTester tester, {MedicineScanner? scanner}) async {
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: scanner ?? FakeScanner(const LabelResult.empty()),
        takePhoto: () async => '/tmp/photo.jpg',
      ),
    );
    await tester.pumpAndSettle();
  }

  test('the theme uses the brand typefaces in both modes', () {
    for (final theme in [Brand.lightTheme(), Brand.darkTheme()]) {
      expect(theme.textTheme.bodyLarge!.fontFamily, Brand.textFont);
      expect(theme.textTheme.headlineMedium!.fontFamily, Brand.displayFont);
      expect(theme.textTheme.titleLarge!.fontFamily, Brand.displayFont);
    }
  });

  testWidgets('the profiles screen shows the logo', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LogoMark), findsWidgets);
  });

  testWidgets('a profile shows how many medicines it holds', (tester) async {
    final anna = await repo.createProfile('Anna');
    await repo.addMedicine(anna.id, name: 'Aspirina', quantity: 10, unit: 'compresse');
    await repo.addMedicine(anna.id, name: 'Moment', quantity: 12, unit: 'compresse');
    await pumpApp(tester);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(find.text('2 medicines'), findsWidgets);
  });

  testWidgets('each medicine shows its quantity as a pill', (tester) async {
    final anna = await repo.createProfile('Anna');
    await repo.addMedicine(anna.id, name: 'Aspirina', quantity: 10, unit: 'compresse');
    await pumpApp(tester);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(QuantityPill, '10 compresse'), findsOneWidget);
  });

  testWidgets('reading shows the scan frame', (tester) async {
    final scanner = _SlowScanner();
    await repo.createProfile('Anna');
    await pumpApp(tester, scanner: scanner);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan box'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ScanFrame), findsOneWidget);
    scanner.completer.complete(const LabelResult.empty());
    await tester.pumpAndSettle();
  });

  testWidgets('the scan frame stands still when animations are off', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(textDirection: TextDirection.ltr, child: ScanFrame()),
      ),
    );
    // Would time out if the sweep kept repeating.
    await tester.pumpAndSettle();
    expect(find.byType(ScanFrame), findsOneWidget);
  });
}
