import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../app.dart';
import '../data/archive_repository.dart';
import '../data/tags.dart';
import '../l10n/l10n.dart';
import '../scan/barcode_scan.dart';
import '../scan/photo_scanner.dart';
import 'brand.dart';
import 'empty_state.dart';
import 'medicine_form_screen.dart';

/// A tab gets a search field once it has more medicines than this.
const searchFrom = 8;

/// Tighter than the theme's, so both buttons fit side by side on most phones.
const _fabPadding = EdgeInsetsDirectional.symmetric(horizontal: 20);

/// Room under the list so the last card can scroll clear of the buttons.
const _bottomRoom = 176.0;

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

  /// What is typed in the search field, shown once a tab has more than
  /// [searchFrom] medicines.
  final _search = TextEditingController();

  /// The box photos shown as thumbnails, decrypted once per medicine.
  final _thumbs = <String, Future<Uint8List?>>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
            title: context.l10n.checkMedicine,
            initial: found.label,
            notice: [context.l10n.fromBarcodeFound(aic)],
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

    final l10n = context.l10n;
    setState(() => _reading = true);
    ScanResult result;
    String message;
    try {
      result = await widget.scanner.scan(path);
      message = result.label.isEmpty
          ? l10n.couldntReadLabel
          : result.fromCatalog
          ? l10n.fromBarcodeInPhoto('${result.aic}')
          : missedAic != null
          ? l10n.barcodeNotInList(missedAic)
          : l10n.readFromText;
    } catch (_) {
      result = const ScanResult(LabelResult.empty());
      message = l10n.couldntReadLabel;
    }
    if (!mounted) return;
    setState(() => _reading = false);

    await _openForm(
      title: l10n.checkMedicine,
      initial: result.label,
      photo: result.photo,
      notice: [message, result.photo == null ? l10n.photoDeleted : l10n.photoDeletedOnSave],
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
          editing: editing != null,
          addPhoto: _addPhoto,
          tags: editing?.tags ?? const [],
          knownTags: _repo.customTagsOf(widget.profile.id),
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
        tags: draft.tags,
        photo: draft.keepPhoto ? draft.photo ?? photo : null,
      );
    } else {
      _thumbs.remove(editing.id);
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
          tags: draft.tags,
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.medicineSaved(draft.name.trim()))));
  }

  Future<void> _deleteMedicine(Medicine medicine) async {
    if (await confirmDelete(context, context.l10n.deleteMedicineQuestion(medicine.name))) {
      await _repo.deleteMedicine(medicine.id);
    }
  }

  Future<void> _setArchived(Medicine medicine, bool archived) async {
    await _repo.setArchived(medicine.id, archived);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archived
              ? context.l10n.medicineArchived(medicine.name)
              : context.l10n.medicineRestored(medicine.name),
        ),
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () => _repo.setArchived(medicine.id, !archived),
        ),
      ),
    );
  }

  /// Moves a dragged medicine into the group of [to] (null: No tag).
  Future<void> _move(_Dragged dragged, String? to) async {
    if (dragged.from == to) return;
    final medicine = dragged.medicine;
    final before = await _repo.moveToTag(medicine.id, from: dragged.from, to: to);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.medicineMoved(medicine.name, context.l10n.group(to))),
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () => _repo.setTags(medicine.id, before),
        ),
      ),
    );
  }

  /// Every group [medicine] can be moved to from [group]: the times of day,
  /// the person's own tags, and No tag when it has a tag to leave.
  List<String?> _moveTargets(Medicine medicine, String? group) => [
    for (final tag in [...MedicineTags.fixed, ..._repo.customTagsOf(widget.profile.id)])
      if (tag != group) tag,
    if (group != null) null,
  ];

  Future<void> _showOptions(Medicine medicine, String? group) async {
    final choice = await showModalBottomSheet<_Option>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _OptionsSheet(medicine: medicine),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _Option.edit:
        await _edit(medicine);
      case _Option.move:
        final to = await showModalBottomSheet<({String? tag})>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) =>
              _MoveSheet(medicine: medicine, targets: _moveTargets(medicine, group)),
        );
        if (to != null) await _move(_Dragged(medicine, group), to.tag);
      case _Option.archive:
        await _setArchived(medicine, !medicine.archived);
      case _Option.delete:
        await _deleteMedicine(medicine);
    }
  }

  Future<void> _edit(Medicine medicine) => _openForm(
    title: context.l10n.editMedicine,
    editing: medicine,
    initial: LabelResult(
      name: medicine.name,
      strength: medicine.strength,
      quantity: medicine.quantity,
      unit: medicine.unit,
    ),
  );

  /// One medicine. In a group ([grouped]) it says which other groups it is
  /// in and can be dragged to another group; elsewhere it lists its tags.
  Widget _card(Medicine medicine, {String? group, bool grouped = false}) {
    final l10n = context.l10n;
    final others = [
      for (final t in medicine.tags)
        if (t != group) l10n.tag(t),
    ];
    final card = _MedicineCard(
      medicine: medicine,
      thumbnail: medicine.hasPhoto
          ? _thumbs.putIfAbsent(medicine.id, () => _repo.photoOf(medicine))
          : null,
      details: [
        if (medicine.strength.isNotEmpty) medicine.strength,
        if (medicine.quantity != null) medicine.quantityLabel,
        if (grouped && others.isNotEmpty) l10n.alsoTags(others.join(', ')),
        if (!grouped && medicine.tags.isNotEmpty) medicine.tags.map(l10n.tag).join(', '),
      ],
      onTap: () => _edit(medicine),
      onOptions: () => _showOptions(medicine, group),
    );
    final item = !grouped
        ? card
        : Semantics(
            customSemanticsActions: {
              for (final to in _moveTargets(medicine, group))
                CustomSemanticsAction(label: l10n.moveTo(l10n.group(to))): () =>
                    _move(_Dragged(medicine, group), to),
            },
            child: LayoutBuilder(
              builder: (context, constraints) => LongPressDraggable<_Dragged>(
                data: _Dragged(medicine, group),
                hapticFeedbackOnStart: true,
                // The card hangs below the finger, so the group under it
                // stays in sight and lights up.
                dragAnchorStrategy: (_, _, _) => Offset(constraints.maxWidth * 0.375, -20),
                feedback: Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    width: constraints.maxWidth * 0.75,
                    child: Transform.rotate(angle: -0.03, child: _Lifted(child: card)),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: card),
                child: card,
              ),
            ),
          );
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: item);
  }

  /// The Taking tab: the medicines grouped by tag, or a plain list while
  /// none has a tag.
  List<Widget> _taking(List<Medicine> taking) {
    final l10n = context.l10n;
    final hasTags = taking.any((m) => m.tags.isNotEmpty);
    if (!hasTags) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, _bottomRoom),
          sliver: SliverList.list(children: [for (final m in taking) _card(m)]),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: _Hint(l10n.dragHint),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, _bottomRoom),
        sliver: SliverList.list(
          children: [
            for (final g in groupByTag(taking))
              _DropZone(
                key: ValueKey('section-${g.tag ?? 'none'}'),
                tag: g.tag,
                onDrop: _move,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GroupHeader(tag: g.tag, count: g.medicines.length),
                    for (final m in g.medicines) _card(m, group: g.tag, grouped: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// [medicines] whose name has what is typed in the search field.
  List<Medicine> _matching(List<Medicine> medicines) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty || medicines.length <= searchFrom) return medicines;
    return [
      for (final m in medicines)
        if (m.name.toLowerCase().contains(query)) m,
    ];
  }

  Future<void> _deleteProfile() async {
    final name = widget.profile.name;
    if (await confirmDelete(context, context.l10n.deleteProfileQuestion(name))) {
      await _repo.deleteProfile(widget.profile.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _reading
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // Side by side, or one above the other when the text is large.
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FloatingActionButton.extended(
                    heroTag: null,
                    extendedPadding: _fabPadding,
                    onPressed: _scan,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(l10n.scanBox),
                  ),
                  FloatingActionButton.extended(
                    heroTag: null,
                    extendedPadding: _fabPadding,
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    onPressed: () => _openForm(title: l10n.addMedicine),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.typeItIn),
                  ),
                ],
              ),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(widget.profile.name),
            actions: [
              PopupMenuButton<void>(
                tooltip: l10n.moreOptions,
                itemBuilder: (_) => [
                  PopupMenuItem(onTap: _deleteProfile, child: Text(l10n.deleteProfile)),
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
                final all = _showArchived ? archived : taking;
                final medicines = _matching(all);
                final searching = all.length > searchFrom;
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
                              label: Text(l10n.takingCount(taking.length)),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: Text(l10n.archivedCount(archived.length)),
                            ),
                          ],
                          selected: {_showArchived},
                          onSelectionChanged: (s) => setState(() => _showArchived = s.single),
                        ),
                      ),
                    ),
                    if (searching)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              labelText: l10n.searchMedicines(widget.profile.name),
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: l10n.clearSearch,
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(_search.clear),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    if (searching && medicines.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: _Hint(l10n.noMatch(_search.text.trim())),
                        ),
                      )
                    else if (medicines.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _showArchived
                            ? EmptyState(
                                title: l10n.noArchivedTitle,
                                message: l10n.noArchivedMessage,
                              )
                            : EmptyState(
                                title: l10n.noMedicinesTitle,
                                message: l10n.noMedicinesMessage,
                              ),
                      )
                    else if (_showArchived)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, _bottomRoom),
                        sliver: SliverList.list(children: [for (final m in medicines) _card(m)]),
                      )
                    else
                      ..._taking(medicines),
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
    required this.details,
    required this.onTap,
    required this.onOptions,
    this.thumbnail,
  });

  final Medicine medicine;

  /// Strength, pack size and tags, shown on one line under the name.
  final List<String> details;

  /// The kept box photo, while it is being decrypted.
  final Future<Uint8List?>? thumbnail;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: ListTile(
        minTileHeight: 72,
        onTap: onTap,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
        leading: switch (thumbnail) {
          final photo? => ExcludeSemantics(
            child: ClipRRect(
              key: ValueKey('thumb-${medicine.id}'),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 48,
                child: FutureBuilder(
                  future: photo,
                  builder: (context, snapshot) => switch (snapshot.data) {
                    final bytes? => Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      cacheWidth: (48 * MediaQuery.devicePixelRatioOf(context)).round(),
                      errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest),
                    ),
                    null => ColoredBox(color: scheme.surfaceContainerHighest),
                  },
                ),
              ),
            ),
          ),
          null => null,
        },
        title: Text(
          medicine.name,
          style: theme.textTheme.titleLarge!.copyWith(color: scheme.onSurface),
        ),
        subtitle: details.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  details.join(' · '),
                  style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
        trailing: IconButton(
          tooltip: context.l10n.optionsFor(medicine.name),
          icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
          onPressed: onOptions,
        ),
      ),
    );
  }
}

enum _Option { edit, move, archive, delete }

/// What can be done with one medicine. Delete is last and set apart, so it
/// is not hit by accident.
class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({required this.medicine});
  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    void pick(_Option o) => Navigator.pop(context, o);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Semantics(
                header: true,
                child: Text(medicine.name, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.edit),
              onTap: () => pick(_Option.edit),
            ),
            if (!medicine.archived)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text(l10n.moveToMenu),
                onTap: () => pick(_Option.move),
              ),
            ListTile(
              leading: Icon(
                medicine.archived ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
              ),
              title: Text(medicine.archived ? l10n.restore : l10n.archiveStopped),
              onTap: () => pick(_Option.archive),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              iconColor: scheme.error,
              textColor: scheme.error,
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.delete),
              onTap: () => pick(_Option.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// The groups a medicine can be moved to. Pops with the chosen one.
class _MoveSheet extends StatelessWidget {
  const _MoveSheet({required this.medicine, required this.targets});
  final Medicine medicine;
  final List<String?> targets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.moveMedicineTo(medicine.name),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final tag in targets)
              ListTile(
                leading: Icon(tagIcon(tag), color: Theme.of(context).colorScheme.primary),
                title: Text(l10n.group(tag)),
                onTap: () => Navigator.pop(context, (tag: tag)),
              ),
            const SizedBox(height: 8),
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
            child: Text(context.l10n.readingLabel, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.happensOnPhone,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A medicine being dragged, and the group it was taken from.
class _Dragged {
  const _Dragged(this.medicine, this.from);
  final Medicine medicine;
  final String? from;
}

/// Where a dragged medicine can be dropped to get [tag] (null: No tag). It
/// lights up while a medicine from another group is over it.
class _DropZone extends StatelessWidget {
  const _DropZone({super.key, required this.tag, required this.onDrop, required this.child});

  final String? tag;
  final void Function(_Dragged dragged, String? to) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<_Dragged>(
      onWillAcceptWithDetails: (d) => d.data.from != tag,
      onAcceptWithDetails: (d) => onDrop(d.data, tag),
      builder: (context, candidates, _) {
        final hot = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: ShapeDecoration(
            color: hot ? scheme.primaryContainer : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: hot ? scheme.primary : Colors.transparent, width: 2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.tag, required this.count});
  final String? tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      header: true,
      label: '${context.l10n.group(tag)}, $count',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
        child: Row(
          spacing: 10,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tagIcon(tag), size: 18, color: scheme.primary),
            ),
            Flexible(child: Text(context.l10n.group(tag), style: theme.textTheme.titleMedium)),
            Text(
              '$count',
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// A card lifted off the list while it is dragged.
class _Lifted extends StatelessWidget {
  const _Lifted({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x47000000), blurRadius: 24, offset: Offset(0, 10))],
    ),
    child: child,
  );
}
