import 'dart:async';

import 'package:flutter/material.dart';

import 'jobs/create_job_page.dart';
import 'jobs/customer_job_detail_page.dart';
import 'jobs/job_helpers.dart';
import 'jobs/job_service.dart';
import 'jobs/job_widgets.dart';
import 'notification.dart';
import 'services/service_marketplace_page.dart';
import 'tutorial/ayos_tutorial.dart';
import 'theme/ayo_theme.dart';
import 'widgets/ayo_avatar.dart';
import 'widgets/ayo_category_visual.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.tutorialAnchors,
  });

  final AyosTutorialAnchors? tutorialAnchors;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final JobService _jobService = JobService();
  final PageController _promoController = PageController();
  Timer? _promoTimer;

  bool _isLoading = true;
  String? _errorMessage;
  String _userName = 'Pengguna';
  String _userAddress = 'Alamat belum diatur';
  String? _avatarUrl;
  List<Map<String, dynamic>> _recentJobs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  int _promoPage = 0;

  static const List<_PromoItem> _promos = <_PromoItem>[
    _PromoItem(
      eyebrow: 'BANTUAN HARIAN',
      title: 'Rumah lebih rapi,\nwaktu lebih santai.',
      categoryName: 'Rumah Tangga',
      icon: Icons.home_repair_service_rounded,
      background: Color(0xFFFFE8B8),
    ),
    _PromoItem(
      eyebrow: 'TUGAS & KREATIF',
      title: 'Butuh desain atau\nbantuan coding?',
      categoryName: 'Design & Coding',
      icon: Icons.code_rounded,
      background: Color(0xFFFFD9CF),
    ),
    _PromoItem(
      eyebrow: 'HEMAT WAKTU',
      title: 'Titip beli kebutuhan\ntanpa keluar tempat.',
      categoryName: 'Jasa Titip',
      icon: Icons.shopping_bag_rounded,
      background: Color(0xFFDCECCF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _promoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_promoController.hasClients) return;
      final int nextPage = (_promoPage + 1) % _promos.length;
      _promoController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchMyProfile(),
        _jobService.fetchCustomerJobs(),
        _jobService.fetchMyAddresses(),
        _jobService.fetchCategories(),
      ]);
      final Map<String, dynamic>? profile = result[0] as Map<String, dynamic>?;
      final List<Map<String, dynamic>> jobs =
          result[1] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> addresses =
          result[2] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> categories =
          result[3] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _userName = (profile?['fullname'] ?? 'Pengguna').toString();
        _avatarUrl = profile?['avatar_url']?.toString();
        final String profileAddress = (profile?['alamat'] ?? '')
            .toString()
            .trim();
        if (profileAddress.isNotEmpty) {
          // Home mengikuti alamat utama pada Edit Profil. Alamat job tetap terpisah.
          _userAddress = profileAddress;
        } else if (addresses.isNotEmpty) {
          _userAddress = addresses.first['address'].toString();
        } else {
          _userAddress = 'Alamat belum diatur';
        }
        _recentJobs = jobs.take(3).toList();
        _categories = categories;
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

  Future<void> _openCreateJob({String? categoryName}) async {
    final bool? created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateJobPage(initialCategoryName: categoryName),
      ),
    );
    if (created == true) await _fetchDashboardData();
  }

  Future<void> _showServiceSearch() async {
    FocusScope.of(context).unfocus();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const ServiceMarketplacePage()),
    );
    if (mounted) await _fetchDashboardData();
  }

  Future<void> _openJob(String jobId) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CustomerJobDetailPage(jobId: jobId),
      ),
    );
    if (changed == true) await _fetchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: jobOrangeColor),
            )
          : RefreshIndicator(
              color: jobOrangeColor,
              onRefresh: _fetchDashboardData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
                children: <Widget>[
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE0DD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Sebagian data belum dapat dimuat: $_errorMessage',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: KeyedSubtree(
                      key: widget.tutorialAnchors?.homeHeader,
                      child: _buildHeader(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: KeyedSubtree(
                      key: widget.tutorialAnchors?.homeSearchOrIncome,
                      child: _buildSearchBar(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: KeyedSubtree(
                      key: widget.tutorialAnchors?.homePromoOrService,
                      child: _buildPromoBanner(),
                    ),
                  ),
                  const SizedBox(height: 22),
                  KeyedSubtree(
                    key: widget.tutorialAnchors?.homeCategoriesOrActive,
                    child: _buildCategorySection(),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildRecentJobsSection(),
                  ),
                ],
              ),
            ),
      floatingActionButton: KeyedSubtree(
        key: widget.tutorialAnchors?.homePrimaryActionOrAvailable,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: FloatingActionButton.extended(
          heroTag: 'customer-home-create-job-fab',
          onPressed: () => _openCreateJob(),
          backgroundColor: jobOrangeColor,
          foregroundColor: const Color(0xFF553600),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Buat Pekerjaan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: jobBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'Ayo Suruh',
        style: TextStyle(
          color: jobDarkBrownColor,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
      actions: <Widget>[
        const NotificationBell(
          color: jobDarkBrownColor,
          activeMode: 'customer',
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Halo,',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF746A64),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 1),
              Text(
                _userName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 17,
                      height: 1.16,
                      color: const Color(0xFF302A27),
                    ),
              ),
              const SizedBox(height: 5),
              Row(
                children: <Widget>[
                  const Icon(Icons.location_on_rounded, size: 15, color: jobBrownColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _userAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6F645D),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AyoAvatar(
          imageUrl: _avatarUrl,
          size: 48,
          backgroundColor: const Color(0xFFFFEFE1),
          logoPadding: 7,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: jobBorderColor),
      ),
      child: TextField(
        readOnly: true,
        onTap: _showServiceSearch,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF746A64)),
          hintText: 'Cari layanan yang kamu butuhkan...',
          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9B918C)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Column(
      children: <Widget>[
        AspectRatio(
          // Poster Canva rekomendasi: 1200 x 500 px (rasio 12:5).
          aspectRatio: 12 / 5,
          child: PageView.builder(
            controller: _promoController,
            itemCount: _promos.length,
            onPageChanged: (int index) => setState(() => _promoPage = index),
            itemBuilder: (BuildContext context, int index) {
              final _PromoItem promo = _promos[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openCreateJob(categoryName: promo.categoryName),
                  child: Ink(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    decoration: BoxDecoration(
                      color: promo.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                promo.eyebrow,
                                style: const TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: jobBrownColor,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                promo.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.18,
                                  fontWeight: FontWeight.w800,
                                  color: jobDarkBrownColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pesan sekarang  →',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: jobBrownColor.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            promo.icon,
                            size: 38,
                            color: jobBrownColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(_promos.length, (int index) {
            final bool active = index == _promoPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? jobOrangeColor : const Color(0xFFD7C8BE),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    Widget categoryTile(Map<String, dynamic> category) {
      final String name = (category['name'] ?? 'Lainnya').toString();
      return SizedBox(
        width: 82,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openCreateJob(categoryName: name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AyoCategoryImage(
                    name: name,
                    width: 72,
                    height: 72,
                    radius: 18,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10.4,
                          height: 1.08,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4D433D),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Kategori Layanan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: _showServiceSearch,
                child: Text(
                  'Lihat semua',
                  style: AyoTypography.link(context, color: AyoColors.coral),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Kategori belum tersedia.',
              style: TextStyle(fontSize: 12, color: Color(0xFF7C6F67)),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              physics: const BouncingScrollPhysics(),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                return categoryTile(_categories[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentJobsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Status Pekerjaan Saya',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_recentJobs.isEmpty)
          const EmptyJobState(
            title: 'Belum ada pekerjaan',
            description:
                'Buat pekerjaan pertama dan mulai menerima penawaran dari mitra.',
          )
        else
          ..._recentJobs.map((Map<String, dynamic> job) {
            final int bidCount = embeddedBids(job).where((bid) {
              return bid['status'] == 'pending';
            }).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: JobListCard(
                job: job,
                subtitle: bidCount > 0
                    ? '$bidCount penawaran masuk'
                    : '${formatJobDate(job['schedule_date'])} · ${formatJobTime(job['schedule_time'])}',
                onTap: () => _openJob(job['id'].toString()),
              ),
            );
          }),
      ],
    );
  }
}

class _PromoItem {
  const _PromoItem({
    required this.eyebrow,
    required this.title,
    required this.categoryName,
    required this.icon,
    required this.background,
  });

  final String eyebrow;
  final String title;
  final String categoryName;
  final IconData icon;
  final Color background;
}
