import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/backup.dart';
import 'package:medicine_archive/data/photo_store.dart';
import 'package:medicine_archive/data/tags.dart';
import 'package:medicine_archive/scan/label_parser.dart';
import 'package:medicine_archive/ui/backup_flow.dart';

import 'fakes.dart';

class FakeBackupFiles implements BackupFiles {
  FakeBackupFiles({this.toPick, this.saveWorks = true});
  Uint8List? toPick;
  final bool saveWorks;
  String? savedName;
  Uint8List? saved;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    if (!saveWorks) return false;
    savedName = fileName;
    saved = bytes;
    return true;
  }

  @override
  Future<Uint8List?> pick() async => toPick;
}

void main() {
  const codec = BackupCodec(iterations: 1000);
  late ArchiveRepository repo;

  setUp(() async => repo = await memoryRepository());

  Future<void> pumpApp(WidgetTester tester, FakeBackupFiles files) async {
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: FakeScanner(const LabelResult.empty()),
        takePhoto: () async => null,
        backupFiles: files,
        backupCodec: codec,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    // The key derivation runs as real work, not on the fake clock.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<Uint8List> backupOf(Future<void> Function(ArchiveRepository) fill) async {
    final other = await ArchiveRepository.open(MemoryStore(), photos: MemoryPhotoStore());
    await fill(other);
    return codec.seal(await other.exportData(), 'secret pass');
  }

  testWidgets('export asks for a password twice and saves an encrypted file', (tester) async {
    final anna = await repo.createProfile('Anna');
    await repo.addMedicine(anna.id, name: 'Metformina', tags: [MedicineTags.morning]);
    final files = FakeBackupFiles();
    await pumpApp(tester, files);

    await menu(tester, 'Export backup');
    final export = find.widgetWithText(FilledButton, 'Export');
    expect(tester.widget<FilledButton>(export).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret pass');
    await tester.enterText(find.widgetWithText(TextField, 'Repeat password'), 'secret pazz');
    await tester.pump();
    expect(find.text("The passwords don't match"), findsOneWidget);
    expect(tester.widget<FilledButton>(export).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Repeat password'), 'secret pass');
    await tester.pump();
    await tester.tap(export);
    await settle(tester);

    expect(files.savedName, matches(RegExp(r'^medicine-archive-\d{4}-\d{2}-\d{2}\.mabk$')));
    final opened = await tester.runAsync(() => codec.open(files.saved!, 'secret pass'));
    expect(BackupSummary.of(opened!).medicines, 1);
    expect(find.textContaining('Backup saved'), findsOneWidget);
  });

  testWidgets('a short password is not accepted', (tester) async {
    await repo.createProfile('Anna');
    await pumpApp(tester, FakeBackupFiles());
    await menu(tester, 'Export backup');

    await tester.enterText(find.widgetWithText(TextField, 'Password'), '123');
    await tester.enterText(find.widgetWithText(TextField, 'Repeat password'), '123');
    await tester.pump();
    expect(find.text('At least 6 characters'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Export')).onPressed,
      isNull,
    );
  });

  testWidgets('after a reinstall, the empty screen offers to import a backup', (tester) async {
    final file = await tester.runAsync(
      () => backupOf((r) async {
        final anna = await r.createProfile('Anna');
        await r.addMedicine(anna.id, name: 'Metformina', tags: [MedicineTags.evening]);
      }),
    );
    await pumpApp(tester, FakeBackupFiles(toPick: file));

    await tester.tap(find.text('Import a backup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret pass');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await settle(tester);

    expect(find.text('Anna'), findsOneWidget);
    expect(repo.medicinesOf(repo.profiles.single.id).single.tags, [MedicineTags.evening]);
    expect(find.textContaining('Backup imported'), findsOneWidget);
  });

  testWidgets('a wrong password says so and imports nothing', (tester) async {
    final file = await tester.runAsync(() => backupOf((r) async => r.createProfile('Anna')));
    await pumpApp(tester, FakeBackupFiles(toPick: file));

    await tester.tap(find.text('Import a backup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'not it');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await settle(tester);

    expect(find.text('Wrong password, or the file is damaged.'), findsOneWidget);
    expect(repo.profiles, isEmpty);
  });

  testWidgets('importing over data asks first, and Cancel keeps it', (tester) async {
    await repo.createProfile('Carla');
    final file = await tester.runAsync(
      () => backupOf((r) async {
        await r.createProfile('Anna');
        await r.createProfile('Bob');
      }),
    );
    await pumpApp(tester, FakeBackupFiles(toPick: file));

    await menu(tester, 'Import backup');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret pass');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await settle(tester);

    expect(find.text('Replace everything on this phone?'), findsOneWidget);
    expect(find.textContaining('2 profiles and 0 medicines'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.profiles.single.name, 'Carla');

    await menu(tester, 'Import backup');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret pass');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
    await tester.pumpAndSettle();
    expect(repo.profiles.map((p) => p.name), ['Anna', 'Bob']);
  });

  testWidgets('cancelling the file picker does nothing', (tester) async {
    await repo.createProfile('Carla');
    await pumpApp(tester, FakeBackupFiles());
    await menu(tester, 'Import backup');
    expect(find.widgetWithText(TextField, 'Password'), findsNothing);
    expect(repo.profiles.single.name, 'Carla');
  });
}
