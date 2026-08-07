import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../jobs/create_job_page.dart';
import '../jobs/job_helpers.dart';
import '../jobs/job_service.dart';
import 'mitra_service_service.dart';
import '../widgets/home_shortcut_button.dart';

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
    final Map<String, dynamic>? category = service['categories'] is Map
        ? Map<String, dynamic>.from(service['categories'] as Map)
        : null;
    final Map<String, dynamic>? mitra = service['mitra'] is Map
        ? Map<String, dynamic>.from(service['mitra'] as Map)
        : null;
    final String mitraId = (service['mitra_id'] ?? '').toString();
    if (mitraId.isEmpty) return;

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

  List<Map<String, dynamic>> get _filteredCategories {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return _categories;
    return _categories.where((Map<String, dynamic> item) {
      return (item['name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredServices {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return _services;
    return _services.where((Map<String, dynamic> item) {
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((Map<String, dynamic> category) {
                        final String name =
                            (category['name'] ?? 'Lainnya').toString();
                        return ActionChip(
                          avatar: Icon(
                            categoryIcon(name),
                            size: 17,
                            color: jobBrownColor,
                          ),
                          label: Text(name),
                          backgroundColor: categoryBackground(name),
                          side: BorderSide.none,
                          onPressed: () => _createFromCategory(name),
                        );
                      }).toList(),
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
    final num price = service['starting_price'] is num
        ? service['starting_price'] as num
        : num.tryParse(service['starting_price']?.toString() ?? '') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: jobBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFFE6C0),
                backgroundImage:
                    avatar == null || avatar.isEmpty ? null : NetworkImage(avatar),
                child: avatar == null || avatar.isEmpty
                    ? const Icon(Icons.person_rounded, color: jobBrownColor)
                    : null,
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
                    Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF786A62),
                      ),
                    ),
                  ],
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
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _orderService(service),
              style: FilledButton.styleFrom(
                backgroundColor: jobOrangeColor,
                foregroundColor: const Color(0xFF553600),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text(
                'Pesan Jasa',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
