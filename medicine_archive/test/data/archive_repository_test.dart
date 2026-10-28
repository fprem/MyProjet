import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/encrypted_file_store.dart';
import 'package:medicine_archive/data/key_provider.dart';

void main() {
  late Directory dir;
  late File file;
  late InMemoryKeyProvider keys;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('archive_test');
    file = File('${dir.path}/archive.enc');
    keys = InMemoryKeyProvider();
  });

  tearDown(() => dir.delete(recursive: true));

  Future<ArchiveRepository> open() async =>
      ArchiveRepository.open(EncryptedFileStore(file: file, keys: keys));

  test('starts with no profiles', () async {
    final repo = await open();
    expect(repo.profiles, isEmpty);
  });

  test('creates a profile with a trimmed name', () async {
    final repo = await open();
    final profile = await repo.createProfile('  Anna ');
    expect(profile.name, 'Anna');
    expect(repo.profiles.map((p) => p.name), ['Anna']);
  });

  test('rejects an empty profile name', () async {
    final repo = await open();
    expect(() => repo.createProfile('   '), throwsArgumentError);
  });

  test('lists profiles alphabetically, ignoring case', () async {
    final repo = await open();
    await repo.createProfile('marco');
    await repo.createProfile('Anna');
    expect(repo.profiles.map((p) => p.name), ['Anna', 'marco']);
  });

  test('adds medicines under the right profile only', () async {
    final repo = await open();
    final anna = await repo.createProfile('Anna');
    final marco = await repo.createProfile('Marco');
    await repo.addMedicine(anna.id, name: 'Tachipirina 500 mg', quantity: 20, unit: 'compresse');

    expect(repo.medicinesOf(anna.id).single.name, 'Tachipirina 500 mg');
    expect(repo.medicinesOf(anna.id).single.quantity, 20);
    expect(repo.medicinesOf(anna.id).single.unit, 'compresse');
    expect(repo.medicinesOf(marco.id), isEmpty);
  });

  test('rejects a medicine without a name or with a negative quantity', () async {
    final repo = await open();
    final anna = await repo.createProfile('Anna');
    expect(() => repo.addMedicine(anna.id, name: ' ', quantity: 1), throwsArgumentError);
    expect(() => repo.addMedicine(anna.id, name: 'Aspirina', quantity: -1), throwsArgumentError);
  });

  test('updates and deletes a medicine', () async {
    final repo = await open();
    final anna = await repo.createProfile('Anna');
    final med = await repo.addMedicine(anna.id, name: 'Aspirina', quantity: 10);
    await repo.updateMedicine(med.copyWith(quantity: 8));
    expect(repo.medicinesOf(anna.id).single.quantity, 8);

    await repo.deleteMedicine(med.id);
    expect(repo.medicinesOf(anna.id), isEmpty);
  });

  test('deleting a profile deletes its medicines', () async {
    final repo = await open();
    final anna = await repo.createProfile('Anna');
    await repo.addMedicine(anna.id, name: 'Aspirina', quantity: 10);
    await repo.deleteProfile(anna.id);
    expect(repo.profiles, isEmpty);
    expect(repo.medicinesOf(anna.id), isEmpty);
  });

  test('data survives reopening the archive', () async {
    final repo = await open();
    final anna = await repo.createProfile('Anna');
    await repo.addMedicine(anna.id, name: 'Aspirina', quantity: 10, unit: 'compresse');

    final reopened = await open();
    expect(reopened.profiles.single.name, 'Anna');
    expect(reopened.medicinesOf(anna.id).single.name, 'Aspirina');
  });

  test('notifies listeners on changes', () async {
    final repo = await open();
    var calls = 0;
    repo.addListener(() => calls++);
    await repo.createProfile('Anna');
    expect(calls, 1);
  });

  group('encryption at rest', () {
    test('the file on disk does not contain the plain data', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      await repo.addMedicine(anna.id, name: 'Tachipirina', quantity: 20);

      final bytes = await file.readAsBytes();
      final asText = latin1.decode(bytes);
      expect(asText, isNot(contains('Anna')));
      expect(asText, isNot(contains('Tachipirina')));
    });

    test('a different key cannot read the archive', () async {
      final repo = await open();
      await repo.createProfile('Anna');

      final other = EncryptedFileStore(file: file, keys: InMemoryKeyProvider());
      expect(() => other.read(), throwsA(isA<ArchiveDecryptionException>()));
    });

    test('a tampered file is rejected', () async {
      final repo = await open();
      await repo.createProfile('Anna');

      final bytes = await file.readAsBytes();
      bytes[bytes.length - 1] ^= 0xFF;
      await file.writeAsBytes(bytes);

      expect(() => EncryptedFileStore(file: file, keys: keys).read(),
          throwsA(isA<ArchiveDecryptionException>()));
    });

    test('each save uses a fresh nonce', () async {
      final store = EncryptedFileStore(file: file, keys: keys);
      await store.write({'a': 1});
      final first = await file.readAsBytes();
      await store.write({'a': 1});
      final second = await file.readAsBytes();
      expect(first, isNot(equals(second)));
    });
  });
}
