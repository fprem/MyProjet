import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// A backup that can't be opened: wrong password, damaged, or not a backup.
class BackupException implements Exception {
  const BackupException.notBackup()
    : problem = BackupProblem.notBackup,
      message = "This file isn't a Medicine Archive backup.";
  const BackupException.wrongPassword()
    : problem = BackupProblem.wrongPassword,
      message = 'Wrong password, or the file is damaged.';
  const BackupException.damaged()
    : problem = BackupProblem.damaged,
      message = 'The file is damaged.';

  final BackupProblem problem;

  /// The problem in English, for logs. The app shows its own words for it.
  final String message;

  @override
  String toString() => 'BackupException: $message';
}

enum BackupProblem { notBackup, wrongPassword, damaged }

/// What a backup holds, to show before importing it.
class BackupSummary {
  const BackupSummary({required this.profiles, required this.medicines});
  final int profiles;
  final int medicines;

  factory BackupSummary.of(Map<String, dynamic> backup) => BackupSummary(
    profiles: (backup['profiles'] as List?)?.length ?? 0,
    medicines: (backup['medicines'] as List?)?.length ?? 0,
  );
}

/// Turns a backup into a file that only its password opens, and back.
///
/// The archive on the phone is encrypted with a key kept by Android, which
/// is gone once the app is uninstalled. A backup file must outlive that, so
/// its key comes from a password instead: PBKDF2-HMAC-SHA256 with a random
/// salt, then AES-256-GCM.
///
/// Layout: "MABK", a version byte, the PBKDF2 rounds (4 bytes, big-endian),
/// the salt (16 bytes), then nonce, ciphertext and MAC.
class BackupCodec {
  const BackupCodec({this.iterations = 120000});

  /// PBKDF2 rounds for new backups. Opening reads them from the file.
  final int iterations;

  static const _magic = [0x4d, 0x41, 0x42, 0x4b]; // MABK
  static const _version = 1;
  static const _saltLength = 16;
  static const _headerLength = 4 + 1 + 4 + _saltLength;
  static final _cipher = AesGcm.with256bits();

  static Future<SecretKey> _key(String password, List<int> salt, int rounds) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: rounds,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);

  Future<Uint8List> seal(Map<String, dynamic> backup, String password) async {
    final salt = SecretKeyData.random(length: _saltLength).bytes;
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(backup)),
      secretKey: await _key(password, salt, iterations),
    );
    final rounds = ByteData(4)..setUint32(0, iterations);
    return Uint8List.fromList([
      ..._magic,
      _version,
      ...rounds.buffer.asUint8List(),
      ...salt,
      ...box.concatenation(),
    ]);
  }

  Future<Map<String, dynamic>> open(Uint8List file, String password) async {
    if (file.length <= _headerLength ||
        !_magic.indexed.every((e) => file[e.$1] == e.$2) ||
        file[4] != _version) {
      throw const BackupException.notBackup();
    }
    final rounds = ByteData.sublistView(file, 5, 9).getUint32(0);
    if (rounds < 1 || rounds > 5000000) {
      throw const BackupException.notBackup();
    }
    final salt = file.sublist(9, _headerLength);
    try {
      final box = SecretBox.fromConcatenation(
        file.sublist(_headerLength),
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
      );
      final clear = await _cipher.decrypt(box, secretKey: await _key(password, salt, rounds));
      return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } on SecretBoxAuthenticationError {
      throw const BackupException.wrongPassword();
    } on ArgumentError {
      throw const BackupException.damaged();
    } on FormatException {
      throw const BackupException.damaged();
    }
  }
}
