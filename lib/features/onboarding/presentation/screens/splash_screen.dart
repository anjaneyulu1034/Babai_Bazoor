import 'dart:math' as math;

import 'package:babai_bazor_app/core/constants/app_colors.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:flutter/material.dart';

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

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _loopController;
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      _goToLanguage();
    });
  }

  void _goToLanguage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LanguageSelectionScreen(
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loopController.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.tr;

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      body: AnimatedBuilder(
        animation: Listenable.merge([_loopController, _introController]),
        builder: (context, child) {
          final loop = _loopController.value;
          final intro = Curves.easeOutCubic.transform(_introController.value);

          final floatOffset = math.sin(loop * 2 * math.pi) * 10;
          final contentScale = 0.94 + (intro * 0.06);

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF9A3D),
                        Color(0xFFF47A20),
                        Color(0xFFDA5D00),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(
                      math.sin(loop * 2 * math.pi) * 18,
                      math.cos(loop * 2 * math.pi) * 14,
                    ),
                    child: Opacity(
                      opacity: 0.28,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.2, -0.6),
                            radius: 1.0,
                            colors: [
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00FFFFFF), Color(0x2E000000)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -80 + (math.sin(loop * 2 * math.pi) * 18),
                top: -50,
                child: _GlowBubble(size: 220, color: const Color(0x33FFFFFF)),
              ),
              Positioned(
                right: -70 + (math.cos(loop * 2 * math.pi) * 14),
                bottom: 40,
                child: _GlowBubble(size: 200, color: const Color(0x29FFE0B8)),
              ),
              SafeArea(
                child: Center(
                  child: Opacity(
                    opacity: intro,
                    child: Transform.translate(
                      offset: Offset(0, (1 - intro) * 36 + floatOffset),
                      child: Transform.scale(
                        scale: contentScale,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Image.asset(
                                    'assets/play_store_512.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                t(widget.language, 'app_name'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                t(widget.language, 'tagline'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFFE7CC),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 34),
                              const Text(
                                'Shop smarter with a beautiful local market experience.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFFFF2E3),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateX(math.sin(loop * 2 * math.pi) * 0.09)
                                  ..rotateY(
                                    math.cos(loop * 2 * math.pi) * 0.12,
                                  ),
                                child: Container(
                                  width: 280,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFFFFF),
                                        Color(0xFFFFE6C8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x4D000000),
                                        blurRadius: 26,
                                        offset: Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Fast Delivery\nFresh Picks\nTrusted Quality',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF8F3D00),
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
