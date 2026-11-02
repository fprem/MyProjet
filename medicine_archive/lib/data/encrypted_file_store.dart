import 'dart:convert';
import 'dart:io';

import 'archive_store.dart';
import 'key_provider.dart';
import 'sealer.dart';

export 'sealer.dart' show ArchiveDecryptionException;

/// Saves the archive as one file encrypted with AES-256-GCM (see [Sealer]).
class EncryptedFileStore implements ArchiveStore {
  EncryptedFileStore({required this.file, required KeyProvider keys}) : _sealer = Sealer(keys);

  final File file;
  final Sealer _sealer;

  @override
  Future<Map<String, dynamic>?> read() async {
    if (!await file.exists()) return null;
    final clear = await _sealer.open(await file.readAsBytes());
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> json) async {
    final sealed = await _sealer.seal(utf8.encode(jsonEncode(json)));
    // Write to a temporary file first so a crash never leaves half an archive.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(sealed, flush: true);
    await tmp.rename(file.path);
  }
}
