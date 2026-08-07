import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_preferences.dart';
import 'auth/auth_service.dart';
import 'auth/forgot_password_page.dart';
import 'auth/reset_password_page.dart';
import 'navbar.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialEmail,
    this.noticeMessage,
  });

  final String? initialEmail;
  final String? noticeMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  /* ---------- CONTROLLERS ---------- */
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  /* ---------- STATE ---------- */
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isNavigating = false;
  bool _rememberMe = true;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail?.trim() ?? '';
    unawaited(_loadRememberPreference());
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNoticeMessage());

    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (AuthState state) {
        if (state.event == AuthChangeEvent.passwordRecovery &&
            state.session != null) {
          unawaited(_openPasswordRecovery());
          return;
        }
        if (state.event == AuthChangeEvent.signedIn && state.session != null) {
          unawaited(_completeLogin(showMessage: false));
        }
      },
    );
  }

  Future<void> _loadRememberPreference() async {
    final bool remember = await AuthPreferences.shouldRememberSession();
    final String? rememberedEmail = await AuthPreferences.rememberedEmail();
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (_emailCtrl.text.trim().isEmpty && rememberedEmail != null) {
        _emailCtrl.text = rememberedEmail;
      }
    });
  }

  void _showNoticeMessage() {
    final String message = widget.noticeMessage?.trim() ?? '';
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _openPasswordRecovery() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const ResetPasswordPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeLogin({required bool showMessage}) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      await AuthService.syncCurrentUserProfile();
      if (!mounted) return;

      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil masuk! Selamat datang.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    } catch (error) {
      _isNavigating = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Akun berhasil masuk, tetapi profil gagal disiapkan: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /* ---------- PROSES LOGIN ---------- */
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (response.user != null) {
        await AuthPreferences.saveLoginPreference(
          rememberMe: _rememberMe,
          email: _emailCtrl.text.trim(),
        );
        // Password tidak disimpan oleh aplikasi. Android/iOS credential manager
        // dapat menawarkan penyimpanan aman berdasarkan autofillHints field login.
        TextInput.finishAutofillContext(shouldSave: _rememberMe);
        await _completeLogin(showMessage: true);
      }
    } on AuthException catch (error) {
      String message = error.message;
      if (message.toLowerCase().contains('invalid login credentials')) {
        message = 'Email atau password salah. Silakan periksa kembali.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login gagal: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted && !_isNavigating) setState(() => _isLoading = false);
    }
  }

  /* ---------- GOOGLE LOGIN / REGISTRASI ---------- */
  Future<void> _googleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await AuthPreferences.saveLoginPreference(
        rememberMe: _rememberMe,
        email: _emailCtrl.text.trim(),
      );
      final bool launched = await AuthService.signInWithGoogle();
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Halaman Google tidak dapat dibuka.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal masuk dengan Google: ${error.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal masuk dengan Google: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted && !_isNavigating) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF39C12); // Orange Tombol & Aksen
    const titleColor = Color(0xFF8B5A2B); // Cokelat Judul & Link
    const inputBgColor = Color(0xFFF8F5F2); // Background Textfield

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F3),
      body: Stack(
        children: [
          // Latar Belakang Dekoratif Bawah (Wave/Curve)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFF8EFEA),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(100),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    // --- LOGO & HEADER ---
                    Image.asset(
                      'assets/images/icon.jpeg', // Sesuaikan dengan lokasi ikon logo Anda
                      height: 100,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.directions_run_rounded,
                        size: 90,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ayo Suruh',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Butuh bantuan? Ayo suruh kami!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- CARD FORM LOGIN ---
                    Container(
                      padding: const EdgeInsets.all(22),
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
                            // Judul Card
                            const Center(
                              child: Text(
                                'Masuk ke Akun',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Field 1: Masuk dengan Email
                            _buildLabel('Masuk dengan Email'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _emailCtrl,
                              hintText: 'nama@email.com',
                              icon: Icons.email_outlined,
                              bgColor: inputBgColor,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const <String>[
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              validator: (val) =>
                                  val == null || !val.contains('@')
                                      ? 'Email tidak valid'
                                      : null,
                            ),
                            const SizedBox(height: 16),

                            // Field 2: Password + Lupa Password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildLabel('Password'),
                                GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () {
                                          Navigator.push<void>(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => ForgotPasswordPage(
                                                initialEmail: _emailCtrl.text.trim(),
                                              ),
                                            ),
                                          );
                                        },
                                  child: const Text(
                                    'Lupa Password?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _passCtrl,
                              hintText: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              bgColor: inputBgColor,
                              obscureText: _obscurePassword,
                              autofillHints: const <String>[AutofillHints.password],
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                },
                              ),
                              validator: (val) => val == null || val.isEmpty
                                  ? 'Password tidak boleh kosong'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: primaryColor,
                                    onChanged: _isLoading
                                        ? null
                                        : (bool? value) {
                                            setState(() => _rememberMe = value ?? false);
                                          },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Ingat saya di perangkat ini',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF655A53),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Tombol Masuk
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
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
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Masuk',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Pembatas "atau"
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(color: Colors.grey[300])),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Text(
                                    'atau',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(color: Colors.grey[300])),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Tombol Google
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _googleLogin,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[300]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                      height: 18,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.g_mobiledata,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Masuk dengan Google',
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

                    const SizedBox(height: 28),

                    // --- FOOTER LINKS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Belum punya akun? ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterPage()),
                            );
                          },
                          child: const Text(
                            'Daftar',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: bgColor,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
          borderSide: const BorderSide(color: Color(0xFFF39C12), width: 1.2),
        ),
      ),
    );
  }
}
