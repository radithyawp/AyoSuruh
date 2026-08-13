import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_preferences.dart';
import '../login.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import '../theme/ayo_theme.dart';
import '../widgets/ayo_snackbar.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  static const Color _orange = Color(0xFFF6990E);
  static Color get _brown => AyoAdaptiveColors.brown;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final SupabaseClient supabase = Supabase.instance.client;
      if (supabase.auth.currentSession == null) {
        throw StateError(
          'Sesi pemulihan sudah berakhir. Minta tautan reset password baru.',
        );
      }

      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      final String email = supabase.auth.currentUser?.email ?? '';
      final bool rememberMe = await AuthPreferences.shouldRememberSession();
      await AuthPreferences.saveLoginPreference(
        rememberMe: rememberMe,
        email: email,
      );
      await supabase.auth.signOut();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LoginPage(
            initialEmail: email,
            noticeMessage: 'Password berhasil diperbarui. Silakan masuk kembali.',
          ),
        ),
        (Route<dynamic> route) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, error.message);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Password belum dapat diperbarui: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: AyoText(
          'Buat Password Baru',
          style: TextStyle(color: _brown, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
            children: <Widget>[
              const Icon(Icons.password_rounded, size: 64, color: _orange),
              const SizedBox(height: 20),
              const AyoText(
                'Masukkan password baru untuk akun Ayo Suruh Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF746760), height: 1.4),
              ),
              const SizedBox(height: 28),
              _passwordField(
                controller: _passwordController,
                label: AyoI18n.t('Password Baru'),
                obscure: _obscurePassword,
                onToggle: () => setState(
                  () => _obscurePassword = !_obscurePassword,
                ),
                validator: (String? value) {
                  if ((value ?? '').length < 8) {
                    return 'Password minimal 8 karakter.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _passwordField(
                controller: _confirmController,
                label: AyoI18n.t('Konfirmasi Password Baru'),
                obscure: _obscureConfirm,
                onToggle: () => setState(
                  () => _obscureConfirm = !_obscureConfirm,
                ),
                validator: (String? value) {
                  if (value != _passwordController.text) {
                    return 'Konfirmasi password tidak sama.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _savePassword,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const AyoText(
                          'Simpan Password Baru',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autofillHints: const <String>[AutofillHints.newPassword],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8D8CE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _orange, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
