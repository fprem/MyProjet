import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app.dart';
import '../data/archive_repository.dart';
import '../scan/barcode_scan.dart';
import '../scan/photo_scanner.dart';
import 'brand.dart';
import 'empty_state.dart';
import 'fitted_name.dart';
import 'medicine_form_screen.dart';

/// One person's medicines, with Scan box as the main action.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.profile,
    required this.scanner,
    required this.takePhoto,
    this.scanBarcode,
  });

  final ArchiveRepository repository;
  final Profile profile;
  final MedicineScanner scanner;
  final TakePhoto takePhoto;
  final ScanBarcode? scanBarcode;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _reading = false;

  /// Which tab is shown: the medicines being taken, or the archived ones.
  bool _showArchived = false;

  ArchiveRepository get _repo => widget.repository;

  /// Scan box: the barcode first, then a photo of the text if needed.
  Future<void> _scan() async {
    String? missedAic;
    if (widget.scanBarcode case final scanBarcode?) {
      final outcome = await scanBarcode(context);
      if (outcome == null || !mounted) return;
      if (outcome case BarcodeRead(:final aic)) {
        setState(() => _reading = true);
        final found = await widget.scanner.lookup(aic);
        if (!mounted) return;
        setState(() => _reading = false);
        if (found.fromCatalog) {
          await _openForm(
            title: 'Check medicine',
            initial: found.label,
            notice: ["From the barcode: AIC $aic, found in AIFA's medicine list."],
          );
          return;
        }
        missedAic = aic;
      }
    }
    await _scanPhoto(missedAic: missedAic);
  }

  Future<void> _scanPhoto({String? missedAic}) async {
    final path = await widget.takePhoto();
    if (path == null || !mounted) return;

    setState(() => _reading = true);
    ScanResult result;
    String message;
    try {
      result = await widget.scanner.scan(path);
      message = result.label.isEmpty
          ? "Couldn't read the label. Please type it in."
          : result.fromCatalog
          ? "From the barcode in the photo: AIC ${result.aic}, found in AIFA's medicine list."
          : missedAic != null
          ? "The barcode (AIC $missedAic) isn't in AIFA's list, so the text in the photo was read."
          : 'Read from the text in the photo. Check it and fix anything that is wrong.';
    } catch (_) {
      result = const ScanResult(LabelResult.empty());
      message = "Couldn't read the label. Please type it in.";
    }
    if (!mounted) return;
    setState(() => _reading = false);

    await _openForm(
      title: 'Check medicine',
      initial: result.label,
      photo: result.photo,
      notice: [
        message,
        result.photo == null
            ? 'The photo has been deleted.'
            : 'The photo is deleted when you save, unless you keep it.',
      ],
    );
  }

  Future<Uint8List?> _addPhoto() async {
    final path = await widget.takePhoto();
    if (path == null) return null;
    return widget.scanner.readPhoto(path);
  }

  Future<void> _openForm({
    required String title,
    LabelResult initial = const LabelResult.empty(),
    List<String> notice = const [],
    Uint8List? photo,
    Medicine? editing,
  }) async {
    if (editing != null) photo = await _repo.photoOf(editing);
    if (!mounted) return;
    final draft = await Navigator.push<MedicineDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineFormScreen(
          title: title,
          initial: initial,
          notice: notice,
          photo: photo,
          keepPhoto: editing != null && photo != null,
          addPhoto: _addPhoto,
        ),
      ),
    );
    if (draft == null) return;
    if (editing == null) {
      setState(() => _showArchived = false); // new medicines are being taken
      await _repo.addMedicine(
        widget.profile.id,
        name: draft.name,
        strength: draft.strength,
        quantity: draft.quantity,
        unit: draft.unit,
        photo: draft.keepPhoto ? draft.photo ?? photo : null,
      );
    } else {
      if (draft.keepPhoto && draft.photo != null && !identical(draft.photo, photo)) {
        await _repo.setPhoto(editing.id, draft.photo!);
      } else if (editing.hasPhoto && !draft.keepPhoto) {
        await _repo.removePhoto(editing.id);
      }
      await _repo.updateMedicine(
        editing.copyWith(
          name: draft.name,
          strength: draft.strength,
          quantity: draft.quantity,
          unit: draft.unit,
        ),
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

  Future<void> _setArchived(Medicine medicine, bool archived) async {
    await _repo.setArchived(medicine.id, archived);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${medicine.name} ${archived ? 'archived' : 'restored'}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _repo.setArchived(medicine.id, !archived),
        ),
      ),
    );
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
                final taking = _repo.medicinesOf(widget.profile.id);
                final archived = _repo.medicinesOf(widget.profile.id, archived: true);
                final medicines = _showArchived ? archived : taking;
                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: false,
                              icon: const Icon(Icons.medication_outlined),
                              label: Text('Taking (${taking.length})'),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: Text('Archived (${archived.length})'),
                            ),
                          ],
                          selected: {_showArchived},
                          onSelectionChanged: (s) => setState(() => _showArchived = s.single),
                        ),
                      ),
                    ),
                    if (medicines.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _showArchived
                            ? const EmptyState(
                                title: 'No archived medicines',
                                message:
                                    'When someone stops taking a medicine, tap Archive '
                                    'on it and it moves here.',
                              )
                            : const EmptyState(
                                title: 'No medicines yet',
                                message:
                                    'Tap Scan box to read a medicine box. '
                                    'Only what you check and save is kept, encrypted on this phone.',
                              ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                        sliver: SliverList.list(
                          children: [
                            for (final medicine in medicines) ...[
                              _MedicineCard(
                                medicine: medicine,
                                onTap: () => _openForm(
                                  title: 'Edit medicine',
                                  editing: medicine,
                                  initial: LabelResult(
                                    name: medicine.name,
                                    strength: medicine.strength,
                                    quantity: medicine.quantity,
                                    unit: medicine.unit,
                                  ),
                                ),
                                onArchive: () => _setArchived(medicine, !medicine.archived),
                                onDelete: () => _deleteMedicine(medicine),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.onTap,
    required this.onArchive,
    required this.onDelete,
  });

  final Medicine medicine;
  final VoidCallback onTap;

  /// Archives the medicine, or restores it when it is archived.
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDetails = medicine.strength.isNotEmpty || medicine.quantity != null;
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
        title: FittedName(
          medicine.name,
          style: theme.textTheme.titleLarge!.copyWith(color: scheme.onSurface),
        ),
        subtitle: !hasDetails
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (medicine.strength.isNotEmpty) StrengthTag(medicine.strength),
                      if (medicine.quantity != null) QuantityPill(medicine.quantityLabel),
                    ],
                  ),
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: medicine.archived ? 'Restore ${medicine.name}' : 'Archive ${medicine.name}',
              icon: Icon(
                medicine.archived ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: onArchive,
            ),
            IconButton(
              tooltip: 'Delete ${medicine.name}',
              icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
              onPressed: onDelete,
            ),
          ],
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
