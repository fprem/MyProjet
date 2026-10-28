import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/scan/label_parser.dart';

// Keeps the preview honest: the Delorazepam sample in lib/demo is the real
// box's text, so it must read the same way the app does.
void main() {
  test('the real box, out of order, reads fully', () {
    final result = const LabelParser().parse(const [
      LabelLine('0,5', 100, top: 985),
      LabelLine('Delorazepam', 92, top: 810),
      LabelLine('mg', 52, top: 1090),
      LabelLine('ratiopharm Italia', 88, top: 940),
      LabelLine('0,5 mg compresse', 46, top: 1040),
      LabelLine('Medicinale equivalente', 28, top: 1165),
      LabelLine('Uso orale', 26, top: 1215),
      LabelLine('teva', 82, top: 1300),
      LabelLine('20 compresse', 30, top: 1295),
    ]);
    expect(result.name, 'Delorazepam ratiopharm Italia');
    expect(result.strength, '0,5 mg');
    expect(result.quantity, 20);
    expect(result.unit, 'compresse');
  });
}
