import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isLoading = false;
  bool _emailSent = false;

  static const Color _orange = Color(0xFFF39C12);
  static const Color _brown = Color(0xFF8B5A2B);
  static const Color _background = Color(0xFFFAF6F3);

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      const String resetRedirect = 'io.supabase.ayosuruh://reset-password/';

      debugPrint('RESET PASSWORD REDIRECT SENT => $resetRedirect');

      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: resetRedirect,
      );
      if (!mounted) return;
      setState(() => _emailSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tautan reset password sudah dikirim. Periksa email Anda.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tautan reset belum dapat dikirim: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _brown),
        ),
        title: const Text(
          'Lupa Password',
          style: TextStyle(color: _brown, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8C5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                size: 38,
                color: _brown,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Reset password secara mandiri',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF312A26),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _emailSent
                  ? 'Email sudah dikirim. Buka tautan dari Supabase/Ayo Suruh, lalu Anda akan kembali ke aplikasi untuk membuat password baru.'
                  : 'Masukkan email akun Ayo Suruh. Kami akan mengirim tautan aman untuk membuat password baru tanpa perlu menghubungi admin.',
              style: const TextStyle(color: Color(0xFF746760), height: 1.45),
            ),
            const SizedBox(height: 26),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                validator: (String? value) {
                  final String email = (value ?? '').trim();
                  if (email.isEmpty || !email.contains('@')) {
                    return 'Masukkan email yang valid.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'nama@email.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE8D8CE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _orange, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _sendResetLink,
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _emailSent ? 'Kirim Ulang Tautan' : 'Kirim Tautan Reset',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline_rounded, size: 17, color: _brown),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Fitur ini tetap dapat digunakan walaupun konfirmasi email saat registrasi tidak diwajibkan. Email reset password tetap harus dapat diterima oleh pemilik akun.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF746760)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
