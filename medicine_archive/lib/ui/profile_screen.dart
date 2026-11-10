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

  /// Which group the Taking tab shows: null for all of them, grouped.
  ({String? tag})? _filter;

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

  /// [moveTargets]: the groups the medicine can be moved to from [group],
  /// offered to TalkBack and Switch Access as the same move that dragging does.
  Widget _card(
    Medicine medicine, {
    String? group,
    bool draggable = false,
    List<String?> moveTargets = const [],
  }) {
    final l10n = context.l10n;
    final card = _MedicineCard(
      medicine: medicine,
      otherTags: [
        for (final t in medicine.tags)
          if (t != group) t,
      ],
      showTags: group == null && !draggable,
      onTap: () => _openForm(
        title: l10n.editMedicine,
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
    );
    final item = !draggable
        ? card
        : Semantics(
            customSemanticsActions: {
              for (final to in moveTargets)
                if (to != group)
                  CustomSemanticsAction(label: l10n.moveTo(l10n.group(to))): () =>
                      _move(_Dragged(medicine, group), to),
            },
            child: LayoutBuilder(
              builder: (context, constraints) => LongPressDraggable<_Dragged>(
                data: _Dragged(medicine, group),
                hapticFeedbackOnStart: true,
                // The card hangs below the finger, so the group or chip under
                // it stays in sight and lights up.
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

  /// The Taking tab: chips to pick a group, then the medicines grouped by tag.
  List<Widget> _taking(List<Medicine> taking) {
    final groups = groupByTag(taking);
    final hasTags = taking.any((m) => m.tags.isNotEmpty);
    int count(String? tag) => groups.where((g) => g.tag == tag).firstOrNull?.medicines.length ?? 0;
    final chipTags = <String?>[
      ...MedicineTags.fixed,
      for (final g in groups)
        if (g.tag != null && !MedicineTags.isFixed(g.tag!)) g.tag,
      if (hasTags) null,
    ];
    final filter = _filter;
    final l10n = context.l10n;
    // Every group a medicine can go to: the times of day, the person's own
    // tags, and No tag once something is tagged.
    final targets = <String?>[...chipTags, if (!hasTags) null];
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        children: [
          ChoiceChip(
            key: const ValueKey('filter-all'),
            label: Text(l10n.allCount(taking.length)),
            selected: filter == null,
            onSelected: (_) => setState(() => _filter = null),
          ),
          for (final tag in chipTags)
            _DropZone(
              tag: tag,
              onDrop: _move,
              shape: const StadiumBorder(),
              child: ChoiceChip(
                key: ValueKey('filter-${tag ?? 'none'}'),
                avatar: filter?.tag == tag && filter != null ? null : Icon(tagIcon(tag), size: 18),
                label: Text(l10n.groupCount(l10n.group(tag), count(tag))),
                selected: filter != null && filter.tag == tag,
                onSelected: (_) => setState(() => _filter = (tag: tag)),
              ),
            ),
        ],
      ),
    );

    final List<Widget> list;
    if (filter != null) {
      final shown = groups.where((g) => g.tag == filter.tag).firstOrNull?.medicines ?? const [];
      list = [
        if (shown.isEmpty) _Hint(l10n.emptyGroupHint),
        for (final m in shown) _card(m, group: filter.tag, draggable: true, moveTargets: targets),
      ];
    } else if (!hasTags) {
      list = [for (final m in taking) _card(m, draggable: true, moveTargets: targets)];
    } else {
      list = [
        for (final g in groups)
          _DropZone(
            key: ValueKey('section-${g.tag ?? 'none'}'),
            tag: g.tag,
            onDrop: _move,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GroupHeader(tag: g.tag, count: g.medicines.length),
                for (final m in g.medicines)
                  _card(m, group: g.tag, draggable: true, moveTargets: targets),
              ],
            ),
          ),
      ];
    }
    return [
      SliverToBoxAdapter(child: chips),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: _Hint(l10n.dragHint),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
        sliver: SliverList.list(children: list),
      ),
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
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: _scan,
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(l10n.scanBox),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(widget.profile.name),
            actions: [
              IconButton(
                tooltip: l10n.addByHand,
                icon: const Icon(Icons.edit_note_rounded),
                onPressed: _reading ? null : () => _openForm(title: l10n.addMedicine),
              ),
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
                    if (medicines.isEmpty)
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
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
    required this.onTap,
    required this.onArchive,
    required this.onDelete,
    this.otherTags = const [],
    this.showTags = false,
  });

  final Medicine medicine;

  /// Its tags other than the group it is shown in, as small hints.
  final List<String> otherTags;

  /// Show [otherTags] as plain tags rather than "+ Evening" hints.
  final bool showTags;
  final VoidCallback onTap;

  /// Archives the medicine, or restores it when it is archived.
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final hasDetails =
        medicine.strength.isNotEmpty || medicine.quantity != null || otherTags.isNotEmpty;
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
                      for (final t in otherTags)
                        _TagHint(showTags ? l10n.tag(t) : '+ ${l10n.tag(t)}'),
                    ],
                  ),
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: medicine.archived
                  ? l10n.restoreMedicine(medicine.name)
                  : l10n.archiveMedicine(medicine.name),
              icon: Icon(
                medicine.archived ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: onArchive,
            ),
            IconButton(
              tooltip: l10n.deleteMedicine(medicine.name),
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
  const _DropZone({
    super.key,
    required this.tag,
    required this.onDrop,
    required this.shape,
    required this.child,
  });

  final String? tag;
  final void Function(_Dragged dragged, String? to) onDrop;
  final ShapeBorder shape;
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
            shape: shape is StadiumBorder
                ? StadiumBorder(
                    side: BorderSide(color: hot ? scheme.primary : Colors.transparent, width: 3),
                  )
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(color: hot ? scheme.primary : Colors.transparent, width: 2),
                  ),
          ),
          padding: shape is StadiumBorder
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 4),
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

/// One of a medicine's other tags, shown small on its card.
class _TagHint extends StatelessWidget {
  const _TagHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: theme.textTheme.labelMedium),
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
