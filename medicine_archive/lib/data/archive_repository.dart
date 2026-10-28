import 'dart:math';

import 'package:flutter/foundation.dart';

import 'archive_store.dart';
import 'models.dart';

export 'models.dart';

/// Profiles and their medicines. Every change is saved to the store at once.
class ArchiveRepository extends ChangeNotifier {
  ArchiveRepository._(this._store);

  final ArchiveStore _store;
  final List<Profile> _profiles = [];
  final List<Medicine> _medicines = [];

  static Future<ArchiveRepository> open(ArchiveStore store) async {
    final repo = ArchiveRepository._(store);
    final json = await store.read();
    if (json != null) {
      repo._profiles.addAll(
        (json['profiles'] as List).map((p) => Profile.fromJson(p as Map<String, dynamic>)),
      );
      repo._medicines.addAll(
        (json['medicines'] as List).map((m) => Medicine.fromJson(m as Map<String, dynamic>)),
      );
    }
    return repo;
  }

  /// All profiles, sorted by name.
  List<Profile> get profiles => List.unmodifiable(
    [..._profiles]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );

  /// The medicines of one profile, sorted by name.
  List<Medicine> medicinesOf(String profileId) => List.unmodifiable(
    _medicines.where((m) => m.profileId == profileId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );

  Future<Profile> createProfile(String name) async {
    final profile = Profile(id: _newId(), name: _requireName(name));
    _profiles.add(profile);
    await _save();
    return profile;
  }

  Future<void> deleteProfile(String profileId) async {
    _profiles.removeWhere((p) => p.id == profileId);
    _medicines.removeWhere((m) => m.profileId == profileId);
    await _save();
  }

  Future<Medicine> addMedicine(
    String profileId, {
    required String name,
    required int quantity,
    String unit = '',
  }) async {
    if (!_profiles.any((p) => p.id == profileId)) {
      throw ArgumentError.value(profileId, 'profileId', 'No such profile');
    }
    final medicine = _validate(
      Medicine(id: _newId(), profileId: profileId, name: name, quantity: quantity, unit: unit),
    );
    _medicines.add(medicine);
    await _save();
    return medicine;
  }

  Future<void> updateMedicine(Medicine medicine) async {
    final index = _medicines.indexWhere((m) => m.id == medicine.id);
    if (index < 0) throw ArgumentError.value(medicine.id, 'id', 'No such medicine');
    _medicines[index] = _validate(medicine);
    await _save();
  }

  Future<void> deleteMedicine(String medicineId) async {
    _medicines.removeWhere((m) => m.id == medicineId);
    await _save();
  }

  Medicine _validate(Medicine m) {
    if (m.quantity < 0) {
      throw ArgumentError.value(m.quantity, 'quantity', 'Must not be negative');
    }
    return Medicine(
      id: m.id,
      profileId: m.profileId,
      name: _requireName(m.name),
      quantity: m.quantity,
      unit: m.unit.trim(),
    );
  }

  static String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'Must not be empty');
    return trimmed;
  }

  static final _random = Random.secure();

  static String _newId() =>
      List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  Future<void> _save() async {
    await _store.write({
      'profiles': _profiles.map((p) => p.toJson()).toList(),
      'medicines': _medicines.map((m) => m.toJson()).toList(),
    });
    notifyListeners();
  }
}
