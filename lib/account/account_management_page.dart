import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_preferences.dart';
import '../login.dart';
import '../widgets/home_shortcut_button.dart';
import 'account_service.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import '../theme/ayo_theme.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  static Color get _brown => AyoAdaptiveColors.brown;
  static const Color _orange = Color(0xFFF6990E);

  final AccountService _service = AccountService();
  final TextEditingController _noteController = TextEditingController();

  Map<String, dynamic>? _readiness;
  String? _reasonCode;
  bool _loading = true;
  bool _processing = false;

  static const List<Map<String, String>> _reasons = <Map<String, String>>[
    <String, String>{'code': 'rarely_use', 'label': 'Jarang menggunakan Ayo Suruh'},
    <String, String>{'code': 'service_issue', 'label': 'Layanan belum sesuai kebutuhan'},
    <String, String>{'code': 'privacy', 'label': 'Pertimbangan privasi atau keamanan'},
    <String, String>{'code': 'payment', 'label': 'Masalah pembayaran atau pencairan'},
    <String, String>{'code': 'experience', 'label': 'Pengalaman aplikasi kurang nyaman'},
    <String, String>{'code': 'other', 'label': 'Alasan lainnya'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic> readiness =
          await _service.fetchDeletionReadiness();
      if (!mounted) return;
      setState(() {
        _readiness = readiness;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AyoText('Status akun belum dapat dimuat: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? get _reasonLabel {
    if (_reasonCode == null) return null;
    for (final Map<String, String> item in _reasons) {
      if (item['code'] == _reasonCode) return item['label'];
    }
    return null;
  }

  Future<void> _finishSession(String notice) async {
    await AuthPreferences.clearRememberedLogin();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Auth identity mungkin sudah dihapus oleh Edge Function.
    }
    if (!mounted) return;
    // Beri framework satu microtask untuk menyelesaikan teardown dialog/widget
    // sebelum seluruh route lama dibuang. Ini mencegah assertion lifecycle yang
    // sempat terlihat sesaat setelah permanent delete.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(noticeMessage: notice),
      ),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _deactivate() async {
    if (_processing) return;
    final bool canDeactivate = _readiness?['can_deactivate'] == true;
    if (!canDeactivate) {
      _showBlockedMessage('Akun belum dapat dinonaktifkan.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const AyoText('Nonaktifkan sementara?'),
        content: const AyoText(
          'Kamu akan keluar dari Ayo Suruh dan profil Mitra tidak ditampilkan sampai akun diaktifkan kembali. Login berikutnya akan mengaktifkan akun kembali.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AyoText('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AyoText('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await _service.deactivateAccount(
        reasonCode: _reasonCode,
        reasonLabel: _reasonLabel,
        note: _noteController.text,
      );
      await _finishSession(
        'Akun dinonaktifkan sementara. Login kembali kapan saja untuk mengaktifkannya.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AyoText('$error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _deletePermanently() async {
    if (_processing) return;
    final bool canDelete = _readiness?['can_delete'] == true;
    if (!canDelete) {
      _showBlockedMessage('Akun belum dapat dihapus permanen.');
      return;
    }

    String confirmationText = '';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
          title: const AyoText('Hapus akun permanen?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AyoText(
                'Identitas login dan data profil pribadi akan dihapus. Riwayat transaksi yang wajib dipertahankan dapat tetap tersimpan dalam bentuk akun yang dianonimkan.',
              ),
              const SizedBox(height: 16),
              const AyoText(
                'Ketik persis HAPUS untuk melanjutkan:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (String value) {
                  setDialogState(() => confirmationText = value);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: AyoI18n.t('HAPUS'),
                  helperText: AyoI18n.t('Huruf besar/kecil harus sama persis.'),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AyoText('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: confirmationText == 'HAPUS'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const AyoText('Hapus Permanen'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted || confirmationText != 'HAPUS') return;

    setState(() => _processing = true);
    try {
      await _service.deleteAccount(
        confirmation: confirmationText,
        reasonCode: _reasonCode,
        reasonLabel: _reasonLabel,
        note: _noteController.text,
      );
      await _finishSession(
        'Akun Ayo Suruh berhasil dihapus. Terima kasih sudah pernah menjadi bagian dari Ayo Suruh.',
      );
    } catch (error) {
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AyoText('$error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showBlockedMessage(String title) {
    final List<String> blockers = _blockers;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: AyoText(title),
        content: AyoText(
          blockers.isEmpty
              ? 'Periksa kembali status akun dan coba beberapa saat lagi.'
              : blockers.map((String item) => '• $item').join('\n'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AyoText('Mengerti'),
          ),
        ],
      ),
    );
  }

  List<String> get _blockers {
    final dynamic raw = _readiness?['blockers'];
    if (raw is! List) return <String>[];
    return raw.map((dynamic item) => item.toString()).toList();
  }

  String _rupiah(dynamic value) {
    final num amount = value is num
        ? value
        : num.tryParse(value?.toString() ?? '') ?? 0;
    final String digits = amount.round().abs().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
      out.write(digits[i]);
    }
    return 'Rp${amount < 0 ? '-' : ''}${out.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: _brown),
        ),
        title: AyoText(
          'Kelola Akun',
          style: TextStyle(color: _brown, fontWeight: FontWeight.w800),
        ),
        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: <Widget>[
                  _introCard(),
                  const SizedBox(height: 18),
                  _readinessCard(),
                  const SizedBox(height: 20),
                  AyoText(
                    'Sebelum pergi, boleh cerita kenapa?',
                    style: TextStyle(
                      color: _brown,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const AyoText(
                    'Opsional. Jawaban ini membantu kami memperbaiki Ayo Suruh.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF766A63)),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: _reasonCode,
                    onChanged: (String? value) {
                      setState(() => _reasonCode = value);
                    },
                    child: Column(
                      children: _reasons.map(_reasonTile).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 600,
                    decoration: InputDecoration(
                      labelText: AyoI18n.t('Catatan tambahan (opsional)'),
                      hintText: AyoI18n.t('Apa yang bisa kami perbaiki?'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _processing ? null : _deactivate,
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    label: const AyoText('Nonaktifkan Sementara'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: _brown,
                      side: BorderSide(color: _brown),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _processing ? null : _deletePermanently,
                    icon: _processing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: const AyoText('Hapus Akun Permanen'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const AyoText(
                    'Ayo Suruh tidak membuat tombol hapus menjadi sulit ditemukan. Penghapusan hanya ditahan ketika masih ada pekerjaan, refund/dispute, pencairan, atau saldo Mitra yang harus diselesaikan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.45,
                      color: Color(0xFF7C7068),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEED8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.manage_accounts_outlined, color: _brown),
          SizedBox(width: 12),
          Expanded(
            child: AyoText(
              'Kamu bisa berhenti sementara atau menghapus akun secara permanen. Sebelum penghapusan, sistem memeriksa kewajiban transaksi agar hak Customer dan Mitra tetap terlindungi.',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readinessCard() {
    final List<String> blockers = _blockers;
    final bool canDelete = _readiness?['can_delete'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canDelete ? const Color(0xFFCFE2C3) : const Color(0xFFFFD6D1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                canDelete ? Icons.check_circle_outline : Icons.info_outline,
                color: canDelete ? const Color(0xFF5C744D) : Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AyoText(
                  canDelete ? 'Akun siap dihapus' : 'Ada yang perlu diselesaikan',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: AyoI18n.t('Periksa ulang'),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (blockers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...blockers.map(
              (String item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: AyoText('• $item', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
          if (_readiness?['is_mitra'] == true) ...<Widget>[
            const Divider(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: <Widget>[
                _amountChip('Pending', _readiness?['wallet_pending']),
                _amountChip('Tersedia', _readiness?['wallet_available']),
                _amountChip('Ditahan', _readiness?['wallet_held']),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountChip(String label, dynamic value) {
    return Chip(
      label: AyoText('$label · ${_rupiah(value)}'),
      backgroundColor: const Color(0xFFF8F3EF),
      side: BorderSide.none,
    );
  }

  Widget _reasonTile(Map<String, String> item) {
    final bool selected = _reasonCode == item['code'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFE9CA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? _orange : const Color(0xFFEAE0DA),
        ),
      ),
      child: RadioListTile<String>(
        value: item['code']!,
        activeColor: _orange,
        dense: true,
        title: AyoText(item['label']!, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
