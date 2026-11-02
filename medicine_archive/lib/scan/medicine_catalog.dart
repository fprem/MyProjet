import 'aic_code.dart';
import 'label_parser.dart';

/// Looks medicines up by their AIC code.
abstract interface class MedicineCatalog {
  /// What the pack with this AIC is, or null when it is not known.
  Future<LabelResult?> lookup(String aic);
}

/// AIFA's public list of every medicine pack authorised in Italy, kept in
/// the app so lookups work offline.
///
/// The list is AIFA's open-data CSV, turned at build time into one line per
/// pack, sorted by AIC: `aic \t name \t strength \t quantity \t unit`.
class AifaCatalog implements MedicineCatalog {
  AifaCatalog(this._load);
  AifaCatalog.fromTsv(String tsv) : this(() async => tsv);

  final Future<String> Function() _load;
  Future<String>? _tsv;

  @override
  Future<LabelResult?> lookup(String aic) async {
    if (!AicCode.isValid(aic)) return null;
    final String tsv;
    try {
      tsv = await (_tsv ??= _load().then((t) => '\n$t'));
    } catch (_) {
      return null; // no list in this build: the label text is read instead
    }
    final start = tsv.indexOf('\n$aic\t');
    if (start < 0) return null;
    var end = tsv.indexOf('\n', start + 1);
    if (end < 0) end = tsv.length;
    final f = tsv.substring(start + 1, end).split('\t');
    if (f.length < 5) return null;
    return LabelResult(name: f[1], strength: f[2], quantity: int.tryParse(f[3]), unit: f[4]);
  }

  /// Turns AIFA's CSV ("confezioni.csv") into the catalog's lines. Columns
  /// are found by name, so a reordered file still works.
  static String tsvFromCsv(String csv) {
    if (csv.startsWith('﻿')) csv = csv.substring(1);
    final firstLine = csv.substring(0, _lineEnd(csv));
    final separator = ';'.allMatches(firstLine).length >= ','.allMatches(firstLine).length
        ? ';'
        : ',';
    final rows = _parseCsv(csv, separator);
    if (rows.isEmpty) throw const FormatException('Empty file');
    final header = [for (final h in rows.first) h.trim().toLowerCase()];
    int column(bool Function(String) test) => header.indexWhere(test);
    final aicCol = column((h) => h == 'codice_aic' || h == 'aic' || h.contains('aic'));
    final nameCol = column((h) => h.contains('denominazione'));
    final descCol = column((h) => h.contains('descrizione'));
    if (aicCol < 0 || nameCol < 0 || descCol < 0) {
      throw FormatException('Not the AIFA list: missing columns in $header');
    }

    const parser = LabelParser();
    final lines = <String, String>{};
    for (final row in rows.skip(1)) {
      if (row.length <= [aicCol, nameCol, descCol].reduce((a, b) => a > b ? a : b)) continue;
      final aic = row[aicCol].trim().padLeft(9, '0');
      final name = _clean(row[nameCol]);
      if (!AicCode.isValid(aic) || name.isEmpty) continue;

      // The description reads like `"0,5 MG COMPRESSE" 20 COMPRESSE`: the
      // strength and form in quotes, then the pack size.
      final desc = _clean(row[descCol]);
      final close = desc.lastIndexOf('"');
      final dose = close > 0 ? desc.substring(0, close) : desc;
      final pack = close > 0 ? desc.substring(close + 1) : desc;
      final strength = parser.parse([LabelLine(dose.replaceAll('"', ' '), 1)]).strength;
      final size = parser.parse([LabelLine(pack, 1)]);

      lines[aic] = [
        aic,
        LabelParser.tidy(name),
        strength,
        size.quantity?.toString() ?? '',
        size.unit,
      ].join('\t');
    }
    final keys = lines.keys.toList()..sort();
    return keys.map((k) => '${lines[k]}\n').join();
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();

  static int _lineEnd(String s) {
    final i = s.indexOf('\n');
    return i < 0 ? s.length : i;
  }

  /// A small CSV reader: quoted fields, doubled quotes, newlines in quotes.
  static List<List<String>> _parseCsv(String csv, String separator) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < csv.length; i++) {
      final c = csv[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == separator) {
        row.add(field.toString());
        field.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        if (row.any((f) => f.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(c);
      }
    }
    row.add(field.toString());
    if (row.any((f) => f.isNotEmpty)) rows.add(row);
    return rows;
  }
}
