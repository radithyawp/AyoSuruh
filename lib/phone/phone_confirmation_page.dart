import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/ayo_localization.dart';
import '../theme/ayo_theme.dart';
import '../widgets/ayo_snackbar.dart';
import 'phone_confirmation_service.dart';

class PhoneConfirmationPage extends StatefulWidget {
  const PhoneConfirmationPage({super.key});

  @override
  State<PhoneConfirmationPage> createState() => _PhoneConfirmationPageState();
}

class _PhoneConfirmationPageState extends State<PhoneConfirmationPage> {
  final TextEditingController _phoneController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  bool _requestingHint = false;
  bool _internalPhoneChange = false;
  String _verificationLevel = PhoneConfirmationService.unverified;
  String? _confirmedPhone;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_handlePhoneEdited);
    _load();
  }

  @override
  void dispose() {
    _phoneController.removeListener(_handlePhoneEdited);
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) throw StateError('Pengguna belum login.');
      final Map<String, dynamic>? row = await _supabase
          .from('users')
          .select('phone, phone_verification_level')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final String phone = (row?['phone'] ?? '').toString();
      final String level = (row?['phone_verification_level'] ??
              PhoneConfirmationService.unverified)
          .toString();
      _internalPhoneChange = true;
      _phoneController.text = phone;
      _internalPhoneChange = false;
      setState(() {
        _verificationLevel = level;
        _confirmedPhone = PhoneConfirmationService.isConfirmed(level)
            ? PhoneConfirmationService.normalizeIndonesiaPhone(phone)
            : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AyoSnackBar.error(context, 'Status nomor HP belum dapat dimuat: $error');
    }
  }

  void _handlePhoneEdited() {
    if (_internalPhoneChange || !mounted) return;
    final String normalized = PhoneConfirmationService.normalizeIndonesiaPhone(
      _phoneController.text,
    );
    if (_confirmedPhone != null && normalized == _confirmedPhone) return;
    if (_verificationLevel == PhoneConfirmationService.unverified) return;
    setState(() => _verificationLevel = PhoneConfirmationService.unverified);
  }

  Future<void> _pickFromDevice() async {
    if (_requestingHint || !PhoneConfirmationService.supportsDeviceHint) return;
    setState(() => _requestingHint = true);
    try {
      final String? phone =
          await PhoneConfirmationService.requestPhoneNumberHint();
      if (!mounted) return;
      if (phone == null) {
        AyoSnackBar.info(context, 'Pemilihan nomor dari perangkat dibatalkan.');
        return;
      }
      if (!PhoneConfirmationService.isValidIndonesiaPhone(phone)) {
        AyoSnackBar.error(
          context,
          'Nomor dari perangkat belum sesuai format nomor Indonesia.',
        );
        return;
      }
      _internalPhoneChange = true;
      _phoneController.text = phone;
      _internalPhoneChange = false;
      setState(() {
        _verificationLevel = PhoneConfirmationService.deviceConfirmed;
        _confirmedPhone = phone;
      });
      AyoSnackBar.success(context, 'Nomor dari perangkat berhasil dipilih.');
    } on PlatformException {
      if (!mounted) return;
      AyoSnackBar.info(
        context,
        'Nomor SIM belum dapat dibaca otomatis. Masukkan nomor secara manual.',
      );
    } finally {
      if (mounted) setState(() => _requestingHint = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final String phone = PhoneConfirmationService.normalizeIndonesiaPhone(
      _phoneController.text,
    );
    if (!PhoneConfirmationService.isValidIndonesiaPhone(phone)) {
      AyoSnackBar.error(context, 'Masukkan nomor HP Indonesia yang valid.');
      return;
    }

    setState(() => _saving = true);
    try {
      await PhoneConfirmationService.saveCurrentUserPhone(
        phone: phone,
        verificationLevel: _verificationLevel,
      );
      if (!mounted) return;
      AyoSnackBar.success(
        context,
        PhoneConfirmationService.isConfirmed(_verificationLevel)
            ? 'Nomor HP berhasil dikonfirmasi dari perangkat.'
            : 'Nomor HP berhasil disimpan. Statusnya belum dikonfirmasi.',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Nomor HP belum dapat disimpan: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool confirmed =
        PhoneConfirmationService.isConfirmed(_verificationLevel);
    final Color brown = AyoAdaptiveColors.brown;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: AyoText(
          'Konfirmasi Nomor HP',
          style: TextStyle(color: brown, fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            confirmed
                                ? Icons.verified_user_outlined
                                : Icons.phonelink_lock_outlined,
                            color: confirmed
                                ? const Color(0xFF5F784F)
                                : const Color(0xFFF6990E),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AyoText(
                              confirmed
                                  ? 'Nomor dikonfirmasi dari perangkat'
                                  : 'Nomor belum dikonfirmasi',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const AyoText(
                        'Ayo Suruh dapat meminta Android menampilkan nomor yang tersedia dari SIM di perangkat ini. Cara ini tidak mengirim SMS dan tidak meminta izin membaca SMS. Ini membantu mengurangi salah input nomor, tetapi bukan verifikasi SMS atau bukti identitas hukum.',
                        style: TextStyle(fontSize: 12.5, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AyoText(
                  'Nomor HP',
                  style: TextStyle(
                    color: brown,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: InputDecoration(
                    hintText: AyoI18n.t('Contoh: 08123456789'),
                    prefixIcon: const Icon(Icons.smartphone_outlined),
                    filled: true,
                    fillColor: AyoAdaptiveColors.surfaceRaised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (PhoneConfirmationService.supportsDeviceHint)
                  OutlinedButton.icon(
                    onPressed: _requestingHint ? null : _pickFromDevice,
                    icon: _requestingHint
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sim_card_outlined),
                    label: const AyoText('Gunakan nomor dari perangkat ini'),
                  )
                else
                  const AyoText(
                    'Pemilihan nomor dari SIM tersedia pada aplikasi Android. Nomor yang diketik manual akan disimpan sebagai belum dikonfirmasi.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                const SizedBox(height: 10),
                AyoText(
                  confirmed
                      ? 'Jika nomor diubah manual, status konfirmasi perangkat akan dilepas sampai nomor dipilih kembali dari perangkat.'
                      : 'Nomor yang diketik manual tetap dapat disimpan, tetapi akan ditandai belum dikonfirmasi.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF6990E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const AyoText('Simpan Nomor'),
                ),
              ],
            ),
    );
  }
}
