/// Where the archive is kept. The app uses [EncryptedFileStore]; tests can
/// use an in-memory store.
abstract interface class ArchiveStore {
  /// The saved archive, or null when nothing has been saved yet.
  Future<Map<String, dynamic>?> read();

  Future<void> write(Map<String, dynamic> json);
}
