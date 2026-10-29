/// The AIC: the 9-digit code AIFA gives every pack sold in Italy. The last
/// digit is a check digit, so a misread code is almost always caught.
abstract final class AicCode {
  // Code 32, the barcode on the "bollino", writes the AIC in base 32 with
  // these characters (no vowels, so it never spells a word).
  static const _code32 = '0123456789BCDFGHJKLMNPQRSTUVWXYZ';

  static final _nineDigits = RegExp(r'^A?(\d{9})$');
  static final _code32Value = RegExp('^[$_code32]{6}\$');
  // GS1 DataMatrix: application identifier 712 holds the Italian AIC.
  static final _gs1Aic = RegExp(r'712(\d{9})');
  static final _textAic = RegExp(
    r'A\.?\s?I\.?\s?C\.?\s*(?:n[.°º]?|nr\.?)?\s*:?\s*(\d{9})\b|\bA(\d{9})\b',
    caseSensitive: false,
  );

  /// The AIC in a barcode's raw value, or null when it holds none.
  static String? fromBarcode(String raw) {
    final value = raw.trim().toUpperCase();
    final digits = _nineDigits.firstMatch(value);
    if (digits != null) return _checked(digits[1]!);
    if (_code32Value.hasMatch(value)) {
      var n = 0;
      for (final c in value.split('')) {
        n = n * 32 + _code32.indexOf(c);
      }
      return _checked(n.toString().padLeft(9, '0'));
    }
    for (final m in _gs1Aic.allMatches(value)) {
      final aic = _checked(m[1]!);
      if (aic != null) return aic;
    }
    return null;
  }

  /// The AIC printed on the box ("A.I.C. n. 012345678"), or null.
  static String? fromText(String text) {
    for (final m in _textAic.allMatches(text)) {
      final aic = _checked(m[1] ?? m[2]!);
      if (aic != null) return aic;
    }
    return null;
  }

  /// [aic] written as Code 32.
  static String toCode32(String aic) {
    var n = int.parse(aic);
    final out = StringBuffer();
    for (var i = 0; i < 6; i++) {
      out.write(_code32[n % 32]);
      n ~/= 32;
    }
    return out.toString().split('').reversed.join();
  }

  static bool isValid(String aic) => aic.length == 9 && _checked(aic) != null;

  static String? _checked(String aic) {
    if (!RegExp(r'^\d{9}$').hasMatch(aic)) return null;
    var sum = 0;
    for (var i = 0; i < 8; i++) {
      var d = aic.codeUnitAt(i) - 48;
      if (i.isOdd) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
    }
    return sum % 10 == aic.codeUnitAt(8) - 48 ? aic : null;
  }
}
