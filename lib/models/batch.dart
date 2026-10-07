import 'json_casts.dart';

class Batch {
  final int id;
  final int? ownerId;
  final int farmId;
  final DateTime startDate;
  final int flockSize;
  final String status;
  final DateTime? createdAt;

  const Batch({
    required this.id,
    this.ownerId,
    required this.farmId,
    required this.startDate,
    this.flockSize = 0,
    this.status = 'active',
    this.createdAt,
  });

  factory Batch.fromJson(Map<String, dynamic> json) => Batch(
        id: asInt(json['id']),
        ownerId: asIntOrNull(json['owner_id']),
        farmId: asInt(json['farm_id']),
        startDate: asDate(json['start_date']),
        flockSize: asInt(json['flock_size']),
        status: asStr(json['status'], fallback: 'active'),
        createdAt: asDateOrNull(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (ownerId != null) 'owner_id': ownerId,
        'farm_id': farmId,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'flock_size': flockSize,
        'status': status,
        'created_at': createdAt?.toIso8601String(),
      };
}
