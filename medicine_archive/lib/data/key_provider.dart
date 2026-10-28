import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Supplies the 256-bit key that encrypts the archive.
abstract interface class KeyProvider {
  Future<List<int>> key();
}

List<int> _randomKey() {
  final random = Random.secure();
  return List<int>.generate(32, (_) => random.nextInt(256));
}

/// Keeps the key in Android's Keystore-backed secure storage. The key is
/// created on first use and never leaves the device.
class SecureStorageKeyProvider implements KeyProvider {
  SecureStorageKeyProvider([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'archive_key_v1';
  final FlutterSecureStorage _storage;
  List<int>? _cached;

  @override
  Future<List<int>> key() async {
    if (_cached != null) return _cached!;
    final stored = await _storage.read(key: _keyName);
    if (stored != null) return _cached = base64Decode(stored);
    final created = _randomKey();
    await _storage.write(key: _keyName, value: base64Encode(created));
    return _cached = created;
  }
}

/// A random key held in memory, for tests.
class InMemoryKeyProvider implements KeyProvider {
  final List<int> _key = _randomKey();

  @override
  Future<List<int>> key() async => _key;
}
