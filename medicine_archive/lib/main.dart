import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/archive_repository.dart';
import 'data/encrypted_file_store.dart';
import 'data/key_provider.dart';
import 'data/photo_store.dart';
import 'scan/aifa_asset_catalog.dart';
import 'scan/photo_barcode_reader.dart';
import 'scan/mlkit_label_reader.dart';
import 'scan/photo_scanner.dart';
import 'ui/barcode_scan_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationSupportDirectory();
  final keys = SecureStorageKeyProvider();
  final store = EncryptedFileStore(file: File('${dir.path}/archive.enc'), keys: keys);
  final photos = EncryptedPhotoStore(directory: Directory('${dir.path}/photos'), keys: keys);

  final ArchiveRepository repository;
  try {
    repository = await ArchiveRepository.open(store, photos: photos);
  } on ArchiveDecryptionException catch (e) {
    runApp(_ErrorApp(message: "The archive couldn't be opened. ${e.message}."));
    return;
  }

  final picker = ImagePicker();
  runApp(
    MedicineArchiveApp(
      repository: repository,
      scanner: PhotoScanner(
        reader: MlKitLabelReader(),
        barcodes: PhotoBarcodeReader(),
        catalog: bundledAifaCatalog(),
      ),
      scanBarcode: scanBarcodeLive,
      takePhoto: () async {
        final photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2000,
          imageQuality: 85,
        );
        return photo?.path;
      },
    ),
  );
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
      ),
    ),
  );
}
