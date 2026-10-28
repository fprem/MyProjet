import 'package:flutter/material.dart';

import '../app.dart';
import '../data/archive_repository.dart';
import '../scan/photo_scanner.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.name),
        actions: [
          IconButton(
            tooltip: 'Add by hand',
            icon: const Icon(Icons.edit_note),
            onPressed: () => _openForm(title: 'Add medicine'),
          ),
          PopupMenuButton<void>(
            tooltip: 'More options',
            itemBuilder: (_) => [
              PopupMenuItem(onTap: _deleteProfile, child: const Text('Delete profile')),
            ],
          ),
        ],
      ),
      floatingActionButton: _reading
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: _scan,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Scan box'),
            ),
      body: _reading
          ? Center(
              child: Semantics(
                liveRegion: true,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Reading the label…'),
                  ],
                ),
              ),
            )
          : ListenableBuilder(
              listenable: _repo,
              builder: (context, _) {
                final medicines = _repo.medicinesOf(widget.profile.id);
                if (medicines.isEmpty) {
                  return const EmptyState(
                    icon: Icons.medication_outlined,
                    title: 'No medicines yet',
                    message:
                        'Tap Scan box to photograph a medicine package. '
                        'Only the name and quantity are kept, encrypted on this phone.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: medicines.length,
                  itemBuilder: (context, i) {
                    final medicine = medicines[i];
                    return ListTile(
                      leading: const Icon(Icons.medication_outlined),
                      title: Text(medicine.name),
                      subtitle: Text(medicine.quantityLabel),
                      onTap: () => _openForm(
                        title: 'Edit medicine',
                        editing: medicine,
                        initial: LabelResult(
                          name: medicine.name,
                          quantity: medicine.quantity,
                          unit: medicine.unit,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete ${medicine.name}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteMedicine(medicine),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
