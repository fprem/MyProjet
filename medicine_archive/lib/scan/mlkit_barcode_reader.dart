import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import 'photo_scanner.dart';

/// Reads barcodes with Google ML Kit, on the device. Nothing is sent online.
///
/// Code 39 covers the bollino's Code 32; Data Matrix covers the newer GS1
/// codes on Italian packs.
class MlKitBarcodeReader implements BarcodeReader {
  final _scanner = BarcodeScanner(
    formats: const [BarcodeFormat.code39, BarcodeFormat.dataMatrix, BarcodeFormat.code128],
  );

  @override
  Future<List<String>> read(String imagePath) async {
    final codes = await _scanner.processImage(InputImage.fromFilePath(imagePath));
    return [for (final c in codes) ?c.rawValue];
  }

  Future<void> close() => _scanner.close();
}
