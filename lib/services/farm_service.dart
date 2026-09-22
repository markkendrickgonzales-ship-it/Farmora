import 'supabase_client.dart';

class FarmService {
  // ── Helpers ─────────────────────────────────────────────────────────────
  
  static bool _isValidUUID(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    );
    return uuidRegex.hasMatch(value);
  }
  // ─── Farms ───────────────────────────────────────────────────────────────

  /// Returns all farms ordered by farm_name.
  static Future<List<Map<String, dynamic>>> fetchFarms() async {
    try {
      final data = await supabase
          .from('farms')
          .select()
          .order('farm_name', ascending: true);
      print('DEBUG: fetchFarms data = $data');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (error) {
      print('DEBUG: fetchFarms error = $error');
      rethrow;
    }
  }

  /// Returns unique farms from telemetry data (for UUID-based operations like feeding logs)
  static Future<List<Map<String, dynamic>>> fetchTelemetryFarms() async {
    try {
      final data = await supabase
          .from('sensor_telemetry')
          .select('farm_id');
      
      // Extract unique farm_ids
      final uniqueFarmIds = <String>{};
      for (final row in data) {
        final farmId = row['farm_id'] as String?;
        if (farmId != null) {
          uniqueFarmIds.add(farmId);
        }
      }
      
      // Return as list of maps with farm_id
      final result = uniqueFarmIds.map((id) => {'farm_id': id}).toList();
      print('DEBUG: fetchTelemetryFarms data = $result');
      return result;
    } catch (error) {
      print('DEBUG: fetchTelemetryFarms error = $error');
      rethrow;
    }
  }

  // ─── Telemetry ───────────────────────────────────────────────────────────

  /// Returns the single most-recent telemetry row for [farmId],
  /// or null if no records exist yet.
  static Future<Map<String, dynamic>?> fetchLatestTelemetry(
      String farmId) async {
    try {
      // Skip query if farmId is not a valid UUID (e.g., integer from farms table)
      if (!_isValidUUID(farmId)) {
        print('DEBUG: fetchLatestTelemetry skipped - farmId is not a valid UUID: $farmId');
        return null;
      }
      
      final data = await supabase
          .from('sensor_telemetry')
          .select()
          .eq('farm_id', farmId)
          .order('recorded_at', ascending: false)
          .limit(1);
      
      print('DEBUG: fetchLatestTelemetry data = $data');
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.isEmpty ? null : list.first;
    } catch (error) {
      print('DEBUG: fetchLatestTelemetry error = $error');
      rethrow;
    }
  }

  /// Returns the last [limit] telemetry rows for [farmId], newest first.
  static Future<List<Map<String, dynamic>>> fetchTelemetryHistory(
      String farmId, {int limit = 20}) async {
    // Skip query if farmId is not a valid UUID (e.g., integer from farms table)
    if (!_isValidUUID(farmId)) {
      print('DEBUG: fetchTelemetryHistory skipped - farmId is not a valid UUID: $farmId');
      return [];
    }
    
    final data = await supabase
        .from('sensor_telemetry')
        .select()
        .eq('farm_id', farmId)
        .order('recorded_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ─── Alerts ──────────────────────────────────────────────────────────────

  /// Returns the most recent alerts for [farmId], newest first.
  static Future<List<Map<String, dynamic>>> fetchRecentAlerts(
      String farmId, {int limit = 10}) async {
    // Alerts table uses integer farm_id, so convert string to int
    final farmIdInt = int.tryParse(farmId);
    if (farmIdInt == null) {
      print('DEBUG: fetchRecentAlerts skipped - farmId is not a valid integer: $farmId');
      return [];
    }
    
    final data = await supabase
        .from('alerts')
        .select()
        .eq('farm_id', farmIdInt)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ─── Feeding logs ────────────────────────────────────────────────────────

  /// Returns recent feeding-log rows for [farmId], newest first.
  static Future<List<Map<String, dynamic>>> fetchFeedingLogs(
      String farmId, {int limit = 50}) async {
    // Skip query if farmId is not a valid UUID (e.g., integer from farms table)
    if (!_isValidUUID(farmId)) {
      print('DEBUG: fetchFeedingLogs skipped - farmId is not a valid UUID: $farmId');
      return [];
    }
    
    final data = await supabase
        .from('feeding_logs')
        .select()
        .eq('farm_id', farmId)
        .order('action_time', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Aggregates total feed (kg) and water (L) from [feedingLogs] for today.
  static ({double feedKg, double waterL}) aggregateTodayUsage(
      List<Map<String, dynamic>> feedingLogs) {
    final now = DateTime.now();
    double feed = 0;
    double water = 0;

    for (final row in feedingLogs) {
      final ts = DateTime.tryParse(row['action_time'] as String? ?? '');
      if (ts == null) continue;
      if (ts.year != now.year || ts.month != now.month || ts.day != now.day) {
        continue;
      }
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final unit = (row['unit'] as String? ?? '').toLowerCase();
      final type = (row['action_type'] as String? ?? '').toLowerCase();

      if (type.contains('feed') || unit == 'kg') {
        feed += amount;
      } else if (type.contains('water') || unit == 'l' || unit == 'liters') {
        water += amount;
      }
    }
    return (feedKg: feed, waterL: water);
  }
}
