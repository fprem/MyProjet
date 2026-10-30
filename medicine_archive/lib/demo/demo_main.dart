// A browser preview of the app, for trying the screens without a phone.
//
// The camera, ML Kit and the encrypted file are Android-only, so here they
// are stood in for: "taking a photo" picks the next sample box below, its
// text goes through the real LabelParser, its barcode through the real AIC
// decoder, a drawing stands in for the photo, and everything lives in memory.
//
//   flutter build web -t lib/demo/demo_main.dart

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/archive_repository.dart';
import '../data/archive_store.dart';
import '../scan/aic_code.dart';
import '../scan/barcode_scan.dart';
import '../scan/medicine_catalog.dart';
import '../scan/photo_scanner.dart';
import '../ui/barcode_help.dart';

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

/// The barcode on each sample box, when it is readable. Tachipirina's is its
/// real AIC, 012745093, as Code 32.
const _sampleBarcodes = <String?>[null, '0D4YD5', null, null];

/// One line of AIFA's list, so the Tachipirina sample is found by barcode.
final _catalog = AifaCatalog.fromTsv('012745093\tTachipirina\t500 mg\t20\tcompresse\n');

class _SampleScanner implements MedicineScanner {
  final _parser = const LabelParser();

  @override
  Future<ScanResult> lookup(String aic) async {
    final known = await _catalog.lookup(aic);
    return ScanResult(known ?? const LabelResult.empty(), aic: aic, fromCatalog: known != null);
  }

  @override
  Future<Uint8List?> readPhoto(String imagePath) => _drawBox(_sampleBoxes[int.parse(imagePath)]);

  @override
  Future<ScanResult> scan(String imagePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final i = int.parse(imagePath);
    final aic = switch (_sampleBarcodes[i]) {
      final code? => AicCode.fromBarcode(code),
      null => null,
    };
    final known = aic == null ? null : await _catalog.lookup(aic);
    return ScanResult(
      known ?? _parser.parse(_sampleBoxes[i]),
      aic: aic,
      fromCatalog: known != null,
      photo: await _drawBox(_sampleBoxes[i]),
    );
  }
}

/// A drawing of the box stands in for the photo: its lines of text, top to
/// bottom, the taller ones larger.
Future<Uint8List> _drawBox(List<LabelLine> lines) async {
  const width = 600.0, height = 400.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFF8A6A4F),
  );
  final box = RRect.fromRectAndRadius(
    const Rect.fromLTWH(40, 40, width - 80, height - 80),
    const Radius.circular(10),
  );
  canvas.drawRRect(box, Paint()..color = const Color(0xFFFDFDFB));
  canvas.drawRect(
    const Rect.fromLTWH(40, 40, 70, height - 80),
    Paint()..color = const Color(0xFF8FE3CF),
  );

  final ordered = [...lines]..sort((a, b) => (a.top ?? 0).compareTo(b.top ?? 0));
  final tallest = lines.map((l) => l.height).reduce(max);
  var y = 64.0;
  for (final line in ordered) {
    final painter = TextPainter(
      text: TextSpan(
        text: line.text,
        style: TextStyle(
          color: const Color(0xFF14211F),
          fontFamily: 'Figtree',
          fontSize: 13 + 17 * line.height / tallest,
          fontWeight: line.height > tallest * 0.6 ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 180);
    if (y + painter.height > height - 50) break;
    painter.paint(canvas, Offset(130, y));
    y += painter.height + 2;
  }
  final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
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
  // Long names shrink to fit, or wrap between words.
  await repository.addMedicine(anna.id, name: 'Delorazepam Ratiopharm', strength: '1 mg');
  await repository.addMedicine(
    anna.id,
    name: 'Amoxicillina e Acido Clavulanico Sandoz',
    strength: '875 mg + 125 mg',
    quantity: 12,
    unit: 'compresse',
  );
  // A finished antibiotic course, so the Archived tab has something in it.
  final augmentin = await repository.addMedicine(
    anna.id,
    name: 'Augmentin',
    strength: '875 mg',
    quantity: 12,
    unit: 'compresse',
  );
  await repository.setArchived(augmentin.id, true);

  var next = 0;
  runApp(
    MedicineArchiveApp(
      repository: repository,
      scanner: _SampleScanner(),
      scanBarcode: _sampleBarcodeScan,
      takePhoto: () async => '${next++ % _sampleBoxes.length}',
    ),
  );
}

/// Stands in for the live camera: one tap reads Tachipirina's barcode.
Future<BarcodeScan?> _sampleBarcodeScan(BuildContext context) => Navigator.push<BarcodeScan>(
  context,
  MaterialPageRoute(
    builder: (context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan the barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: const [BarcodeHelpButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            const Text(
              'Here the phone shows the live camera. In this preview, pick what it sees:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, BarcodeRead(AicCode.fromBarcode('0D4YD5')!)),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Tachipirina barcode'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context, const UsePhotoInstead()),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('No barcode? Take a photo'),
            ),
          ],
        ),
      ),
    ),
  ),
);
