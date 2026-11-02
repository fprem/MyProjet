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

/// A repository past the welcome screens, as most tests want.
Future<ArchiveRepository> memoryRepository({bool onboarded = true}) async {
  final repo = await ArchiveRepository.open(MemoryStore());
  if (onboarded) await repo.completeOnboarding();
  return repo;
}

class FakeScanner implements MedicineScanner {
  FakeScanner(
    this.result, {
    this.fail = false,
    this.photo,
    this.fromCatalog = false,
    this.aic,
    this.catalog = const {},
  });
  final LabelResult result;
  final bool fail;
  final Uint8List? photo;
  final bool fromCatalog;
  final String? aic;

  /// What [lookup] finds, by AIC.
  final Map<String, LabelResult> catalog;
  final scanned = <String>[];
  final photosRead = <String>[];

  @override
  Future<ScanResult> scan(String imagePath) async {
    scanned.add(imagePath);
    if (fail) throw Exception('ocr failed');
    return ScanResult(result, photo: photo, fromCatalog: fromCatalog, aic: aic);
  }

  @override
  Future<ScanResult> lookup(String aic) async {
    final known = catalog[aic];
    return ScanResult(known ?? const LabelResult.empty(), aic: aic, fromCatalog: known != null);
  }

  @override
  Future<Uint8List?> readPhoto(String imagePath) async {
    photosRead.add(imagePath);
    return photo;
  }
}

/// A valid 1×1 PNG, so Image.memory can decode it in tests.
final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);
