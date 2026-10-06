import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiConfig {
  static const String baseUrl = 'https://frmora.space/api';

  static Uri url(String endpoint, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/$endpoint').replace(
        queryParameters: (query == null || query.isEmpty) ? null : query,
      );
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

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

  Future<dynamic> get(String endpoint, {Map<String, String>? query}) async {
    final res = await http
        .get(ApiConfig.url(endpoint, query), headers: _headers)
        .timeout(_timeout);
    return _decode(endpoint, res);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final res = await http
        .post(ApiConfig.url(endpoint),
            headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(endpoint, res);
  }

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
        (msg as String?) ??
            'Request failed ($endpoint, HTTP ${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return parsed is Map ? parsed['data'] : parsed;
  }
}
