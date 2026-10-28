import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../scan/label_parser.dart';

/// What the person confirmed in the form.
class MedicineDraft {
  const MedicineDraft({required this.name, required this.quantity, this.unit = ''});
  final String name;
  final int quantity;
  final String unit;
}

/// Lets the person check or type a medicine's name and quantity. Pops with a
/// [MedicineDraft] on Save.
class MedicineFormScreen extends StatefulWidget {
  const MedicineFormScreen({
    super.key,
    required this.title,
    this.initial = const LabelResult.empty(),
    this.notice = const [],
  });

  final String title;
  final LabelResult initial;

  /// Lines shown above the form, such as what happened to the photo.
  final List<String> notice;

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _quantity = TextEditingController(text: widget.initial.quantity?.toString() ?? '');
  late final _unit = TextEditingController(text: widget.initial.unit);

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    super.dispose();
  }

  int? get _parsedQuantity => int.tryParse(_quantity.text.trim());

  bool get _canSave => _name.text.trim().isNotEmpty && _parsedQuantity != null;

  void _save() {
    Navigator.pop(
      context,
      MedicineDraft(name: _name.text.trim(), quantity: _parsedQuantity!, unit: _unit.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.notice.isNotEmpty) ...[
            Card.filled(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in widget.notice)
                      Text(
                        line,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
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
            decoration: InputDecoration(
              labelText: 'Name',
              helperText: _name.text.trim().isEmpty ? 'Required' : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
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
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    helperText: _parsedQuantity == null ? 'Required' : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit (optional)',
                    hintText: 'compresse, ml…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _canSave ? _save : null, child: const Text('Save')),
          const SizedBox(height: 16),
          Text(
            'Saved encrypted on this phone only.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
