/// One line of text read from a photo. [height] is the height of the text in
/// pixels (taller text is usually the brand name). [top] is how far down the
/// photo the line sits, when known.
class LabelLine {
  const LabelLine(this.text, this.height, {this.top});
  final String text;
  final double height;
  final double? top;

  double? get bottom => top == null ? null : top! + height;
}

/// What could be read off a medicine box. Any part may be missing.
class LabelResult {
  const LabelResult({required this.name, this.strength = '', this.quantity, this.unit = ''});
  const LabelResult.empty() : this(name: '');

  final String name;

  /// How much of the drug is in each dose, as printed: "0,5 mg", "500 mg/5 ml".
  /// The same medicine often comes in several strengths, so this matters.
  final String strength;

  /// How many are in the pack, with what they are counted in.
  final int? quantity;
  final String unit;

  bool get isEmpty => name.isEmpty && strength.isEmpty && quantity == null;
}

/// Guesses a medicine's name, strength and pack size from the text on its box.
///
/// The guess is always shown to the person to check before it is saved.
class LabelParser {
  const LabelParser();

  // Pack-size units seen on Italian and English boxes.
  static const _units =
      r'compresse|compressa|cpr|cps|capsule|capsula|capsules?|caps|tablets?|tabs?|'
      r'pills?|bustine|bustina|sachets?|supposte|supposta|fiale|fiala|ampoules?|'
      r'cerotti|patches|confetti|pastiglie|gocce|ml';

  // How much drug is in a dose: 0,5 mg · 2.5mg · 500 mcg · 1 g · 1000 UI · 2 %
  // · 5 mg/ml · 500 mg/5 ml. A volume on its own ("100 ml") is a pack size.
  static const _amount = r'\d+(?:[.,]\d+)?';
  static const _strengthUnit = r'(?:mg|mcg|µg|μg|ug|g|ui|iu|%)';
  static final _strength = RegExp(
    '(?<![\\w.,])($_amount)\\s*($_strengthUnit)(?:\\s*/\\s*(\\d*(?:[.,]\\d+)?)\\s*(ml|g|l|dose))?(?![\\w])',
    caseSensitive: false,
  );
  static final _bareNumber = RegExp('^$_amount\$');
  static final _bareUnit = RegExp('^$_strengthUnit\$', caseSensitive: false);

  static final _numberThenUnit = RegExp('(\\d+)\\s*($_units)\\b', caseSensitive: false);
  static final _unitThenNumber = RegExp('\\b($_units)\\.?\\s*x\\s*(\\d+)\\b', caseSensitive: false);
  static final _xThenNumber = RegExp(r'\bx\s*(\d+)\b', caseSensitive: false);
  static final _letters = RegExp(r'[A-Za-zÀ-ÿ]');
  static final _formWords = RegExp(
    r'\b(compresse|compressa|rivestite|effervescenti|capsule|capsula|tablets?|capsules?)\b',
    caseSensitive: false,
  );

  LabelResult parse(List<LabelLine> lines) {
    final cleaned = _joinPackSize([
      for (final l in lines)
        if (l.text.trim().isNotEmpty) LabelLine(l.text.trim(), l.height, top: l.top),
    ]);

    final strength = _findStrength(cleaned);

    int? quantity;
    var unit = '';
    for (final line in cleaned) {
      final found = _quantityIn(line.text);
      if (found != null) {
        (quantity, unit) = found;
        break;
      }
    }

    return LabelResult(
      name: _findName(cleaned),
      strength: strength,
      quantity: quantity,
      unit: unit,
    );
  }

  static final _bareInteger = RegExp(r'^\d+$');
  static final _bareCountUnit = RegExp('^(?:$_units)\\.?\$', caseSensitive: false);

  /// A badge like "20 compresse" can come back as two lines, "20" and
  /// "compresse". Put them back together.
  static List<LabelLine> _joinPackSize(List<LabelLine> lines) {
    final out = <LabelLine>[];
    for (var i = 0; i < lines.length; i++) {
      final isPair =
          i + 1 < lines.length &&
          _bareInteger.hasMatch(lines[i].text) &&
          _bareCountUnit.hasMatch(lines[i + 1].text);
      if (isPair) {
        final a = lines[i], b = lines[i + 1];
        out.add(
          LabelLine('${a.text} ${b.text}', a.height > b.height ? a.height : b.height, top: a.top),
        );
        i++;
      } else {
        out.add(lines[i]);
      }
    }
    return out;
  }

  String _findStrength(List<LabelLine> lines) {
    for (final line in lines) {
      final m = _strength.firstMatch(line.text);
      if (m != null) return _formatStrength(m);
    }
    // "0,5" and "mg" printed as two pieces, as on a round badge.
    for (var i = 0; i + 1 < lines.length; i++) {
      if (_bareNumber.hasMatch(lines[i].text) && _bareUnit.hasMatch(lines[i + 1].text)) {
        return '${lines[i].text} ${lines[i + 1].text.toLowerCase()}'.replaceAll('ui', 'UI');
      }
    }
    return '';
  }

  static String _formatStrength(RegExpMatch m) {
    final unit = m.group(2)!;
    final shown = (unit.toLowerCase() == 'ui' || unit.toLowerCase() == 'iu')
        ? 'UI'
        : unit.toLowerCase();
    final per = m.group(4);
    final suffix = per == null
        ? ''
        : '/${m.group(3)!.isEmpty ? '' : '${m.group(3)} '}${per.toLowerCase()}';
    return '${m.group(1)} $shown$suffix';
  }

  /// The brand name: the biggest text that isn't a number, a strength or a
  /// pack size, plus lines right below it in the same size ("Delorazepam" /
  /// "ratiopharm Italia"). The word for the tablet form is dropped.
  String _findName(List<LabelLine> lines) {
    final candidates = <LabelLine>[];
    for (final line in lines) {
      if (_quantityIn(line.text) != null) continue;
      if (_bareUnit.hasMatch(line.text)) continue;
      var text = line.text.replaceFirst(_strength, ' ').replaceAll(_formWords, ' ');
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (_letters.allMatches(text).length < 2) continue;
      candidates.add(LabelLine(text, line.height, top: line.top));
    }
    if (candidates.isEmpty) return '';

    final tallest = candidates.map((l) => l.height).reduce((a, b) => a > b ? a : b);
    final big = candidates.where((l) => l.height >= tallest * 0.6).toList();
    final located = big.every((l) => l.top != null);

    if (!located) {
      big.sort((a, b) => b.height.compareTo(a.height));
      return tidy(big.first.text);
    }

    // Top to bottom. The name starts at the highest big line and takes the
    // big lines that follow it closely, so a logo further down is left out.
    big.sort((a, b) => a.top!.compareTo(b.top!));
    final name = [big.first];
    for (final next in big.skip(1)) {
      final gap = next.top! - name.last.bottom!;
      if (gap > name.last.height * 0.5) break;
      name.add(next);
    }
    return name.map((l) => tidy(l.text)).join(' ');
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
  static String tidy(String text) {
    if (text != text.toUpperCase()) return text;
    return text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
