import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';

import '../widgets/home_shortcut_button.dart';
import 'wallet_service.dart';

const Color _bankBrown = Color(0xFF8A5300);
const Color _bankOrange = Color(0xFFFF9800);
const Color _bankBackground = Color(0xFFFFF9FC);

class MitraBankAccountsPage extends StatefulWidget {
  const MitraBankAccountsPage({super.key});

  @override
  State<MitraBankAccountsPage> createState() => _MitraBankAccountsPageState();
}

class _MitraBankAccountsPageState extends State<MitraBankAccountsPage> {
  final WalletService _service = WalletService();

  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<Map<String, dynamic>> _accounts = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> accounts = await _service
          .fetchBankAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openForm([Map<String, dynamic>? account]) async {
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BankAccountFormSheet(
        account: account,
        onSubmit:
            ({
              required String bankName,
              required String accountNumber,
              required String accountHolder,
              required bool isDefault,
            }) async {
              if (account == null) {
                await _service.addBankAccount(
                  bankName: bankName,
                  accountNumber: accountNumber,
                  accountHolder: accountHolder,
                  isDefault: isDefault || _accounts.isEmpty,
                );
              } else {
                await _service.updateBankAccount(
                  accountId: account['id'].toString(),
                  bankName: bankName,
                  accountNumber: accountNumber,
                  accountHolder: accountHolder,
                  makeDefault: isDefault,
                );
              }
            },
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _setDefault(Map<String, dynamic> account) async {
    if (account['is_default'] == true || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await _service.setDefaultBankAccount(account['id'].toString());
      await _load();
      if (!mounted) return;
      AyoSnackBar.success(context, 'Rekening utama berhasil diganti.');
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Rekening utama belum dapat diganti: $error',
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> account) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus rekening?'),
        content: Text(
          '${account['bank_name']} • ${_mask(account['account_number'])} akan dihapus dari daftar pencairan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      await _service.deleteBankAccount(account['id'].toString());
      await _load();
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Rekening belum dapat dihapus: $error',
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _mask(Object? raw) {
    final String value = (raw ?? '').toString().trim();
    if (value.length <= 4) return value;
    return '•••• ${value.substring(value.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bankBackground,
      appBar: AppBar(
        backgroundColor: _bankBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.arrow_back_rounded, color: _bankBrown),
        ),
        title: const Text(
          'Rekening Pencairan',
          style: TextStyle(
            color: _bankBrown,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: const <Widget>[HomeShortcutButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _actionLoading ? null : () => _openForm(),
        backgroundColor: _bankOrange,
        foregroundColor: const Color(0xFF553600),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tambah Rekening',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _bankOrange));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.account_balance_outlined,
                size: 54,
                color: _bankBrown,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    if (_accounts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 80),
          Image.asset(
            'assets/images/ayos/ayos_pointing_left.png',
            height: 180,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada rekening pencairan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: _bankBrown,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tambahkan rekening bank atau akun pencairan. Rekening utama akan dipakai sebagai pilihan awal saat kamu mencairkan saldo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF756861),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: _bankOrange,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
        itemCount: _accounts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> account = _accounts[index];
          final bool isDefault = account['is_default'] == true;
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDefault
                    ? const Color(0xFFFFB347)
                    : const Color(0xFFE9DFD8),
                width: isDefault ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE9C7),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: _bankBrown,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (account['bank_name'] ?? 'Rekening').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _mask(account['account_number']),
                            style: const TextStyle(
                              color: Color(0xFF6B6059),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4E3),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Utama',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4E6A42),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  (account['account_holder'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF766A63),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    if (!isDefault)
                      TextButton.icon(
                        onPressed: _actionLoading
                            ? null
                            : () => _setDefault(account),
                        icon: const Icon(Icons.star_outline_rounded, size: 17),
                        label: const Text('Jadikan Utama'),
                      ),
                    TextButton.icon(
                      onPressed: _actionLoading
                          ? null
                          : () => _openForm(account),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: _actionLoading ? null : () => _delete(account),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                      label: const Text('Hapus'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BankAccountFormSheet extends StatefulWidget {
  const _BankAccountFormSheet({required this.account, required this.onSubmit});

  final Map<String, dynamic>? account;
  final Future<void> Function({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    required bool isDefault,
  })
  onSubmit;

  @override
  State<_BankAccountFormSheet> createState() => _BankAccountFormSheetState();
}

class _BankAccountFormSheetState extends State<_BankAccountFormSheet> {
  static const List<String> _banks = <String>[
    'BCA',
    'BRI',
    'BNI',
    'Mandiri',
    'BSI',
    'CIMB Niaga',
    'Permata',
    'Bank Jago',
    'SeaBank',
    'DANA',
    'GoPay',
    'OVO',
    'Lainnya',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _accountController;
  late final TextEditingController _holderController;
  String? _selectedBank;
  bool _makeDefault = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? account = widget.account;
    final String existingBank = (account?['bank_name'] ?? '').toString();
    _selectedBank = _banks.contains(existingBank)
        ? existingBank
        : (existingBank.isEmpty ? null : 'Lainnya');
    _accountController = TextEditingController(
      text: (account?['account_number'] ?? '').toString(),
    );
    _holderController = TextEditingController(
      text: (account?['account_holder'] ?? '').toString(),
    );
    _makeDefault = account?['is_default'] == true;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        bankName: _selectedBank!,
        accountNumber: _accountController.text.trim(),
        accountHolder: _holderController.text.trim(),
        isDefault: _makeDefault,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Rekening belum dapat disimpan: $error',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: _bankBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.account == null ? 'Tambah Rekening' : 'Edit Rekening',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _bankBrown,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBank,
                  items: _banks
                      .map(
                        (String bank) => DropdownMenuItem<String>(
                          value: bank,
                          child: Text(bank),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) =>
                      setState(() => _selectedBank = value),
                  validator: (String? value) =>
                      value == null ? 'Pilih bank/e-wallet.' : null,
                  decoration: _decoration('Bank / e-wallet'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  validator: (String? value) {
                    if ((value ?? '').trim().length < 6) {
                      return 'Nomor rekening belum valid.';
                    }
                    return null;
                  },
                  decoration: _decoration('Nomor rekening / akun'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _holderController,
                  textCapitalization: TextCapitalization.words,
                  validator: (String? value) {
                    if ((value ?? '').trim().length < 2) {
                      return 'Nama pemilik wajib diisi.';
                    }
                    return null;
                  },
                  decoration: _decoration('Nama pemilik rekening'),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  value: _makeDefault,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: _bankOrange,
                  title: const Text(
                    'Jadikan rekening utama',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Rekening utama menjadi pilihan awal saat pencairan.',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: widget.account?['is_default'] == true
                      ? null
                      : (bool value) => setState(() => _makeDefault = value),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _bankBrown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text(
                      'Simpan Rekening',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE6DAD2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _bankOrange, width: 1.4),
      ),
    );
  }
}
