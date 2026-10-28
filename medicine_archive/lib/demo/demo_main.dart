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

/// Text as the phone's text reader returns it for a few boxes. The first one
/// is a real box (test/fixtures/delorazepam_box.jpg): lines out of order, the
/// strength also printed on a round badge, and a taller logo at the bottom.
const _sampleBoxes = <List<LabelLine>>[
  [
    LabelLine('0,5', 100, top: 985),
    LabelLine('Delorazepam', 92, top: 810),
    LabelLine('mg', 52, top: 1090),
    LabelLine('ratiopharm Italia', 88, top: 940),
    LabelLine('0,5 mg compresse', 46, top: 1040),
    LabelLine('Medicinale equivalente', 28, top: 1165),
    LabelLine('Uso orale', 26, top: 1215),
    LabelLine('teva', 82, top: 1300),
    LabelLine('20 compresse', 30, top: 1295),
  ],
  [
    LabelLine('Medicinale da banco', 10, top: 100),
    LabelLine('TACHIPIRINA', 40, top: 140),
    LabelLine('500 mg', 20, top: 200),
    LabelLine('20 compresse', 14, top: 240),
  ],
  [
    LabelLine('Moment', 36, top: 100),
    LabelLine('200 mg', 18, top: 160),
    LabelLine('12 compresse rivestite', 12, top: 200),
  ],
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
  await repository.addMedicine(
    anna.id,
    name: 'Aspirina',
    strength: '500 mg',
    quantity: 10,
    unit: 'compresse',
  );

  var next = 0;
  runApp(
    MedicineArchiveApp(
      repository: repository,
      scanner: _SampleReader(),
      takePhoto: () async => '${next++ % _sampleBoxes.length}',
    ),
  );
}
