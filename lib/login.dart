import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_navigation.dart';
import 'admin/admin_service.dart';
import 'auth/auth_preferences.dart';
import 'auth/auth_service.dart';
import 'auth/forgot_password_page.dart';
import 'auth/reset_password_page.dart';
import 'navbar.dart';
import 'register.dart';
import 'theme/ayo_theme.dart';
import 'widgets/ayo_pressable.dart';
import 'widgets/ayo_snackbar.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialEmail, this.noticeMessage});

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

    _authSubscription = _supabase.auth.onAuthStateChange.listen((
      AuthState state,
    ) {
      if (state.event == AuthChangeEvent.passwordRecovery &&
          state.session != null) {
        unawaited(_openPasswordRecovery());
        return;
      }
      if (state.event == AuthChangeEvent.signedIn && state.session != null) {
        unawaited(_completeLogin(showMessage: false));
      }
    });
  }

  Future<void> _loadRememberPreference() async {
    final List<dynamic> preference =
        await Future.wait<dynamic>(<Future<dynamic>>[
          AuthPreferences.shouldRememberSession(),
          AuthPreferences.rememberedEmail(),
          AuthPreferences.clearLegacyStoredPassword(),
        ]);
    final bool remember = preference[0] as bool;
    final String? rememberedEmail = preference[1] as String?;
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
    AyoSnackBar.success(context, message);
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
      final bool reactivated =
          await AuthService.reactivateCurrentAccountIfNeeded();
      await AuthService.syncCurrentUserProfile();
      if (_rememberMe) {
        await AuthPreferences.saveLoginPreference(
          rememberMe: true,
          email: _supabase.auth.currentUser?.email,
        );
      }
      if (!mounted) return;

      if (showMessage || reactivated) {
        AyoSnackBar.success(
          context,
          reactivated
              ? 'Akun diaktifkan kembali. Selamat datang!'
              : 'Berhasil masuk! Selamat datang.',
        );
      }

      bool isAdmin = false;
      try {
        isAdmin = await AdminService().isCurrentUserAdmin();
      } catch (_) {
        isAdmin = false;
      }
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              isAdmin ? const AdminNavigation() : const MainNavigation(),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      _isNavigating = false;
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Akun berhasil masuk, tetapi profil gagal disiapkan: $error',
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
        // Ayo Suruh tidak menyimpan password. Autofill/password manager OS tetap
        // dapat menawarkan penyimpanan credential secara terpisah.
        TextInput.finishAutofillContext(shouldSave: _rememberMe);
        await _completeLogin(showMessage: true);
      }
    } on AuthException catch (error) {
      String message = error.message;
      if (message.toLowerCase().contains('invalid login credentials')) {
        message = 'Email atau password salah. Silakan periksa kembali.';
      }
      if (!mounted) return;
      AyoSnackBar.error(context, message);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Login gagal: $error');
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
        AyoSnackBar.error(context, 'Halaman Google tidak dapat dibuka.');
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Gagal masuk dengan Google: ${error.message}',
      );
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Gagal masuk dengan Google: $error');
    } finally {
      if (mounted && !_isNavigating) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF6990E); // Orange Tombol & Aksen
    const titleColor = Color(0xFF6E481F); // Cokelat Judul & Link
    const inputBgColor = Color(0xFFFFFBF8); // Background Textfield

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF7),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(100)),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    // --- LOGO & HEADER ---
                    Image.asset(
                      'assets/images/Logo_Ayo_Suruh.png',
                      height: 120,
                      errorBuilder: (_, _, _) => const Icon(
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
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                            color: Colors.black.withValues(alpha: 0.04),
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
                                AyoPressable(
                                  onTap: _isLoading
                                      ? null
                                      : () {
                                          Navigator.push<void>(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  ForgotPasswordPage(
                                                    initialEmail: _emailCtrl
                                                        .text
                                                        .trim(),
                                                  ),
                                            ),
                                          );
                                        },
                                  child: Text(
                                    'Lupa Password?',
                                    style: AyoTypography.link(
                                      context,
                                      color: titleColor,
                                    ).copyWith(fontSize: 12),
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
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
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
                                            final bool remember =
                                                value ?? false;
                                            setState(
                                              () => _rememberMe = remember,
                                            );
                                            if (!remember) {
                                              unawaited(
                                                AuthPreferences.clearRememberedLogin(),
                                              );
                                            }
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
                                  child: Divider(color: Colors.grey[300]),
                                ),
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
                                Expanded(
                                  child: Divider(color: Colors.grey[300]),
                                ),
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
                                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/240px-Google_%22G%22_logo.svg.png',
                                      height: 18,
                                      errorBuilder: (_, _, _) => const Icon(
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
                        AyoPressable(
                          haptic: true,
                          pressedScale: 0.96,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          child: Text(
                            'Daftar',
                            style: AyoTypography.link(
                              context,
                              color: titleColor,
                            ).copyWith(fontSize: 13),
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
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
          borderSide: const BorderSide(color: Color(0xFFF39C12), width: 1.2),
        ),
      ),
    );
  }
}
