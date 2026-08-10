import 'package:flutter/material.dart';
import 'widgets/ayo_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:ayosuruh/services/notification_service.dart';

// Import Halaman Terkait
import 'edit_profile.dart';
import 'edit_poto_profile.dart'; // Inklusi khusus untuk edit foto profil
import 'login.dart';
import 'help_center.dart';
import 'pengaturan.dart';
import 'jobs/job_service.dart';
import 'jobs/mitra_job_history_page.dart';
import 'notification.dart';
import 'mitra/mitra_application_page.dart';
import 'mitra/mitra_application_service.dart';
import 'location/location_picker_page.dart';
import 'payments/payment_history_page.dart';
import 'wallet/mitra_wallet_page.dart';
import 'wallet/wallet_service.dart';
import 'tutorial/ayos_tutorial.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'widgets/ayo_pressable.dart';
import 'widgets/ayo_avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.activeMode = 'customer',
    this.canUseMitraMode = false,
    this.onModeChanged,
    this.tutorialAnchors,
  });

  final String activeMode;
  final bool canUseMitraMode;
  final Future<void> Function(String mode)? onModeChanged;
  final AyosTutorialAnchors? tutorialAnchors;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final JobService _jobService = JobService();
  final MitraApplicationService _applicationService = MitraApplicationService();
  final WalletService _walletService = WalletService();

  Map<String, dynamic>? _userRow;
  Map<String, dynamic>? _mitraApplication;
  Map<String, dynamic>? _mitraBaseLocation;
  bool _isLoading = true;
  bool _isSwitchingMode = false;

  // Warna-warna Utama Ayo Suruh
  static const Color _primaryOrange = Color(0xFFF39C12);
  static const Color _brownColor = Color(0xFF8B5A2B);
  static const Color _bgGrey = Color(0xFFFAF6F3);

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  /* ---------- MEMUAT DATA USER ---------- */
  Future<void> _loadProfileData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _logout(context);
        return;
      }

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final Map<String, dynamic> profile = Map<String, dynamic>.from(
        response ?? <String, dynamic>{},
      );

      Map<String, dynamic>? application;
      Map<String, dynamic>? mitraBaseLocation;
      if (widget.activeMode == 'mitra' && widget.canUseMitraMode) {
        try {
          final List<dynamic> mitraResult =
              await Future.wait<dynamic>(<Future<dynamic>>[
                _jobService.fetchMitraDashboardProfile(),
                _walletService.fetchSummary(),
                _applicationService.fetchMitraBaseLocation(),
              ]);
          profile.addAll(mitraResult[0] as Map<String, dynamic>);
          profile.addAll(mitraResult[1] as Map<String, dynamic>);
          mitraBaseLocation = mitraResult[2] as Map<String, dynamic>?;
        } catch (error) {
          debugPrint('Statistik mitra belum dapat dimuat: $error');
        }
      } else if (!widget.canUseMitraMode) {
        try {
          application = await _applicationService.fetchMyApplication();
        } catch (error) {
          debugPrint('Status pengajuan mitra belum dapat dimuat: $error');
        }
      }

      profile['email'] = profile['email'] ?? user.email;

      if (mounted) {
        setState(() {
          _userRow = profile;
          _mitraApplication = application;
          _mitraBaseLocation = mitraBaseLocation;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /* ---------- NAVIGASI ---------- */

  // Navigasi ke Edit Data Profil (Nama, Telepon, dsb)
  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(userRow: _userRow ?? {}),
      ),
    );

    if (result == true) {
      _loadProfileData();
    }
  }

  // Navigasi Khusus ke Edit Foto Profil
  Future<void> _navigateToEditPhoto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPhotoProfilePage(userRow: _userRow ?? {}),
      ),
    );

    if (result == true) {
      _loadProfileData();
    }
  }

  Future<void> _navigateToHelpCenter() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpPage()),
    );
  }

  Future<void> _navigateToPengaturanPage() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PengaturanPage()),
    );
  }

  Future<void> _navigateToMitraLocation() async {
    try {
      final Map<String, dynamic>? current =
          _mitraBaseLocation ??
          await _applicationService.fetchMitraBaseLocation();
      final double? latitude = double.tryParse(
        current?['latitude']?.toString() ?? '',
      );
      final double? longitude = double.tryParse(
        current?['longitude']?.toString() ?? '',
      );
      final LatLng? initialPoint = latitude != null && longitude != null
          ? LatLng(latitude, longitude)
          : null;
      final String initialAddress =
          (current?['address'] ?? _userRow?['alamat'] ?? '').toString();

      if (!mounted) return;
      final PickedLocation? picked = await Navigator.push<PickedLocation>(
        context,
        MaterialPageRoute<PickedLocation>(
          builder: (_) => LocationPickerPage(
            initialPoint: initialPoint,
            addressLabel: initialAddress,
          ),
        ),
      );
      if (picked == null || !mounted) return;

      final Map<String, dynamic> saved = await _applicationService
          .saveMitraBaseLocation(
            address: picked.addressLabel.trim().isEmpty
                ? initialAddress
                : picked.addressLabel,
            latitude: picked.point.latitude,
            longitude: picked.point.longitude,
          );
      if (!mounted) return;
      setState(() => _mitraBaseLocation = saved);
      AyoSnackBar.success(
        context,
        'Lokasi Utama Mitra berhasil diperbarui.',
      );
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Lokasi Mitra belum dapat diperbarui: $error',
      );
    }
  }

  Future<void> _navigateToMitraHistory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const MitraJobHistoryPage()),
    );
    if (mounted) await _loadProfileData();
  }

  Future<void> _navigateToWallet() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const MitraWalletPage()),
    );
    if (mounted) await _loadProfileData();
  }

  Future<void> _navigateToMitraApplication() async {
    final String status = (_mitraApplication?['status'] ?? '')
        .toString()
        .toLowerCase();

    final Widget page;
    if (_mitraApplication == null || status == 'rejected') {
      page = MitraApplicationPage(existingApplication: _mitraApplication);
    } else {
      page = MitraApplicationStatusPage(initialApplication: _mitraApplication);
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) await _loadProfileData();
  }

  /* ---------- DIALOG & LOGOUT ---------- */
  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar Akun',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    // Kegagalan FCM tidak boleh menggagalkan logout akun.
    if (!kIsWeb) {
      try {
        await NotificationService.instance.unregisterCurrentDevice();
      } catch (error, stackTrace) {
        debugPrint('Pembersihan token FCM dilewati: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    try {
      await _supabase.auth.signOut();
    } catch (error, stackTrace) {
      debugPrint('Error logout Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  /* ---------- BUILD METHOD ---------- */
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _primaryOrange)),
      );
    }

    final String displayName = _userRow?['fullname'] ?? 'Pengguna';
    final String email = _userRow?['email'] ?? '-';
    final String phone = _userRow?['phone'] ?? '-';
    final String? avatarUrl = _userRow?['avatar_url'];
    final bool isMitra = widget.activeMode == 'mitra' && widget.canUseMitraMode;

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        child: Column(
          children: [
            // --- HEADER AVATAR & AKUN (Klik Avatar Untuk Ubah Foto) ---
            KeyedSubtree(
              key: widget.tutorialAnchors?.profileHeader,
              child: _buildProfileHeader(
                displayName,
                email,
                phone,
                avatarUrl,
                isMitra,
              ),
            ),
            const SizedBox(height: 18),
            if (widget.canUseMitraMode) ...[
              KeyedSubtree(
                key: widget.tutorialAnchors?.profileMode,
                child: _buildModeSwitcher(isMitra),
              ),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 6),

            // --- TAMPILAN DINAMIS BERDASARKAN MODE AKTIF ---
            if (isMitra) ...[
              _buildMitraStatsCard(),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: widget.tutorialAnchors?.profileFinance,
                child: _buildSaldoCard(
                  title: "PENDAPATAN MITRA",
                  buttonText: "Cairkan",
                  onPressed: _navigateToWallet,
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                Icons.history,
                'Riwayat Pekerjaan Mitra',
                _navigateToMitraHistory,
              ),
              _buildMenuCard(
                Icons.edit_outlined,
                'Edit Profil',
                _navigateToEditProfile,
              ),
              _buildMitraLocationCard(),
              _buildMenuCard(
                Icons.account_balance_wallet_outlined,
                'Dompet & Rekening',
                _navigateToWallet,
              ),
            ] else ...[
              KeyedSubtree(
                key: widget.tutorialAnchors?.profileFinance,
                child: _buildSaldoCard(
                  title: "SALDO AYOPAY",
                  buttonText: "Isi Saldo",
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                Icons.history,
                'Riwayat Transaksi',
                () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PaymentHistoryPage(),
                  ),
                ),
              ),
              _buildMenuCard(
                Icons.person_outline,
                'Edit Profil',
                _navigateToEditProfile,
              ),
              if (!widget.canUseMitraMode) _buildPartnerBanner(),
            ],

            // --- MENU UMUM ---
            _buildMenuCard(
              Icons.help_outline,
              'Bantuan & Pusat Dukungan',
              _navigateToHelpCenter,
            ),
            _buildMenuCard(
              Icons.settings_outlined,
              'Pengaturan',
              _navigateToPengaturanPage,
            ),
            const SizedBox(height: 24),

            // --- TOMBOL KELUAR SESI ---
            _buildLogoutButton(),
            const SizedBox(height: 20),

            // --- FOOTER VERSI ---
            Text(
              'Ayo Suruh v2.4.0',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------- HELPER WIDGETS ---------- */

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEFE1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/images/Logo_Ayo_Suruh.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 9),
          const Text(
            'Profil',
            style: TextStyle(
              color: _brownColor,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        NotificationBell(
          color: Colors.black87,
          size: 25,
          activeMode: widget.activeMode,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildProfileHeader(
    String name,
    String email,
    String phone,
    String? avatarUrl,
    bool isMitra,
  ) {
    return Column(
      children: [
        // Avatar dengan Badge Kamera (Klik untuk ubah foto)
        AyoPressable(
          onTap: _navigateToEditPhoto,
          haptic: true,
          pressedScale: 0.965,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              AyoAvatar(
                imageUrl: avatarUrl,
                size: 108,
                backgroundColor: const Color(0xFFFFEFE1),
                logoPadding: 18,
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _primaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isMitra
                      ? Colors.green.shade100
                      : const Color(0xFFFFE8C2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isMitra ? 'Mitra' : 'Customer',
                  style: TextStyle(
                    color: isMitra ? Colors.green.shade800 : _brownColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(email, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          phone,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _brownColor,
          ),
        ),
      ],
    );
  }

  Future<void> _switchMode(bool currentlyMitra) async {
    final Future<void> Function(String mode)? callback = widget.onModeChanged;
    if (callback == null || _isSwitchingMode) return;

    final String targetMode = currentlyMitra ? 'customer' : 'mitra';
    setState(() => _isSwitchingMode = true);
    try {
      await callback(targetMode);
    } finally {
      if (mounted) setState(() => _isSwitchingMode = false);
    }
  }

  Widget _buildModeSwitcher(bool isMitra) {
    final String activeLabel = isMitra ? 'Peran aktif: Mitra' : 'Peran aktif: Customer';
    final String description = isMitra
        ? 'Terima pekerjaan, kirim penawaran, dan kelola progres.'
        : 'Buat pekerjaan, pilih Mitra, dan kelola kebutuhanmu.';
    final String buttonLabel = isMitra ? 'Beralih ke Customer' : 'Beralih ke Mitra';
    final IconData activeIcon = isMitra
        ? Icons.engineering_rounded
        : Icons.person_rounded;
    final IconData buttonIcon = isMitra
        ? Icons.person_outline_rounded
        : Icons.engineering_outlined;
    final Color accent = isMitra ? const Color(0xFF4B613E) : _brownColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMitra
              ? const <Color>[Color(0xFFEAF3E4), Color(0xFFF7FAF5)]
              : const <Color>[Color(0xFFFFE8C5), Color(0xFFFFF7EA)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMitra ? const Color(0xFFCFE2C3) : const Color(0xFFF1D1A0),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(activeIcon, color: accent, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      activeLabel,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.2,
                        height: 1.3,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: _isSwitchingMode ? null : () => _switchMode(isMitra),
                icon: _isSwitchingMode
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(buttonIcon, size: 16),
                label: Text(buttonLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaldoCard({
    required String title,
    required String buttonText,
    VoidCallback? onPressed,
  }) {
    final bool isMitraIncome = title == 'PENDAPATAN MITRA';

    // Hindari ambiguitas parser pada kombinasi operator ternary dan
    // null-aware index access di beberapa versi Dart/Flutter.
    final Map<String, dynamic>? userRow = _userRow;
    final dynamic rawAmount;
    if (userRow == null) {
      rawAmount = null;
    } else if (isMitraIncome) {
      rawAmount = userRow['available_balance'] ?? userRow['total_pendapatan'];
    } else {
      rawAmount = userRow['saldo'];
    }

    final num amount = rawAmount is num
        ? rawAmount
        : num.tryParse(rawAmount?.toString() ?? '') ?? 0;
    final String saldo = _formatThousands(amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0E6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: _brownColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp $saldo',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(
              Icons.add_circle_outline,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              buttonText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brownColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMitraStatsCard() {
    final pekerjaanSelesai = _userRow?['pekerjaan_selesai'] ?? 0;
    final rating = _userRow?['rating'] ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '$pekerjaanSelesai',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _brownColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pekerjaan Selesai',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 22),
                const SizedBox(width: 6),
                Text(
                  '$rating',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerBanner() {
    final String status = (_mitraApplication?['status'] ?? '')
        .toString()
        .toLowerCase();

    String title = 'Daftar Menjadi Mitra';
    String subtitle = 'Dapatkan penghasilan tambahan';
    IconData icon = Icons.work_outline;
    Color background = _primaryOrange;

    if (status == 'applied') {
      title = 'Pengajuan Mitra Diproses';
      subtitle = 'Tekan untuk memeriksa status verifikasi';
      icon = Icons.hourglass_top_rounded;
      background = const Color(0xFFFFDCA8);
    } else if (status == 'approved') {
      title = 'Pengajuan Mitra Disetujui';
      subtitle = 'Aktifkan dashboard mitramu sekarang';
      icon = Icons.verified_outlined;
      background = const Color(0xFFDDEED3);
    } else if (status == 'rejected') {
      title = 'Perbaiki Pengajuan Mitra';
      subtitle = 'Periksa catatan verifikasi dan ajukan ulang';
      icon = Icons.edit_note_rounded;
      background = const Color(0xFFFFD8D8);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.black87),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          trailing: const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.black87,
          ),
          onTap: _navigateToMitraApplication,
        ),
      ),
    );
  }

  Widget _buildMitraLocationCard() {
    final String address = (_mitraBaseLocation?['address'] ?? '')
        .toString()
        .trim();
    final bool ready =
        address.isNotEmpty &&
        _mitraBaseLocation?['latitude'] != null &&
        _mitraBaseLocation?['longitude'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: ready
              ? const Color(0xFFF0F6EC)
              : const Color(0xFFFFF0DD),
          child: Icon(
            ready ? Icons.location_on_rounded : Icons.location_off_outlined,
            color: ready ? const Color(0xFF5C744D) : _brownColor,
          ),
        ),
        title: const Text(
          'Lokasi Utama Mitra',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          ready
              ? address
              : 'Lengkapi titik lokasi agar jarak muncul pada penawaran Customer.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            color: ready ? Colors.black54 : _brownColor,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _navigateToMitraLocation,
      ),
    );
  }

  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFF7F3F0),
            child: Icon(icon, color: Colors.black87, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          onTap: onTap,
        ),
      ),
    );
  }

  String _formatThousands(num value) {
    final String digits = value.round().toString();
    final StringBuffer result = StringBuffer();
    for (int index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        result.write('.');
      }
      result.write(digits[index]);
    }
    return result.toString();
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _showLogoutConfirmationDialog,
        icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
        label: const Text(
          'Log out',
          style: TextStyle(
            color: Colors.red,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF5F5),
          side: BorderSide(color: Colors.red.shade200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
