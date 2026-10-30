import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/encrypted_file_store.dart';
import 'package:medicine_archive/data/key_provider.dart';

void main() {
  late Directory dir;
  late InMemoryKeyProvider keys;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('archived_test');
    keys = InMemoryKeyProvider();
  });

  tearDown(() => dir.delete(recursive: true));

  Future<ArchiveRepository> open() =>
      ArchiveRepository.open(EncryptedFileStore(file: File('${dir.path}/a.enc'), keys: keys));

  test('archiving moves a medicine out of the current list into the archived one', () async {
    final repo = await open();
    final anna = await repo.createProfile('Anna');
    final moment = await repo.addMedicine(anna.id, name: 'Moment');
    await repo.addMedicine(anna.id, name: 'Aspirina');

    await repo.setArchived(moment.id, true);

    expect(repo.medicinesOf(anna.id).map((m) => m.name), ['Aspirina']);
    expect(repo.medicinesOf(anna.id, archived: true).map((m) => m.name), ['Moment']);
    expect(repo.medicinesOf(anna.id, archived: true).single.archived, isTrue);
  });

  test('restoring brings it back', () async {
    final repo = await open();
    final anna = await repo.createProfile('Anna');
    final moment = await repo.addMedicine(anna.id, name: 'Moment');
    await repo.setArchived(moment.id, true);
    await repo.setArchived(moment.id, false);
    expect(repo.medicinesOf(anna.id).single.name, 'Moment');
    expect(repo.medicinesOf(anna.id, archived: true), isEmpty);
  });

  test('the archive survives reopening, and older archives open with nothing archived', () async {
    final repo = await open();
    final anna = await repo.createProfile('Anna');
    final moment = await repo.addMedicine(anna.id, name: 'Moment');
    await repo.addMedicine(anna.id, name: 'Aspirina');
    await repo.setArchived(moment.id, true);

    final reopened = await open();
    expect(reopened.medicinesOf(anna.id).single.name, 'Aspirina');
    expect(reopened.medicinesOf(anna.id, archived: true).single.name, 'Moment');

    expect(Medicine.fromJson({'id': 'x', 'profileId': 'p', 'name': 'Old'}).archived, isFalse);
  });

  test('editing an archived medicine keeps it archived', () async {
    final repo = await open();
    final anna = await repo.createProfile('Anna');
    final moment = await repo.addMedicine(anna.id, name: 'Moment');
    await repo.setArchived(moment.id, true);
    await repo.updateMedicine(moment.copyWith(name: 'Moment Act'));
    expect(repo.medicinesOf(anna.id, archived: true).single.name, 'Moment Act');
  });
}
