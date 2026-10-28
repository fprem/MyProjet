/// One line of text read from a photo, with its height in pixels. Taller
/// text is usually the brand name.
class LabelLine {
  const LabelLine(this.text, this.height);
  final String text;
  final double height;
}

/// What could be read off a medicine box. Any part may be missing.
class LabelResult {
  const LabelResult({required this.name, this.quantity, this.unit = ''});
  const LabelResult.empty() : this(name: '');

  final String name;
  final int? quantity;
  final String unit;

  bool get isEmpty => name.isEmpty && quantity == null;
}

/// Guesses a medicine's name and pack size from the text on its box.
///
/// The guess is always shown to the person to check before it is saved.
class LabelParser {
  const LabelParser();

  // Pack-size units seen on Italian and English boxes.
  static const _units =
      r'compresse|compressa|cpr|cps|capsule|capsula|capsules?|caps|tablets?|tabs?|'
      r'pills?|bustine|bustina|sachets?|supposte|supposta|fiale|fiala|ampoules?|'
      r'cerotti|patches|confetti|pastiglie|gocce|ml';

  static final _numberThenUnit =
      RegExp('(\\d+)\\s*($_units)\\b', caseSensitive: false);
  static final _unitThenNumber =
      RegExp('\\b($_units)\\.?\\s*x\\s*(\\d+)\\b', caseSensitive: false);
  static final _xThenNumber = RegExp(r'\bx\s*(\d+)\b', caseSensitive: false);
  static final _dosage = RegExp(
      r'^\d+(?:[.,]\d+)?\s*(?:mg|g|mcg|µg|ug|ui|iu|%|mg/ml)(?:\s*/\s*\d+\s*(?:mg|ml))?$',
      caseSensitive: false);
  static final _letters = RegExp(r'[A-Za-zÀ-ÿ]');

  LabelResult parse(List<LabelLine> lines) {
    final cleaned = [
      for (final l in lines)
        if (l.text.trim().isNotEmpty) LabelLine(l.text.trim(), l.height),
    ];

    int? quantity;
    var unit = '';
    for (final line in cleaned) {
      final found = _quantityIn(line.text);
      if (found != null) {
        (quantity, unit) = found;
        break;
      }
    }

    final dosage = cleaned.where((l) => _dosage.hasMatch(l.text)).firstOrNull;
    final candidates = cleaned
        .where((l) =>
            _letters.allMatches(l.text).length >= 2 &&
            !_dosage.hasMatch(l.text) &&
            _quantityIn(l.text) == null)
        .toList()
      ..sort((a, b) => b.height.compareTo(a.height));

    var name = candidates.isEmpty ? '' : _tidy(candidates.first.text);
    if (name.isNotEmpty && dosage != null) name = '$name ${dosage.text.toLowerCase()}';

    return LabelResult(name: name, quantity: quantity, unit: unit);
  }

  (int, String)? _quantityIn(String text) {
    final a = _numberThenUnit.firstMatch(text);
    if (a != null) return (int.parse(a.group(1)!), a.group(2)!.toLowerCase());
    final b = _unitThenNumber.firstMatch(text);
    if (b != null) return (int.parse(b.group(2)!), b.group(1)!.toLowerCase());
    final c = _xThenNumber.firstMatch(text);
    if (c != null) return (int.parse(c.group(1)!), '');
    return null;
  }

  /// Boxes often print the brand in capitals; "TACHIPIRINA" reads better as
  /// "Tachipirina". Mixed-case names are left as printed.
  static String _tidy(String text) {
    if (text != text.toUpperCase()) return text;
    return text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
