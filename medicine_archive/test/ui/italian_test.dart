import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/tags.dart';
import 'package:medicine_archive/scan/label_parser.dart';

import 'fakes.dart';

void main() {
  late ArchiveRepository repo;

  setUp(() async => repo = await memoryRepository());

  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: FakeScanner(const LabelResult(name: 'Eutirox', strength: '50 mcg')),
        takePhoto: () async => '/tmp/photo.jpg',
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('in Italian', () {
    testWidgets('the profiles screen speaks Italian', (tester) async {
      final anna = await repo.createProfile('Anna');
      await repo.addMedicine(anna.id, name: 'Eutirox');
      await pumpApp(tester, locale: const Locale('it'));

      expect(find.text('Nuovo profilo'), findsOneWidget);
      expect(find.text('Profili'), findsOneWidget);
      expect(find.text('1 farmaco'), findsOneWidget);
    });

    testWidgets('a profile shows Italian groups, chips and the scan button', (tester) async {
      final anna = await repo.createProfile('Anna');
      await repo.addMedicine(anna.id, name: 'Eutirox', tags: [MedicineTags.morning]);
      await repo.addMedicine(anna.id, name: 'Cardioaspirin', tags: [MedicineTags.evening]);
      await pumpApp(tester, locale: const Locale('it'));
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();

      expect(find.text('Scansiona scatola'), findsOneWidget);
      expect(find.text('In uso (2)'), findsOneWidget);
      expect(find.text('Tutti (2)'), findsOneWidget);
      expect(find.text('Mattina'), findsOneWidget); // the group heading
      expect(find.text('Mattina (1)'), findsOneWidget); // the chip
      expect(find.text('Sera'), findsOneWidget);
    });

    testWidgets('the form after a scan is in Italian', (tester) async {
      await repo.createProfile('Anna');
      await pumpApp(tester, locale: const Locale('it'));
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scansiona scatola'));
      await tester.pumpAndSettle();

      expect(find.text('Controlla il farmaco'), findsOneWidget);
      expect(find.text('Salva'), findsOneWidget);
      expect(find.text('Dosaggio (facoltativo)'), findsOneWidget);
    });

    testWidgets('the layout holds in Italian at 200% text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final anna = await repo.createProfile('Anna');
      await repo.addMedicine(
        anna.id,
        name: 'Amoxicillina e Acido Clavulanico Sandoz',
        strength: '875 mg + 125 mg',
        quantity: 12,
        unit: 'compresse',
        tags: [MedicineTags.morning, MedicineTags.evening],
      );
      await pumpApp(tester, locale: const Locale('it'));
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Amoxicillina e Acido Clavulanico Sandoz').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a phone in another language gets English', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpApp(tester);
    expect(find.text('New profile'), findsOneWidget);
  });

  testWidgets('a phone set to Italian gets Italian', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpApp(tester);
    expect(find.text('Nuovo profilo'), findsOneWidget);
  });

  test('every English text has an Italian one, with the same placeholders', () {
    Map<String, dynamic> read(String lang) =>
        jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
    final en = read('en');
    final it = read('it');
    Set<String> keys(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@')).toSet();
    expect(keys(it), keys(en));
    final placeholder = RegExp(r'\{(\w+)[},]');
    for (final key in keys(en)) {
      Set<String> names(String text) => placeholder.allMatches(text).map((m) => m[1]!).toSet();
      expect(names(it[key] as String), names(en[key] as String), reason: key);
    }
  });
}
