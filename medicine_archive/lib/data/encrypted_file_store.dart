import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'archive_store.dart';
import 'key_provider.dart';

class ArchiveDecryptionException implements Exception {
  const ArchiveDecryptionException(this.message);
  final String message;

  @override
  String toString() => 'ArchiveDecryptionException: $message';
}

/// Saves the archive as one file encrypted with AES-256-GCM.
///
/// File layout: a version byte, then nonce (12 bytes), ciphertext and MAC
/// (16 bytes). Every write uses a fresh nonce, and the MAC makes any change
/// to the file fail on read.
class EncryptedFileStore implements ArchiveStore {
  EncryptedFileStore({required this.file, required this.keys});

  final File file;
  final KeyProvider keys;

  static const _version = 1;
  static final _cipher = AesGcm.with256bits();

  Future<SecretKey> _secretKey() async => SecretKey(await keys.key());

  @override
  Future<Map<String, dynamic>?> read() async {
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.first != _version) {
      throw const ArchiveDecryptionException('Unknown archive format');
    }
    try {
      final box = SecretBox.fromConcatenation(
        bytes.sublist(1),
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
      );
      final clear = await _cipher.decrypt(box, secretKey: await _secretKey());
      return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } on SecretBoxAuthenticationError {
      throw const ArchiveDecryptionException('Wrong key or damaged archive');
    } on ArgumentError {
      throw const ArchiveDecryptionException('Damaged archive');
    }
  }

  @override
  Future<void> write(Map<String, dynamic> json) async {
    final box = await _cipher.encrypt(utf8.encode(jsonEncode(json)), secretKey: await _secretKey());
    // Write to a temporary file first so a crash never leaves half an archive.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes([_version, ...box.concatenation()], flush: true);
    await tmp.rename(file.path);
  }
}
