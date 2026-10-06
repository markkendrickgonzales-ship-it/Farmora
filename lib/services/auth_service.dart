import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _kToken = 'auth_token';
  static const _kUserId = 'auth_user_id';
  static const _kEmail = 'auth_email';
  static const _kFullName = 'auth_full_name';

  SharedPreferences? _prefs;
  String? _token;
  int? _userId;
  String _email = '';
  String _fullName = '';

  String? get token => _token;
  int? get userId => _userId;
  String get email => _email;
  String get fullName => _fullName;

  String get userIdStr => _userId?.toString() ?? '';
  bool get isSignedIn => _token != null && _userId != null;

  Future<SharedPreferences> _prefsStore() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> restore() async {
    final p = await _prefsStore();
    _token = p.getString(_kToken);
    _userId = p.getInt(_kUserId);
    _email = p.getString(_kEmail) ?? '';
    _fullName = p.getString(_kFullName) ?? '';
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await ApiService.instance.post('login.php', {
      'email': email,
      'password': password,
    });
    await _saveSession(Map<String, dynamic>.from(data as Map));
  }

  Future<void> register({
    required String email,
    required String password,
    String fullName = '',
  }) async {
    final data = await ApiService.instance.post('register.php', {
      'email': email,
      'password': password,
      'full_name': fullName,
    });
    await _saveSession(Map<String, dynamic>.from(data as Map));
  }

  Future<void> logout() async {
    try {
      await ApiService.instance.post('logout.php', {});
    } catch (_) {}
    final p = await _prefsStore();
    await p.remove(_kToken);
    await p.remove(_kUserId);
    await p.remove(_kEmail);
    await p.remove(_kFullName);
    _token = null;
    _userId = null;
    _email = '';
    _fullName = '';
    notifyListeners();
  }

  Future<void> updateCachedName(String fullName) async {
    _fullName = fullName;
    final p = await _prefsStore();
    await p.setString(_kFullName, fullName);
    notifyListeners();
  }

  Future<void> requestPasswordReset() async {
    await ApiService.instance.post('forgot_password.php', {'email': _email});
  }

  Future<void> _saveSession(Map<String, dynamic> session) async {
    _token = session['token'] as String?;
    _userId = (session['user_id'] as num?)?.toInt();
    _email = session['email'] as String? ?? '';
    _fullName = session['full_name'] as String? ?? '';
    final p = await _prefsStore();
    await p.setString(_kToken, _token ?? '');
    await p.setInt(_kUserId, _userId ?? 0);
    await p.setString(_kEmail, _email);
    await p.setString(_kFullName, _fullName);
    notifyListeners();
  }
}
