import 'json_casts.dart';

/// A farm row from the Hostinger MySQL `farms` table via get_farms.php.
class Farm {
  final int id;
  final String name;
  final String location;
  final String farmType;
  final DateTime? createdAt;

  const Farm({
    required this.id,
    required this.name,
    this.location = '',
    this.farmType = '',
    this.createdAt,
  });

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
        id: asInt(json['id']),
        name: asStr(json['farm_name'], fallback: 'Farm'),
        location: asStr(json['location']),
        farmType: asStr(json['farm_type']),
        createdAt: asDateOrNull(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'farm_name': name,
        'location': location,
        'farm_type': farmType,
        'created_at': createdAt?.toIso8601String(),
      };
}
