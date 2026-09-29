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
    final parts = displayName
        .replaceAll(RegExp(r'[^A-Za-z ]'), '')
        .trim()
        .split(RegExp(r'\s+'));
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
      fullName:
          (fullName != null && fullName.isNotEmpty) ? fullName : this.fullName,
      role: (role != null && role.isNotEmpty) ? role : this.role,
      phone: (phone != null && phone.isNotEmpty) ? phone : this.phone,
      location:
          (location != null && location.isNotEmpty) ? location : this.location,
      emailConfirmed: emailConfirmed,
    );
  }
}

class FarmService {
  // ── Helpers ─────────────────────────────────────────────────────────────

  static bool _isValidUUID(String value) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(value);
  }

  // ── Per-user ownership scoping ──────────────────────────────────────────
  //
  // Migration 0002 adds an owner column and RLS policies to every app-facing
  // table. RLS is the real enforcement (server-side); these client filters are
  // defence-in-depth so the correct subset is requested even before RLS is
  // tuned, and so a leaked anon key can't trivially read another user's rows.
  //
  // The owner column per table is fixed by migration 0002, so it is declared
  // statically rather than discovered at runtime (PostgREST does not expose
  // information_schema to the authenticated role). If a query fails because
  // the column is not present yet — i.e. the migration has not been applied —
  // the table is remembered as "unscoped" and the query is retried without
  // the owner filter, so the app keeps working against a pre-0002 database.

  /// Table -> column that stores the owning auth user id (from migration 0002).
  /// Farm-linked device tables (sensor_telemetry, alerts) are intentionally
  /// absent: they have no owner column and are isolated via RLS + the scoped
  /// farm ids callers pass in.
  static const Map<String, String> _ownerColumnByTable = {
    'farms': 'owner_id',
    'batches': 'owner_id',
    'feeding_logs': 'user_id',
    'reports': 'user_id',
    'vitamin_logs': 'logged_by',
  };

  /// Tables where the owner column turned out to be missing (migration not
  /// applied): skip client scoping for them after the first failure.
  static final Set<String> _unscopedTables = {};

  static bool _isMissingColumnError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('column') &&
        (s.contains('does not exist') || s.contains('not found'));
  }

  /// Runs `select` on [table], scoped to the signed-in user wherever the
  /// schema supports it. Filters are applied before the order/limit transforms
  /// because PostgREST forbids filtering after ordering.
  ///
  /// Owner-column tables are filtered client-side by the current user id.
  /// Farm-linked device tables (sensor_telemetry / alerts) are NOT filtered
  /// here — their farm ids are integers that don't compare reliably against
  /// the text id list, and the ids callers pass already come from the scoped
  /// [fetchFarms]. Row Level Security (migration 0002) enforces isolation for
  /// those tables server-side.
  static Future<List<dynamic>> _ownedSelect(String table,
      {String columns = '*',
      String? eqColumn,
      dynamic eqValue,
      String? orderColumn,
      bool ascending = true,
      int? limit}) async {
    // Returns a fresh builder each call — the chain mutates via `dynamic`.
    Future<List<dynamic>> run(bool scope) async {
      dynamic builder = supabase.from(table).select(columns);
      if (eqColumn != null) builder = builder.eq(eqColumn, eqValue);
      if (scope) {
        final userId = supabase.auth.currentUser?.id;
        final ownerCol = _ownerColumnByTable[table];
        if (userId != null && ownerCol != null) {
          builder = builder.eq(ownerCol, userId);
        }
      }
      if (orderColumn != null) {
        builder = builder.order(orderColumn, ascending: ascending);
      }
      if (limit != null) builder = builder.limit(limit);
      final data = await builder;
      return data as List;
    }

    // Only owner-column tables are client-scoped; farm-linked tables fall
    // through to unscoped reads guarded by RLS.
    final shouldScope = _ownerColumnByTable.containsKey(table) &&
        !_unscopedTables.contains(table);
    if (!shouldScope) return run(false);

    try {
      return await run(true);
    } catch (e) {
      if (_isMissingColumnError(e)) {
        // Migration 0002 not applied on this project yet: fall back to
        // unscoped reads (RLS may still be off) and remember not to retry.
        print(
            'DEBUG: FarmService.$table owner column missing - RLS migration '
            'not applied? Falling back to unscoped query.');
        _unscopedTables.add(table);
        return run(false);
      }
      rethrow;
    }
  }

  /// Inserts [payload] into [table], stamping the caller into the table's owner
  /// column (migration 0002). If that column is not present yet — migration not
  /// applied — the insert is retried without it so writes keep working.
  static Future<void> _ownedInsert(
      String table, Map<String, dynamic> payload) async {
    final ownerCol = _ownerColumnByTable[table];
    final userId = supabase.auth.currentUser?.id;
    final scoped = <String, dynamic>{
      ...payload,
      if (ownerCol != null && userId != null) ownerCol: userId,
    };
    try {
      await supabase.from(table).insert(scoped);
    } catch (e) {
      if (ownerCol != null && _isMissingColumnError(e)) {
        print(
            'DEBUG: FarmService.$table owner column missing on insert - '
            'retrying without it.');
        scoped.remove(ownerCol);
        await supabase.from(table).insert(scoped);
        return;
      }
      rethrow;
    }
  }

  // ─── Farms ───────────────────────────────────────────────────────────────

  /// Returns the farms belonging to the signed-in user, ordered by farm_name.
  static Future<List<Map<String, dynamic>>> fetchFarms() async {
    try {
      final data =
          await _ownedSelect('farms', orderColumn: 'farm_name', ascending: true);
      print('DEBUG: fetchFarms data = $data');
      return List<Map<String, dynamic>>.from(data);
    } catch (error) {
      print('DEBUG: fetchFarms error = $error');
      rethrow;
    }
  }

  /// Returns unique farms from telemetry data (for UUID-based operations like
  /// feeding logs). Scoped through farm ownership so a user only ever sees
  /// telemetry belonging to their own farms.
  static Future<List<Map<String, dynamic>>> fetchTelemetryFarms() async {
    try {
      final data = await _ownedSelect('sensor_telemetry', columns: 'farm_id');

      // Extract unique farm_ids (column may arrive as int or String).
      final uniqueFarmIds = <String>{};
      for (final row in data) {
        final farmId = row['farm_id']?.toString();
        if (farmId != null && farmId.isNotEmpty) {
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
        print(
            'DEBUG: fetchLatestTelemetry skipped - farmId is not a valid UUID: $farmId');
        return null;
      }

      final data = await _ownedSelect(
        'sensor_telemetry',
        eqColumn: 'farm_id',
        eqValue: farmId,
        orderColumn: 'recorded_at',
        ascending: false,
        limit: 1,
      );

      print('DEBUG: fetchLatestTelemetry data = $data');
      final list = List<Map<String, dynamic>>.from(data);
      return list.isEmpty ? null : list.first;
    } catch (error) {
      print('DEBUG: fetchLatestTelemetry error = $error');
      rethrow;
    }
  }

  /// Returns the last [limit] telemetry rows for [farmId], newest first.
  static Future<List<Map<String, dynamic>>> fetchTelemetryHistory(String farmId,
      {int limit = 20}) async {
    // Skip query if farmId is not a valid UUID (e.g., integer from farms table)
    if (!_isValidUUID(farmId)) {
      print(
          'DEBUG: fetchTelemetryHistory skipped - farmId is not a valid UUID: $farmId');
      return [];
    }

    final data = await _ownedSelect(
      'sensor_telemetry',
      eqColumn: 'farm_id',
      eqValue: farmId,
      orderColumn: 'recorded_at',
      ascending: false,
      limit: limit,
    );
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Alerts ──────────────────────────────────────────────────────────────

  /// Returns the most recent alerts for [farmId], newest first.
  static Future<List<Map<String, dynamic>>> fetchRecentAlerts(String farmId,
      {int limit = 10}) async {
    // Alerts table uses integer farm_id, so convert string to int
    final farmIdInt = int.tryParse(farmId);
    if (farmIdInt == null) {
      print(
          'DEBUG: fetchRecentAlerts skipped - farmId is not a valid integer: $farmId');
      return [];
    }

    final data = await _ownedSelect(
      'alerts',
      eqColumn: 'farm_id',
      eqValue: farmIdInt,
      orderColumn: 'created_at',
      ascending: false,
      limit: limit,
    );
    return List<Map<String, dynamic>>.from(data);
  }

  /// Returns the most recent alerts across **all** farms the caller owns,
  /// newest first. Used when the caller only holds the telemetry UUID farm id
  /// (the `alerts` table is keyed by the integer farm id).
  static Future<List<Map<String, dynamic>>> fetchRecentAlertsAnyFarm(
      {int limit = 10}) async {
    final data = await _ownedSelect(
      'alerts',
      orderColumn: 'created_at',
      ascending: false,
      limit: limit,
    );
    return List<Map<String, dynamic>>.from(data);
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

      await _ownedInsert('feeding_logs', {
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
  /// Also scoped to the caller via the `user_id` owner column.
  static Future<List<Map<String, dynamic>>> fetchFeedingLogs(String farmId,
      {int limit = 50}) async {
    // Skip query if farmId is not a valid UUID (e.g., integer from farms table)
    if (!_isValidUUID(farmId)) {
      print(
          'DEBUG: fetchFeedingLogs skipped - farmId is not a valid UUID: $farmId');
      return [];
    }

    final data = await _ownedSelect(
      'feeding_logs',
      eqColumn: 'farm_id',
      eqValue: farmId,
      orderColumn: 'action_time',
      ascending: false,
      limit: limit,
    );
    return List<Map<String, dynamic>>.from(data);
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

      await _ownedInsert('reports', payload);
    } catch (error) {
      print('DEBUG: insertReport error = $error');
      rethrow;
    }
  }

  /// Fetch recent reports for a farm, scoped to the caller's `user_id`.
  static Future<List<Map<String, dynamic>>> fetchReports(String farmId,
      {int limit = 50}) async {
    // Skip query if farmId is not a valid UUID
    if (!_isValidUUID(farmId)) {
      print(
          'DEBUG: fetchReports skipped - farmId is not a valid UUID: $farmId');
      return [];
    }

    final data = await _ownedSelect(
      'reports',
      eqColumn: 'farm_id',
      eqValue: farmId,
      orderColumn: 'created_at',
      ascending: false,
      limit: limit,
    );
    return List<Map<String, dynamic>>.from(data);
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
