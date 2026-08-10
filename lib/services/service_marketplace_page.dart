import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../jobs/create_job_page.dart';
import '../jobs/job_helpers.dart';
import '../jobs/job_service.dart';
import 'mitra_service_service.dart';
import 'service_detail_page.dart';
import '../widgets/home_shortcut_button.dart';
import '../widgets/network_photo_gallery.dart';
import '../widgets/ayo_avatar.dart';
import '../widgets/ayo_category_visual.dart';
import '../widgets/ayo_snackbar.dart';

class ServiceMarketplacePage extends StatefulWidget {
  const ServiceMarketplacePage({super.key});

  @override
  State<ServiceMarketplacePage> createState() => _ServiceMarketplacePageState();
}

class _ServiceMarketplacePageState extends State<ServiceMarketplacePage> {
  final TextEditingController _searchController = TextEditingController();
  final JobService _jobService = JobService();
  final MitraServiceService _service = MitraServiceService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  bool _loading = true;
  String? _error;
  String _query = '';
  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _services = <Map<String, dynamic>>[];
  bool _showBookmarkedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchCategories(),
        _service.fetchPublicServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = result[0] as List<Map<String, dynamic>>;
        _services = result[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createFromCategory(String categoryName) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateJobPage(initialCategoryName: categoryName),
      ),
    );
  }

  Future<void> _orderService(Map<String, dynamic> service) async {
    final String currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    final String mitraId = (service['mitra_id'] ?? '').toString();
    if (mitraId.isEmpty) return;
    if (currentUserId.isNotEmpty && currentUserId == mitraId) {
      AyoSnackBar.info(
        context,
        'Jasa ini milik akunmu. Kelola dari halaman Jasa Saya.',
      );
      return;
    }

    final Map<String, dynamic>? category = service['categories'] is Map
        ? Map<String, dynamic>.from(service['categories'] as Map)
        : null;
    final Map<String, dynamic>? mitra = service['mitra'] is Map
        ? Map<String, dynamic>.from(service['mitra'] as Map)
        : null;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateJobPage(
          initialCategoryName: (category?['name'] ?? '').toString(),
          initialTitle: (service['title'] ?? '').toString(),
          initialDescription:
              'Permintaan berdasarkan jasa mitra: ${(service['description'] ?? '').toString()}',
          initialBudget: service['starting_price'] is num
              ? service['starting_price'] as num
              : num.tryParse(service['starting_price']?.toString() ?? ''),
          preferredMitraId: mitraId,
          preferredMitraName: (mitra?['fullname'] ?? 'Mitra Ayo Suruh').toString(),
        ),
      ),
    );
  }

  Future<void> _openServiceDetail(Map<String, dynamic> service) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServiceDetailPage(service: service),
      ),
    );
    await _load();
  }

  Future<void> _toggleBookmark(Map<String, dynamic> service) async {
    final String serviceId = (service['id'] ?? '').toString();
    if (serviceId.isEmpty) return;
    final bool current = service['is_bookmarked'] == true;
    try {
      final bool next = await _service.toggleBookmark(
        serviceId: serviceId,
        currentlyBookmarked: current,
      );
      if (!mounted) return;
      setState(() => service['is_bookmarked'] = next);
      AyoSnackBar.success(
        context,
        next ? 'Jasa disimpan ke bookmark.' : 'Jasa dihapus dari bookmark.',
      );
    } catch (error) {
      if (mounted) {
        AyoSnackBar.error(context, 'Bookmark belum dapat diperbarui: $error');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCategories {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return _categories;
    return _categories.where((Map<String, dynamic> item) {
      return (item['name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredServices {
    final String q = _query.trim().toLowerCase();
    return _services.where((Map<String, dynamic> item) {
      if (_showBookmarkedOnly && item['is_bookmarked'] != true) return false;
      if (q.isEmpty) return true;
      final Map<dynamic, dynamic>? category = item['categories'] is Map
          ? item['categories'] as Map<dynamic, dynamic>
          : null;
      final Map<dynamic, dynamic>? mitra =
          item['mitra'] is Map ? item['mitra'] as Map<dynamic, dynamic> : null;
      final String haystack = <String>[
        (item['title'] ?? '').toString(),
        (item['description'] ?? '').toString(),
        (category?['name'] ?? '').toString(),
        (mitra?['fullname'] ?? '').toString(),
        (mitra?['location'] ?? '').toString(),
        if (item['tags'] is List)
          ...(item['tags'] as List).map((dynamic tag) => tag.toString()),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = _filteredCategories;
    final List<Map<String, dynamic>> services = _filteredServices;

    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: AppBar(
        backgroundColor: jobBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: const Text(
          'Cari Layanan',
          style: TextStyle(color: jobBrownColor, fontWeight: FontWeight.w900),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: jobOrangeColor))
          : RefreshIndicator(
              color: jobOrangeColor,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                children: <Widget>[
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (String value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Cari elektronik, coding, jastip, nama mitra...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: jobBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: jobOrangeColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4DF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Sebagian katalog belum dapat dimuat: $_error',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Katalog Ayo Suruh',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: jobBrownColor,
                          ),
                        ),
                      ),
                      Text(
                        '${categories.length} kategori',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF786A62),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (categories.isEmpty)
                    const Text(
                      'Kategori tidak ditemukan.',
                      style: TextStyle(color: Color(0xFF746760)),
                    )
                  else
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final double itemWidth = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: categories.map((Map<String, dynamic> category) {
                            final String name =
                                (category['name'] ?? 'Lainnya').toString();
                            return SizedBox(
                              width: itemWidth,
                              child: AyoGradientBorder(
                                gradient: ayoCategoryGradient(name),
                                radius: 18,
                                width: 1.4,
                                child: Material(
                                  color: Colors.white,
                                  child: InkWell(
                                    onTap: () => _createFromCategory(name),
                                    child: Padding(
                                      padding: const EdgeInsets.all(7),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          AyoCategoryImage(
                                            name: name,
                                            width: itemWidth - 16,
                                            height: 88,
                                            radius: 13,
                                            gradientBorder: false,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(4, 9, 4, 4),
                                            child: Text(
                                              name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                height: 1.15,
                                                fontWeight: FontWeight.w800,
                                                color: jobBrownColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  const SizedBox(height: 26),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Jasa yang Ditawarkan Mitra',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: jobBrownColor,
                          ),
                        ),
                      ),
                      Text(
                        '${services.length} jasa',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF786A62),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pilih jasa untuk membuat permintaan yang ditujukan ke mitra tersebut. Harga akhir tetap mengikuti penawaran di dalam job.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF766A63),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      selected: _showBookmarkedOnly,
                      avatar: Icon(
                        _showBookmarkedOnly
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 17,
                      ),
                      label: const Text('Jasa tersimpan'),
                      onSelected: (bool selected) {
                        setState(() => _showBookmarkedOnly = selected);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (services.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: jobBorderColor),
                      ),
                      child: const Column(
                        children: <Widget>[
                          Icon(
                            Icons.storefront_outlined,
                            size: 42,
                            color: Color(0xFFC6B6AB),
                          ),
                          SizedBox(height: 9),
                          Text(
                            'Belum ada jasa mitra yang cocok. Kamu tetap dapat membuat pekerjaan melalui kategori di atas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: Color(0xFF746760),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...services.map(_serviceCard),
                ],
              ),
            ),
    );
  }

  Widget _serviceCard(Map<String, dynamic> service) {
    final Map<String, dynamic>? category = service['categories'] is Map
        ? Map<String, dynamic>.from(service['categories'] as Map)
        : null;
    final Map<String, dynamic>? mitra = service['mitra'] is Map
        ? Map<String, dynamic>.from(service['mitra'] as Map)
        : null;
    final String categoryName = (category?['name'] ?? 'Lainnya').toString();
    final String mitraName = (mitra?['fullname'] ?? 'Mitra Ayo Suruh').toString();
    final String? avatar = mitra?['avatar_url']?.toString();
    final num rating = mitra?['rating'] is num
        ? mitra!['rating'] as num
        : num.tryParse(mitra?['rating']?.toString() ?? '') ?? 0;
    final String location = (mitra?['location'] ?? '').toString().trim();
    final num price = service['starting_price'] is num
        ? service['starting_price'] as num
        : num.tryParse(service['starting_price']?.toString() ?? '') ?? 0;
    final String currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    final bool isOwnService = currentUserId.isNotEmpty &&
        currentUserId == service['mitra_id']?.toString();
    final dynamic rawTags = service['tags'];
    final List<String> tags = rawTags is List
        ? rawTags
            .map((dynamic tag) => tag.toString())
            .where((String tag) => tag.trim().isNotEmpty)
            .toList()
        : <String>[];
    final dynamic rawImages = service['service_images'];
    final List<String> imageUrls = rawImages is List
        ? rawImages
            .whereType<Map>()
            .map((Map image) => (image['image_url'] ?? '').toString().trim())
            .where((String url) => url.isNotEmpty)
            .toList()
        : <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openServiceDetail(service),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: jobBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
          if (imageUrls.isNotEmpty) ...<Widget>[
            NetworkPhotoGallery(
              urls: imageUrls,
              aspectRatio: 16 / 9,
              borderRadius: 15,
            ),
            const SizedBox(height: 13),
          ],
          Row(
            children: <Widget>[
              AyoAvatar(
                imageUrl: avatar,
                size: 42,
                backgroundColor: const Color(0xFFFFEFE1),
                logoPadding: 6,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      mitraName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 7,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _serviceMeta(
                          icon: Icons.star_rounded,
                          text: rating > 0
                              ? rating.toStringAsFixed(1)
                              : 'Baru',
                          iconColor: const Color(0xFFF6990E),
                        ),
                        if (location.isNotEmpty)
                          _serviceMeta(
                            icon: Icons.location_on_outlined,
                            text: location,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _toggleBookmark(service),
                tooltip: service['is_bookmarked'] == true
                    ? 'Hapus bookmark'
                    : 'Simpan jasa',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  service['is_bookmarked'] == true
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: jobBrownColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: categoryBackground(categoryName),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Mulai ${_currency.format(price)}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: jobBrownColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            categoryName,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF8B7A70),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (service['title'] ?? 'Jasa Mitra').toString(),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF312A26),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            (service['description'] ?? '').toString(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Color(0xFF685D56),
            ),
          ),
          if (tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(4).map((String tag) {
                return Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('#$tag', style: const TextStyle(fontSize: 9)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isOwnService ? null : () => _orderService(service),
              style: FilledButton.styleFrom(
                backgroundColor: jobOrangeColor,
                foregroundColor: const Color(0xFF553600),
                disabledBackgroundColor: const Color(0xFFE8E0D9),
                disabledForegroundColor: const Color(0xFF8B7E76),
              ),
              icon: Icon(
                isOwnService ? Icons.person_outline_rounded : Icons.arrow_forward_rounded,
                size: 17,
              ),
              label: Text(
                isOwnService ? 'Jasa Anda' : 'Pesan Jasa',
                style: const TextStyle(fontWeight: FontWeight.w900),
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

  Widget _serviceMeta({
    required IconData icon,
    required String text,
    Color iconColor = const Color(0xFF8B7A70),
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.8,
                color: Color(0xFF746760),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
