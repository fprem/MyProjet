import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/backup.dart';
import 'package:medicine_archive/data/photo_store.dart';
import 'package:medicine_archive/data/tags.dart';

import '../ui/fakes.dart';

void main() {
  // Few rounds keep the tests fast; the app uses many more.
  const codec = BackupCodec(iterations: 1000);

  Future<ArchiveRepository> filled() async {
    final repo = await ArchiveRepository.open(MemoryStore(), photos: MemoryPhotoStore());
    await repo.completeOnboarding();
    final anna = await repo.createProfile('Anna');
    await repo.addMedicine(
      anna.id,
      name: 'Metformina',
      strength: '500 mg',
      quantity: 60,
      unit: 'compresse',
      tags: [MedicineTags.morning, 'When needed'],
      photo: Uint8List.fromList([1, 2, 3]),
    );
    final old = await repo.addMedicine(anna.id, name: 'Augmentin');
    await repo.setArchived(old.id, true);
    await repo.createProfile('Bob');
    return repo;
  }

  group('BackupCodec', () {
    test('opens with the same password', () async {
      final sealed = await codec.seal({'a': 1}, 'secret pass');
      expect(await codec.open(sealed, 'secret pass'), {'a': 1});
    });

    test('a wrong password is refused', () async {
      final sealed = await codec.seal({'a': 1}, 'secret pass');
      expect(() => codec.open(sealed, 'other pass'), throwsA(isA<BackupException>()));
    });

    test('a file that is not a backup is refused', () async {
      expect(
        () => codec.open(Uint8List.fromList(utf8.encode('hello')), 'secret pass'),
        throwsA(isA<BackupException>()),
      );
    });

    test('a changed byte is refused', () async {
      final sealed = await codec.seal({'a': 1}, 'secret pass');
      sealed[sealed.length - 1] ^= 1;
      expect(() => codec.open(sealed, 'secret pass'), throwsA(isA<BackupException>()));
    });

    test('nothing readable is in the file', () async {
      final sealed = await codec.seal({'name': 'Metformina'}, 'secret pass');
      expect(latin1.decode(sealed, allowInvalid: true).contains('Metformina'), isFalse);
    });

    test('the same data and password give a different file each time', () async {
      final a = await codec.seal({'a': 1}, 'secret pass');
      final b = await codec.seal({'a': 1}, 'secret pass');
      expect(a, isNot(b));
    });
  });

  group('repository export and import', () {
    test(
      'everything comes back on another phone: profiles, medicines, tags, archive, photos',
      () async {
        final from = await filled();
        final file = await codec.seal(await from.exportData(), 'secret pass');

        final to = await ArchiveRepository.open(MemoryStore(), photos: MemoryPhotoStore());
        await to.importData(await codec.open(file, 'secret pass'));

        expect(to.profiles.map((p) => p.name), ['Anna', 'Bob']);
        final anna = to.profiles.first;
        final metformina = to.medicinesOf(anna.id).single;
        expect(metformina.name, 'Metformina');
        expect(metformina.strength, '500 mg');
        expect(metformina.quantityLabel, '60 compresse');
        expect(metformina.tags, [MedicineTags.morning, 'When needed']);
        expect(await to.photoOf(metformina), [1, 2, 3]);
        expect(to.medicinesOf(anna.id, archived: true).single.name, 'Augmentin');
        expect(to.needsOnboarding, isFalse);
      },
    );

    test('import replaces what was there, photos included', () async {
      final backup = await (await filled()).exportData();
      final photos = MemoryPhotoStore();
      final to = await ArchiveRepository.open(MemoryStore(), photos: photos);
      final carla = await to.createProfile('Carla');
      final m = await to.addMedicine(carla.id, name: 'Old', photo: Uint8List.fromList([9]));

      await to.importData(backup);

      expect(to.profiles.map((p) => p.name), ['Anna', 'Bob']);
      expect(await photos.read(m.id), isNull);
    });

    test('a backup that is not ours is refused and nothing changes', () async {
      final to = await ArchiveRepository.open(MemoryStore(), photos: MemoryPhotoStore());
      await to.createProfile('Carla');
      expect(() => to.importData({'something': 'else'}), throwsA(isA<BackupException>()));
      expect(to.profiles.single.name, 'Carla');
    });

    test('counts what a backup holds, to show before importing', () async {
      final summary = BackupSummary.of(await (await filled()).exportData());
      expect(summary.profiles, 2);
      expect(summary.medicines, 2);
    });
  });
}
