import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionService {
  AuthSessionService._();

  static final AuthSessionService instance = AuthSessionService._();

  static const String _accessTokenKey = 'access_token';

  String? _cachedToken;

  Future<void> saveToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }

    _cachedToken = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, normalized);
    } catch (_) {
      // Keep in-memory token available for current app session.
    }
  }

  Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_accessTokenKey);
      _cachedToken = token;
      return token;
    } catch (_) {
      return _cachedToken;
    }
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
    } catch (_) {
      // Ignore persistence cleanup failure.
    }
  }
}
