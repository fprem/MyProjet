import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'backup_flow.dart';

/// Saves and opens backup files with Android's own file chooser, so the
/// person picks the place (Downloads, Drive, a USB stick…). The app itself
/// still needs no storage or internet permission.
class DeviceBackupFiles implements BackupFiles {
  const DeviceBackupFiles();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(dialogTitle: 'Save backup', fileName: fileName, bytes: bytes) !=
      null;

  @override
  Future<Uint8List?> pick() async {
    final result = await FilePicker.pickFiles(dialogTitle: 'Open backup', withData: true);
    return result?.files.singleOrNull?.bytes;
  }
}
