import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/features/auth/presentation/screens/mobile_login_screen.dart';
import 'package:flutter/material.dart';

class LoginRequiredScreen extends StatelessWidget {
  const LoginRequiredScreen({super.key, required this.language, this.message});

  final AppLanguage language;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF7F8FA),
        title: const Text('Login Required'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6E6E6)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 42,
                  color: Color(0xFF4B5563),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please login to continue',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  message ?? 'You need to login before adding items to cart.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => MobileLoginScreen(
                            language: language,
                            onLanguageChanged: (_) {},
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF101010),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Login Now'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Continue Browsing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
