import 'package:babai_bazor_app/core/constants/app_colors.dart';
import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/services/app_language_service.dart';
import 'package:babai_bazor_app/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';

class BabaiBazorApp extends StatefulWidget {
  const BabaiBazorApp({super.key});

  @override
  State<BabaiBazorApp> createState() => _BabaiBazorAppState();
}

class _BabaiBazorAppState extends State<BabaiBazorApp> {
  final ValueNotifier<AppLanguage> _languageNotifier = ValueNotifier(
    AppLanguage.en,
  );
  bool _languageReady = false;

  @override
  void initState() {
    super.initState();
    _restoreLanguage();
  }

  @override
  void dispose() {
    _languageNotifier.dispose();
    super.dispose();
  }

  Future<void> _restoreLanguage() async {
    final stored = await AppLanguageService.instance.getLanguage();
    if (!mounted) {
      return;
    }
    _languageNotifier.value = stored;
    setState(() {
      _languageReady = true;
    });
  }

  void _setLanguage(AppLanguage language) {
    if (_languageNotifier.value == language) {
      return;
    }
    _languageNotifier.value = language;
    AppLanguageService.instance.saveLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    if (!_languageReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Babai Bazor',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.scaffold,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryOrange,
          primary: AppColors.primaryOrange,
          secondary: AppColors.deepBlue,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textDark),
          bodyLarge: TextStyle(color: AppColors.textDark),
          titleMedium: TextStyle(color: AppColors.textDark),
          titleLarge: TextStyle(color: AppColors.textDark),
        ),
      ),
      builder: (context, child) {
        return AppLanguageScope(
          notifier: _languageNotifier,
          onChanged: _setLanguage,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: SplashScreen(
        language: _languageNotifier.value,
        onLanguageChanged: _setLanguage,
      ),
    );
  }
}
