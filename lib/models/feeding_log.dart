import 'json_casts.dart';

/// One feeding / watering entry from the `feeding_logs` table, served by
/// get_logs.php and written by add_log.php.
class FeedingLog {
  final int id;
  final int farmId;
  final String actionType;
  final double amount;
  final String unit;
  final String triggerSource;
  final String? notes;

  /// Public URL of the photo uploaded through upload_file.php, if any.
  final String? imageUrl;
  final DateTime actionTime;

  const FeedingLog({
    required this.id,
    required this.farmId,
    required this.actionType,
    required this.amount,
    required this.unit,
    this.triggerSource = 'manual',
    this.notes,
    this.imageUrl,
    required this.actionTime,
  });

  factory FeedingLog.fromJson(Map<String, dynamic> json) => FeedingLog(
        id: asInt(json['id']),
        farmId: asInt(json['farm_id']),
        actionType: asStr(json['action_type'], fallback: 'Feeding'),
        amount: asDouble(json['amount']),
        unit: asStr(json['unit'], fallback: 'kg'),
        triggerSource: asStr(json['trigger_source'], fallback: 'manual'),
        notes: asStrOrNull(json['notes']),
        imageUrl: asStrOrNull(json['image_url']),
        actionTime: asDate(json['action_time']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'farm_id': farmId,
        'action_type': actionType,
        'amount': amount,
        'unit': unit,
        'trigger_source': triggerSource,
        'notes': notes,
        'image_url': imageUrl,
        'action_time': actionTime.toIso8601String(),
      };

  /// 'Feeding' rows render 🌾, 'Watering' rows 💧 (same rule as Farm Logs).
  bool get isFeeding => actionType.toLowerCase().contains('feed');
  bool get isWatering => actionType.toLowerCase().contains('water');
}
