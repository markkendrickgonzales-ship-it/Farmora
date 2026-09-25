import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Immutable snapshot of the signed-in user's profile, combining Supabase
/// Auth data (email / id) with the optional public `profiles` table.
class UserProfile {
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final String phone;
  final String location;
  final bool emailConfirmed;

  const UserProfile({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.phone,
    required this.location,
    this.emailConfirmed = false,
  });

  /// What to show as the user's name: the stored full name, otherwise the
  /// email local-part, otherwise a generic label.
  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Farmora user';
  }

  /// Two-letter avatar initials derived from [displayName].
  String get initials {
    final parts =
        displayName.replaceAll(RegExp(r'[^A-Za-z ]'), '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  UserProfile copyWith({
    String? fullName,
    String? role,
    String? phone,
    String? location,
  }) {
    return UserProfile(
      userId: userId,
      email: email,
      fullName: (fullName != null && fullName.isNotEmpty) ? fullName : this.fullName,
      role: (role != null && role.isNotEmpty) ? role : this.role,
      phone: (phone != null && phone.isNotEmpty) ? phone : this.phone,
      location: (location != null && location.isNotEmpty) ? location : this.location,
      emailConfirmed: emailConfirmed,
    );
  }
}

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

  /// Insert a new feeding log entry
  static Future<void> insertFeedingLog({
    required String farmId,
    required String actionType,
    required double amount,
    required String unit,
    String triggerSource = 'manual',
    String? notes,
    String? imagePath,
  }) async {
    try {
      // Validate farm_id is UUID
      if (!_isValidUUID(farmId)) {
        throw Exception('Invalid farm ID format. Must be a UUID.');
      }

      // Validate amount
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }

      // Validate unit
      if (!['kg', 'L', 'liters'].contains(unit.toLowerCase())) {
        throw Exception('Invalid unit. Must be kg or L');
      }

      // Validate action type
      if (!['feeding', 'watering'].contains(actionType.toLowerCase())) {
        throw Exception('Invalid action type. Must be Feeding or Watering');
      }

      // Include image path in notes for now (will be properly stored when file storage is implemented)
      String enhancedNotes = notes ?? '';
      if (imagePath != null && imagePath.isNotEmpty) {
        enhancedNotes = enhancedNotes.isEmpty
            ? 'Image attached: ${imagePath.split('/').last}'
            : '$enhancedNotes\n\nImage attached: ${imagePath.split('/').last}';
      }

      await supabase.from('feeding_logs').insert({
        'farm_id': farmId,
        'action_type': actionType,
        'amount': amount,
        'unit': unit,
        'trigger_source': triggerSource,
        'notes': enhancedNotes.isNotEmpty ? enhancedNotes : null,
        'action_time': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      print('DEBUG: insertFeedingLog error = $error');
      rethrow;
    }
  }

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

  // ─── Reports ────────────────────────────────────────────────────────────

  /// Insert a new report into the database
  static Future<void> insertReport({
    required String farmId,
    required String title,
    required String category,
    required String notes,
    String? filePath,
  }) async {
    try {
      // Validate farm_id is UUID if needed
      if (!_isValidUUID(farmId)) {
        throw Exception('Invalid farm ID format');
      }

      // Prepare the insert payload with standard columns that should exist in the schema
      final payload = <String, dynamic>{
        'farm_id': farmId,
        'title': title,
        'category': category,
        'notes': notes.isNotEmpty ? notes : null,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Note: file_path/file_url column handling depends on actual database schema
      // For now, we insert without file attachment to avoid schema errors
      // TODO: Add proper file storage integration once schema is confirmed

      await supabase.from('reports').insert(payload);
    } catch (error) {
      print('DEBUG: insertReport error = $error');
      rethrow;
    }
  }

  /// Fetch recent reports for a farm
  static Future<List<Map<String, dynamic>>> fetchReports(
      String farmId, {int limit = 50}) async {
    // Skip query if farmId is not a valid UUID
    if (!_isValidUUID(farmId)) {
      print('DEBUG: fetchReports skipped - farmId is not a valid UUID: $farmId');
      return [];
    }

    final data = await supabase
        .from('reports')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ─── Farming advisories ─────────────────────────────────────────────────

  /// Returns all rows from the `farming_advisories` guide table by id.
  static Future<List<Map<String, dynamic>>> fetchAdvisories() async {
    try {
      final data = await supabase
          .from('farming_advisories')
          .select()
          .order('id', ascending: true);
      print('DEBUG: fetchAdvisories data = $data');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (error) {
      print('DEBUG: fetchAdvisories error = $error');
      rethrow;
    }
  }

  // ─── User profiles ───────────────────────────────────────────────────────

  /// The currently signed-in user (null when logged out).
  static User? get currentUser => supabase.auth.currentUser;

  /// Loads the caller's profile.
  ///
  /// Name/email come from Supabase Auth ([currentUser]); the optional
  /// public `profiles` table supplies role, phone and location. If the
  /// table doesn't exist yet the auth values alone are returned.
  static Future<UserProfile> fetchMyProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }

    final meta = user.userMetadata ?? {};
    final profile = UserProfile(
      userId: user.id,
      email: user.email ?? '',
      fullName: (meta['full_name'] as String?) ?? '',
      role: (meta['role'] as String?) ?? 'Farm manager',
      phone: (meta['phone'] as String?) ?? '',
      location: (meta['location'] as String?) ?? '',
      emailConfirmed: user.emailConfirmedAt != null,
    );

    try {
      final rows = await supabase.from('profiles').select().eq('id', user.id);
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isNotEmpty) {
        final row = list.first;
        return profile.copyWith(
          fullName: row['full_name'] as String?,
          role: row['role'] as String?,
          phone: row['phone'] as String?,
          location: row['location'] as String?,
        );
      }
    } catch (error) {
      // profiles table missing / not yet readable – auth data is enough.
      print('DEBUG: fetchMyProfile profiles lookup skipped = $error');
    }
    return profile;
  }

  /// Saves edited profile fields: upserts into the `profiles` table and
  /// mirrors them into the auth user metadata so the data survives even if
  /// the table isn't configured.
  static Future<void> updateMyProfile({
    required String fullName,
    required String role,
    required String phone,
    required String location,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }

    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': fullName,
        'role': role,
        'phone': phone,
        'location': location,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      print('DEBUG: updateMyProfile upsert failed = $error');
    }

    await supabase.auth.updateUser(
      UserAttributes(
        data: {
          'full_name': fullName,
          'role': role,
          'phone': phone,
          'location': location,
        },
      ),
    );
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
