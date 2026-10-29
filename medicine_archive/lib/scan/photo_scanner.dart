import 'dart:io';
import 'dart:typed_data';

import 'aic_code.dart';
import 'label_parser.dart';
import 'medicine_catalog.dart';

export 'label_parser.dart';

/// Reads the lines of text in a photo.
abstract interface class LabelReader {
  Future<List<LabelLine>> read(String imagePath);
}

/// Reads the raw values of the barcodes in a photo.
abstract interface class BarcodeReader {
  Future<List<String>> read(String imagePath);
}

/// What a scan found, for the person to check.
class ScanResult {
  const ScanResult(this.label, {this.aic, this.fromCatalog = false, this.photo});

  final LabelResult label;

  /// The pack's AIC code, when one was read.
  final String? aic;

  /// True when [label] comes from AIFA's list rather than from reading the text.
  final bool fromCatalog;

  /// The photo, held in memory only. It is saved (encrypted) only if the
  /// person chooses to keep it.
  final Uint8List? photo;
}

/// Turns a photo of a medicine box into a [ScanResult].
abstract interface class MedicineScanner {
  Future<ScanResult> scan(String imagePath);
}

class _NoBarcodes implements BarcodeReader {
  const _NoBarcodes();
  @override
  Future<List<String>> read(String imagePath) async => const [];
}

class _NoCatalog implements MedicineCatalog {
  const _NoCatalog();
  @override
  Future<LabelResult?> lookup(String aic) async => null;
}

/// Looks for the AIC barcode first and, when AIFA's list knows the code,
/// takes the name, strength and pack size from there. Otherwise it reads the
/// text on the box. The photo file is always deleted, whether reading worked
/// or not.
class PhotoScanner implements MedicineScanner {
  PhotoScanner({
    required this.reader,
    this.barcodes = const _NoBarcodes(),
    this.catalog = const _NoCatalog(),
    this.parser = const LabelParser(),
  });

  final LabelReader reader;
  final BarcodeReader barcodes;
  final MedicineCatalog catalog;
  final LabelParser parser;

  @override
  Future<ScanResult> scan(String imagePath) async {
    final file = File(imagePath);
    try {
      final photo = await file.readAsBytes();

      String? aic;
      try {
        for (final raw in await barcodes.read(imagePath)) {
          aic = AicCode.fromBarcode(raw);
          if (aic != null) break;
        }
      } catch (_) {
        // An unreadable barcode is not an error: the text is still there.
      }

      List<LabelLine> lines;
      Object? readError;
      try {
        lines = await reader.read(imagePath);
      } catch (e) {
        lines = const [];
        readError = e;
      }
      aic ??= AicCode.fromText(lines.map((l) => l.text).join('\n'));

      final known = aic == null ? null : await catalog.lookup(aic);
      if (known == null) {
        if (readError != null) throw readError;
        return ScanResult(parser.parse(lines), aic: aic, photo: photo);
      }
      final read = lines.isEmpty ? const LabelResult.empty() : parser.parse(lines);
      final hasSize = known.quantity != null;
      return ScanResult(
        LabelResult(
          name: known.name.isNotEmpty ? known.name : read.name,
          strength: known.strength.isNotEmpty ? known.strength : read.strength,
          quantity: hasSize ? known.quantity : read.quantity,
          unit: hasSize ? known.unit : read.unit,
        ),
        aic: aic,
        fromCatalog: true,
        photo: photo,
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}
