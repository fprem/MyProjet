import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'archive_store.dart';
import 'backup.dart';
import 'models.dart';
import 'photo_store.dart';
import 'tags.dart';

export 'models.dart';

/// Profiles and their medicines. Every change is saved to the store at once.
class ArchiveRepository extends ChangeNotifier {
  ArchiveRepository._(this._store, this._photos);

  final ArchiveStore _store;
  final PhotoStore _photos;
  final List<Profile> _profiles = [];
  final List<Medicine> _medicines = [];
  bool _onboarded = false;

  static Future<ArchiveRepository> open(ArchiveStore store, {PhotoStore? photos}) async {
    final repo = ArchiveRepository._(store, photos ?? MemoryPhotoStore());
    final json = await store.read();
    if (json != null) {
      repo._profiles.addAll(
        (json['profiles'] as List).map((p) => Profile.fromJson(p as Map<String, dynamic>)),
      );
      repo._medicines.addAll(
        (json['medicines'] as List).map((m) => Medicine.fromJson(m as Map<String, dynamic>)),
      );
      // Archives from before the welcome screens: anyone with profiles has
      // already found their way around.
      repo._onboarded = json['onboarded'] as bool? ?? repo._profiles.isNotEmpty;
    }
    return repo;
  }

  /// Whether to show the welcome screens: only at the very first start.
  bool get needsOnboarding => !_onboarded;

  Future<void> completeOnboarding() async {
    _onboarded = true;
    await _save();
  }

  /// All profiles, sorted by name.
  List<Profile> get profiles => List.unmodifiable(
    [..._profiles]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );

  /// The medicines of one profile, sorted by name: the ones being taken, or
  /// with [archived] the ones the person stopped taking.
  List<Medicine> medicinesOf(String profileId, {bool archived = false}) => List.unmodifiable(
    _medicines.where((m) => m.profileId == profileId && m.archived == archived).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );

  Future<Profile> createProfile(String name) async {
    final profile = Profile(id: _newId(), name: _requireName(name));
    _profiles.add(profile);
    await _save();
    return profile;
  }

  Future<void> deleteProfile(String profileId) async {
    final gone = _medicines.where((m) => m.profileId == profileId).toList();
    _profiles.removeWhere((p) => p.id == profileId);
    _medicines.removeWhere((m) => m.profileId == profileId);
    await _save();
    for (final m in gone) {
      if (m.hasPhoto) await _photos.delete(m.id);
    }
  }

  Future<Medicine> addMedicine(
    String profileId, {
    required String name,
    int? quantity,
    String unit = '',
    String strength = '',
    List<String> tags = const [],
    Uint8List? photo,
  }) async {
    if (!_profiles.any((p) => p.id == profileId)) {
      throw ArgumentError.value(profileId, 'profileId', 'No such profile');
    }
    final medicine = _validate(
      Medicine(
        id: _newId(),
        profileId: profileId,
        name: name,
        quantity: quantity,
        unit: unit,
        strength: strength,
        tags: tags,
        hasPhoto: photo != null,
      ),
    );
    if (photo != null) await _photos.write(medicine.id, photo);
    _medicines.add(medicine);
    await _save();
    return medicine;
  }

  Future<void> updateMedicine(Medicine medicine) async {
    final index = _medicines.indexWhere((m) => m.id == medicine.id);
    if (index < 0) throw ArgumentError.value(medicine.id, 'id', 'No such medicine');
    // The photo and the archive are changed only through their own methods.
    final current = _medicines[index];
    _medicines[index] = _validate(
      medicine.copyWith(hasPhoto: current.hasPhoto, archived: current.archived),
    );
    await _save();
  }

  Future<void> deleteMedicine(String medicineId) async {
    _medicines.removeWhere((m) => m.id == medicineId);
    await _save();
    await _photos.delete(medicineId);
  }

  /// The kept photo of [medicine]'s box, or null.
  Future<Uint8List?> photoOf(Medicine medicine) async =>
      medicine.hasPhoto ? _photos.read(medicine.id) : null;

  /// Moves a medicine to the archive (stopped taking it), or back.
  Future<void> setArchived(String medicineId, bool archived) async {
    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index < 0) throw ArgumentError.value(medicineId, 'id', 'No such medicine');
    _medicines[index] = _medicines[index].copyWith(archived: archived);
    await _save();
  }

  /// Replaces the tags of a medicine.
  Future<void> setTags(String medicineId, List<String> tags) async {
    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index < 0) throw ArgumentError.value(medicineId, 'id', 'No such medicine');
    _medicines[index] = _medicines[index].copyWith(tags: MedicineTags.normalize(tags));
    await _save();
  }

  /// Moves a medicine from the group of tag [from] to the group of tag [to]
  /// (null is the "No tag" group): [from] is swapped for [to], and its other
  /// tags are kept. Returns the tags it had, for Undo.
  Future<List<String>> moveToTag(
    String medicineId, {
    required String? from,
    required String? to,
  }) async {
    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index < 0) throw ArgumentError.value(medicineId, 'id', 'No such medicine');
    final before = _medicines[index].tags;
    await setTags(medicineId, [...before.where((t) => t != from), ?to]);
    return before;
  }

  /// The custom tags used by a profile's medicines, archived ones too, A–Z.
  List<String> customTagsOf(String profileId) {
    final tags = <String>[];
    for (final m in _medicines.where((m) => m.profileId == profileId)) {
      for (final t in m.tags.where((t) => !MedicineTags.isFixed(t))) {
        if (!tags.any((c) => c.toLowerCase() == t.toLowerCase())) tags.add(t);
      }
    }
    return tags..sort(MedicineTags.compareCustom);
  }

  /// Keeps [bytes] as the photo of a medicine's box, encrypted.
  Future<void> setPhoto(String medicineId, Uint8List bytes) async {
    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index < 0) throw ArgumentError.value(medicineId, 'id', 'No such medicine');
    await _photos.write(medicineId, bytes);
    _medicines[index] = _medicines[index].copyWith(hasPhoto: true);
    await _save();
  }

  /// Deletes the kept photo and keeps the medicine.
  Future<void> removePhoto(String medicineId) async {
    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index < 0) return;
    _medicines[index] = _medicines[index].copyWith(hasPhoto: false);
    await _save();
    await _photos.delete(medicineId);
  }

  static const _backupFormat = 'medicine-archive-backup';

  /// Everything, kept photos included, for a backup file (see [BackupCodec]).
  Future<Map<String, dynamic>> exportData() async => {
    'format': _backupFormat,
    'version': 1,
    'profiles': _profiles.map((p) => p.toJson()).toList(),
    'medicines': _medicines.map((m) => m.toJson()).toList(),
    'photos': {
      for (final m in _medicines.where((m) => m.hasPhoto))
        if (await _photos.read(m.id) case final bytes?) m.id: base64Encode(bytes),
    },
  };

  /// Replaces everything on this phone with a backup from [exportData].
  /// Throws [BackupException], changing nothing, when it isn't one.
  Future<void> importData(Map<String, dynamic> backup) async {
    final List<Profile> profiles;
    final List<Medicine> medicines;
    final Map<String, Uint8List> photos;
    try {
      if (backup['format'] != _backupFormat) throw const FormatException();
      profiles = [
        for (final p in backup['profiles'] as List) Profile.fromJson(p as Map<String, dynamic>),
      ];
      medicines = [
        for (final m in backup['medicines'] as List) Medicine.fromJson(m as Map<String, dynamic>),
      ];
      final ids = {for (final m in medicines) m.id};
      photos = {
        for (final MapEntry(:key, :value)
            in (backup['photos'] as Map<String, dynamic>? ?? const {}).entries)
          if (ids.contains(key) && _safeId.hasMatch(key)) key: base64Decode(value as String),
      };
    } catch (_) {
      throw const BackupException("This file isn't a Medicine Archive backup.");
    }
    final gone = _medicines.where((m) => m.hasPhoto).map((m) => m.id).toList();
    for (final id in gone) {
      await _photos.delete(id);
    }
    for (final MapEntry(:key, :value) in photos.entries) {
      await _photos.write(key, value);
    }
    _profiles
      ..clear()
      ..addAll(profiles);
    _medicines
      ..clear()
      ..addAll(medicines.map((m) => m.copyWith(hasPhoto: photos.containsKey(m.id))));
    _onboarded = true;
    await _save();
  }

  Medicine _validate(Medicine m) {
    if (m.quantity case final q? when q < 0) {
      throw ArgumentError.value(m.quantity, 'quantity', 'Must not be negative');
    }
    return Medicine(
      id: m.id,
      profileId: m.profileId,
      name: _requireName(m.name),
      quantity: m.quantity,
      unit: m.unit.trim(),
      strength: m.strength.trim(),
      hasPhoto: m.hasPhoto,
      archived: m.archived,
      tags: MedicineTags.normalize(m.tags),
    );
  }

  static String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'Must not be empty');
    return trimmed;
  }

  static final _safeId = RegExp(r'^[A-Za-z0-9_-]+$');

  static final _random = Random.secure();

  static String _newId() =>
      List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  Future<void> _save() async {
    await _store.write({
      'profiles': _profiles.map((p) => p.toJson()).toList(),
      'medicines': _medicines.map((m) => m.toJson()).toList(),
      'onboarded': _onboarded,
    });
    notifyListeners();
  }
}
