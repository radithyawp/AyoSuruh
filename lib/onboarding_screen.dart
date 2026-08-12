import 'dart:async';

import 'package:ayosuruh/admin/admin_navigation.dart';
import 'package:ayosuruh/admin/admin_service.dart';
import 'package:ayosuruh/auth/auth_preferences.dart';
import 'package:ayosuruh/auth/auth_service.dart';
import 'package:ayosuruh/auth/reset_password_page.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import 'package:ayosuruh/login.dart';
import 'package:ayosuruh/navbar.dart';
import 'package:ayosuruh/settings/app_settings.dart';
import 'package:ayosuruh/theme/ayo_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _recoveryDetected = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState state) {
        if (state.event == AuthChangeEvent.passwordRecovery &&
            state.session != null) {
          _recoveryDetected = true;
          unawaited(_openPasswordRecovery());
        }
      },
    );
    _startTimer();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openPasswordRecovery() async {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ResetPasswordPage()),
    );
  }

  Future<void> _startTimer() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _hasNavigated || _recoveryDetected) return;

    final SupabaseClient supabase = Supabase.instance.client;
    final Session? session = supabase.auth.currentSession;
    if (session != null) {
      final bool rememberSession = await AuthPreferences.shouldRememberSession();
      if (!rememberSession) {
        await supabase.auth.signOut();
        if (!mounted || _hasNavigated) return;
        _hasNavigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        );
        return;
      }

      try {
        await AuthService.syncCurrentUserProfile();
      } catch (_) {
        // Profil dapat disinkronkan lagi setelah halaman utama terbuka.
      }

      bool isAdmin = false;
      try {
        isAdmin = await AdminService().isCurrentUserAdmin();
      } catch (_) {
        isAdmin = false;
      }
      if (!mounted || _hasNavigated) return;
      _hasNavigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => isAdmin ? const AdminNavigation() : const MainNavigation(),
        ),
      );
      return;
    }

    if (!mounted || _hasNavigated) return;
    final bool onboardingSeen = await AuthPreferences.hasSeenOnboarding();
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => onboardingSeen ? const LoginPage() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const <Color>[Color(0xFF1D1917), Color(0xFF12100F)]
                : const <Color>[Color(0xFFFFFFFF), Color(0xFFFFFAF7)],
            stops: const <double>[0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Spacer(),
              SizedBox(
                width: 230,
                height: 230,
                child: Image.asset(
                  'assets/images/logo_ayo_suruh_transparent.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              const Spacer(),
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AyoColors.orange,
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 16),
              AyoText(
                'Menyiapkan Ayo Suruh untukmu...',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingModel {
  OnboardingModel({
    required this.title,
    required this.description,
    required this.imagePath,
  });

  final String title;
  final String description;
  final String imagePath;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingModel> _items = <OnboardingModel>[
    OnboardingModel(
      title: 'Butuh Bantuan?',
      description:
          'Temukan mitra terpercaya untuk menyelesaikan pekerjaan Anda dengan cepat dan mudah.',
      imagePath: 'assets/images/ayos/ayos_hello.png',
    ),
    OnboardingModel(
      title: 'Temukan Mitra Terpercaya',
      description:
          'Pilih mitra terbaik berdasarkan rating dan ulasan dari pengguna lain untuk hasil kerja yang memuaskan.',
      imagePath: 'assets/images/ayos/ayos_play_phone.png',
    ),
    OnboardingModel(
      title: 'Selesai Lebih Cepat',
      description:
          'Lacak progres pekerjaan secara langsung dan bayar dengan mudah serta aman.',
      imagePath: 'assets/images/ayos/ayos_hooray_with_confetti.png',
    ),
  ];

  Future<void> _finishOnboarding() async {
    await AuthPreferences.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _toggleLanguage() async {
    final AppSettingsController settings = AppSettingsController.instance;
    await settings.setLanguage(
      settings.language == AyoLanguage.indonesia
          ? AyoLanguage.english
          : AyoLanguage.indonesia,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final bool isLastPage = _currentIndex == _items.length - 1;
    final bool english = AppSettingsController.instance.isEnglish;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const <Color>[Color(0xFF1D1917), Color(0xFF12100F)]
                : const <Color>[Color(0xFFFFFFFF), Color(0xFFFFFAF7)],
            stops: const <double>[0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Material(
                      color: theme.colorScheme.surface.withValues(alpha: dark ? 0.85 : 0.9),
                      shape: StadiumBorder(
                        side: BorderSide(color: theme.colorScheme.outline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _toggleLanguage,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.translate_rounded, size: 17),
                              const SizedBox(width: 6),
                              AyoText(
                                english ? 'ID' : 'EN',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: AyoText(
                        'Lewati',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _items.length,
                  onPageChanged: (int index) => setState(() => _currentIndex = index),
                  itemBuilder: (BuildContext context, int index) {
                    final OnboardingModel item = _items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: dark
                                    ? theme.colorScheme.surface.withValues(alpha: 0.45)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  item.imagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 100,
                                      color: AyoColors.orange.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AyoText(
                            item.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AyoText(
                            item.description,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(
                  _items.length,
                  (int index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? AyoColors.orange
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: <Widget>[
                    if (_currentIndex > 0) ...<Widget>[
                      TextButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AyoText(
                          'Kembali',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (isLastPage) {
                            _finishOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AyoColors.orange,
                          foregroundColor: AyoColors.brownDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            AyoText(
                              isLastPage
                                  ? 'Mulai Sekarang'
                                  : (_currentIndex == 0 ? 'Selanjutnya' : 'Lanjut'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
