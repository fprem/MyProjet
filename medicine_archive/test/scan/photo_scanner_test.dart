import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/scan/photo_scanner.dart';

class FakeReader implements LabelReader {
  FakeReader(this.lines, {this.fail = false});
  final List<LabelLine> lines;
  final bool fail;
  String? readPath;

  @override
  Future<List<LabelLine>> read(String imagePath) async {
    readPath = imagePath;
    if (fail) throw Exception('ocr failed');
    return lines;
  }
}

void main() {
  late Directory dir;
  late File photo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('scan_test');
    photo = File('${dir.path}/photo.jpg');
    await photo.writeAsBytes([1, 2, 3]);
  });

  tearDown(() => dir.delete(recursive: true));

  test('reads the photo and returns the parsed label', () async {
    final reader = FakeReader([LabelLine('Moment', 30), LabelLine('12 compresse', 10)]);
    final scanner = PhotoScanner(reader: reader);
    final result = await scanner.scan(photo.path);
    expect(reader.readPath, photo.path);
    expect(result.name, 'Moment');
    expect(result.quantity, 12);
  });

  test('deletes the photo after reading it', () async {
    final scanner = PhotoScanner(reader: FakeReader([LabelLine('Moment', 30)]));
    await scanner.scan(photo.path);
    expect(photo.existsSync(), isFalse);
  });

  test('deletes the photo even when reading fails', () async {
    final scanner = PhotoScanner(reader: FakeReader(const [], fail: true));
    await expectLater(scanner.scan(photo.path), throwsException);
    expect(photo.existsSync(), isFalse);
  });
}
