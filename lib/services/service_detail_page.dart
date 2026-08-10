import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../jobs/create_job_page.dart';
import '../jobs/job_helpers.dart';
import '../widgets/ayo_avatar.dart';
import '../widgets/ayo_snackbar.dart';
import '../widgets/network_photo_gallery.dart';
import 'mitra_public_profile_page.dart';
import 'mitra_service_service.dart';

class ServiceDetailPage extends StatefulWidget {
  const ServiceDetailPage({
    super.key,
    required this.service,
  });

  final Map<String, dynamic> service;

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  final MitraServiceService _service = MitraServiceService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  late Map<String, dynamic> _item;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _otherServices = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _bookmarking = false;

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.service);
    _loadDepth();
  }

  Future<void> _loadDepth() async {
    final String mitraId = (_item['mitra_id'] ?? '').toString();
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.fetchPublicMitraProfile(mitraId),
        _service.fetchPublicServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = result[0] as Map<String, dynamic>?;
        _otherServices = (result[1] as List<Map<String, dynamic>>)
            .where((row) =>
                row['mitra_id']?.toString() == mitraId &&
                row['id']?.toString() != _item['id']?.toString())
            .take(4)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _mitra => _item['mitra'] is Map
      ? Map<String, dynamic>.from(_item['mitra'] as Map)
      : <String, dynamic>{};

  Map<String, dynamic> get _category => _item['categories'] is Map
      ? Map<String, dynamic>.from(_item['categories'] as Map)
      : <String, dynamic>{};

  List<String> get _tags {
    final dynamic raw = _item['tags'];
    if (raw is! List) return <String>[];
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }

  List<String> _imageUrls(Map<String, dynamic> service) {
    final dynamic raw = service['service_images'];
    if (raw is! List) return <String>[];
    return raw
        .whereType<Map>()
        .map((image) => (image['image_url'] ?? '').toString().trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }

  num get _price => _item['starting_price'] is num
      ? _item['starting_price'] as num
      : num.tryParse(_item['starting_price']?.toString() ?? '') ?? 0;

  Future<void> _toggleBookmark() async {
    if (_bookmarking) return;
    final String id = (_item['id'] ?? '').toString();
    if (id.isEmpty) return;
    final bool current = _item['is_bookmarked'] == true;
    setState(() => _bookmarking = true);
    try {
      final bool next = await _service.toggleBookmark(
        serviceId: id,
        currentlyBookmarked: current,
      );
      if (!mounted) return;
      setState(() => _item['is_bookmarked'] = next);
      AyoSnackBar.success(
        context,
        next ? 'Jasa disimpan ke bookmark.' : 'Jasa dihapus dari bookmark.',
      );
    } catch (error) {
      if (mounted) AyoSnackBar.error(context, 'Bookmark belum dapat diperbarui: $error');
    } finally {
      if (mounted) setState(() => _bookmarking = false);
    }
  }

  Future<void> _share() async {
    final String id = (_item['id'] ?? '').toString();
    final String title = (_item['title'] ?? 'Jasa Ayo Suruh').toString();
    final String mitra = (_mitra['fullname'] ?? 'Mitra Ayo Suruh').toString();
    final String url =
        'https://madouseixalisphera.github.io/AyoSuruh-Web/?service=$id';
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        title: title,
        subject: 'Jasa dari Ayo Suruh',
        text: '$title oleh $mitra\nMulai ${_currency.format(_price)}\n$url',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _orderService([Map<String, dynamic>? selected]) async {
    final Map<String, dynamic> service = selected ?? _item;
    final String mitraId = (service['mitra_id'] ?? '').toString();
    final String currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    if (mitraId.isEmpty || mitraId == currentUserId) {
      AyoSnackBar.info(context, 'Jasa ini milik akunmu sendiri.');
      return;
    }
    final Map<String, dynamic> category = service['categories'] is Map
        ? Map<String, dynamic>.from(service['categories'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> mitra = service['mitra'] is Map
        ? Map<String, dynamic>.from(service['mitra'] as Map)
        : _mitra;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateJobPage(
          initialCategoryName: (category['name'] ?? '').toString(),
          initialTitle: (service['title'] ?? '').toString(),
          initialDescription:
              'Permintaan berdasarkan jasa mitra: ${(service['description'] ?? '').toString()}',
          initialBudget: service['starting_price'] is num
              ? service['starting_price'] as num
              : num.tryParse(service['starting_price']?.toString() ?? ''),
          preferredMitraId: mitraId,
          preferredMitraName:
              (mitra['fullname'] ?? 'Mitra Ayo Suruh').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = (_item['title'] ?? 'Jasa Mitra').toString();
    final String category = (_category['name'] ?? 'Lainnya').toString();
    final String mitraName = (_mitra['fullname'] ?? 'Mitra Ayo Suruh').toString();
    final String? avatar = _mitra['avatar_url']?.toString();
    final num rating = _mitra['rating'] is num
        ? _mitra['rating'] as num
        : num.tryParse(_mitra['rating']?.toString() ?? '') ?? 0;
    final String location = (_mitra['location'] ?? _profile?['location'] ?? '')
        .toString()
        .trim();
    final bool isOwn = Supabase.instance.client.auth.currentUser?.id ==
        _item['mitra_id']?.toString();

    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: AppBar(
        backgroundColor: jobBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Detail Jasa'),
        actions: <Widget>[
          IconButton(
            onPressed: _share,
            tooltip: 'Bagikan jasa',
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            onPressed: _bookmarking ? null : _toggleBookmark,
            tooltip: _item['is_bookmarked'] == true
                ? 'Hapus bookmark'
                : 'Simpan jasa',
            icon: Icon(
              _item['is_bookmarked'] == true
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: <Widget>[
          if (_imageUrls(_item).isNotEmpty)
            NetworkPhotoGallery(
              urls: _imageUrls(_item),
              aspectRatio: 16 / 10,
              borderRadius: 20,
            ),
          const SizedBox(height: 18),
          Text(
            category,
            style: const TextStyle(
              color: jobBrownColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 23,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E2825),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Mulai ${_currency.format(_price)}',
            style: const TextStyle(
              fontSize: 18,
              color: jobOrangeColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (_tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _tags
                  .map(
                    (tag) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('#$tag'),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: jobBorderColor),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MitraPublicProfilePage(
                    mitraId: (_item['mitra_id'] ?? '').toString(),
                    initialMitra: _mitra,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  AyoAvatar(
                    imageUrl: avatar,
                    size: 54,
                    backgroundColor: const Color(0xFFFFEFE1),
                    logoPadding: 7,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          mitraName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.verified_rounded,
                                size: 14, color: Color(0xFF4B613E)),
                            const SizedBox(width: 4),
                            const Text(
                              'Mitra terverifikasi',
                              style: TextStyle(fontSize: 10.5),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.star_rounded,
                                size: 14, color: jobOrangeColor),
                            Text(
                              rating > 0 ? rating.toStringAsFixed(1) : 'Baru',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (location.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF776B64),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Tentang jasa',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            (_item['description'] ?? '').toString(),
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Color(0xFF5F5550),
            ),
          ),
          if (_loading) ...<Widget>[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ] else if (_otherServices.isNotEmpty) ...<Widget>[
            const SizedBox(height: 28),
            const Text(
              'Jasa lain dari Mitra ini',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ..._otherServices.map((service) => _otherServiceCard(service)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: FilledButton.icon(
            onPressed: isOwn ? null : _orderService,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: jobOrangeColor,
              foregroundColor: const Color(0xFF553600),
            ),
            icon: Icon(isOwn ? Icons.person_rounded : Icons.arrow_forward_rounded),
            label: Text(
              isOwn ? 'Jasa Anda' : 'Pesan Jasa',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }

  Widget _otherServiceCard(Map<String, dynamic> service) {
    final String title = (service['title'] ?? 'Jasa Mitra').toString();
    final num price = service['starting_price'] is num
        ? service['starting_price'] as num
        : num.tryParse(service['starting_price']?.toString() ?? '') ?? 0;
    final List<String> images = _imageUrls(service);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ServiceDetailPage(service: service),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: jobBorderColor),
            ),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 68,
                    height: 58,
                    child: images.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFFFF1DF),
                            child: Icon(Icons.storefront_outlined),
                          )
                        : Image.network(images.first, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mulai ${_currency.format(price)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: jobBrownColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
