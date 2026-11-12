import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/scan/photo_scanner.dart';
import 'package:medicine_archive/ui/brand.dart';
import 'package:medicine_archive/ui/profiles_screen.dart';

import 'fakes.dart';

/// What Android 12+ hands over from the wallpaper, here from a seed.
PhoneColours wallpaper(Color seed) => (
  light: ColorScheme.fromSeed(seedColor: seed),
  dark: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
);

const brandLight = Color(0xFF0E5F5B);
const brandDark = Brand.mint;
const useColours = "Use my phone's colours";

void main() {
  late ArchiveRepository repo;

  setUp(() async => repo = await memoryRepository());

  Future<void> pumpApp(
    WidgetTester tester, {
    PhoneColours? phoneColours,
    ThemeMode themeMode = ThemeMode.light,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: FakeScanner(const LabelResult.empty()),
        takePhoto: () async => '/tmp/photo.jpg',
        themeMode: themeMode,
        phoneColours: phoneColours,
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  ColorScheme scheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(ProfilesScreen))).colorScheme;

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
  }

  group('the brand look stays unless the person asks', () {
    testWidgets('without wallpaper colours (before Android 12) there is no switch', (tester) async {
      await pumpApp(tester);
      expect(find.byTooltip('More options'), findsNothing);
      expect(find.text(useColours), findsNothing);
      expect(scheme(tester).primary, brandLight);
    });

    testWidgets('with wallpaper colours, the switch is there and off', (tester) async {
      await pumpApp(tester, phoneColours: wallpaper(Colors.deepPurple));
      expect(scheme(tester).primary, brandLight);
      await openMenu(tester);
      final item = tester.widget<CheckedPopupMenuItem<void>>(
        find.ancestor(of: find.text(useColours), matching: find.byType(CheckedPopupMenuItem<void>)),
      );
      expect(item.checked, isFalse);
    });
  });

  group('turning it on', () {
    testWidgets('takes the wallpaper colours at once, and saves the choice', (tester) async {
      final phone = wallpaper(Colors.deepPurple);
      await pumpApp(tester, phoneColours: phone);
      await openMenu(tester);
      await tester.tap(find.text(useColours));
      await tester.pumpAndSettle();

      expect(repo.phoneColours, isTrue);
      expect(scheme(tester).primary, isNot(brandLight));
      expect(scheme(tester).primary, phone.light.primary);
    });

    testWidgets('dark mode takes the dark wallpaper colours', (tester) async {
      final phone = wallpaper(Colors.orange);
      await repo.setPhoneColours(true);
      await pumpApp(tester, phoneColours: phone, themeMode: ThemeMode.dark);
      expect(scheme(tester).brightness, Brightness.dark);
      expect(scheme(tester).primary, phone.dark.primary);
      expect(scheme(tester).primary, isNot(brandDark));
    });

    testWidgets('turning it off brings the teal back', (tester) async {
      await repo.setPhoneColours(true);
      await pumpApp(tester, phoneColours: wallpaper(Colors.red));
      await openMenu(tester);
      await tester.tap(find.text(useColours));
      await tester.pumpAndSettle();
      expect(repo.phoneColours, isFalse);
      expect(scheme(tester).primary, brandLight);
    });

    testWidgets('a saved choice on a phone without wallpaper colours keeps the brand', (
      tester,
    ) async {
      await repo.setPhoneColours(true);
      await pumpApp(tester);
      expect(scheme(tester).primary, brandLight);
    });

    testWidgets('the app keeps its own fonts and shapes', (tester) async {
      await repo.setPhoneColours(true);
      await pumpApp(tester, phoneColours: wallpaper(Colors.blue));
      final theme = Theme.of(tester.element(find.byType(ProfilesScreen)));
      expect(theme.textTheme.bodyMedium?.fontFamily, Brand.textFont);
      expect(theme.textTheme.headlineSmall?.fontFamily, Brand.displayFont);
      expect(theme.floatingActionButtonTheme.shape, const StadiumBorder());
    });
  });

  testWidgets('in Italian the switch reads naturally', (tester) async {
    await pumpApp(tester, phoneColours: wallpaper(Colors.green), locale: const Locale('it'));
    await tester.tap(find.byTooltip('Altre opzioni'));
    await tester.pumpAndSettle();
    expect(find.text('Usa i colori del telefono'), findsOneWidget);
  });

  // Wallpapers can be any colour: the text must stay readable on all of them.
  for (final seed in [Colors.yellow, Colors.red, Colors.lightBlue, Colors.pink, Colors.brown]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('readable and tappable with a ${seed.toARGB32().toRadixString(16)} '
          'wallpaper, ${mode.name}', (tester) async {
        final handle = tester.ensureSemantics();
        await repo.setPhoneColours(true);
        final anna = await repo.createProfile('Anna');
        await repo.addMedicine(anna.id, name: 'Aspirina', quantity: 10, unit: 'compresse');
        await pumpApp(tester, phoneColours: wallpaper(seed), themeMode: mode);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await tester.tap(find.text('Anna'));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }
}
