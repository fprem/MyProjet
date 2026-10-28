import 'dart:io';

import 'label_parser.dart';

export 'label_parser.dart';

/// Reads the lines of text in a photo.
abstract interface class LabelReader {
  Future<List<LabelLine>> read(String imagePath);
}

/// Turns a photo of a medicine box into a [LabelResult].
abstract interface class MedicineScanner {
  Future<LabelResult> scan(String imagePath);
}

/// Reads the photo, then deletes it, whether reading worked or not. Only the
/// text the person confirms is ever kept.
class PhotoScanner implements MedicineScanner {
  PhotoScanner({required this.reader, this.parser = const LabelParser()});

  final LabelReader reader;
  final LabelParser parser;

  @override
  Future<LabelResult> scan(String imagePath) async {
    try {
      return parser.parse(await reader.read(imagePath));
    } finally {
      final photo = File(imagePath);
      if (await photo.exists()) await photo.delete();
    }
  }
}
