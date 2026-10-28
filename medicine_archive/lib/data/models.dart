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
    required this.quantity,
    this.unit = '',
  });

  final String id;
  final String profileId;
  final String name;
  final int quantity;

  /// What the quantity counts, as printed on the box ("compresse", "ml").
  /// Empty when unknown.
  final String unit;

  /// "20 compresse", or just "20" when the unit is unknown.
  String get quantityLabel => unit.isEmpty ? '$quantity' : '$quantity $unit';

  Medicine copyWith({String? name, int? quantity, String? unit}) => Medicine(
        id: id,
        profileId: profileId,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
      };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        profileId: json['profileId'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        unit: json['unit'] as String? ?? '',
      );
}
