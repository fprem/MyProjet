import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/encrypted_file_store.dart';
import 'package:medicine_archive/data/key_provider.dart';
import 'package:medicine_archive/data/photo_store.dart';

void main() {
  late Directory dir;
  late InMemoryKeyProvider keys;
  final photo = Uint8List.fromList(List.generate(64, (i) => i * 3 % 256));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('photo_test');
    keys = InMemoryKeyProvider();
  });

  tearDown(() => dir.delete(recursive: true));

  EncryptedPhotoStore photos([KeyProvider? k]) =>
      EncryptedPhotoStore(directory: Directory('${dir.path}/photos'), keys: k ?? keys);

  Future<ArchiveRepository> open() => ArchiveRepository.open(
    EncryptedFileStore(file: File('${dir.path}/archive.enc'), keys: keys),
    photos: photos(),
  );

  List<File> photoFiles() {
    final d = Directory('${dir.path}/photos');
    return d.existsSync() ? d.listSync().whereType<File>().toList() : [];
  }

  group('encrypted photo store', () {
    test('gives back what was written', () async {
      await photos().write('m1', photo);
      expect(await photos().read('m1'), photo);
    });

    test('the file on disk is not the photo', () async {
      await photos().write('m1', photo);
      final files = photoFiles();
      expect(files, hasLength(1));
      final onDisk = await files.single.readAsBytes();
      expect(onDisk, isNot(equals(photo)));
      for (var i = 0; i + 8 <= photo.length; i += 8) {
        final chunk = photo.sublist(i, i + 8);
        expect(_contains(onDisk, chunk), isFalse, reason: 'plain bytes at $i leaked');
      }
    });

    test('a different key cannot read it', () async {
      await photos().write('m1', photo);
      expect(
        () => photos(InMemoryKeyProvider()).read('m1'),
        throwsA(isA<ArchiveDecryptionException>()),
      );
    });

    test('reading a missing photo gives null, deleting it twice is fine', () async {
      expect(await photos().read('nope'), isNull);
      await photos().write('m1', photo);
      await photos().delete('m1');
      await photos().delete('m1');
      expect(await photos().read('m1'), isNull);
      expect(photoFiles(), isEmpty);
    });

    test('ids cannot reach outside the photo folder', () async {
      expect(() => photos().write('../archive', photo), throwsArgumentError);
    });
  });

  group('photos kept with a medicine', () {
    test('a medicine is saved without a photo unless one is given', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final med = await repo.addMedicine(anna.id, name: 'Moment');
      expect(med.hasPhoto, isFalse);
      expect(await repo.photoOf(med), isNull);
      expect(photoFiles(), isEmpty);
    });

    test('a kept photo is stored encrypted and survives reopening', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final med = await repo.addMedicine(anna.id, name: 'Moment', photo: photo);
      expect(med.hasPhoto, isTrue);

      final reopened = await open();
      final again = reopened.medicinesOf(anna.id).single;
      expect(again.hasPhoto, isTrue);
      expect(await reopened.photoOf(again), photo);
    });

    test('the photo can be removed and the medicine kept', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final med = await repo.addMedicine(anna.id, name: 'Moment', photo: photo);
      await repo.removePhoto(med.id);
      final after = repo.medicinesOf(anna.id).single;
      expect(after.hasPhoto, isFalse);
      expect(await repo.photoOf(after), isNull);
      expect(photoFiles(), isEmpty);
    });

    test('deleting the medicine deletes its photo', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final med = await repo.addMedicine(anna.id, name: 'Moment', photo: photo);
      await repo.deleteMedicine(med.id);
      expect(photoFiles(), isEmpty);
    });

    test('deleting the profile deletes the photos of its medicines', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final bea = await repo.createProfile('Bea');
      await repo.addMedicine(anna.id, name: 'Moment', photo: photo);
      await repo.addMedicine(anna.id, name: 'Aspirina', photo: photo);
      final keep = await repo.addMedicine(bea.id, name: 'Brufen', photo: photo);
      await repo.deleteProfile(anna.id);
      expect(photoFiles(), hasLength(1));
      expect(await repo.photoOf(keep), photo);
    });

    test('editing a medicine keeps its photo', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final med = await repo.addMedicine(anna.id, name: 'Moment', photo: photo);
      await repo.updateMedicine(med.copyWith(name: 'Moment Act'));
      final after = repo.medicinesOf(anna.id).single;
      expect(after.hasPhoto, isTrue);
      expect(await repo.photoOf(after), photo);
    });
  });
}

bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
