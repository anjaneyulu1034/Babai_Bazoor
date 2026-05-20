import 'dart:async';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/constants/app_colors.dart';
import 'package:babai_bazor_app/core/constants/app_assets.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:babai_bazor_app/features/auth/presentation/screens/mobile_login_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _autoSlideTimer;
  int _currentPage = 0;
  bool _isCheckingSession = true;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      emoji: '🛒',
      title: 'Groceries in 10 mins',
      subtitle: 'Fresh produce, dairy & snacks at your door',
    ),
    _OnboardingSlide(
      emoji: '🔧',
      title: 'Home Services',
      subtitle: 'Certified pros for cleaning, repairs & more',
    ),
    _OnboardingSlide(
      emoji: '💅',
      title: 'Beauty at Home',
      subtitle: 'Salon-quality services at your doorstep',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _restoreSessionIfLoggedIn();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _isCheckingSession) {
        return;
      }

      setState(() {
        _currentPage = (_currentPage + 1) % _slides.length;
      });
    });
  }

  Future<void> _restoreSessionIfLoggedIn() async {
    final token = await AuthSessionService.instance.getToken();
    if (token == null || token.trim().isEmpty) {
      if (mounted) {
        setState(() => _isCheckingSession = false);
      }
      return;
    }

    var sessionValid = true;
    try {
      final response = await http
          .get(
            AuthApiEndpoints.me(),
            headers: {
              ApiHeaders.authorization:
                  '${ApiHeaders.bearerPrefix}${token.trim()}',
              ApiHeaders.acceptLanguage: widget.language.code,
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthSessionService.instance.clearToken();
        sessionValid = false;
      }
    } on SocketException {
      // Offline reopen: keep saved session and open home.
      sessionValid = true;
    } on TimeoutException {
      sessionValid = true;
    } catch (_) {
      sessionValid = true;
    }

    if (!mounted) {
      return;
    }

    if (sessionValid) {
      final savedLocation =
          await AuthSessionService.instance.getDeliveryLocation();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            language: widget.language,
            currentLocation: savedLocation,
          ),
        ),
      );
      return;
    }

    setState(() => _isCheckingSession = false);
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MobileLoginScreen(
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.tr;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final slideTitleFont = (screenWidth * 0.098).clamp(42.0, 54.0);

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A143B),
                    Color(0xFF81241B),
                    Color(0xFFC9380B),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: _CircleRings()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
              child: Column(
                children: [
                  Image.asset(
                    AppAssets.logo,
                    width: 220,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t(widget.language, 'tagline'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD4BEB6),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) {
                        return currentChild ?? const SizedBox.shrink();
                      },
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _SplashSlideContent(
                        key: ValueKey<int>(_currentPage),
                        slide: _slides[_currentPage],
                        slideTitleFont: slideTitleFont,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final active = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 30 : 9,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFFFBE0A)
                              : const Color(0x99E4A67D),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (_isCheckingSession)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFBE0A),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _goToLogin,
                        style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFBE0A),
                        foregroundColor: const Color(0xFF111111),
                        minimumSize: const Size.fromHeight(74),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                        child: Text('${t(widget.language, 'get_started')} →'),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Terms & Privacy Policy apply',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD6A78A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;
}

class _SplashSlideContent extends StatelessWidget {
  const _SplashSlideContent({
    super.key,
    required this.slide,
    required this.slideTitleFont,
  });

  final _OnboardingSlide slide;
  final double slideTitleFont;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text(slide.emoji, style: const TextStyle(fontSize: 90)),
          const SizedBox(height: 22),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: slideTitleFont,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFDCC7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _CircleRings extends StatelessWidget {
  const _CircleRings();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 620,
          height: 620,
          child: Stack(
            alignment: Alignment.center,
            children: const [
              _Ring(size: 620),
              _Ring(size: 430),
              _Ring(size: 240),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x26FFFFFF), width: 1),
      ),
    );
  }
}
