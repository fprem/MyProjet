import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/data/archive_repository.dart';

import '../ui/fakes.dart';

void main() {
  test('a brand new archive wants the welcome screens', () async {
    final repo = await ArchiveRepository.open(MemoryStore());
    expect(repo.needsOnboarding, isTrue);
  });

  test('once completed, they are not shown again, even after reopening', () async {
    final store = MemoryStore();
    final repo = await ArchiveRepository.open(store);
    await repo.completeOnboarding();
    expect(repo.needsOnboarding, isFalse);
    expect((await ArchiveRepository.open(store)).needsOnboarding, isFalse);
  });

  test('people who already use the app do not see them', () async {
    final store = MemoryStore()
      ..data = {
        'profiles': [
          {'id': 'p1', 'name': 'Anna'},
        ],
        'medicines': [],
      };
    expect((await ArchiveRepository.open(store)).needsOnboarding, isFalse);
  });
}
