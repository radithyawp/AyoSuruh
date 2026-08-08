import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_service.dart';
import 'kebijakan.dart';
import 'login.dart';
import 'syarat_ketentuan.dart';

// Konstanta Warna
const Color kPrimaryColor = Color(0xFFF39C12); // Warna Orange Utama
const Color kTitleColor = Color(0xFF8B5A2B); // Warna Cokelat Judul
const Color kInputBgColor = Color(0xFFF7F3F0); // Background Textfield
const Color kBackgroundColor = Color(0xFFFAF6F3); // Background Screen

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  /* ---------- CONTROLLERS ---------- */
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  /* ---------- STATE ---------- */
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isNavigating = false;
  bool _isGoogleFlow = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((
      AuthState state,
    ) {
      final String provider =
          state.session?.user.appMetadata['provider']?.toString() ?? '';
      if (_isGoogleFlow &&
          state.event == AuthChangeEvent.signedIn &&
          state.session != null &&
          provider == 'google') {
        unawaited(_completeGoogleRegistration());
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _finishRegistration({
    required String message,
    String? email,
  }) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      // Jika Supabase memberikan session setelah sign-up/OAuth, sinkronkan
      // profil terlebih dahulu lalu paksa keluar. Sesuai flow Ayo Suruh,
      // registrasi tidak langsung membawa pengguna masuk ke aplikasi.
      if (_supabase.auth.currentSession != null) {
        await AuthService.syncCurrentUserProfile();
        await _supabase.auth.signOut();
      }

      _isGoogleFlow = false;
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              LoginPage(initialEmail: email, noticeMessage: message),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      _isNavigating = false;
      _isGoogleFlow = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akun dibuat, tetapi proses akhir registrasi gagal: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeGoogleRegistration() async {
    final String email = _supabase.auth.currentUser?.email?.trim() ?? '';
    await _finishRegistration(
      email: email,
      message:
          'Google berhasil digunakan. Silakan login untuk masuk ke Ayo Suruh.',
    );
  }

  /* ---------- PROSES REGISTRASI ---------- */
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final String email = _emailCtrl.text.trim();
      final String fullName = _fullNameCtrl.text.trim();
      final String phone = _phoneCtrl.text.trim();

      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: _passwordCtrl.text,
        data: <String, dynamic>{
          'fullname': fullName,
          'full_name': fullName,
          'phone': phone,
        },
      );

      if (!mounted) return;
      if (response.user == null) {
        throw const AuthException(
          'Supabase tidak mengembalikan data pengguna.',
        );
      }

      final String message = response.session == null
          ? 'Registrasi berhasil. Jika verifikasi email diaktifkan, selesaikan verifikasi terlebih dahulu lalu login.'
          : 'Registrasi berhasil. Silakan login untuk masuk ke Ayo Suruh.';

      await _finishRegistration(email: email, message: message);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted && !_isNavigating) setState(() => _isLoading = false);
    }
  }

  /* ---------- GOOGLE REGISTRATION / LOGIN ---------- */
  Future<void> _googleSignUp() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      _isGoogleFlow = true;
      final bool launched = await AuthService.signInWithGoogle();
      if (!launched && mounted) {
        _isGoogleFlow = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Halaman Google tidak dapat dibuka.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on AuthException catch (error) {
      _isGoogleFlow = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mendaftar dengan Google: ${error.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      _isGoogleFlow = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mendaftar dengan Google: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted && !_isNavigating) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // --- LOGO & HEADER ---
                Image.asset(
                  'assets/images/Logo_Ayo_Suruh.png',
                  height: 120,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.directions_run_rounded,
                    size: 80,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ayo Suruh',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: kTitleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Butuh bantuan? Ayo suruh kami!',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // --- CARD FORM REGISTER ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daftar Akun Baru',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lengkapi data diri Anda untuk memulai.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Field 1: Nama Lengkap
                        _buildLabel('Nama Lengkap'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _fullNameCtrl,
                          hintText: 'Masukkan nama lengkap',
                          icon: Icons.person_outline_rounded,
                          bgColor: kInputBgColor,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nama tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Field 2: Email
                        _buildLabel('Email'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _emailCtrl,
                          hintText: 'contoh@email.com',
                          icon: Icons.email_outlined,
                          bgColor: kInputBgColor,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Email tidak boleh kosong';
                            }
                            // Regex email asli milik Anda
                            final emailRegExp = RegExp(
                              r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                            );
                            if (!emailRegExp.hasMatch(val.trim())) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Field 3: Nomor WhatsApp
                        _buildLabel('Nomor WhatsApp'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _phoneCtrl,
                          hintText: 'Contoh: 08123456789',
                          icon: Icons.phone_outlined,
                          bgColor: kInputBgColor,
                          keyboardType: TextInputType.phone,
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'Nomor WA tidak boleh kosong';
                            }
                            if (!RegExp(r'^[0-9+]+$').hasMatch(trimmed)) {
                              return 'Nomor WA hanya boleh berupa angka';
                            }
                            if (trimmed.length < 9) {
                              return 'Nomor WA terlalu pendek (min. 9 digit)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Field 4: Password
                        _buildLabel('Password'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _passwordCtrl,
                          hintText: 'Min. 8 karakter',
                          icon: Icons.lock_outline_rounded,
                          bgColor: kInputBgColor,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Password wajib diisi';
                            }
                            if (val.length < 8) {
                              return 'Minimal 8 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Field 5: Konfirmasi Password
                        _buildLabel('Konfirmasi Password'),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _confirmPasswordCtrl,
                          hintText: 'Ulangi password',
                          icon: Icons.lock_reset_rounded,
                          bgColor: kInputBgColor,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              );
                            },
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Konfirmasi password wajib diisi';
                            }
                            if (val != _passwordCtrl.text) {
                              return 'Konfirmasi password tidak cocok!';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),

                        // Tombol Daftar
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Daftar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Pembatas "atau"
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'atau',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Tombol Google
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _googleSignUp,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/240px-Google_%22G%22_logo.svg.png',
                                  height: 18,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Daftar dengan Google',
                                  style: TextStyle(
                                    color: Colors.black87,
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
                  ),
                ),

                const SizedBox(height: 24),

                // --- FOOTER LINKS ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sudah punya akun? ',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: const Text(
                        'Masuk',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: kTitleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Terms & Privacy Note
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        'Dengan mendaftar, Anda menyetujui ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      InkWell(
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const SyaratKetentuanPage(),
                          ),
                        ),
                        child: const Text(
                          'Syarat & Ketentuan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            color: kTitleColor,
                          ),
                        ),
                      ),
                      Text(
                        ' serta ',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      InkWell(
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const KebijakanPage(),
                          ),
                        ),
                        child: const Text(
                          'Kebijakan Privasi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            color: kTitleColor,
                          ),
                        ),
                      ),
                      Text(
                        ' kami.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ---------- HELPER WIDGETS ---------- */
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color bgColor,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: bgColor,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryColor, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 0.8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
      ),
    );
  }
}
