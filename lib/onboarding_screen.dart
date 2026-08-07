import 'dart:async';

import 'package:ayosuruh/auth/auth_preferences.dart';
import 'package:ayosuruh/auth/auth_service.dart';
import 'package:ayosuruh/auth/reset_password_page.dart';
import 'package:ayosuruh/login.dart';
import 'package:ayosuruh/navbar.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. SPLASH SCREEN
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
      final bool rememberSession =
          await AuthPreferences.shouldRememberSession();
      if (!rememberSession) {
        // Checkbox Remember Me mengontrol pemulihan sesi pada cold start.
        // Password tidak pernah disimpan oleh Ayo Suruh.
        await supabase.auth.signOut();
        if (!mounted || _hasNavigated) return;
        _hasNavigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        );
        return;
      } else {
        try {
          await AuthService.syncCurrentUserProfile();
        } catch (_) {
          // Profil dapat dicoba disinkronkan kembali setelah halaman utama terbuka.
        }
        if (!mounted || _hasNavigated) return;
        _hasNavigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MainNavigation()),
        );
        return;
      }
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Colors.white],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Ilustrasi / Logo Splash
              Image.asset(
                'assets/images/logo.jpeg', // Sesuaikan path gambar kamu
                width: 480,
                height: 480,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.directions_run_rounded,
                  size: 120,
                  color: Color(0xFFF39C12),
                ),
              ),
              const SizedBox(height: 24),
              const Spacer(),
              // Loading Indicator
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Color(0xFFF39C12),
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Menyiapkan layanan terbaik untuk Anda...',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}


// 2. ONBOARDING SCREEN
class OnboardingModel {
  final String title;
  final String description;
  final String imagePath;

  OnboardingModel({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingModel> _items = [
    OnboardingModel(
      title: 'Butuh Bantuan?',
      description:
          'Temukan mitra terpercaya untuk menyelesaikan pekerjaan Anda dengan cepat dan mudah.',
      imagePath: 'assets/images/icon.jpeg',
    ),
    OnboardingModel(
      title: 'Temukan Mitra Terpercaya',
      description:
          'Pilih mitra terbaik berdasarkan rating dan ulasan dari pengguna lain untuk hasil kerja yang memuaskan.',
      imagePath: 'assets/images/icon.jpeg',
    ),
    OnboardingModel(
      title: 'Selesai Lebih Cepat',
      description:
          'Lacak progres pekerjaan secara langsung dan bayar dengan mudah serta aman.',
      imagePath: 'assets/images/icon.jpeg',
    ),
  ];

  Future<void> _finishOnboarding() async {
    await AuthPreferences.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _items.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Colors.white],
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- HEADER (Tombol Lewati) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: const Text(
                      'Lewati',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // --- SLIDER ONBOARDING ---
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _items.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Card Gambar
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  item.imagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 100,
                                      color: Colors.orange[200],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Judul
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C323A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Deskripsi
                          Text(
                            item.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // --- INDIKATOR HALAMAN (DOTS) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? const Color(0xFFF39C12)
                          : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- NAVIGASI TOMBOL BAWAH ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    // Tombol Kembali (hanya muncul jika bukan slide pertama)
                    if (_currentIndex > 0) ...[
                      TextButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text(
                          'Kembali',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Tombol Lanjut / Selanjutnya / Mulai
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
                          backgroundColor: const Color(0xFFF39C12),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
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
