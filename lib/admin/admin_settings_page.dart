import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../change_password.dart';
import '../help_center.dart';
import '../kebijakan.dart';
import '../login.dart';
import '../notification_settings_page.dart';
import '../syarat_ketentuan.dart';
import '../security_settings_page.dart';
import '../services/notification_service.dart';
import 'admin_service.dart';
import 'admin_feedback_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  static const Color _brown = Color(0xFF7B4B00);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _background = Color(0xFFFFFAFD);

  final AdminService _service = AdminService();
  Map<String, dynamic> _profile = <String, dynamic>{};
  bool _loading = true;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic> profile = await _service.fetchMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    if (!kIsWeb) {
      try {
        await NotificationService.instance.unregisterCurrentDevice();
      } catch (error) {
        debugPrint('Cleanup FCM Admin dilewati: $error');
      }
    }

    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      AyoSnackBar.error(context, 'Logout Admin belum berhasil: $error');
    }
  }

  void _open(Widget page) {
    Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: <Widget>[
            const Text(
              'Pengaturan Admin',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _brown),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEDE3DC))),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 29,
                    backgroundColor: const Color(0xFFFFE8C5),
                    backgroundImage: (_profile['avatar_url'] ?? '').toString().isEmpty ? null : NetworkImage(_profile['avatar_url'].toString()),
                    child: (_profile['avatar_url'] ?? '').toString().isEmpty
                        ? const Icon(Icons.admin_panel_settings_rounded, color: _brown, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _loading
                        ? const LinearProgressIndicator(color: _orange)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text((_profile['fullname'] ?? 'Admin').toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              Text((_profile['email'] ?? '').toString(), style: const TextStyle(fontSize: 10.5, color: Color(0xFF70655E))),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section('Keamanan', <Widget>[
              _tile(Icons.security_outlined, 'Keamanan Akun', () => _open(const SecuritySettingsPage())),
              _tile(Icons.lock_reset_rounded, 'Ganti Password', () => _open(const ChangePassword())),
              _tile(Icons.notifications_outlined, 'Pengaturan Notifikasi', () => _open(const NotificationSettingsPage())),
            ]),
            const SizedBox(height: 12),
            _section('Insight Pengguna', <Widget>[
              _tile(Icons.rate_review_outlined, 'Masukan Pengguna', () => _open(const AdminFeedbackPage())),
            ]),
            const SizedBox(height: 12),
            _section('Informasi', <Widget>[
              _tile(Icons.help_outline_rounded, 'Pusat Bantuan Admin', () => _open(const HelpPage())),
              _tile(Icons.description_outlined, 'Syarat & Ketentuan', () => _open(const SyaratKetentuanPage())),
              _tile(Icons.privacy_tip_outlined, 'Kebijakan Privasi', () => _open(const KebijakanPage())),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _loggingOut ? null : _logout,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFE0DE), foregroundColor: Colors.red.shade700),
                icon: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: const Text(
                  'Keluar Admin',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEDE3DC))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 6),
            child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _brown)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: _orange),
      title: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}
