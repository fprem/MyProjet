import 'models.dart';

/// Tags group a profile's medicines. Three are fixed, for the time of day
/// (Morning, Noon, Evening); the others are typed by the person and shown
/// exactly as typed.
abstract final class MedicineTags {
  // Fixed tags are stored with a leading colon, so a custom tag the person
  // types as "Morning" stays their own and never becomes the fixed one.
  static const morning = ':morning';
  static const noon = ':noon';
  static const evening = ':evening';

  /// In the order of the day.
  static const fixed = [morning, noon, evening];

  static bool isFixed(String tag) => fixed.contains(tag);

  /// What the person sees for [tag].
  static String label(String tag) => switch (tag) {
    morning => 'Morning',
    noon => 'Noon',
    evening => 'Evening',
    _ => tag,
  };

  /// What the person sees for a group: [tag], or "No tag" for null.
  static String groupLabel(String? tag) => tag == null ? 'No tag' : label(tag);

  /// Trimmed, without empty or repeated tags (custom ones ignore case), the
  /// fixed ones first in the order of the day, then the custom ones as given.
  static List<String> normalize(Iterable<String> tags) {
    final trimmed = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    final custom = <String>[];
    for (final t in trimmed.where((t) => !isFixed(t))) {
      if (!custom.any((c) => c.toLowerCase() == t.toLowerCase())) custom.add(t);
    }
    return [...fixed.where(trimmed.contains), ...custom];
  }

  /// Custom tags A–Z, ignoring case.
  static int compareCustom(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
}

/// The medicines with one tag, or with no tag when [tag] is null.
class TagGroup {
  const TagGroup(this.tag, this.medicines);
  final String? tag;
  final List<Medicine> medicines;
}

/// [medicines] in groups: Morning, Noon, Evening, the custom tags A–Z, then
/// the ones with no tag. A medicine with several tags is in each of their
/// groups. Empty groups are left out; the medicines keep their order.
List<TagGroup> groupByTag(List<Medicine> medicines) {
  final custom = <String>{};
  for (final m in medicines) {
    custom.addAll(m.tags.where((t) => !MedicineTags.isFixed(t)));
  }
  final tags = [...MedicineTags.fixed, ...custom.toList()..sort(MedicineTags.compareCustom)];
  return [
    for (final tag in tags)
      if (medicines.where((m) => m.tags.contains(tag)).toList() case final list
          when list.isNotEmpty)
        TagGroup(tag, list),
    if (medicines.where((m) => m.tags.isEmpty).toList() case final list when list.isNotEmpty)
      TagGroup(null, list),
  ];
}
