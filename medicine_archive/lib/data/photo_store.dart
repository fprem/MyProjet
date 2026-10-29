import 'dart:io';
import 'dart:typed_data';

import 'key_provider.dart';
import 'sealer.dart';

/// Box photos the person chose to keep, one per medicine.
abstract interface class PhotoStore {
  Future<void> write(String id, Uint8List bytes);
  Future<Uint8List?> read(String id);
  Future<void> delete(String id);
}

/// Keeps photos in memory, for tests and the browser preview.
class MemoryPhotoStore implements PhotoStore {
  final _photos = <String, Uint8List>{};

  @override
  Future<void> write(String id, Uint8List bytes) async => _photos[id] = bytes;

  @override
  Future<Uint8List?> read(String id) async => _photos[id];

  @override
  Future<void> delete(String id) async => _photos.remove(id);
}

/// Keeps each photo in its own file, encrypted with the archive's key.
class EncryptedPhotoStore implements PhotoStore {
  EncryptedPhotoStore({required this.directory, required KeyProvider keys})
    : _sealer = Sealer(keys);

  final Directory directory;
  final Sealer _sealer;

  static final _safeId = RegExp(r'^[A-Za-z0-9_-]+$');

  File _file(String id) {
    if (!_safeId.hasMatch(id)) throw ArgumentError.value(id, 'id', 'Not a photo id');
    return File('${directory.path}/$id.enc');
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    final file = _file(id);
    await directory.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(await _sealer.seal(bytes), flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<Uint8List?> read(String id) async {
    final file = _file(id);
    if (!await file.exists()) return null;
    return Uint8List.fromList(await _sealer.open(await file.readAsBytes()));
  }

  @override
  Future<void> delete(String id) async {
    final file = _file(id);
    if (await file.exists()) await file.delete();
  }
}
