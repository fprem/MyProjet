class Profile {
  const Profile({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Profile.fromJson(Map<String, dynamic> json) =>
      Profile(id: json['id'] as String, name: json['name'] as String);
}

class Medicine {
  const Medicine({
    required this.id,
    required this.profileId,
    required this.name,
    this.quantity,
    this.unit = '',
    this.strength = '',
  });

  final String id;
  final String profileId;
  final String name;

  /// How many are in the box. Null when unknown: only the name is required.
  final int? quantity;

  /// What the quantity counts, as printed on the box ("compresse", "ml").
  /// Empty when unknown.
  final String unit;

  /// How much drug is in each dose, as printed ("0,5 mg"). Empty when
  /// unknown. The same medicine often comes in several strengths.
  final String strength;

  /// "20 compresse", just "20" when the unit is unknown, or empty when the
  /// quantity is unknown.
  String get quantityLabel {
    if (quantity == null) return '';
    return unit.isEmpty ? '$quantity' : '$quantity $unit';
  }

  static const _keep = Object();

  /// Pass `quantity: null` to clear the quantity.
  Medicine copyWith({String? name, Object? quantity = _keep, String? unit, String? strength}) =>
      Medicine(
        id: id,
        profileId: profileId,
        name: name ?? this.name,
        quantity: identical(quantity, _keep) ? this.quantity : quantity as int?,
        unit: unit ?? this.unit,
        strength: strength ?? this.strength,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'strength': strength,
  };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    name: json['name'] as String,
    quantity: json['quantity'] as int?,
    unit: json['unit'] as String? ?? '',
    strength: json['strength'] as String? ?? '',
  );
}
