import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Central configuration for the Hostinger PHP REST backend.
///
/// Point [baseUrl] at the folder that holds the `backend_api/` PHP scripts on
/// your Hostinger domain (without a trailing slash). Every service in the app
/// talks to the backend exclusively through [ApiService], so this is the only
/// place the environment is changed.
class ApiConfig {
  static const String baseUrl = 'https://yourdomain.com/api';

  /// Resolves [endpoint] (e.g. `get_logs.php`) against [baseUrl].
  static Uri url(String endpoint, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/$endpoint').replace(
        queryParameters: (query == null || query.isEmpty) ? null : query,
      );
}

/// Error raised for any transport / API failure so screens can show a clean
/// message instead of a raw exception dump.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Thin HTTP layer over the Hostinger PHP endpoints.
///
/// * `GET`  → [get]   (query parameters)
/// * `POST` → [post]  (JSON body)
/// * files  → [uploadMultipart] (multipart/form-data to upload_file.php)
///
/// Every request carries the `Authorization: Bearer <token>` header when a
/// session exists, and every response is expected to be JSON of the shape
/// `{ "success": true, "data": ... }` or `{ "success": false, "message": ... }`
/// as produced by backend_api/db_connect.php.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const Duration _timeout = Duration(seconds: 20);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (AuthService.instance.token != null)
          'Authorization': 'Bearer ${AuthService.instance.token}',
      };

  /// GET [endpoint] with optional [query] parameters; returns decoded JSON.
  Future<dynamic> get(String endpoint, {Map<String, String>? query}) async {
    final res = await http
        .get(ApiConfig.url(endpoint, query), headers: _headers)
        .timeout(_timeout);
    return _decode(endpoint, res);
  }

  /// POST [endpoint] with a JSON [body]; returns decoded JSON.
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final res = await http
        .post(ApiConfig.url(endpoint), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(endpoint, res);
  }

  /// Uploads the file at [filePath] as multipart/form-data to [endpoint]
  /// (defaults to upload_file.php) with extra [fields]; returns the decoded
  /// JSON, whose `data.url` is the public URL of the stored file.
  Future<dynamic> uploadMultipart(
    String filePath, {
    String endpoint = 'upload_file.php',
    String fileField = 'file',
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', ApiConfig.url(endpoint))
      ..headers.addAll({
        if (AuthService.instance.token != null)
          'Authorization': 'Bearer ${AuthService.instance.token}',
      })
      ..files.add(await http.MultipartFile.fromPath(fileField, filePath))
      ..fields.addAll(fields ?? {});
    final res = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 60)));
    return _decode(endpoint, res);
  }

  dynamic _decode(String endpoint, http.Response res) {
    dynamic parsed;
    try {
      parsed = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ApiException(
        'Server returned an invalid response ($endpoint, HTTP ${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode >= 400 || parsed is Map && parsed['success'] == false) {
      final msg = parsed is Map ? parsed['message'] : null;
      throw ApiException(
        (msg as String?) ?? 'Request failed ($endpoint, HTTP ${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return parsed is Map ? parsed['data'] : parsed;
  }
}
