import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/features/auth/presentation/screens/mobile_login_screen.dart';
import 'package:flutter/material.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late AppLanguage _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.language;
  }

  void _continue() {
    widget.onLanguageChanged(_selected);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MobileLoginScreen(
          language: _selected,
          onLanguageChanged: widget.onLanguageChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.tr;
    return Scaffold(
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
          const Positioned(
            left: -70,
            top: -40,
            child: _AmbientBlob(size: 220, color: Color(0x24FFFFFF)),
          ),
          const Positioned(
            right: -50,
            top: 130,
            child: _AmbientBlob(size: 170, color: Color(0x22FFB26B)),
          ),
          const Positioned(
            left: -30,
            bottom: 20,
            child: _AmbientBlob(size: 180, color: Color(0x1AFFFFFF)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), Color(0x1F000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Choose Language',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF8EFE6),
                          letterSpacing: 0.2,
                          height: 1.05,
                          fontFamily: 'serif',
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _LanguageTile(
                        selected: _selected == AppLanguage.en,
                        title: 'English',
                        subtitle: t(_selected, 'english_desc'),
                        onTap: () => setState(() => _selected = AppLanguage.en),
                      ),
                      const SizedBox(height: 14),
                      _LanguageTile(
                        selected: _selected == AppLanguage.te,
                        title: 'తెలుగు',
                        subtitle: t(_selected, 'telugu_desc'),
                        onTap: () => setState(() => _selected = AppLanguage.te),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFBE0A),
                            foregroundColor: const Color(0xFF111111),
                            minimumSize: const Size.fromHeight(58),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Continue'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t(_selected, 'change_anytime'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFFFFD4BE),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? const Color(0x33FFB86A) : const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFFFBE0A) : const Color(0x66FFFFFF),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            if (selected)
              const BoxShadow(
                color: Color(0x30B03700),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? const Color(0xFFFFE9B2)
                            : const Color(0xFFF5F2EE),
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? const Color(0xFFFFD9BE)
                            : const Color(0xFFD8C9C2),
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFBE0A)
                        : const Color(0x99FFFFFF),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: selected
                    ? const Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFBE0A),
                          ),
                          child: SizedBox(width: 16, height: 16),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
