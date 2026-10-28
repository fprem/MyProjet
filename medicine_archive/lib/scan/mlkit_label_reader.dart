import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'photo_scanner.dart';

/// Reads text with Google ML Kit, on the device. Nothing is sent online.
class MlKitLabelReader implements LabelReader {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<List<LabelLine>> read(String imagePath) async {
    final text = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    return [
      for (final block in text.blocks)
        for (final line in block.lines) LabelLine(line.text, line.boundingBox.height),
    ];
  }

  Future<void> close() => _recognizer.close();
}
