import 'dart:convert';
import 'dart:typed_data';

import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/archive_store.dart';
import 'package:medicine_archive/scan/photo_scanner.dart';

class MemoryStore implements ArchiveStore {
  Map<String, dynamic>? data;

  @override
  Future<Map<String, dynamic>?> read() async => data;

  @override
  Future<void> write(Map<String, dynamic> json) async => data = json;
}

Future<ArchiveRepository> memoryRepository() => ArchiveRepository.open(MemoryStore());

class FakeScanner implements MedicineScanner {
  FakeScanner(this.result, {this.fail = false, this.photo, this.fromCatalog = false});
  final LabelResult result;
  final bool fail;
  final Uint8List? photo;
  final bool fromCatalog;
  final scanned = <String>[];

  @override
  Future<ScanResult> scan(String imagePath) async {
    scanned.add(imagePath);
    if (fail) throw Exception('ocr failed');
    return ScanResult(result, photo: photo, fromCatalog: fromCatalog);
  }
}

/// A valid 1×1 PNG, so Image.memory can decode it in tests.
final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);
