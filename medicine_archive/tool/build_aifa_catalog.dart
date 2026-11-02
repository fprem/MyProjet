// Downloads AIFA's open-data list of medicine packs and turns it into the
// app's offline catalog:
//
//   dart run tool/build_aifa_catalog.dart [assets/aifa/catalog.tsv.gz]
//
// Exits non-zero if the list can't be fetched or read; the app still builds
// without it.

import 'dart:convert';
import 'dart:io';

import 'package:medicine_archive/scan/medicine_catalog.dart';

const _sources = [
  'https://drive.aifa.gov.it/farmaci/confezioni.csv',
  'https://drive.aifa.gov.it/farmaci/confezioni_fornitura.csv',
];

Future<void> main(List<String> args) async {
  final out = File(args.isEmpty ? 'assets/aifa/catalog.tsv.gz' : args.first);
  for (final url in _sources) {
    try {
      stdout.writeln('Fetching $url');
      final csv = await _fetch(Uri.parse(url));
      final tsv = AifaCatalog.tsvFromCsv(csv);
      final packs = '\n'.allMatches(tsv).length;
      if (packs < 1000) throw FormatException('Only $packs packs');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(gzip.encode(utf8.encode(tsv)));
      stdout.writeln('Wrote $packs packs to ${out.path} (${out.lengthSync()} bytes)');
      stdout.writeln('Sample: ${tsv.split('\n').take(3).join(' | ')}');
      return;
    } catch (e) {
      stderr.writeln('  failed: $e');
    }
  }
  exitCode = 1;
}

Future<String> _fetch(Uri uri) async {
  final client = HttpClient()..userAgent = 'medicine-archive-build';
  try {
    final response = await (await client.getUrl(uri)).close();
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: uri);
    final bytes = await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes); // older exports are Latin-1
    }
  } finally {
    client.close();
  }
}
