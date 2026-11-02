import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/ui/barcode_help.dart';
import 'package:medicine_archive/ui/brand.dart';

void main() {
  Future<void> openHelp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Brand.lightTheme(),
        home: Scaffold(appBar: AppBar(actions: const [BarcodeHelpButton()])),
      ),
    );
    await tester.tap(find.byTooltip('Which barcode?'));
    await tester.pumpAndSettle();
  }

  testWidgets('the ? shows which barcode to scan and which not', (tester) async {
    await openHelp(tester);

    expect(find.text('Scan this'), findsOneWidget);
    expect(find.text('Not this'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('bollino', caseSensitive: false)), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Data Matrix')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('EAN-13')), findsWidgets);
  });

  // AIFA's list is CC BY 4.0, which asks for the source to be named.
  testWidgets('the help credits AIFA for the medicine list', (tester) async {
    await openHelp(tester);

    expect(find.textContaining('AIFA', findRichText: true), findsWidgets);
    expect(find.textContaining('CC BY 4.0', findRichText: true), findsOneWidget);
  });

  testWidgets('the help closes with Got it', (tester) async {
    await openHelp(tester);
    await tester.scrollUntilVisible(
      find.text('Got it'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Scan this'), findsNothing);
  });

  testWidgets('the help reads well at large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openHelp(tester);

    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  for (final dark in [false, true]) {
    testWidgets('the help button stands out on the black scan bar (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? Brand.darkTheme() : Brand.lightTheme(),
          home: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              actions: const [BarcodeHelpButton()],
            ),
          ),
        ),
      );

      expect(find.text('Help'), findsOneWidget);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  }
}
