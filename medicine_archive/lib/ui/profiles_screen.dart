import 'package:flutter/material.dart';

import '../app.dart';
import '../data/archive_repository.dart';
import '../scan/barcode_scan.dart';
import '../scan/photo_scanner.dart';
import 'brand.dart';
import 'empty_state.dart';
import 'profile_screen.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({
    super.key,
    required this.repository,
    required this.scanner,
    required this.takePhoto,
    this.scanBarcode,
  });

  final ArchiveRepository repository;
  final MedicineScanner scanner;
  final TakePhoto takePhoto;
  final ScanBarcode? scanBarcode;

  Future<void> _createProfile(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewProfileDialog(),
    );
    if (name != null) await repository.createProfile(name);
  }

  void _open(BuildContext context, Profile profile) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProfileScreen(
        repository: repository,
        profile: profile,
        scanner: scanner,
        takePhoto: takePhoto,
        scanBarcode: scanBarcode,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _createProfile(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New profile'),
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final profiles = repository.profiles;
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Row(
                  spacing: 12,
                  children: [LogoMark(size: 36), Text('Medicine Archive')],
                ),
              ),
              if (profiles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    title: 'No profiles yet',
                    message: 'Create a profile for each person whose medicines you keep.',
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Profiles',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                  sliver: SliverList.separated(
                    itemCount: profiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final profile = profiles[i];
                      final count = repository.medicinesOf(profile.id).length;
                      return _ProfileCard(
                        profile: profile,
                        count: count,
                        onTap: () => _open(context, profile),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.count, required this.onTap});

  final Profile profile;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: ListTile(
        minTileHeight: 80,
        onTap: onTap,
        leading: ExcludeSemantics(
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              profile.name.characters.first.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
        ),
        title: Text(profile.name, style: theme.textTheme.titleLarge),
        subtitle: Text(count == 1 ? '1 medicine' : '$count medicines'),
        trailing: Icon(Icons.arrow_forward_rounded, color: scheme.onSurfaceVariant),
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
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
