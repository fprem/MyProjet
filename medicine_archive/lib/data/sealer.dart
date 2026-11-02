import 'package:cryptography/cryptography.dart';

import 'key_provider.dart';

class ArchiveDecryptionException implements Exception {
  const ArchiveDecryptionException(this.message);
  final String message;

  @override
  String toString() => 'ArchiveDecryptionException: $message';
}

/// Encrypts and decrypts bytes with AES-256-GCM.
///
/// Sealed layout: a version byte, then nonce (12 bytes), ciphertext and MAC
/// (16 bytes). Every seal uses a fresh nonce, and the MAC makes any change
/// to the bytes fail on open.
class Sealer {
  const Sealer(this.keys);

  final KeyProvider keys;

  static const _version = 1;
  static final _cipher = AesGcm.with256bits();

  Future<SecretKey> _secretKey() async => SecretKey(await keys.key());

  Future<List<int>> seal(List<int> clear) async {
    final box = await _cipher.encrypt(clear, secretKey: await _secretKey());
    return [_version, ...box.concatenation()];
  }

  Future<List<int>> open(List<int> sealed) async {
    if (sealed.isEmpty || sealed.first != _version) {
      throw const ArchiveDecryptionException('Unknown archive format');
    }
    try {
      final box = SecretBox.fromConcatenation(
        sealed.sublist(1),
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
      );
      return await _cipher.decrypt(box, secretKey: await _secretKey());
    } on SecretBoxAuthenticationError {
      throw const ArchiveDecryptionException('Wrong key or damaged archive');
    } on ArgumentError {
      throw const ArchiveDecryptionException('Damaged archive');
    }
  }
}
