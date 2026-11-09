import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/encrypted_file_store.dart';
import 'package:medicine_archive/data/key_provider.dart';
import 'package:medicine_archive/data/tags.dart';

void main() {
  late Directory dir;
  late InMemoryKeyProvider keys;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tags_test');
    keys = InMemoryKeyProvider();
  });

  tearDown(() => dir.delete(recursive: true));

  Future<ArchiveRepository> open() =>
      ArchiveRepository.open(EncryptedFileStore(file: File('${dir.path}/a.enc'), keys: keys));

  group('Tags', () {
    test('the three fixed tags come in the order of the day', () {
      expect(MedicineTags.fixed, [MedicineTags.morning, MedicineTags.noon, MedicineTags.evening]);
      expect(MedicineTags.fixed.map(MedicineTags.label), ['Morning', 'Noon', 'Evening']);
    });

    test('a custom tag is shown exactly as typed', () {
      expect(MedicineTags.isFixed('When needed'), isFalse);
      expect(MedicineTags.label('When needed'), 'When needed');
    });

    test('a custom tag typed as "Morning" is not the fixed one', () {
      expect(MedicineTags.isFixed('Morning'), isFalse);
      expect(MedicineTags.isFixed(MedicineTags.morning), isTrue);
    });

    test('normalize trims, drops empty and repeated tags, and puts fixed ones first', () {
      expect(
        MedicineTags.normalize([' Holiday ', MedicineTags.evening, '', 'holiday', MedicineTags.morning, MedicineTags.evening]),
        [MedicineTags.morning, MedicineTags.evening, 'Holiday'],
      );
    });
  });

  group('groupByTag', () {
    Medicine med(String name, List<String> tags) =>
        Medicine(id: name, profileId: 'p', name: name, tags: tags);

    test('groups by fixed tags, then custom A–Z, then untagged; empty groups are left out', () {
      final groups = groupByTag([
        med('Aspirina', []),
        med('Dibase', ['Sunday only']),
        med('Eutirox', [MedicineTags.morning]),
        med('Delorazepam', [MedicineTags.evening]),
        med('Tachipirina', ['When needed']),
        med('Brufen', ['after meals']),
      ]);
      expect(groups.map((g) => g.tag), [
        MedicineTags.morning,
        MedicineTags.evening,
        'after meals',
        'Sunday only',
        'When needed',
        null,
      ]);
      expect(groups.last.medicines.single.name, 'Aspirina');
    });

    test('a medicine with two tags is in both groups', () {
      final groups = groupByTag([
        med('Metformina', [MedicineTags.morning, MedicineTags.evening]),
      ]);
      expect(groups.map((g) => g.tag), [MedicineTags.morning, MedicineTags.evening]);
      expect(groups.every((g) => g.medicines.single.name == 'Metformina'), isTrue);
    });

    test('keeps the order of the medicines inside a group', () {
      final groups = groupByTag([med('B', [MedicineTags.noon]), med('A', [MedicineTags.noon])]);
      expect(groups.single.medicines.map((m) => m.name), ['B', 'A']);
    });
  });

  group('repository', () {
    test('a medicine is saved with its tags, encrypted, and they survive reopening', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      await repo.addMedicine(anna.id, name: 'Metformina', tags: [MedicineTags.evening, MedicineTags.morning]);

      final reopened = await open();
      expect(reopened.medicinesOf(anna.id).single.tags, [MedicineTags.morning, MedicineTags.evening]);
      final raw = await File('${dir.path}/a.enc').readAsBytes();
      expect(String.fromCharCodes(raw).contains('morning'), isFalse);
    });

    test('older archives open with no tags', () {
      expect(Medicine.fromJson({'id': 'x', 'profileId': 'p', 'name': 'Old'}).tags, isEmpty);
    });

    test('editing a medicine can change its tags', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final m = await repo.addMedicine(anna.id, name: 'Eutirox', tags: [MedicineTags.morning]);
      await repo.updateMedicine(m.copyWith(tags: [MedicineTags.noon, 'Holiday']));
      expect(repo.medicinesOf(anna.id).single.tags, [MedicineTags.noon, 'Holiday']);
    });

    test('setTags replaces the tags', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final m = await repo.addMedicine(anna.id, name: 'Eutirox', tags: [MedicineTags.morning]);
      await repo.setTags(m.id, ['When needed']);
      expect(repo.medicinesOf(anna.id).single.tags, ['When needed']);
    });

    test('moving swaps the tag of the old group for the new one and keeps the others', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final m = await repo.addMedicine(
        anna.id,
        name: 'Metformina',
        tags: [MedicineTags.morning, MedicineTags.evening, 'Holiday'],
      );

      final before = await repo.moveToTag(m.id, from: MedicineTags.morning, to: MedicineTags.noon);

      expect(before, [MedicineTags.morning, MedicineTags.evening, 'Holiday']);
      expect(repo.medicinesOf(anna.id).single.tags, [MedicineTags.noon, MedicineTags.evening, 'Holiday']);
    });

    test('moving to a group it is already in just leaves the old one', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final m = await repo.addMedicine(anna.id, name: 'Metformina', tags: [MedicineTags.morning, MedicineTags.evening]);
      await repo.moveToTag(m.id, from: MedicineTags.morning, to: MedicineTags.evening);
      expect(repo.medicinesOf(anna.id).single.tags, [MedicineTags.evening]);
    });

    test('moving to "No tag" removes only the tag it came from', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final m = await repo.addMedicine(anna.id, name: 'Metformina', tags: [MedicineTags.morning, MedicineTags.evening]);
      await repo.moveToTag(m.id, from: MedicineTags.morning, to: null);
      expect(repo.medicinesOf(anna.id).single.tags, [MedicineTags.evening]);
    });

    test('moving out of "No tag" adds the new tag', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final m = await repo.addMedicine(anna.id, name: 'Aspirina');
      await repo.moveToTag(m.id, from: null, to: 'When needed');
      expect(repo.medicinesOf(anna.id).single.tags, ['When needed']);
    });

    test('the custom tags of a profile, A–Z, including archived medicines', () async {
      final repo = await open();
      final anna = await repo.createProfile('Anna');
      final bob = await repo.createProfile('Bob');
      await repo.addMedicine(anna.id, name: 'A', tags: [MedicineTags.morning, 'When needed']);
      final b = await repo.addMedicine(anna.id, name: 'B', tags: ['holiday']);
      await repo.setArchived(b.id, true);
      await repo.addMedicine(anna.id, name: 'C', tags: ['When needed']);
      await repo.addMedicine(bob.id, name: 'D', tags: ['Bob only']);

      expect(repo.customTagsOf(anna.id), ['holiday', 'When needed']);
    });
  });
}
