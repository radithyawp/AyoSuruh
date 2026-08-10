import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/ayo_snackbar.dart';
import '../widgets/home_shortcut_button.dart';
import 'wallet_service.dart';

const Color _pinBrown = Color(0xFF8A5300);
const Color _pinOrange = Color(0xFFF6990E);
const Color _pinBackground = Color(0xFFFFFAF7);

Future<bool> ensureWalletPinConfigured(
  BuildContext context,
  WalletService service,
) async {
  try {
    final Map<String, dynamic> status = await service.fetchPinStatus();
    if (status['has_pin'] == true) return true;
  } catch (error) {
    if (context.mounted) {
      AyoSnackBar.error(context, 'Status PIN AyoPay belum dapat dibaca: $error');
    }
    return false;
  }

  if (!context.mounted) return false;
  final bool? configured = await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(builder: (_) => const WalletPinPage()),
  );
  return configured == true;
}

Future<String?> showWalletPinPrompt(
  BuildContext context, {
  String title = 'Masukkan PIN AyoPay',
  String message = 'Konfirmasi tindakan finansial dengan PIN 6 digit Anda.',
}) async {
  final TextEditingController controller = TextEditingController();
  String? fieldError;

  final String? result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          void submit() {
            final String pin = controller.text.trim();
            if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
              setDialogState(() {
                fieldError = 'PIN harus tepat 6 angka.';
              });
              return;
            }
            Navigator.pop(dialogContext, pin);
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8C2),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.lock_rounded, color: _pinBrown),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _pinBrown,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  obscuringCharacter: '●',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'PIN 6 digit',
                    errorText: fieldError,
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFFFFBF7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  maxLength: 6,
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: submit,
                style: FilledButton.styleFrom(backgroundColor: _pinOrange),
                child: const Text('Konfirmasi'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.clear();
  controller.dispose();
  return result;
}

class WalletPinPage extends StatefulWidget {
  const WalletPinPage({super.key});

  @override
  State<WalletPinPage> createState() => _WalletPinPageState();
}

class _WalletPinPageState extends State<WalletPinPage> {
  final WalletService _service = WalletService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _hasPin = false;
  bool _forgotMode = false;
  DateTime? _pinChangedAt;
  DateTime? _lockedUntil;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic> status = await _service.fetchPinStatus();
      if (!mounted) return;
      setState(() {
        _hasPin = status['has_pin'] == true;
        _pinChangedAt = DateTime.tryParse(
          (status['pin_changed_at'] ?? '').toString(),
        )?.toLocal();
        _lockedUntil = DateTime.tryParse(
          (status['locked_until'] ?? '').toString(),
        )?.toLocal();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AyoSnackBar.error(context, 'Status PIN AyoPay belum dapat dibaca: $error');
    }
  }

  String? _validatePin(String? value) {
    final String pin = (value ?? '').trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      return 'PIN harus tepat 6 angka.';
    }
    const Set<String> weakPins = <String>{
      '000000', '111111', '222222', '333333', '444444',
      '555555', '666666', '777777', '888888', '999999',
      '123456', '654321', '112233', '121212', '123123', '101010',
    };
    if (weakPins.contains(pin)) {
      return 'PIN terlalu mudah ditebak.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_newPinController.text != _confirmPinController.text) {
      AyoSnackBar.error(context, 'Konfirmasi PIN baru tidak sama.');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_forgotMode) {
        await _service.resetPinWithPassword(
          password: _passwordController.text,
          newPin: _newPinController.text,
        );
        if (!mounted) return;
        AyoSnackBar.success(context, 'PIN AyoPay berhasil direset.');
      } else if (_hasPin) {
        await _service.changePin(
          currentPin: _currentPinController.text,
          newPin: _newPinController.text,
        );
        if (!mounted) return;
        AyoSnackBar.success(context, 'PIN AyoPay berhasil diubah.');
      } else {
        await _service.setupPin(_newPinController.text);
        if (!mounted) return;
        AyoSnackBar.success(context, 'PIN AyoPay berhasil dibuat.');
      }

      _currentPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
      _passwordController.clear();
      await _load();
      if (!mounted) return;
      Navigator.pop(context, true);
    } on WalletPinException catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, error.message);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pinBackground,
      appBar: AppBar(
        backgroundColor: _pinBackground,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'PIN AyoPay',
          style: TextStyle(fontWeight: FontWeight.w900, color: _pinBrown),
        ),
        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pinOrange))
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: <Widget>[
                  _securityCard(),
                  const SizedBox(height: 16),
                  _formCard(),
                ],
              ),
            ),
    );
  }

  Widget _securityCard() {
    final bool locked = _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF8A5300), Color(0xFFB87516)],
        ),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              locked ? Icons.lock_clock_rounded : Icons.verified_user_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  !_hasPin
                      ? 'Aktifkan keamanan AyoPay'
                      : locked
                          ? 'PIN dikunci sementara'
                          : 'PIN AyoPay aktif',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  !_hasPin
                      ? 'PIN 6 digit akan melindungi pencairan saldo dan perubahan rekening.'
                      : locked
                          ? 'Terlalu banyak percobaan salah. Coba kembali setelah masa kunci berakhir.'
                          : 'Diperlukan untuk pencairan, pembatalan pencairan, dan perubahan rekening.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
                if (_hasPin && _pinChangedAt != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Terakhir diubah ${_formatDate(_pinChangedAt!)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    final String title = !_hasPin
        ? 'Buat PIN AyoPay'
        : _forgotMode
            ? 'Reset PIN dengan password'
            : 'Ubah PIN AyoPay';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEDFD5)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _pinBrown,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _forgotMode
                  ? 'Masukkan password akun untuk memverifikasi identitas. Reset dengan password tersedia untuk akun email/password.'
                  : 'Jangan gunakan PIN yang mudah ditebak seperti 123456 atau tanggal lahir.',
              style: const TextStyle(fontSize: 11.5, height: 1.45, color: Colors.black54),
            ),
            const SizedBox(height: 15),
            if (_hasPin && !_forgotMode)
              _pinField(
                controller: _currentPinController,
                label: 'PIN saat ini',
              ),
            if (_forgotMode)
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const <String>[AutofillHints.password],
                validator: (String? value) => (value ?? '').isEmpty
                    ? 'Password akun wajib diisi.'
                    : null,
                decoration: _decoration('Password akun'),
              ),
            if ((_hasPin && !_forgotMode) || _forgotMode)
              const SizedBox(height: 12),
            _pinField(controller: _newPinController, label: 'PIN baru'),
            const SizedBox(height: 12),
            _pinField(
              controller: _confirmPinController,
              label: 'Ulangi PIN baru',
            ),
            const SizedBox(height: 17),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _pinOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shield_rounded),
                label: Text(
                  !_hasPin
                      ? 'Aktifkan PIN'
                      : _forgotMode
                          ? 'Reset PIN'
                          : 'Ubah PIN',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            if (_hasPin) ...<Widget>[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          setState(() {
                            _forgotMode = !_forgotMode;
                            _currentPinController.clear();
                            _newPinController.clear();
                            _confirmPinController.clear();
                            _passwordController.clear();
                          });
                        },
                  child: Text(
                    _forgotMode ? 'Kembali ke Ubah PIN' : 'Lupa PIN?',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      obscuringCharacter: '●',
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      validator: _validatePin,
      decoration: _decoration(label).copyWith(counterText: ''),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFFFBF7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE9DDD6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _pinOrange, width: 1.4),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
