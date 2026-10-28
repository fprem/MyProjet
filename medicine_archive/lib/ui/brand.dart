import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's look: deep teal and mint, Bricolage Grotesque for headings and
/// Figtree for text. Everything visual comes from here.
abstract final class Brand {
  static const displayFont = 'Bricolage Grotesque';
  static const textFont = 'Figtree';

  static const ink = Color(0xFF0E3F3D);
  static const mint = Color(0xFF8FE3CF);

  static ThemeData lightTheme() => _theme(
    ColorScheme.fromSeed(seedColor: const Color(0xFF0E6B66)).copyWith(
      primary: const Color(0xFF0E5F5B),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFCDF3E8),
      onPrimaryContainer: const Color(0xFF00201D),
      surface: const Color(0xFFF2F6F4),
      onSurface: const Color(0xFF0F1F1E),
      onSurfaceVariant: const Color(0xFF3F4F4D),
      surfaceContainerLowest: Colors.white,
      surfaceContainerHighest: const Color(0xFFE1EAE7),
    ),
  );

  static ThemeData darkTheme() => _theme(
    ColorScheme.fromSeed(seedColor: const Color(0xFF0E6B66), brightness: Brightness.dark).copyWith(
      primary: mint,
      onPrimary: const Color(0xFF00382F),
      primaryContainer: const Color(0xFF16524C),
      onPrimaryContainer: const Color(0xFFCDF3E8),
      surface: const Color(0xFF0B1514),
      onSurface: const Color(0xFFE2EEEB),
      onSurfaceVariant: const Color(0xFFB4C7C3),
      surfaceContainerLowest: const Color(0xFF14211F),
      surfaceContainerHighest: const Color(0xFF243331),
    ),
  );

  static ThemeData _theme(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme.apply(
      fontFamily: textFont,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    TextStyle? display(TextStyle? s, FontWeight w) =>
        s?.copyWith(fontFamily: displayFont, fontWeight: w, letterSpacing: -0.4);
    final textTheme = text.copyWith(
      displayLarge: display(text.displayLarge, FontWeight.w700),
      displayMedium: display(text.displayMedium, FontWeight.w700),
      displaySmall: display(text.displaySmall, FontWeight.w700),
      headlineLarge: display(text.headlineLarge, FontWeight.w700),
      headlineMedium: display(text.headlineMedium, FontWeight.w700),
      headlineSmall: display(text.headlineSmall, FontWeight.w700),
      titleLarge: display(text.titleLarge, FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    final rounded16 = BorderRadius.circular(16);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: rounded16, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: rounded16, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: rounded16,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleMedium,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        elevation: 2,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
        extendedTextStyle: textTheme.titleMedium,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: textTheme.headlineSmall,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: rounded16),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}

/// The logo: a capsule inside a camera viewfinder. Decorative, so hidden
/// from screen readers.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 40, this.withTile = true});

  final double size;

  /// Draw the dark rounded tile behind the mark, as on the launcher icon.
  final bool withTile;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _LogoPainter(withTile)),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.withTile);
  final bool withTile;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on the same 108-unit grid as design/logo/logo.svg.
    canvas.scale(size.width / 108);
    if (withTile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 108, 108), const Radius.circular(26)),
        Paint()..color = Brand.ink,
      );
    }
    drawViewfinder(canvas, const Rect.fromLTRB(30, 30, 78, 78), Brand.mint, 4.5, 10);

    canvas.save();
    canvas.translate(54, 54);
    canvas.rotate(-math.pi / 4);
    final left = RRect.fromLTRBAndCorners(
      -19,
      -9.5,
      0,
      9.5,
      topLeft: const Radius.circular(9.5),
      bottomLeft: const Radius.circular(9.5),
    );
    final right = RRect.fromLTRBAndCorners(
      0,
      -9.5,
      19,
      9.5,
      topRight: const Radius.circular(9.5),
      bottomRight: const Radius.circular(9.5),
    );
    canvas.drawRRect(left, Paint()..color = Colors.white);
    canvas.drawRRect(right, Paint()..color = Brand.mint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.withTile != withTile;
}

/// Draws the four rounded corners of a camera viewfinder.
void drawViewfinder(Canvas canvas, Rect r, Color color, double stroke, double arm) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  const k = 4.0;
  final path = Path()
    ..moveTo(r.left, r.top + arm)
    ..lineTo(r.left, r.top + k)
    ..quadraticBezierTo(r.left, r.top, r.left + k, r.top)
    ..lineTo(r.left + arm, r.top)
    ..moveTo(r.right - arm, r.top)
    ..lineTo(r.right - k, r.top)
    ..quadraticBezierTo(r.right, r.top, r.right, r.top + k)
    ..lineTo(r.right, r.top + arm)
    ..moveTo(r.right, r.bottom - arm)
    ..lineTo(r.right, r.bottom - k)
    ..quadraticBezierTo(r.right, r.bottom, r.right - k, r.bottom)
    ..lineTo(r.right - arm, r.bottom)
    ..moveTo(r.left + arm, r.bottom)
    ..lineTo(r.left + k, r.bottom)
    ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - k)
    ..lineTo(r.left, r.bottom - arm);
  canvas.drawPath(path, paint);
}

/// A medicine's quantity, as a rounded pill ("20 compresse").
class QuantityPill extends StatelessWidget {
  const QuantityPill(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(color: scheme.primaryContainer, shape: const StadiumBorder()),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

/// A viewfinder with a line sweeping over it while the label is read. The
/// line stands still when the system asks for less motion.
class ScanFrame extends StatefulWidget {
  const ScanFrame({super.key});

  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _sweep
        ..stop()
        ..value = 0.5;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, _) => CustomPaint(
          size: const Size(220, 150),
          painter: _ScanPainter(
            Curves.easeInOut.transform(_sweep.value),
            frame: scheme.primary,
            box: scheme.primaryContainer,
          ),
        ),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.t, {required this.frame, required this.box});
  final double t;
  final Color frame;
  final Color box;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final inner = outer.deflate(22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(10)),
      Paint()..color = box,
    );
    drawViewfinder(canvas, outer.deflate(4), frame, 4, 26);
    final y = inner.top + inner.height * t;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(inner.left - 8, y - 1.5, inner.right + 8, y + 1.5),
        const Radius.circular(2),
      ),
      Paint()..color = frame,
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t || old.frame != frame || old.box != box;
}
