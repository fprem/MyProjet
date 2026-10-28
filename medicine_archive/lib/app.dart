import 'package:flutter/material.dart';

import 'data/archive_repository.dart';
import 'scan/photo_scanner.dart';
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

  static const _seed = Color(0xFF00696B);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicine Archive',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark, useMaterial3: true),
      home: ProfilesScreen(repository: repository, scanner: scanner, takePhoto: takePhoto),
    );
  }
}
