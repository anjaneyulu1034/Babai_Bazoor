import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionService {
  AuthSessionService._();

  static final AuthSessionService instance = AuthSessionService._();

  static const String _accessTokenKey = 'access_token';
  static const String _deliveryLocationKey = 'delivery_location';

  String? _cachedToken;
  String? _cachedDeliveryLocation;

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

  Future<void> saveDeliveryLocation(String location) async {
    final normalized = location.trim();
    if (normalized.isEmpty) {
      return;
    }

    _cachedDeliveryLocation = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deliveryLocationKey, normalized);
    } catch (_) {
      // Keep in-memory value for current session.
    }
  }

  Future<String?> getDeliveryLocation() async {
    if (_cachedDeliveryLocation != null &&
        _cachedDeliveryLocation!.trim().isNotEmpty) {
      return _cachedDeliveryLocation;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final location = prefs.getString(_deliveryLocationKey);
      _cachedDeliveryLocation = location;
      return location;
    } catch (_) {
      return _cachedDeliveryLocation;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.trim().isNotEmpty;
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    _cachedDeliveryLocation = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_deliveryLocationKey);
    } catch (_) {
      // Ignore persistence cleanup failure.
    }
  }
}
