import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageService {
  AppLanguageService._();

  static final AppLanguageService instance = AppLanguageService._();

  static const String _languageCodeKey = 'app_language_code';

  AppLanguage? _cached;

  Future<void> saveLanguage(AppLanguage language) async {
    _cached = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageCodeKey, language.code);
    } catch (_) {
      // Keep in-memory language for this app session.
    }
  }

  Future<AppLanguage> getLanguage() async {
    if (_cached != null) {
      return _cached!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_languageCodeKey)?.trim().toLowerCase();
      _cached = code == AppLanguage.te.code ? AppLanguage.te : AppLanguage.en;
      return _cached!;
    } catch (_) {
      return _cached ?? AppLanguage.en;
    }
  }
}
