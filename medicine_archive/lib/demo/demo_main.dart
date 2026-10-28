// A browser preview of the app, for trying the screens without a phone.
//
// The camera, ML Kit and the encrypted file are Android-only, so here they
// are stood in for: "taking a photo" picks the next sample box below, its
// text goes through the real LabelParser, and the archive lives in memory.
//
//   flutter build web -t lib/demo/demo_main.dart

import 'package:flutter/material.dart';

import '../app.dart';
import '../data/archive_repository.dart';
import '../data/archive_store.dart';
import '../scan/photo_scanner.dart';

class _MemoryStore implements ArchiveStore {
  Map<String, dynamic>? _data;

  @override
  Future<Map<String, dynamic>?> read() async => _data;

  @override
  Future<void> write(Map<String, dynamic> json) async => _data = json;
}

/// Text as ML Kit would read it off a few real-looking boxes.
const _sampleBoxes = <List<LabelLine>>[
  [
    LabelLine('Medicinale da banco', 10),
    LabelLine('TACHIPIRINA', 40),
    LabelLine('500 mg', 20),
    LabelLine('20 compresse', 14),
  ],
  [LabelLine('Moment', 36), LabelLine('200 mg', 18), LabelLine('12 compresse rivestite', 12)],
  [LabelLine('Bentelan', 32), LabelLine('0,5 mg', 16), LabelLine('10 compresse effervescenti', 12)],
  [LabelLine('xx??', 8)], // a blurry photo: nothing readable
];

class _SampleReader implements MedicineScanner {
  final _parser = const LabelParser();

  @override
  Future<LabelResult> scan(String imagePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return _parser.parse(_sampleBoxes[int.parse(imagePath)]);
  }
}

Future<void> main() async {
  final repository = await ArchiveRepository.open(_MemoryStore());
  final anna = await repository.createProfile('Anna');
  await repository.addMedicine(anna.id, name: 'Aspirina 500 mg', quantity: 10, unit: 'compresse');

  var next = 0;
  runApp(
    MedicineArchiveApp(
      repository: repository,
      scanner: _SampleReader(),
      takePhoto: () async => '${next++ % _sampleBoxes.length}',
    ),
  );
}
