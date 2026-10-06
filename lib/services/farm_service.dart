import 'api_service.dart';
import 'auth_service.dart';
import '../models/farm.dart';
import '../models/feeding_log.dart';
import '../models/report.dart';

/// Immutable snapshot of the signed-in user's profile, served by the Hostinger
/// PHP backend (get_profile.php) from the MySQL `users` table.
class UserProfile {
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final String phone;
  final String location;

  /// Accounts created through the PHP backend are active immediately, so
  /// this defaults to true; the field stays for the profile badge.
  final bool emailConfirmed;

  const UserProfile({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.phone,
    required this.location,
    this.emailConfirmed = true,
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

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['id']?.toString() ?? AuthService.instance.userIdStr,
        email: json['email'] as String? ?? AuthService.instance.email,
        fullName: json['full_name'] as String? ?? '',
        role: json['role'] as String? ?? 'Farm manager',
        phone: json['phone'] as String? ?? '',
        location: json['location'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': userId,
        'email': email,
        'full_name': fullName,
        'role': role,
        'phone': phone,
        'location': location,
      };
}

/// Data layer for the app, talking to the Hostinger PHP REST backend through
/// [ApiService]. Per-user isolation that RLS provided on Supabase is now
/// enforced server-side: every PHP script filters rows by the bearer token's
/// user id, so the client simply asks for "my" data.
class FarmService {
  // ─── Farms ───────────────────────────────────────────────────────────────

  /// Returns the farms belonging to the signed-in user, ordered by name.
  static Future<List<Farm>> fetchFarms() async {
    final data = await ApiService.instance.get('get_farms.php');
    return (data as List)
        .map((r) => Farm.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ─── Telemetry ───────────────────────────────────────────────────────────

  /// Returns the single most-recent telemetry row for [farmId],
  /// or null if no records exist yet.
  static Future<Map<String, dynamic>?> fetchLatestTelemetry(int farmId) async {
    final data = await ApiService.instance
        .get('get_telemetry.php', query: {'farm_id': '$farmId', 'mode': 'latest'});
    final list = List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    return list.isEmpty ? null : list.first;
  }

  /// Returns the last [limit] telemetry rows for [farmId], newest first.
  static Future<List<Map<String, dynamic>>> fetchTelemetryHistory(
      int farmId, {int limit = 20}) async {
    final data = await ApiService.instance.get('get_telemetry.php', query: {
      'farm_id': '$farmId',
      'mode': 'history',
      'limit': '$limit',
    });
    return List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  // ─── Alerts ──────────────────────────────────────────────────────────────

  /// Returns the most recent alerts for [farmId], newest first.
  static Future<List<Map<String, dynamic>>> fetchRecentAlerts(int farmId,
      {int limit = 10}) async {
    final data = await ApiService.instance
        .get('get_alerts.php', query: {'farm_id': '$farmId', 'limit': '$limit'});
    return List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  /// Returns the most recent alerts across **all** farms the caller owns,
  /// newest first. Used when no specific farm id is at hand.
  static Future<List<Map<String, dynamic>>> fetchRecentAlertsAnyFarm(
      {int limit = 10}) async {
    final data = await ApiService.instance
        .get('get_alerts.php', query: {'limit': '$limit'});
    return List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  // ─── Feeding logs ────────────────────────────────────────────────────────

  /// Inserts a feeding log via add_log.php. When [imagePath] points at a
  /// local photo it is uploaded first through upload_file.php and the
  /// returned URL is stored on the row.
  static Future<void> insertFeedingLog({
    required int farmId,
    required String actionType,
    required double amount,
    required String unit,
    String triggerSource = 'manual',
    String? notes,
    String? imagePath,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }
    if (!['kg', 'L', 'liters'].contains(unit.toLowerCase())) {
      throw Exception('Invalid unit. Must be kg or L');
    }
    if (!['feeding', 'watering'].contains(actionType.toLowerCase())) {
      throw Exception('Invalid action type. Must be Feeding or Watering');
    }

    String? imageUrl;
    if (imagePath != null && imagePath.isNotEmpty) {
      imageUrl = await _uploadFile(imagePath, folder: 'feeding_logs');
    }

    await ApiService.instance.post('add_log.php', {
      'farm_id': farmId,
      'action_type': actionType,
      'amount': amount,
      'unit': unit,
      'trigger_source': triggerSource,
      'notes': (notes != null && notes.trim().isNotEmpty)
          ? notes.trim()
          : null,
      'image_url': imageUrl,
      'action_time': DateTime.now().toIso8601String(),
    });
  }

  /// Returns recent feeding-log entries for [farmId], newest first.
  static Future<List<FeedingLog>> fetchFeedingLogs(int farmId,
      {int limit = 50}) async {
    final data = await ApiService.instance
        .get('get_logs.php', query: {'farm_id': '$farmId', 'limit': '$limit'});
    return (data as List? ?? [])
        .map((r) => FeedingLog.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ─── Reports ────────────────────────────────────────────────────────────

  /// Inserts a report via add_report.php, uploading the attachment at
  /// [filePath] (photo or document) through upload_file.php first when set.
  static Future<void> insertReport({
    required int farmId,
    required String title,
    required String category,
    required String notes,
    String? filePath,
  }) async {
    String? fileUrl;
    if (filePath != null && filePath.isNotEmpty) {
      fileUrl = await _uploadFile(filePath, folder: 'reports');
    }

    await ApiService.instance.post('add_report.php', {
      'farm_id': farmId,
      'title': title,
      'category': category,
      'notes': notes.isNotEmpty ? notes : null,
      'file_url': fileUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Fetch recent reports for a farm, newest first.
  static Future<List<Report>> fetchReports(int farmId, {int limit = 50}) async {
    final data = await ApiService.instance
        .get('get_reports.php', query: {'farm_id': '$farmId', 'limit': '$limit'});
    return (data as List? ?? [])
        .map((r) => Report.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ─── Farming advisories ─────────────────────────────────────────────────

  /// Returns all rows from the `farming_advisories` guide table.
  static Future<List<Map<String, dynamic>>> fetchAdvisories() async {
    final data = await ApiService.instance.get('get_advisories.php');
    return List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  // ─── User profile ───────────────────────────────────────────────────────

  /// The currently signed-in user id (null when logged out).
  static String? get currentUserId =>
      AuthService.instance.isSignedIn ? AuthService.instance.userIdStr : null;

  /// Loads the caller's profile from get_profile.php.
  static Future<UserProfile> fetchMyProfile() async {
    if (!AuthService.instance.isSignedIn) {
      throw Exception('Not signed in');
    }
    final data = await ApiService.instance.get('get_profile.php');
    return UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Saves edited profile fields through update_profile.php and mirrors the
  /// name into the local session cache.
  static Future<void> updateMyProfile({
    required String fullName,
    required String role,
    required String phone,
    required String location,
  }) async {
    if (!AuthService.instance.isSignedIn) {
      throw Exception('Not signed in');
    }
    await ApiService.instance.post('update_profile.php', {
      'full_name': fullName,
      'role': role,
      'phone': phone,
      'location': location,
    });
    await AuthService.instance.updateCachedName(fullName);
  }

  // ─── File uploads ───────────────────────────────────────────────────────

  /// Uploads [filePath] to upload_file.php and returns the public URL the
  /// backend stores for it (throwing [ApiException] on failure).
  static Future<String> _uploadFile(String filePath, {required String folder}) async {
    final data = await ApiService.instance
        .uploadMultipart(filePath, fields: {'folder': folder});
    final url = (data as Map?)?['url']?.toString();
    if (url == null || url.isEmpty) {
      throw ApiException('Upload succeeded but no file URL was returned');
    }
    return url;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Aggregates total feed (kg) and water (L) from [feedingLogs] for today.
  static ({double feedKg, double waterL}) aggregateTodayUsage(
      List<FeedingLog> feedingLogs) {
    final now = DateTime.now();
    double feed = 0;
    double water = 0;

    for (final log in feedingLogs) {
      final ts = log.actionTime;
      if (ts.year != now.year || ts.month != now.month || ts.day != now.day) {
        continue;
      }
      final unit = log.unit.toLowerCase();
      final type = log.actionType.toLowerCase();

      if (type.contains('feed') || unit == 'kg') {
        feed += log.amount;
      } else if (type.contains('water') || unit == 'l' || unit == 'liters') {
        water += log.amount;
      }
    }
    return (feedKg: feed, waterL: water);
  }
}
