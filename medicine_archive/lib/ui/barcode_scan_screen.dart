import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../scan/aic_code.dart';
import '../scan/barcode_scan.dart';
import '../scan/photo_barcode_reader.dart';
import 'barcode_help.dart';

/// Opens [BarcodeScanScreen] and returns how it ended.
Future<BarcodeScan?> scanBarcodeLive(BuildContext context) => Navigator.push<BarcodeScan>(
  context,
  MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
);

/// The live camera, looking for the AIC barcode on the box. Pops with
/// [BarcodeRead] as soon as one is read, or [UsePhotoInstead].
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController(formats: medicineBarcodeFormats);
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final aic = AicCode.fromBarcode(barcode.rawValue ?? '');
      if (aic != null) {
        _done = true;
        Navigator.pop(context, BarcodeRead(aic));
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan the barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: const [BarcodeHelpButton()],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 300,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primaryContainer, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  Text(
                    'Point the camera at the barcode on the box (the AIC code on the bollino).',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
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
        ],
      ),
    );
  }
}
