import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'brand.dart';

/// The "? Help" on the scan screen. Opens [showBarcodeHelp].
///
/// Its colours are fixed, not taken from the theme, because the scan screen
/// is black in light and dark mode alike.
class BarcodeHelpButton extends StatelessWidget {
  const BarcodeHelpButton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Tooltip(
      message: context.l10n.whichBarcode,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Brand.mint,
          foregroundColor: Brand.ink,
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        onPressed: () => showBarcodeHelp(context),
        icon: const Icon(Icons.help_rounded),
        label: Text(context.l10n.help),
      ),
    ),
  );
}

/// Shows which barcodes on the box the app reads, and which one it skips.
Future<void> showBarcodeHelp(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => const _BarcodeHelp(),
);

class _BarcodeHelp extends StatelessWidget {
  const _BarcodeHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(l10n.helpTitle, style: theme.textTheme.headlineSmall),
          _Heading(icon: Icons.check_circle_rounded, color: scheme.primary, text: l10n.scanThis),
          _Example(
            image: 'assets/help/bollino.png',
            label: l10n.bollinoImageLabel,
            title: l10n.bollinoTitle,
            text: l10n.bollinoText,
          ),
          _Example(
            image: 'assets/help/datamatrix.png',
            label: l10n.datamatrixImageLabel,
            title: l10n.datamatrixTitle,
            text: l10n.datamatrixText,
          ),
          _Heading(icon: Icons.cancel_rounded, color: scheme.error, text: l10n.notThis),
          _Example(
            image: 'assets/help/ean13.png',
            label: l10n.eanImageLabel,
            title: l10n.eanTitle,
            text: l10n.eanText,
            wrong: true,
          ),
          Text(
            l10n.aifaCredit,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.gotIt)),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Icon(icon, color: color),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
      ),
    ],
  );
}

class _Example extends StatelessWidget {
  const _Example({
    required this.image,
    required this.label,
    required this.title,
    required this.text,
    this.wrong = false,
  });

  final String image;
  final String label;
  final String title;
  final String text;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: wrong ? scheme.error : scheme.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(image, semanticLabel: label, fit: BoxFit.contain),
            ),
          ),
          Text(title, style: theme.textTheme.titleMedium),
          Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
