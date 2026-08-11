import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'jobs/create_job_page.dart';
import 'jobs/customer_job_detail_page.dart';
import 'jobs/job_helpers.dart';
import 'jobs/job_service.dart';
import 'jobs/job_widgets.dart';
import 'home/home_trivia_service.dart';
import 'mitra/mitra_application_page.dart';
import 'mitra/mitra_application_service.dart';
import 'notification.dart';
import 'services/mitra_service_service.dart';
import 'services/service_detail_page.dart';
import 'services/service_marketplace_page.dart';
import 'tutorial/ayos_tutorial.dart';
import 'theme/ayo_theme.dart';
import 'widgets/ayo_avatar.dart';
import 'widgets/ayo_category_visual.dart';
import 'widgets/ayo_snackbar.dart';
import 'widgets/home_trivia_ticker.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.tutorialAnchors,
    this.onOpenChat,
  });

  final AyosTutorialAnchors? tutorialAnchors;
  final VoidCallback? onOpenChat;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final JobService _jobService = JobService();
  final MitraApplicationService _mitraApplicationService =
      MitraApplicationService();
  final MitraServiceService _mitraServiceService = MitraServiceService();
  final HomeTriviaService _homeTriviaService = HomeTriviaService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  static const int _promoLoopSeed = 1000;
  late final PageController _promoController;
  Timer? _promoTimer;

  bool _isLoading = true;
  String? _errorMessage;
  String _userName = 'Pengguna';
  String _userAddress = 'Alamat belum diatur';
  String? _avatarUrl;
  List<Map<String, dynamic>> _recentJobs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _featuredServices = <Map<String, dynamic>>[];
  bool _isLoadingFeaturedServices = true;
  List<String> _triviaItems = <String>[];

  static const List<_PromoItem> _promos = <_PromoItem>[
    _PromoItem(
      assetPathId: 'assets/images/home_slider_1_id.png',
      assetPathEn: 'assets/images/home_slider_1_en.png',
      semanticLabel: 'Beresin Kost Sat-Set. Tanpa Ribet!',
      action: _PromoAction.serviceCatalog,
    ),
    _PromoItem(
      assetPathId: 'assets/images/home_slider_2_id.png',
      assetPathEn: 'assets/images/home_slider_2_en.png',
      semanticLabel: 'Fitur Chat, Telpon dan Notifikasi Bisa Bantu Kamu',
      action: _PromoAction.chat,
    ),
    _PromoItem(
      assetPathId: 'assets/images/home_slider_3_id.png',
      assetPathEn: 'assets/images/home_slider_3_en.png',
      semanticLabel: 'Bisa Posting Jasa. Temuin atau Bikin yang Kamu Mau!',
      action: _PromoAction.createJob,
    ),
    _PromoItem(
      assetPathId: 'assets/images/home_slider_4_id.png',
      assetPathEn: 'assets/images/home_slider_4_en.png',
      semanticLabel: 'Ayo Suruh tersedia di Play Store',
      action: _PromoAction.playStore,
    ),
    _PromoItem(
      assetPathId: 'assets/images/home_slider_5_id.png',
      assetPathEn: 'assets/images/home_slider_5_en.png',
      semanticLabel: 'Mau Tambah Uang Saku',
      action: _PromoAction.registerMitra,
    ),
  ];

  static final Uri _playStoreUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.ayosuruh.app',
  );


  @override
  void initState() {
    super.initState();
    _triviaItems = _homeTriviaService.fallbackItems;
    _promoController =
        PageController(initialPage: _promos.length * _promoLoopSeed);
    _fetchDashboardData();
    _schedulePromoAdvance();
  }

  void _schedulePromoAdvance() {
    _promoTimer?.cancel();
    _promoTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !_promoController.hasClients) {
        _schedulePromoAdvance();
        return;
      }

      final int currentRawPage =
          (_promoController.page ?? (_promos.length * _promoLoopSeed))
              .round();
      _promoController.animateToPage(
        currentRawPage + 1,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _pausePromoAdvance() {
    _promoTimer?.cancel();
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
      unawaited(_loadHomeServices());
      unawaited(_loadHomeTrivia());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHomeServices() async {
    try {
      final List<Map<String, dynamic>> services =
          await _mitraServiceService.fetchFeaturedServices(limit: 6);
      if (!mounted) return;
      setState(() {
        _featuredServices = services;
        _isLoadingFeaturedServices = false;
      });
    } catch (error) {
      debugPrint('Gagal memuat jasa pilihan Home: $error');
      if (mounted) setState(() => _isLoadingFeaturedServices = false);
    }
  }

  Future<void> _loadHomeTrivia() async {
    try {
      final List<String> items = await _homeTriviaService.fetchActiveTrivia();
      if (!mounted || items.isEmpty) return;
      setState(() => _triviaItems = items);
    } catch (error) {
      debugPrint('Gagal memuat trivia Home: $error');
    }
  }

  Future<void> _openServiceDetail(Map<String, dynamic> service) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServiceDetailPage(service: service),
      ),
    );
    if (mounted) unawaited(_loadHomeServices());
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


  Future<void> _openMitraRegistration() async {
    try {
      final Map<String, dynamic>? application =
          await _mitraApplicationService.fetchMyApplication();
      if (!mounted) return;

      final String status =
          (application?['status'] ?? '').toString().trim().toLowerCase();
      final Widget page = application == null || status == 'rejected'
          ? MitraApplicationPage(existingApplication: application)
          : MitraApplicationStatusPage(initialApplication: application);

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      );
      if (mounted) await _fetchDashboardData();
    } catch (error) {
      debugPrint('Gagal membuka pendaftaran Mitra dari slider: $error');
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Halaman pendaftaran Mitra belum dapat dibuka. Coba lagi.',
      );
    }
  }

  Future<void> _openPlayStore() async {
    final bool launched = await launchUrl(
      _playStoreUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      AyoSnackBar.info(
        context,
        'Ayo Suruh akan tersedia di Play Store setelah publikasi selesai.',
      );
    }
  }

  Future<void> _handlePromoTap(_PromoItem promo) async {
    _pausePromoAdvance();
    try {
      switch (promo.action) {
        case _PromoAction.serviceCatalog:
          await _showServiceSearch();
          break;
        case _PromoAction.createJob:
          await _openCreateJob();
          break;
        case _PromoAction.registerMitra:
          await _openMitraRegistration();
          break;
        case _PromoAction.chat:
          widget.onOpenChat?.call();
          break;
        case _PromoAction.playStore:
          await _openPlayStore();
          break;
      }
    } finally {
      if (mounted) _schedulePromoAdvance();
    }
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
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
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
                        child: AyoText(
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
                      key: widget.tutorialAnchors?.homePromoOrService,
                      child: _buildPromoBanner(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: KeyedSubtree(
                      key: widget.tutorialAnchors?.homeTrivia,
                      child: HomeTriviaTicker(items: _triviaItems),
                    ),
                  ),
                  const SizedBox(height: 22),
                  KeyedSubtree(
                    key: widget.tutorialAnchors?.homeCategoriesOrActive,
                    child: _buildCategorySection(),
                  ),
                  const SizedBox(height: 22),
                  KeyedSubtree(
                    key: widget.tutorialAnchors?.homePrimaryActionOrAvailable,
                    child: _buildFeaturedServicesSection(),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildRecentJobsSection(),
                  ),
                ],
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
      toolbarHeight: 68,
      titleSpacing: 18,
      title: Row(
        children: <Widget>[
          SizedBox(
            width: 38,
            height: 38,
            child: Image.asset(
              'assets/images/ayos_runner_logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: KeyedSubtree(
              key: widget.tutorialAnchors?.homeSearchOrIncome,
              child: _buildSearchBar(),
            ),
          ),
          const SizedBox(width: 8),
          NotificationBell(
            color: jobDarkBrownColor,
            activeMode: 'customer',
          ),
        ],
      ),
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
              AyoText(
                'Halo,',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 1),
              AyoText(
                _userName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 17,
                      height: 1.16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 5),
              Row(
                children: <Widget>[
                  Icon(Icons.location_on_rounded, size: 15, color: jobBrownColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: AyoText(
                      _userAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: jobBorderColor),
      ),
      child: TextField(
        readOnly: true,
        onTap: _showServiceSearch,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF746A64)),
          hintText: AyoI18n.t('Cari layanan...'),
          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9B918C)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return AspectRatio(
      // Seluruh artwork slider dibuat pada ukuran 1200 x 500 px (rasio 12:5).
      aspectRatio: 12 / 5,
      child: Listener(
        onPointerDown: (_) => _pausePromoAdvance(),
        onPointerUp: (_) => _schedulePromoAdvance(),
        onPointerCancel: (_) => _schedulePromoAdvance(),
        child: PageView.builder(
          controller: _promoController,
          onPageChanged: (_) => _schedulePromoAdvance(),
          itemBuilder: (BuildContext context, int index) {
            final _PromoItem promo = _promos[index % _promos.length];

            return AnimatedBuilder(
              animation: _promoController,
              child: Semantics(
                button: true,
                label: AyoI18n.t(promo.semanticLabel),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handlePromoTap(promo),
                      splashColor: Colors.white.withValues(alpha: 0.10),
                      highlightColor: Colors.black.withValues(alpha: 0.035),
                      child: Image.asset(
                        promo.localizedAssetPath,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),
              builder: (BuildContext context, Widget? child) {
                double visiblePage =
                    (_promos.length * _promoLoopSeed).toDouble();
                if (_promoController.hasClients &&
                    _promoController.position.hasContentDimensions) {
                  visiblePage = _promoController.page ??
                      (_promos.length * _promoLoopSeed).toDouble();
                }

                final double distance =
                    (visiblePage - index).abs().clamp(0.0, 1.0).toDouble();
                final double opacity = 1.0 - (distance * 0.58);

                return Opacity(
                  opacity: opacity,
                  child: child,
                );
              },
            );
          },
        ),
      ),
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
                  AyoText(
                    name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10.4,
                          height: 1.08,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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
                child: AyoText(
                  'Kategori Layanan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: _showServiceSearch,
                child: AyoText(
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
            child: AyoText(
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

  Widget _buildFeaturedServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AyoText(
                      'Jasa Pilihan Mitra',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    AyoText(
                      'Lihat jasa yang baru ditawarkan Mitra Ayo Suruh.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF786D66),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _showServiceSearch,
                child: AyoText(
                  'Lihat semua',
                  style: AyoTypography.link(context, color: AyoColors.coral),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_isLoadingFeaturedServices)
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: 2,
              separatorBuilder: (_, _) => const SizedBox(width: 11),
              itemBuilder: (_, _) => Container(
                width: 248,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : const Color(0xFFF4EFEA),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          )
        else if (_featuredServices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: jobBorderColor),
              ),
              child: const AyoText(
                'Belum ada jasa Mitra yang dipublikasikan. Cek lagi nanti atau buka katalog untuk melihat layanan lainnya.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Color(0xFF786D66),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 222,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: _featuredServices.length,
              separatorBuilder: (_, _) => const SizedBox(width: 11),
              itemBuilder: (BuildContext context, int index) {
                return _buildFeaturedServiceCard(_featuredServices[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFeaturedServiceCard(Map<String, dynamic> service) {
    final Map<String, dynamic> mitra = service['mitra'] is Map
        ? Map<String, dynamic>.from(service['mitra'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> category = service['categories'] is Map
        ? Map<String, dynamic>.from(service['categories'] as Map)
        : <String, dynamic>{};
    final dynamic rawImages = service['service_images'];
    final List<String> images = rawImages is List
        ? rawImages
            .whereType<Map>()
            .map((Map image) => (image['image_url'] ?? '').toString().trim())
            .where((String url) => url.isNotEmpty)
            .toList()
        : <String>[];
    final String title = (service['title'] ?? 'Jasa Mitra').toString();
    final String mitraName = (mitra['fullname'] ?? 'Mitra Ayo Suruh').toString();
    final String categoryName = (category['name'] ?? 'Lainnya').toString();
    final num rating = mitra['rating'] is num
        ? mitra['rating'] as num
        : num.tryParse(mitra['rating']?.toString() ?? '') ?? 0;
    final num price = service['starting_price'] is num
        ? service['starting_price'] as num
        : num.tryParse(service['starting_price']?.toString() ?? '') ?? 0;

    return SizedBox(
      width: 248,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openServiceDetail(service),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: jobBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: images.isEmpty
                      ? Container(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : const Color(0xFFFFF0E4),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AyoColors.orange,
                            size: 36,
                          ),
                        )
                      : Image.network(
                          images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : const Color(0xFFFFF0E4),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: AyoColors.orange,
                              size: 36,
                            ),
                          ),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AyoText(
                          categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AyoColors.coral,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AyoText(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: jobDarkBrownColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: AyoText(
                                mitraName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF786D66),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF6A900),
                            ),
                            const SizedBox(width: 2),
                            AyoText(
                              rating > 0 ? rating.toStringAsFixed(1) : 'Baru',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        AyoText(
                          'Mulai ${_currency.format(price)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AyoColors.orange,
                          ),
                        ),
                      ],
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

  Widget _buildRecentJobsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AyoText(
          'Status Pekerjaan Saya',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_recentJobs.isEmpty)
          const EmptyJobState(
            title: 'Belum ada pekerjaan',
            description:
                'Buka tab Pekerjaan untuk membuat kebutuhan pertama dan mulai menerima penawaran Mitra.',
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

enum _PromoAction {
  serviceCatalog,
  createJob,
  registerMitra,
  chat,
  playStore,
}

class _PromoItem {
  const _PromoItem({
    required this.assetPathId,
    required this.assetPathEn,
    required this.semanticLabel,
    required this.action,
  });

  final String assetPathId;
  final String assetPathEn;
  final String semanticLabel;
  final _PromoAction action;

  String get localizedAssetPath =>
      AyoI18n.isEnglish ? assetPathEn : assetPathId;
}
