import 'package:flutter/material.dart';

import 'jobs/job_helpers.dart';
import 'jobs/job_service.dart';
import 'jobs/job_widgets.dart';
import 'jobs/mitra_job_detail_page.dart';
import 'jobs/mitra_jobs_page.dart';
import 'notification.dart';
import 'services/mitra_services_page.dart';
import 'tutorial/ayos_tutorial.dart';
import 'widgets/ayo_avatar.dart';
import 'widgets/ayo_empty_state.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class MitraDashboardPage extends StatefulWidget {
  const MitraDashboardPage({
    super.key,
    this.tutorialAnchors,
  });

  final AyosTutorialAnchors? tutorialAnchors;

  @override
  State<MitraDashboardPage> createState() => _MitraDashboardPageState();
}

class _MitraDashboardPageState extends State<MitraDashboardPage> {
  final JobService _jobService = JobService();

  bool _isLoading = true;
  bool _isUnauthorized = false;
  String? _errorMessage;
  Map<String, dynamic> _profile = <String, dynamic>{};
  Map<String, dynamic> _growthBenefits = <String, dynamic>{};
  Map<String, dynamic>? _activeJob;
  List<Map<String, dynamic>> _availableJobs = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final String role = await _jobService.getCurrentRole();
      if (role != 'mitra') {
        if (!mounted) return;
        setState(() {
          _isUnauthorized = true;
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchMitraDashboardProfile(),
        _jobService.fetchAssignedMitraJobs(),
        _jobService.fetchAvailableJobs(),
        _jobService.fetchMyGrowthBenefits(),
      ]);
      final List<Map<String, dynamic>> activeJobs =
          result[1] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> availableJobs =
          result[2] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _profile = result[0] as Map<String, dynamic>;
        _growthBenefits = result[3] as Map<String, dynamic>;
        _activeJob = activeJobs.isEmpty ? null : activeJobs.first;
        _availableJobs = availableJobs.take(3).toList();
        _isUnauthorized = false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openJob(Map<String, dynamic> job) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => MitraJobDetailPage(jobId: job['id'].toString()),
      ),
    );
    if (changed == true) await _loadDashboard();
  }

  Future<void> _openAllJobs() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const MitraJobsPage()),
    );
    await _loadDashboard();
  }

  Future<void> _openMyServices() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const MitraServicesPage()),
    );
    if (mounted) await _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: jobBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: jobOrangeColor)),
      );
    }
    if (_isUnauthorized) {
      return Scaffold(
        backgroundColor: jobBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.lock_outline_rounded, size: 58, color: jobBrownColor),
                const SizedBox(height: 14),
                const AyoText(
                  'Akses Khusus Mitra',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const AyoText(
                  'Dashboard ini hanya dapat digunakan oleh akun dengan role mitra.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: jobBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: jobOrangeColor,
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: <Widget>[
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0DD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AyoText(
                    'Sebagian data belum dapat dimuat: $_errorMessage',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              KeyedSubtree(
                key: widget.tutorialAnchors?.homeHeader,
                child: _buildHeader(),
              ),
              const SizedBox(height: 20),
              KeyedSubtree(
                key: widget.tutorialAnchors?.homeSearchOrIncome,
                child: _buildIncomeCard(),
              ),
              if (_shouldShowFirstJobBonus) ...<Widget>[
                const SizedBox(height: 12),
                _buildFirstJobBonusCard(),
              ],
              const SizedBox(height: 10),
              _buildStats(),
              const SizedBox(height: 14),
              KeyedSubtree(
                key: widget.tutorialAnchors?.homePromoOrService,
                child: _buildServiceMarketplaceShortcut(),
              ),
              const SizedBox(height: 22),
              KeyedSubtree(
                key: widget.tutorialAnchors?.homeCategoriesOrActive,
                child: _buildActiveJob(),
              ),
              const SizedBox(height: 22),
              KeyedSubtree(
                key: widget.tutorialAnchors?.homePrimaryActionOrAvailable,
                child: _buildAvailableJobs(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String? avatar = _profile['avatar_url']?.toString();
    return Row(
      children: <Widget>[
        AyoAvatar(
          imageUrl: avatar,
          size: 46,
          backgroundColor: const Color(0xFFFFE5C0),
          logoPadding: 7,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AyoText(
                'Halo, Mitra!',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              AyoText(
                (_profile['fullname'] ?? 'Mitra Ayo Suruh').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: jobBrownColor,
                  fontSize: 18,
                  height: 1.16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        NotificationBell(
          color: jobBrownColor,
          size: 28,
          activeMode: 'mitra',
        ),
      ],
    );
  }

  Widget _buildServiceMarketplaceShortcut() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _openMyServices,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: jobBorderColor),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : const Color(0xFFFFE6BD),
                child: Icon(Icons.storefront_rounded, color: jobBrownColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AyoText(
                      'Jasa Saya',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: jobBrownColor,
                      ),
                    ),
                    SizedBox(height: 3),
                    AyoText(
                      'Publikasikan keahlian agar customer bisa menemukan jasamu.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: jobBrownColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeCard() {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? colors.surfaceContainerHighest : const Color(0xFFFFEFE3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? colors.outlineVariant : const Color(0xFFFFC98C),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AyoText(
                'Total Pendapatan',
                style: TextStyle(
                  color: dark ? colors.onSurfaceVariant : jobDarkBrownColor,
                ),
              ),
              const SizedBox(height: 4),
              AyoText(
                formatRupiah(_profile['total_pendapatan']),
                style: TextStyle(
                  color: dark ? colors.onSurface : jobBrownColor,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              AyoText(
                'Pendapatan dari pekerjaan yang sudah tercatat',
                style: TextStyle(
                  fontSize: 10,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Positioned(
            right: 2,
            bottom: 0,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 62,
              color: dark
                  ? colors.onSurface.withValues(alpha: 0.08)
                  : const Color(0x1A6F4300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final num rating = _profile['rating'] is num
        ? _profile['rating'] as num
        : num.tryParse(_profile['rating']?.toString() ?? '') ?? 0;
    return Row(
      children: <Widget>[
        Expanded(
          child: _statCard(
            icon: Icons.star_rounded,
            value: rating.toStringAsFixed(1),
            label: AyoI18n.t('Rating Anda'),
            background: const Color(0xFFF7F8F2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_outline_rounded,
            value: (_profile['pekerjaan_selesai'] ?? 0).toString(),
            label: AyoI18n.t('Selesai'),
            background: const Color(0xFFF1EEF1),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color background,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: dark ? colors.surfaceContainerHighest : background,
        borderRadius: BorderRadius.circular(14),
        border: dark ? Border.all(color: colors.outlineVariant) : null,
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: jobDarkBrownColor, size: 21),
              const SizedBox(width: 4),
              AyoText(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 5),
          AyoText(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveJob() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const AyoText('Pekerjaan Aktif', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (_activeJob != null)
              JobStatusChip(status: _activeJob!['status']),
          ],
        ),
        const SizedBox(height: 11),
        if (_activeJob == null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.all(Radius.circular(18)),
              border: Border.fromBorderSide(BorderSide(color: jobBorderColor)),
            ),
            child: AyoEmptyState(
              compact: true,
              assetPath: 'assets/images/ayos/ayos_board_task.png',
              badgeIcon: Icons.assignment_outlined,
              title: 'Belum ada pekerjaan aktif',
              description:
                  'Pekerjaan yang penawarannya diterima Customer akan tampil di sini.',
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: jobBorderColor),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: categoryBackground(categoryName(_activeJob!)),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        categoryIcon(categoryName(_activeJob!)),
                        color: jobGreenColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AyoText(
                            _activeJob!['title'].toString(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          AyoText(
                            'Customer: ${customerName(_activeJob!)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF655B55)),
                          ),
                          const SizedBox(height: 3),
                          AyoText(
                            jobAddress(_activeJob!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF71665F)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: () => _openJob(_activeJob!),
                    style: FilledButton.styleFrom(
                      backgroundColor: jobBrownColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: AyoText(
                      _activeJob!['status'] == 'accepted'
                          ? 'Mulai Pekerjaan'
                          : 'Update Status',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool get _shouldShowFirstJobBonus {
    return _growthBenefits['first_job_bonus_available'] == true ||
        _growthBenefits['first_job_bonus_reserved'] == true;
  }

  num get _normalPlatformFeePercent {
    final dynamic value = _growthBenefits['normal_platform_fee_percent'];
    return value is num ? value : num.tryParse(value?.toString() ?? '') ?? 6;
  }

  Widget _buildFirstJobBonusCard() {
    final bool reserved =
        _growthBenefits['first_job_bonus_reserved'] == true;
    final num rate = _normalPlatformFeePercent;
    final String rateLabel = rate.toDouble() == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color.alphaBlend(
                const Color(0xFFFFB84D).withValues(alpha: 0.14),
                Theme.of(context).colorScheme.surface,
              )
            : const Color(0xFFFFF0D7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF8B6734)
              : const Color(0xFFFFD296),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.celebration_rounded,
              color: jobOrangeColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  AyoI18n.isEnglish
                      ? 'New Partner Bonus'
                      : 'Bonus Mitra Baru',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                AyoText(
                  reserved
                      ? (AyoI18n.isEnglish
                          ? 'Your 0% commission bonus is reserved for your first eligible job. Complete the job and payment to use the bonus.'
                          : 'Bonus 0% komisi sudah dicadangkan untuk pekerjaan pertamamu. Selesaikan pekerjaan dan pembayaran agar bonus terpakai.')
                      : (AyoI18n.isEnglish
                          ? 'Enjoy 0% commission on your first eligible successfully completed job. After the bonus is used, the normal $rateLabel% commission applies.'
                          : 'Nikmati 0% komisi pada pekerjaan pertamamu yang memenuhi syarat dan berhasil selesai. Setelah bonus terpakai, komisi normal $rateLabel% berlaku.'),
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableJobs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const AyoText('Pekerjaan Tersedia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            TextButton(onPressed: _openAllJobs, child: const AyoText('Lihat Semua')),
          ],
        ),
        const SizedBox(height: 4),
        if (_availableJobs.isEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.all(Radius.circular(18)),
              border: Border.fromBorderSide(BorderSide(color: jobBorderColor)),
            ),
            child: AyoEmptyState(
              compact: true,
              assetPath: 'assets/images/ayos/ayos_search.png',
              badgeIcon: Icons.work_outline_rounded,
              title: 'Belum ada pekerjaan baru',
              description: 'Pekerjaan baru dari Customer akan muncul di sini.',
            ),
          )
        else
          ..._availableJobs.map((Map<String, dynamic> job) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openJob(job),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: jobBorderColor),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: categoryBackground(categoryName(job)),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(categoryIcon(categoryName(job)), color: jobDarkBrownColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (isFirstJobPriority(job)) ...<Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE4B8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: AyoText(
                                    AyoI18n.isEnglish
                                        ? 'AYOS PRIORITY'
                                        : 'PRIORITAS AYOS',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF9B5C00),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                              ],
                              AyoText(
                                job['title'].toString(),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              AyoText(
                                jobAddress(job),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF6E645E)),
                              ),
                              const SizedBox(height: 4),
                              AyoText(
                                'Est. ${formatRupiah(job['budget'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: jobBrownColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: Colors.transparent,
                          child: Icon(Icons.chevron_right_rounded, color: jobDarkBrownColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
