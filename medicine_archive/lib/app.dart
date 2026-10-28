import 'package:flutter/material.dart';

import 'data/archive_repository.dart';
import 'scan/photo_scanner.dart';
import 'ui/brand.dart';
import 'ui/profiles_screen.dart';

/// Takes a photo and returns its file path, or null if the person cancelled.
typedef TakePhoto = Future<String?> Function();

class MedicineArchiveApp extends StatelessWidget {
  const MedicineArchiveApp({
    super.key,
    required this.repository,
    required this.scanner,
    required this.takePhoto,
    this.themeMode = ThemeMode.system,
  });

  final ArchiveRepository repository;
  final MedicineScanner scanner;
  final TakePhoto takePhoto;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicine Archive',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: Brand.lightTheme(),
      darkTheme: Brand.darkTheme(),
      home: ProfilesScreen(repository: repository, scanner: scanner, takePhoto: takePhoto),
    );
  }
}
