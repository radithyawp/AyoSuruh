import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_preferences.dart';
import 'change_password.dart';
import 'widgets/home_shortcut_button.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  static const Color _brown = Color(0xFF8B5A2B);
  static const Color _bg = Color(0xFFFAF6F3);

  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final bool remember = await AuthPreferences.shouldRememberSession();
    if (mounted) setState(() => _rememberMe = remember);
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
            icon: Icons.phonelink_lock_outlined,
            title: 'Pemulihan sesi',
            body: _rememberMe
                ? 'Ingat Saya aktif. Sesi yang masih valid dapat dipulihkan pada perangkat ini.'
                : 'Ingat Saya nonaktif. Aplikasi meminta login kembali setelah cold start.',
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded, color: _brown),
                  title: const Text('Ganti Password'),
                  subtitle: const Text('Perbarui password akun email Anda.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ChangePassword()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                const ListTile(
                  leading: Icon(Icons.fingerprint_rounded, color: Color(0xFF9B8F87)),
                  title: Text('PIN / Biometrik Aplikasi'),
                  subtitle: Text(
                    'Disiapkan setelah autentikasi dan session management stabil.',
                  ),
                  trailing: Chip(label: Text('Roadmap')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ayo Suruh tidak menyimpan password mentah. Jika perangkat menawarkan penyimpanan password, kredensial dikelola oleh password manager/autofill sistem.',
            style: TextStyle(fontSize: 11, height: 1.45, color: Color(0xFF746A64)),
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
                  style: const TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF6F635C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
