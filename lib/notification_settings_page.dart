import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/home_shortcut_button.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const Color _brown = Color(0xFF8B5A2B);
  static const Color _orange = Color(0xFFF39C12);
  static const Color _bg = Color(0xFFFAF6F3);

  bool _master = true;
  bool _jobs = true;
  bool _chat = true;
  bool _payments = true;
  bool _promos = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _master = prefs.getBool('notification_master') ?? true;
      _jobs = prefs.getBool('notification_jobs') ?? true;
      _chat = prefs.getBool('notification_chat') ?? true;
      _payments = prefs.getBool('notification_payments') ?? true;
      _promos = prefs.getBool('notification_promos') ?? false;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
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
          'Pengaturan Notifikasi',
          style: TextStyle(color: _brown, fontWeight: FontWeight.w800),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9C9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.notifications_active_outlined, color: _brown),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Preferensi ini sudah disimpan di aplikasi. Pengiriman push ke sistem Android/iOS akan mengikuti preferensi ini setelah Firebase Cloud Messaging diaktifkan.',
                          style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF67503D)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _switchTile(
                  title: 'Semua Notifikasi',
                  subtitle: 'Kontrol utama notifikasi Ayo Suruh',
                  value: _master,
                  onChanged: (bool value) {
                    setState(() => _master = value);
                    _save('notification_master', value);
                  },
                ),
                const SizedBox(height: 10),
                _switchTile(
                  title: 'Pekerjaan',
                  subtitle: 'Penawaran, status pekerjaan, progres, dan rating',
                  value: _jobs,
                  enabled: _master,
                  onChanged: (bool value) {
                    setState(() => _jobs = value);
                    _save('notification_jobs', value);
                  },
                ),
                _switchTile(
                  title: 'Chat',
                  subtitle: 'Pesan baru dari customer atau mitra',
                  value: _chat,
                  enabled: _master,
                  onChanged: (bool value) {
                    setState(() => _chat = value);
                    _save('notification_chat', value);
                  },
                ),
                _switchTile(
                  title: 'Pembayaran & Dompet',
                  subtitle: 'Pembayaran, refund, saldo mitra, dan payout',
                  value: _payments,
                  enabled: _master,
                  onChanged: (bool value) {
                    setState(() => _payments = value);
                    _save('notification_payments', value);
                  },
                ),
                _switchTile(
                  title: 'Promo & Informasi',
                  subtitle: 'Informasi fitur, program, dan promosi Ayo Suruh',
                  value: _promos,
                  enabled: _master,
                  onChanged: (bool value) {
                    setState(() => _promos = value);
                    _save('notification_promos', value);
                  },
                ),
              ],
            ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Card(
      elevation: 0,
      color: enabled ? Colors.white : const Color(0xFFF1ECE9),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SwitchListTile.adaptive(
        activeThumbColor: _orange,
        value: value,
        onChanged: enabled ? onChanged : null,
        title: Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 10.8)),
      ),
    );
  }
}
