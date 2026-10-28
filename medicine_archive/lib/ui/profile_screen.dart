import 'package:flutter/material.dart';

import '../app.dart';
import '../data/archive_repository.dart';
import '../scan/photo_scanner.dart';
import 'brand.dart';
import 'empty_state.dart';
import 'medicine_form_screen.dart';

/// One person's medicines, with Scan box as the main action.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.profile,
    required this.scanner,
    required this.takePhoto,
  });

  final ArchiveRepository repository;
  final Profile profile;
  final MedicineScanner scanner;
  final TakePhoto takePhoto;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _reading = false;

  ArchiveRepository get _repo => widget.repository;

  Future<void> _scan() async {
    final path = await widget.takePhoto();
    if (path == null || !mounted) return;

    setState(() => _reading = true);
    LabelResult result;
    String message;
    try {
      result = await widget.scanner.scan(path);
      message = result.isEmpty
          ? "Couldn't read the label. Please type it in."
          : 'Check what was read and fix anything that is wrong.';
    } catch (_) {
      result = const LabelResult.empty();
      message = "Couldn't read the label. Please type it in.";
    }
    if (!mounted) return;
    setState(() => _reading = false);

    await _openForm(
      title: 'Check medicine',
      initial: result,
      notice: [message, 'The photo has been deleted.'],
    );
  }

  Future<void> _openForm({
    required String title,
    LabelResult initial = const LabelResult.empty(),
    List<String> notice = const [],
    Medicine? editing,
  }) async {
    final draft = await Navigator.push<MedicineDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineFormScreen(title: title, initial: initial, notice: notice),
      ),
    );
    if (draft == null) return;
    if (editing == null) {
      await _repo.addMedicine(
        widget.profile.id,
        name: draft.name,
        quantity: draft.quantity,
        unit: draft.unit,
      );
    } else {
      await _repo.updateMedicine(
        editing.copyWith(name: draft.name, quantity: draft.quantity, unit: draft.unit),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${draft.name.trim()} saved')));
  }

  Future<void> _deleteMedicine(Medicine medicine) async {
    if (await confirmDelete(context, 'Delete ${medicine.name}?')) {
      await _repo.deleteMedicine(medicine.id);
    }
  }

  Future<void> _deleteProfile() async {
    final name = widget.profile.name;
    if (await confirmDelete(context, 'Delete $name and all their medicines?')) {
      await _repo.deleteProfile(widget.profile.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _reading
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: _scan,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan box'),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(widget.profile.name),
            actions: [
              IconButton(
                tooltip: 'Add by hand',
                icon: const Icon(Icons.edit_note_rounded),
                onPressed: _reading ? null : () => _openForm(title: 'Add medicine'),
              ),
              PopupMenuButton<void>(
                tooltip: 'More options',
                itemBuilder: (_) => [
                  PopupMenuItem(onTap: _deleteProfile, child: const Text('Delete profile')),
                ],
              ),
            ],
          ),
          if (_reading)
            const SliverFillRemaining(hasScrollBody: false, child: _Reading())
          else
            ListenableBuilder(
              listenable: _repo,
              builder: (context, _) {
                final medicines = _repo.medicinesOf(widget.profile.id);
                if (medicines.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: 'No medicines yet',
                      message:
                          'Tap Scan box to photograph a medicine package. '
                          'Only the name and quantity are kept, encrypted on this phone.',
                    ),
                  );
                }
                final count = medicines.length;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                  sliver: SliverList.list(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Text(
                          count == 1 ? '1 medicine' : '$count medicines',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      for (final medicine in medicines) ...[
                        _MedicineCard(
                          medicine: medicine,
                          onTap: () => _openForm(
                            title: 'Edit medicine',
                            editing: medicine,
                            initial: LabelResult(
                              name: medicine.name,
                              quantity: medicine.quantity,
                              unit: medicine.unit,
                            ),
                          ),
                          onDelete: () => _deleteMedicine(medicine),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine, required this.onTap, required this.onDelete});

  final Medicine medicine;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        minTileHeight: 84,
        onTap: onTap,
        leading: ExcludeSemantics(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.medication_rounded, color: scheme.primary),
          ),
        ),
        title: Text(medicine.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: QuantityPill(medicine.quantityLabel),
          ),
        ),
        trailing: IconButton(
          tooltip: 'Delete ${medicine.name}',
          icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ScanFrame(),
          const SizedBox(height: 28),
          Semantics(
            liveRegion: true,
            child: Text('Reading the label…', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(
            'This happens on your phone.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
