import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/archive_repository.dart';
import 'data/backup.dart';
import 'l10n/l10n.dart';
import 'scan/barcode_scan.dart';
import 'scan/photo_scanner.dart';
import 'security/app_lock.dart';
import 'ui/backup_flow.dart';
import 'ui/brand.dart';
import 'ui/onboarding_screen.dart';
import 'ui/profiles_screen.dart';

/// The widest the app gets, in dp, so lines stay short enough to read.
const maxContentWidth = 720.0;

/// Takes a photo and returns its file path, or null if the person cancelled.
typedef TakePhoto = Future<String?> Function();

/// The colours Android 12 and later take from the wallpaper.
typedef PhoneColours = ({ColorScheme light, ColorScheme dark});

class MedicineArchiveApp extends StatelessWidget {
  const MedicineArchiveApp({
    super.key,
    required this.repository,
    required this.scanner,
    required this.takePhoto,
    this.scanBarcode,
    this.authenticate,
    this.themeMode = ThemeMode.system,
    this.backupFiles,
    this.backupCodec = const BackupCodec(),
    this.locale,
    this.phoneColours,
  });

  final ArchiveRepository repository;
  final MedicineScanner scanner;
  final TakePhoto takePhoto;

  /// Opens the live barcode scanner. Without one, Scan box goes straight
  /// to the camera.
  final ScanBarcode? scanBarcode;

  /// Keeps the app behind the phone's lock. Without one the app is open.
  final Authenticate? authenticate;
  final ThemeMode themeMode;

  /// Where backups are saved and opened from. Without it there is no
  /// Export or Import.
  final BackupFiles? backupFiles;
  final BackupCodec backupCodec;

  /// The language to show. Null follows the phone (Italian or English).
  final Locale? locale;

  /// The wallpaper's colours, offered as a switch. Null on phones without
  /// them, where the app keeps its teal.
  final PhoneColours? phoneColours;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: repository, builder: (context, _) => _app());

  Widget _app() {
    final phone = repository.phoneColours ? phoneColours : null;
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: locale,
      supportedLocales: appLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: Brand.lightTheme(phone: phone?.light),
      darkTheme: Brand.darkTheme(phone: phone?.dark),
      builder: (context, child) {
        final app = authenticate == null
            ? child!
            : AppLock(authenticate: authenticate!, child: child!);
        // On a tablet or an unfolded phone the app stays one readable column.
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: app,
            ),
          ),
        );
      },
      home: ListenableBuilder(
        listenable: repository,
        builder: (context, _) => repository.needsOnboarding
            ? OnboardingScreen(onDone: repository.completeOnboarding)
            : ProfilesScreen(
                repository: repository,
                scanner: scanner,
                takePhoto: takePhoto,
                scanBarcode: scanBarcode,
                backupFiles: backupFiles,
                backupCodec: backupCodec,
                canUsePhoneColours: phoneColours != null,
              ),
      ),
    );
  }
}
