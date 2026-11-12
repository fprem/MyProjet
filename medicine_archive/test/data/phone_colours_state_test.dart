import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/data/archive_repository.dart';

import '../ui/fakes.dart';

void main() {
  test('phone colours are off in a new archive', () async {
    final repo = await ArchiveRepository.open(MemoryStore());
    expect(repo.phoneColours, isFalse);
  });

  test('archives from before 1.4.0 keep the brand colours', () async {
    final store = MemoryStore()..data = {'profiles': [], 'medicines': [], 'onboarded': true};
    expect((await ArchiveRepository.open(store)).phoneColours, isFalse);
  });

  test('the choice is saved and survives reopening', () async {
    final store = MemoryStore();
    final repo = await ArchiveRepository.open(store);
    var notified = 0;
    repo.addListener(() => notified++);
    await repo.setPhoneColours(true);
    expect(repo.phoneColours, isTrue);
    expect(notified, 1);
    expect((await ArchiveRepository.open(store)).phoneColours, isTrue);

    await repo.setPhoneColours(false);
    expect((await ArchiveRepository.open(store)).phoneColours, isFalse);
  });

  test('restoring a backup keeps this phone\'s colour choice', () async {
    final other = await ArchiveRepository.open(MemoryStore());
    await other.createProfile('Anna');
    final backup = await other.exportData();
    final repo = await ArchiveRepository.open(MemoryStore());
    await repo.setPhoneColours(true);
    await repo.importData(backup);
    expect(repo.profiles.single.name, 'Anna');
    expect(repo.phoneColours, isTrue);
  });
}
