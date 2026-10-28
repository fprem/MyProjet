import 'package:flutter/material.dart';

import '../app.dart';
import '../data/archive_repository.dart';
import '../scan/photo_scanner.dart';
import 'empty_state.dart';
import 'profile_screen.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({
    super.key,
    required this.repository,
    required this.scanner,
    required this.takePhoto,
  });

  final ArchiveRepository repository;
  final MedicineScanner scanner;
  final TakePhoto takePhoto;

  Future<void> _createProfile(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewProfileDialog(),
    );
    if (name != null) await repository.createProfile(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Archive')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProfile(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New profile'),
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final profiles = repository.profiles;
          if (profiles.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No profiles yet',
              message: 'Create a profile for each person whose medicines you keep.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: profiles.length,
            itemBuilder: (context, i) {
              final profile = profiles[i];
              final count = repository.medicinesOf(profile.id).length;
              return ListTile(
                leading: CircleAvatar(child: Text(profile.name.characters.first.toUpperCase())),
                title: Text(profile.name),
                subtitle: Text(count == 1 ? '1 medicine' : '$count medicines'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      repository: repository,
                      profile: profile,
                      scanner: scanner,
                      takePhoto: takePhoto,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NewProfileDialog extends StatefulWidget {
  const _NewProfileDialog();

  @override
  State<_NewProfileDialog> createState() => _NewProfileDialogState();
}

class _NewProfileDialogState extends State<_NewProfileDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isNotEmpty) Navigator.pop(context, _name.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New profile'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
