import 'json_casts.dart';

class Farm {
  final int id;
  final int? ownerId;
  final String name;
  final String location;
  final String farmType;
  final DateTime? createdAt;

  const Farm({
    required this.id,
    this.ownerId,
    required this.name,
    this.location = '',
    this.farmType = '',
    this.createdAt,
  });

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
        id: asInt(json['id']),
        ownerId: asIntOrNull(json['owner_id']),
        name: asStr(json['farm_name'] ?? json['name'], fallback: 'Farm'),
        location: asStr(json['location']),
        farmType: asStr(json['farm_type']),
        createdAt: asDateOrNull(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (ownerId != null) 'owner_id': ownerId,
        'farm_name': name,
        'location': location,
        'farm_type': farmType,
        'created_at': createdAt?.toIso8601String(),
      };
}
