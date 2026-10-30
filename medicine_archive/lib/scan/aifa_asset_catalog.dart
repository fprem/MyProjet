import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'medicine_catalog.dart';

/// Where the build puts AIFA's list (see tool/build_aifa_catalog.dart). A
/// build made without it still works: barcodes then fall back to the text.
const aifaCatalogAsset = 'assets/aifa/catalog.tsv.gz';

/// AIFA's list as bundled in the app, unpacked the first time it is needed.
AifaCatalog bundledAifaCatalog() => AifaCatalog(() async {
  final data = await rootBundle.load(aifaCatalogAsset);
  return compute(_unpack, data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
});

String _unpack(Uint8List gz) => utf8.decode(gzip.decode(gz));
