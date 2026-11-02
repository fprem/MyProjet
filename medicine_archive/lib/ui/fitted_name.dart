import 'dart:math';

import 'package:flutter/material.dart';

/// A medicine name that adapts its size to the space it has.
///
/// It shrinks (down to [minFontSize]) to stay on one line, or else on as few
/// lines as it can. It only ever wraps between words, so no letter or two is
/// left alone on a line.
class FittedName extends StatelessWidget {
  const FittedName(this.name, {super.key, required this.style, this.minFontSize = 14});

  final String name;
  final TextStyle style;
  final double minFontSize;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Measure with the style Text will really use.
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final base = effective.fontSize ?? 22;
    return LayoutBuilder(
      builder: (context, box) {
        TextPainter paint(String text, double size, {int? maxLines}) => TextPainter(
          text: TextSpan(
            text: text,
            style: effective.copyWith(fontSize: size),
          ),
          textDirection: direction,
          textScaler: scaler,
          maxLines: maxLines,
        );

        final fits = box.maxWidth;
        final min = minFontSize.clamp(1, base).toDouble();
        final words = name.split(RegExp(r'\s+'));
        final longestWord = words.reduce((a, b) => a.length >= b.length ? a : b);

        // Every word fits whole on a line, and the name takes at most [lines].
        bool fitsIn(int lines, double size) {
          if ((paint(longestWord, size, maxLines: 1)..layout()).width > fits) return false;
          final tp = paint(name, size)..layout(maxWidth: fits);
          return tp.computeLineMetrics().length <= lines;
        }

        double largest(int lines) {
          // Text grows with the size, so search for the largest size that fits.
          if (fitsIn(lines, base)) return base;
          if (!fitsIn(lines, min)) return -1;
          var lo = min, hi = base;
          for (var i = 0; i < 12; i++) {
            final mid = (lo + hi) / 2;
            if (fitsIn(lines, mid)) {
              lo = mid;
            } else {
              hi = mid;
            }
          }
          return (lo * 2).floorToDouble() / 2; // round down to half points
        }

        // One line if possible, then two, then three, shrinking down to [min].
        var size = -1.0;
        for (var lines = 1; lines <= 3 && size < 0; lines++) {
          size = largest(lines);
        }
        if (size < 0) size = max(largest(words.length), min);
        return Text(name, style: effective.copyWith(fontSize: size));
      },
    );
  }
}
