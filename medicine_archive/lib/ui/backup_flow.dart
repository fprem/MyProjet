import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/archive_repository.dart';
import '../data/backup.dart';

/// Where backup files go and come from: the phone's file chooser in the
/// app, a fake in tests.
abstract interface class BackupFiles {
  /// Asks where to save [bytes]. False when the person cancelled.
  Future<bool> save(String fileName, Uint8List bytes);

  /// Asks for a backup file to open. Null when the person cancelled.
  Future<Uint8List?> pick();
}

const _minPassword = 6;

/// Export backup: asks for a password, then saves the encrypted file.
Future<void> exportBackup(
  BuildContext context,
  ArchiveRepository repository,
  BackupFiles files,
  BackupCodec codec,
) async {
  final password = await showDialog<String>(
    context: context,
    builder: (_) => const _NewPasswordDialog(),
  );
  if (password == null || !context.mounted) return;
  final bytes = await _working(context, () async {
    return codec.seal(await repository.exportData(), password);
  });
  if (bytes == null || !context.mounted) return;
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final name = 'medicine-archive-${now.year}-${two(now.month)}-${two(now.day)}.mabk';
  if (!await files.save(name, bytes) || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Backup saved. Keep the password safe: without it the backup can't be opened."),
    ),
  );
}

/// Import backup: picks a file, asks its password, and after a check
/// replaces what is on this phone.
Future<void> importBackup(
  BuildContext context,
  ArchiveRepository repository,
  BackupFiles files,
  BackupCodec codec,
) async {
  final file = await files.pick();
  if (file == null || !context.mounted) return;
  final backup = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _OpenBackupDialog(file: file, codec: codec),
  );
  if (backup == null || !context.mounted) return;
  final summary = BackupSummary.of(backup);
  final hasData = repository.profiles.isNotEmpty;
  if (hasData && !await _confirmReplace(context, summary)) return;
  if (!context.mounted) return;
  try {
    await repository.importData(backup);
  } on BackupException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Backup imported: ${_count(summary)}.')));
}

String _count(BackupSummary s) =>
    '${s.profiles} ${s.profiles == 1 ? 'profile' : 'profiles'} and '
    '${s.medicines} ${s.medicines == 1 ? 'medicine' : 'medicines'}';

Future<bool> _confirmReplace(BuildContext context, BackupSummary summary) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Replace everything on this phone?'),
      content: Text(
        'The backup has ${_count(summary)}. '
        'What is on this phone now will be replaced by it.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Runs [work] behind a "Working…" dialog, as the password takes a moment.
Future<T?> _working<T>(BuildContext context, Future<T> Function() work) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(spacing: 20, children: [CircularProgressIndicator(), Text('Encrypting…')]),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  String? get _problem {
    if (_password.text.length < _minPassword) return 'At least $_minPassword characters';
    if (_repeat.text.isNotEmpty && _repeat.text != _password.text) {
      return "The passwords don't match";
    }
    return null;
  }

  bool get _ok => _problem == null && _repeat.text == _password.text;

  @override
  Widget build(BuildContext context) {
    final problem = _password.text.isEmpty && _repeat.text.isEmpty ? null : _problem;
    return AlertDialog(
      title: const Text('Export backup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const Text(
              'The backup holds every profile, medicine and kept photo, encrypted '
              'with a password you choose. You need the password to import it, '
              "and nobody can open it without, not even you if it's forgotten.",
            ),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _repeat,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Repeat password', errorText: problem),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: _ok ? () => Navigator.pop(context, _password.text) : null,
          child: const Text('Export'),
        ),
      ],
    );
  }
}

class _OpenBackupDialog extends StatefulWidget {
  const _OpenBackupDialog({required this.file, required this.codec});
  final Uint8List file;
  final BackupCodec codec;

  @override
  State<_OpenBackupDialog> createState() => _OpenBackupDialogState();
}

class _OpenBackupDialogState extends State<_OpenBackupDialog> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final backup = await widget.codec.open(widget.file, _password.text);
      if (mounted) Navigator.pop(context, backup);
    } on BackupException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import backup'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const Text('Type the password the backup was made with.'),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            decoration: InputDecoration(labelText: 'Password', errorText: _error),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _password.text.isEmpty || _busy ? null : _open(),
          ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: _password.text.isEmpty || _busy ? null : _open,
          child: const Text('Open'),
        ),
      ],
    );
  }
}
