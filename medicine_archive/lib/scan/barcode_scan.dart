import 'package:flutter/widgets.dart';

/// What the live barcode scanner ended with.
sealed class BarcodeScan {
  const BarcodeScan();
}

/// An AIC code was read from the box's barcode.
final class BarcodeRead extends BarcodeScan {
  const BarcodeRead(this.aic);
  final String aic;
}

/// The person chose to photograph the box instead.
final class UsePhotoInstead extends BarcodeScan {
  const UsePhotoInstead();
}

/// Opens the live barcode scanner. Null means the person closed it.
typedef ScanBarcode = Future<BarcodeScan?> Function(BuildContext context);
