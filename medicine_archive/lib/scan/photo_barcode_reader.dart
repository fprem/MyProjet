import 'package:mobile_scanner/mobile_scanner.dart';

import 'photo_scanner.dart';

/// Formats used on Italian medicine boxes: Code 39 carries the bollino's
/// Code 32, Data Matrix the newer GS1 codes.
const medicineBarcodeFormats = [
  BarcodeFormat.code39,
  BarcodeFormat.dataMatrix,
  BarcodeFormat.code128,
];

/// Reads the barcodes in a photo with ML Kit, on the device.
class PhotoBarcodeReader implements BarcodeReader {
  final _controller = MobileScannerController(formats: medicineBarcodeFormats, autoStart: false);

  @override
  Future<List<String>> read(String imagePath) async {
    final capture = await _controller.analyzeImage(imagePath, formats: medicineBarcodeFormats);
    return [for (final b in capture?.barcodes ?? const <Barcode>[]) ?b.rawValue];
  }
}
