import 'dart:math';

import 'package:flutter/material.dart';

import 'brand.dart';

/// Three welcome steps, shown once at the very first start. [onDone] runs on
/// OK or Skip.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Step {
  const _Step(this.title, this.body, this.painter);
  final String title;
  final List<String> body;
  final CustomPainter Function(ColorScheme) painter;
}

final _steps = [
  _Step('How many times has someone asked you which medicines you take?', [
    "At the doctor's, at the pharmacy, in the emergency room… and the boxes are at home.",
  ], _DoctorPainter.new),
  _Step('Now that problem is solved', [
    "Your medicines, and your family's, are always with you: in your pocket, on your phone.",
  ], _PocketPainter.new),
  _Step('How it works', [
    'Create a profile for each person.',
    'Scan the barcode on the box, or take a photo.',
    'Check and save. Everything stays encrypted on this phone.',
  ], _AppPainter.new),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  bool get _last => _page == _steps.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      widget.onDone();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: _last
                    ? const SizedBox(height: 48)
                    : TextButton(onPressed: widget.onDone, child: const Text('Skip')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _steps.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) => _StepPage(step: _steps[i], index: i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8,
                      children: [
                        for (var i = 0; i < _steps.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page ? scheme.primary : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  FilledButton(onPressed: _next, child: Text(_last ? "OK, let's start" : 'Next')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, required this.index});

  final _Step step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(48),
                        child: ColoredBox(
                          color: scheme.primaryContainer,
                          child: CustomPaint(painter: step.painter(scheme)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                label: 'Step ${index + 1} of ${_steps.length}',
                excludeSemantics: true,
                child: Text(
                  'STEP ${index + 1} OF ${_steps.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(step.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              for (final line in step.body)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (step.body.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 10),
                          child: Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary),
                        ),
                      Expanded(
                        child: Text(
                          line,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// The illustrations are drawn on a 100-unit square, in the app's colours.

abstract class _Illustration extends CustomPainter {
  _Illustration(this.scheme);
  final ColorScheme scheme;

  Paint fill(Color c) => Paint()..color = c;
  Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void paintUnits(Canvas canvas);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);
    paintUnits(canvas);
    canvas.restore();
  }

  void drawText(Canvas canvas, String text, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          fontWeight: FontWeight.w700,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void drawCapsule(Canvas canvas, Offset c, double angle, double len, double w) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final r = Rect.fromCenter(center: Offset.zero, width: len, height: w);
    canvas.clipRRect(RRect.fromRectAndRadius(r, Radius.circular(w / 2)));
    canvas.drawRect(r, fill(Brand.mint));
    canvas.drawRect(Rect.fromLTRB(0, r.top, r.right, r.bottom), fill(Colors.white));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Illustration old) => old.scheme != scheme;
}

/// A doctor asking, with a question in a speech bubble.
class _DoctorPainter extends _Illustration {
  _DoctorPainter(super.scheme);

  @override
  void paintUnits(Canvas canvas) {
    const ink = Brand.ink;
    // Coat and shoulders.
    final coat = Path()
      ..moveTo(18, 100)
      ..quadraticBezierTo(18, 66, 42, 62)
      ..lineTo(58, 62)
      ..quadraticBezierTo(82, 66, 82, 100)
      ..close();
    canvas.drawPath(coat, fill(Colors.white));
    // Lapels.
    canvas.drawPath(
      Path()
        ..moveTo(42, 62)
        ..lineTo(50, 78)
        ..lineTo(58, 62),
      stroke(ink.withValues(alpha: 0.25), 1.6),
    );
    // Neck and head.
    canvas.drawRect(const Rect.fromLTWH(45, 52, 10, 12), fill(const Color(0xFFE8B996)));
    canvas.drawOval(const Rect.fromLTWH(37, 26, 26, 30), fill(const Color(0xFFF1C7A5)));
    // Hair.
    canvas.drawPath(
      Path()
        ..moveTo(37, 40)
        ..quadraticBezierTo(36, 22, 52, 23)
        ..quadraticBezierTo(65, 24, 63, 40)
        ..quadraticBezierTo(56, 31, 44, 33)
        ..close(),
      fill(ink),
    );
    // Stethoscope.
    canvas.drawPath(
      Path()
        ..moveTo(43, 63)
        ..quadraticBezierTo(38, 80, 48, 84)
        ..moveTo(57, 63)
        ..quadraticBezierTo(62, 80, 52, 84),
      stroke(ink, 2),
    );
    canvas.drawCircle(const Offset(50, 86), 3.4, fill(ink));
    canvas.drawCircle(const Offset(50, 86), 1.6, fill(Brand.mint));
    // Speech bubble with a question mark.
    final bubble = RRect.fromRectAndRadius(
      const Rect.fromLTWH(62, 8, 30, 24),
      const Radius.circular(10),
    );
    canvas.drawRRect(bubble, fill(ink));
    canvas.drawPath(
      Path()
        ..moveTo(68, 30)
        ..lineTo(64, 38)
        ..lineTo(74, 31)
        ..close(),
      fill(ink),
    );
    drawText(canvas, '?', const Offset(77, 20), 18, Brand.mint);
    // A pill floating on the other side.
    drawCapsule(canvas, const Offset(20, 24), -pi / 5, 20, 8);
  }
}

/// A hand taking a phone out of a jeans pocket; the phone shows the app's mark.
class _PocketPainter extends _Illustration {
  _PocketPainter(super.scheme);

  static const _skin = Color(0xFFF1C7A5);
  static const _skinShade = Color(0xFFE2AE88);

  @override
  void paintUnits(Canvas canvas) {
    const ink = Brand.ink;
    const denim = Color(0xFF3B5B8C);
    const denimLight = Color(0xFF4A6DA3);
    const stitch = Color(0xFFE3B24F);
    // Jeans, with a belt loop.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(8, 60, 84, 40),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      ),
      fill(denim),
    );
    canvas.drawRect(const Rect.fromLTWH(8, 60, 84, 5), fill(const Color(0xFF2F4C77)));
    canvas.drawRect(const Rect.fromLTWH(18, 58, 4, 10), fill(const Color(0xFF2F4C77)));
    // Phone, half out of the pocket.
    final phone = RRect.fromRectAndRadius(
      const Rect.fromLTWH(36, 22, 26, 48),
      const Radius.circular(5),
    );
    canvas.drawRRect(phone, fill(ink));
    canvas.drawRRect(phone.deflate(2), fill(const Color(0xFF14211F)));
    drawViewfinder(canvas, const Rect.fromLTWH(41, 29, 16, 16), Brand.mint, 1.6, 4);
    drawCapsule(canvas, const Offset(49, 37), -pi / 4, 10, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(41, 50, 16, 3), const Radius.circular(1.5)),
      fill(Brand.mint.withValues(alpha: 0.7)),
    );
    // The pocket, over the bottom of the phone, with its stitching.
    final pocket = Path()
      ..moveTo(28, 64)
      ..quadraticBezierTo(49, 76, 70, 64)
      ..lineTo(70, 96)
      ..quadraticBezierTo(49, 102, 28, 96)
      ..close();
    canvas.drawPath(pocket, fill(denimLight));
    final dash = stroke(stitch, 1.1);
    canvas.drawPath(
      Path()
        ..moveTo(30, 68)
        ..quadraticBezierTo(49, 79, 68, 68),
      dash,
    );
    canvas.drawLine(const Offset(30.5, 69), const Offset(30.5, 94), dash);
    canvas.drawLine(const Offset(67.5, 69), const Offset(67.5, 94), dash);
    // Arm coming in from the top right, sleeve then hand.
    canvas.drawLine(const Offset(104, -4), const Offset(72, 26), stroke(Colors.white, 17));
    canvas.drawLine(
      const Offset(104, -4),
      const Offset(72, 26),
      stroke(ink.withValues(alpha: 0.08), 17),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(56, 20, 18, 22), const Radius.circular(8)),
      fill(_skin),
    );
    // Fingers wrapping the phone's edge, and the thumb on its face.
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(57, 22.0 + i * 6.5, 8, 5.5),
          const Radius.circular(2.75),
        ),
        fill(_skinShade),
      );
    }
    canvas.save();
    canvas.translate(56, 34);
    canvas.rotate(-0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -11, 8, 15), const Radius.circular(4)),
      fill(_skin),
    );
    canvas.restore();
    // Motion lines: it just came out.
    for (var i = 0; i < 3; i++) {
      final x = 26.0 + i * 4;
      canvas.drawLine(Offset(x, 40 + i * 4.0), Offset(x, 50 + i * 4.0), stroke(ink, 1.6));
    }
    // Check badge: solved.
    canvas.drawCircle(const Offset(20, 22), 9, fill(ink));
    canvas.drawPath(
      Path()
        ..moveTo(15.5, 22)
        ..lineTo(19, 25.5)
        ..lineTo(25, 18.5),
      stroke(Brand.mint, 2.2),
    );
  }
}

/// The app itself: a phone showing a profile's list.
class _AppPainter extends _Illustration {
  _AppPainter(super.scheme);

  @override
  void paintUnits(Canvas canvas) {
    const ink = Brand.ink;
    final phone = RRect.fromRectAndRadius(
      const Rect.fromLTWH(26, 8, 48, 84),
      const Radius.circular(9),
    );
    canvas.drawRRect(phone.shift(const Offset(2, 3)), fill(ink.withValues(alpha: 0.15)));
    canvas.drawRRect(phone, fill(ink));
    final screen = phone.deflate(2.5);
    canvas.drawRRect(screen, fill(const Color(0xFFF2F6F4)));
    // Header: the mark and a name.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(32, 16, 10, 10), const Radius.circular(2.5)),
      fill(ink),
    );
    drawViewfinder(canvas, const Rect.fromLTWH(34, 18, 6, 6), Brand.mint, 0.8, 1.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(45, 18.5, 20, 5), const Radius.circular(2.5)),
      fill(ink),
    );
    // Three medicine rows.
    for (var i = 0; i < 3; i++) {
      final y = 32.0 + i * 16;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(31, y, 38, 13), const Radius.circular(4)),
        fill(Colors.white),
      );
      canvas.drawCircle(Offset(36.5, y + 6.5), 3.2, fill(Brand.mint));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(42, y + 3, 18 - i * 3.0, 3),
          const Radius.circular(1.5),
        ),
        fill(ink),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(42, y + 8, 10, 2.6), const Radius.circular(1.3)),
        fill(Brand.mint),
      );
    }
    // Scan button.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(38, 80, 24, 7), const Radius.circular(3.5)),
      fill(const Color(0xFF0E5F5B)),
    );
    // A box being scanned, beside the phone.
    canvas.save();
    canvas.translate(80, 66);
    canvas.rotate(0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -14, 20, 28), const Radius.circular(2)),
      fill(Colors.white),
    );
    canvas.drawRect(const Rect.fromLTWH(-10, -14, 5, 28), fill(Brand.mint));
    for (var i = 0; i < 6; i++) {
      canvas.drawRect(Rect.fromLTWH(-3.0 + i * 2, 4, i.isEven ? 1.2 : 0.6, 7), fill(ink));
    }
    canvas.restore();
    drawCapsule(canvas, const Offset(16, 30), pi / 6, 16, 6.5);
  }
}
