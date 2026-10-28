import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/data/archive_store.dart';
import 'package:medicine_archive/scan/label_parser.dart';
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
  FakeScanner(this.result, {this.fail = false});
  final LabelResult result;
  final bool fail;
  final scanned = <String>[];

  @override
  Future<LabelResult> scan(String imagePath) async {
    scanned.add(imagePath);
    if (fail) throw Exception('ocr failed');
    return result;
  }
}
