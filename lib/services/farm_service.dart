import 'api_service.dart';
import 'auth_service.dart';
import '../models/farm.dart';
import '../models/feeding_log.dart';
import '../models/report.dart';

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
    this.emailConfirmed = true,
  });

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Farmora user';
  }

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

class FarmService {
  static Future<List<Farm>> fetchFarms() async {
    final data = await ApiService.instance.get('get_farms.php');
    return (data as List)
        .map((r) => Farm.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  static Future<Map<String, dynamic>?> fetchLatestTelemetry(int farmId) async {
    final data = await ApiService.instance.get('get_telemetry.php',
        query: {'farm_id': '$farmId', 'mode': 'latest'});
    final list = List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    return list.isEmpty ? null : list.first;
  }

  static Future<List<Map<String, dynamic>>> fetchTelemetryHistory(int farmId,
      {int limit = 20}) async {
    final data = await ApiService.instance.get('get_telemetry.php', query: {
      'farm_id': '$farmId',
      'mode': 'history',
      'limit': '$limit',
    });
    return List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  static Future<List<Map<String, dynamic>>> fetchRecentAlerts(int farmId,
      {int limit = 10}) async {
    final data = await ApiService.instance.get('get_alerts.php',
        query: {'farm_id': '$farmId', 'limit': '$limit'});
    return List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  static Future<List<Map<String, dynamic>>> fetchRecentAlertsAnyFarm(
      {int limit = 10}) async {
    final data = await ApiService.instance
        .get('get_alerts.php', query: {'limit': '$limit'});
    return List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
  }

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
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'image_url': imageUrl,
      'action_time': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<FeedingLog>> fetchFeedingLogs(int farmId,
      {int limit = 50}) async {
    final data = await ApiService.instance
        .get('get_logs.php', query: {'farm_id': '$farmId', 'limit': '$limit'});
    return (data as List? ?? [])
        .map((r) => FeedingLog.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

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
      'report_title': title,
      'title': title,
      'category': category,
      'notes': notes.isNotEmpty ? notes : null,
      'file_path': fileUrl,
      'file_url': fileUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Report>> fetchReports(int farmId, {int limit = 50}) async {
    final data = await ApiService.instance.get('get_reports.php',
        query: {'farm_id': '$farmId', 'limit': '$limit'});
    return (data as List? ?? [])
        .map((r) => Report.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchAdvisories() async {
    final data = await ApiService.instance.get('get_advisories.php');
    return List<Map<String, dynamic>>.from(
        (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  static String? get currentUserId =>
      AuthService.instance.isSignedIn ? AuthService.instance.userIdStr : null;

  static Future<UserProfile> fetchMyProfile() async {
    if (!AuthService.instance.isSignedIn) {
      throw Exception('Not signed in');
    }
    final data = await ApiService.instance.get('get_profile.php');
    return UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

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

  static Future<String> _uploadFile(String filePath,
      {required String folder}) async {
    final data = await ApiService.instance
        .uploadMultipart(filePath, fields: {'folder': folder});
    final url = (data as Map?)?['url']?.toString();
    if (url == null || url.isEmpty) {
      throw ApiException('Upload succeeded but no file URL was returned');
    }
    return url;
  }

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
