import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Session store backed by the Hostinger PHP auth endpoints
/// (backend_api/register.php / login.php / logout.php).
///
/// Replaces the former Supabase Auth flow. The bearer token issued by PHP is
/// persisted in [SharedPreferences] so the session survives app restarts;
/// [restore] re-validates it lazily on the next authenticated request (the
/// backend answers 401 and screens surface the error). Being a
/// [ChangeNotifier], [MainShell] listens to it for login / logout transitions
/// exactly as it used to listen to Supabase's `onAuthStateChange`.
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

  /// String form for callers that key caches by owner id (services, models).
  String get userIdStr => _userId?.toString() ?? '';
  bool get isSignedIn => _token != null && _userId != null;

  Future<SharedPreferences> _prefsStore() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Loads a persisted session into memory. Call once before [runApp].
  Future<void> restore() async {
    final p = await _prefsStore();
    _token = p.getString(_kToken);
    _userId = p.getInt(_kUserId);
    _email = p.getString(_kEmail) ?? '';
    _fullName = p.getString(_kFullName) ?? '';
    notifyListeners();
  }

  /// Signs in via login.php; throws [ApiException] with the server message.
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

  /// Creates the account via register.php and signs straight in (the PHP
  /// script returns a session like login.php, so no email confirmation step).
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

  /// Best-effort server-side token invalidation, then local wipe.
  Future<void> logout() async {
    try {
      await ApiService.instance.post('logout.php', {});
    } catch (_) {
      // Offline / expired token: local sign-out still proceeds.
    }
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

  /// Mirrors profile edits into the in-memory session (name shown on the
  /// profile header before the next fetch).
  Future<void> updateCachedName(String fullName) async {
    _fullName = fullName;
    final p = await _prefsStore();
    await p.setString(_kFullName, fullName);
    notifyListeners();
  }

  /// Asks the PHP backend to email a password-reset link to the signed-in
  /// user's address (forgot_password.php).
  Future<void> requestPasswordReset() async {
    await ApiService.instance
        .post('forgot_password.php', {'email': _email});
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
