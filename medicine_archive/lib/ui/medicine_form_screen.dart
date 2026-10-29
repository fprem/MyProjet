import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../scan/label_parser.dart';

/// What the person confirmed in the form.
class MedicineDraft {
  const MedicineDraft({
    required this.name,
    this.quantity,
    this.unit = '',
    this.strength = '',
    this.keepPhoto = false,
  });
  final String name;
  final int? quantity;
  final String unit;
  final String strength;

  /// Whether the box photo shown in the form should be kept.
  final bool keepPhoto;
}

/// Lets the person check or type a medicine's name and quantity. Pops with a
/// [MedicineDraft] on Save.
class MedicineFormScreen extends StatefulWidget {
  const MedicineFormScreen({
    super.key,
    required this.title,
    this.initial = const LabelResult.empty(),
    this.notice = const [],
    this.photo,
    this.keepPhoto = false,
  });

  final String title;
  final LabelResult initial;

  /// Lines shown above the form, such as what happened to the photo.
  final List<String> notice;

  /// The box photo, when there is one. The person decides whether to keep
  /// it; [keepPhoto] is where the switch starts.
  final Uint8List? photo;
  final bool keepPhoto;

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _quantity = TextEditingController(text: widget.initial.quantity?.toString() ?? '');
  late final _unit = TextEditingController(text: widget.initial.unit);
  late final _strength = TextEditingController(text: widget.initial.strength);
  late bool _keepPhoto = widget.keepPhoto;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _strength.dispose();
    super.dispose();
  }

  int? get _parsedQuantity => int.tryParse(_quantity.text.trim());

  bool get _canSave => _name.text.trim().isNotEmpty;

  void _save() {
    Navigator.pop(
      context,
      MedicineDraft(
        name: _name.text.trim(),
        strength: _strength.text.trim(),
        quantity: _parsedQuantity,
        unit: _unit.text.trim(),
        keepPhoto: widget.photo != null && _keepPhoto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.notice.isNotEmpty) ...[
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          for (final line in widget.notice)
                            Text(
                              line,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleMedium,
            decoration: InputDecoration(
              labelText: 'Name',
              helperText: _name.text.trim().isEmpty ? 'Required' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _strength,
            style: theme.textTheme.titleMedium,
            decoration: const InputDecoration(
              labelText: 'Strength (optional)',
              hintText: 'e.g. 500 mg',
              helperText: 'Check it: 0,5 mg and 1 mg are different',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: theme.textTheme.titleMedium,
                  decoration: const InputDecoration(labelText: 'Quantity (optional)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unit,
                  style: theme.textTheme.titleMedium,
                  decoration: const InputDecoration(
                    labelText: 'Unit (optional)',
                    hintText: 'compresse, ml…',
                  ),
                ),
              ),
            ],
          ),
          if (widget.photo case final photo?) ...[
            const SizedBox(height: 20),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    value: _keepPhoto,
                    onChanged: (v) => setState(() => _keepPhoto = v),
                    title: const Text('Keep the box photo'),
                    subtitle: const Text('Saved encrypted, shown on this page'),
                    secondary: const Icon(Icons.photo_outlined),
                  ),
                  if (_keepPhoto)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          photo,
                          semanticLabel: 'Photo of the box',
                          fit: BoxFit.contain,
                          height: 280,
                          errorBuilder: (_, _, _) => SizedBox(
                            height: 80,
                            child: Center(
                              child: Text(
                                "The photo can't be shown.",
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(onPressed: _canSave ? _save : null, child: const Text('Save')),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 6,
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
              Flexible(
                child: Text(
                  'Saved encrypted on this phone only.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
