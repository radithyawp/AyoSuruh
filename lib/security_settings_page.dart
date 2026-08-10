import 'package:flutter/material.dart';
import 'widgets/ayo_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_preferences.dart';
import 'change_password.dart';
import 'widgets/home_shortcut_button.dart';
import 'wallet/wallet_pin_page.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  static const Color _brown = Color(0xFF8B5A2B);
  static const Color _orange = Color(0xFFF39C12);
  static const Color _bg = Color(0xFFFAF6F3);

  bool _rememberMe = true;
  bool _updatingRemember = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    await AuthPreferences.clearLegacyStoredPassword();
    final bool remember = await AuthPreferences.shouldRememberSession();
    if (mounted) setState(() => _rememberMe = remember);
  }

  Future<void> _setRememberMe(bool value) async {
    if (_updatingRemember) return;
    setState(() => _updatingRemember = true);
    try {
      await AuthPreferences.saveLoginPreference(
        rememberMe: value,
        email: Supabase.instance.client.auth.currentUser?.email,
      );
      if (!mounted) return;
      setState(() => _rememberMe = value);
      AyoSnackBar.info(
        context,
        value
            ? 'Ingat Saya aktif. Sesi dapat dipulihkan pada perangkat ini.'
            : 'Ingat Saya nonaktif. Aplikasi akan meminta login pada sesi berikutnya.',
      );
    } finally {
      if (mounted) setState(() => _updatingRemember = false);
    }
  }

  Future<void> _forgetThisDevice() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Lupakan perangkat ini?'),
        content: const Text(
          'Email yang diingat akan dihapus dan Remember Me dinonaktifkan. Session saat ini tetap aktif sampai kamu logout atau membuka aplikasi kembali dari kondisi cold start.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lupakan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthPreferences.clearRememberedLogin();
    if (!mounted) return;
    setState(() => _rememberMe = false);
    AyoSnackBar.success(
      context,
      'Data login yang diingat pada perangkat ini sudah dibersihkan.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = Supabase.instance.client.auth.currentUser;
    final List<String> providers = (user?.identities ?? const <UserIdentity>[])
        .map((UserIdentity identity) => identity.provider)
        .where((String provider) => provider.trim().isNotEmpty)
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _brown),
        ),
        title: const Text(
          'Keamanan Akun',
          style: TextStyle(color: _brown, fontWeight: FontWeight.w800),
        ),
        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: <Widget>[
          _infoCard(
            icon: Icons.verified_user_outlined,
            title: 'Akun aktif',
            body: user?.email ?? 'Email tidak tersedia',
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.key_rounded,
            title: 'Metode masuk',
            body: providers.isEmpty
                ? 'Email / password'
                : providers.map(_providerLabel).join(', '),
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.password_rounded,
            title: 'Penyimpanan password',
            body:
                'Ayo Suruh tidak menyimpan password akun. Penyimpanan password, jika dipilih, ditangani oleh password manager/autofill sistem perangkat.',
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              secondary: const Icon(Icons.phonelink_lock_outlined, color: _brown),
              title: const Text(
                'Ingat Saya',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                _rememberMe
                    ? 'Session Supabase dapat dipulihkan saat aplikasi dibuka kembali.'
                    : 'Cold start berikutnya akan meminta login kembali.',
              ),
              value: _rememberMe,
              activeThumbColor: _orange,
              onChanged: _updatingRemember ? null : _setRememberMe,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'TINDAKAN KEAMANAN',
            style: TextStyle(
              color: _brown,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded, color: _brown),
                  title: const Text('Ganti Password'),
                  subtitle: const Text('Perbarui password akun email Anda.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ChangePassword(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.phonelink_erase_rounded, color: _brown),
                  title: const Text('Lupakan perangkat ini'),
                  subtitle: const Text(
                    'Hapus email yang diingat dan nonaktifkan pemulihan session.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _forgetThisDevice,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.shield_rounded, color: _brown),
                  title: const Text('PIN AyoPay'),
                  subtitle: const Text(
                    'Kelola PIN 6 digit untuk pencairan dan rekening.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const WalletPinPage(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                const ListTile(
                  leading: Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFF9B8F87),
                  ),
                  title: Text('Biometrik Aplikasi'),
                  subtitle: Text('Opsional untuk tahap hardening lanjutan.'),
                  trailing: Chip(label: Text('Roadmap')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aksi sensitif seperti penghapusan akun dan transaksi AyoPay divalidasi ulang di server. Akses Admin juga tetap diperiksa oleh RPC Supabase, bukan hanya oleh tampilan aplikasi.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: Color(0xFF746A64),
            ),
          ),
        ],
      ),
    );
  }

  String _providerLabel(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return 'Google';
      case 'email':
        return 'Email / password';
      default:
        return provider;
    }
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE1DA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9C9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _brown),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Color(0xFF6F635C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
