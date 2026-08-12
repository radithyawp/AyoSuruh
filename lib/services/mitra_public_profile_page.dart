import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../jobs/create_job_page.dart';
import '../jobs/job_helpers.dart';
import '../widgets/ayo_avatar.dart';
import 'mitra_service_service.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class MitraPublicProfilePage extends StatefulWidget {
  const MitraPublicProfilePage({
    super.key,
    required this.mitraId,
    this.initialMitra,
  });

  final String mitraId;
  final Map<String, dynamic>? initialMitra;

  @override
  State<MitraPublicProfilePage> createState() => _MitraPublicProfilePageState();
}

class _MitraPublicProfilePageState extends State<MitraPublicProfilePage> {
  final MitraServiceService _service = MitraServiceService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _reviews = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _services = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.fetchPublicMitraProfile(widget.mitraId),
        _service.fetchPublicMitraReviews(widget.mitraId, limit: 6),
        _service.fetchPublicServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = result[0] as Map<String, dynamic>?;
        _reviews = result[1] as List<Map<String, dynamic>>;
        _services = (result[2] as List<Map<String, dynamic>>)
            .where((row) => row['mitra_id']?.toString() == widget.mitraId)
            .toList();
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

  String get _name => (_profile?['fullname'] ??
          widget.initialMitra?['fullname'] ??
          'Mitra Ayo Suruh')
      .toString();

  String? get _avatar =>
      (_profile?['avatar_url'] ?? widget.initialMitra?['avatar_url'])?.toString();

  num get _rating {
    final dynamic raw = _profile?['rating'] ?? widget.initialMitra?['rating'];
    return raw is num ? raw : num.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String get _location => (_profile?['location'] ??
          widget.initialMitra?['location'] ??
          '')
      .toString();

  List<String> get _categories {
    final dynamic raw = _profile?['categories'];
    return raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
  }

  Future<void> _order(Map<String, dynamic> service) async {
    if (Supabase.instance.client.auth.currentUser?.id == widget.mitraId) return;
    final Map<String, dynamic> category = service['categories'] is Map
        ? Map<String, dynamic>.from(service['categories'] as Map)
        : <String, dynamic>{};
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
          preferredMitraId: widget.mitraId,
          preferredMitraName: _name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: AppBar(
        backgroundColor: jobBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const AyoText('Profil Mitra'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: jobOrangeColor))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: AyoText(
                      'Profil Mitra belum dapat dimuat.\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: jobOrangeColor,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
                    children: <Widget>[
                      _profileHeader(),
                      if (_categories.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: _categories
                              .map((name) => Chip(label: AyoText(name)))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _sectionTitle('Jasa aktif', '${_services.length} jasa'),
                      const SizedBox(height: 10),
                      if (_services.isEmpty)
                        _emptyCard('Mitra ini belum memiliki jasa aktif.')
                      else
                        ..._services.map(_serviceCard),
                      const SizedBox(height: 26),
                      _sectionTitle('Ulasan terbaru', '${_reviews.length} ditampilkan'),
                      const SizedBox(height: 10),
                      if (_reviews.isEmpty)
                        _emptyCard('Belum ada ulasan yang dapat ditampilkan.')
                      else
                        ..._reviews.map(_reviewCard),
                    ],
                  ),
                ),
    );
  }

  Widget _profileHeader() {
    final int completed = int.tryParse((_profile?['completed_jobs'] ?? '0').toString()) ?? 0;
    final int reviews = int.tryParse((_profile?['review_count'] ?? '0').toString()) ?? 0;
    final int services = int.tryParse((_profile?['active_services'] ?? '0').toString()) ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: jobBorderColor),
      ),
      child: Column(
        children: <Widget>[
          AyoAvatar(
            imageUrl: _avatar,
            size: 82,
            backgroundColor: const Color(0xFFFFEFE1),
            logoPadding: 12,
          ),
          const SizedBox(height: 12),
          AyoText(
            _name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.verified_rounded, size: 15, color: Color(0xFF4B613E)),
              SizedBox(width: 5),
              AyoText(
                'Mitra terverifikasi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (_location.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            AyoText(
              _location,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF786C65)),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              _stat(_rating > 0 ? _rating.toStringAsFixed(1) : 'Baru', 'Rating'),
              _stat('$completed', 'Selesai'),
              _stat('$reviews', 'Ulasan'),
              _stat('$services', 'Jasa'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: <Widget>[
          AyoText(
            value,
            style: TextStyle(
              color: jobBrownColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          AyoText(
            label,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF8B7F78)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String meta) {
    return Row(
      children: <Widget>[
        Expanded(
          child: AyoText(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        AyoText(meta, style: const TextStyle(fontSize: 10.5, color: Color(0xFF8B7F78))),
      ],
    );
  }

  Widget _serviceCard(Map<String, dynamic> service) {
    final num price = service['starting_price'] is num
        ? service['starting_price'] as num
        : num.tryParse(service['starting_price']?.toString() ?? '') ?? 0;
    final dynamic rawImages = service['service_images'];
    final String? cover = rawImages is List && rawImages.isNotEmpty && rawImages.first is Map
        ? ((rawImages.first as Map)['image_url'] ?? '').toString()
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: jobBorderColor),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 68,
              child: cover == null || cover.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFFFF1DF),
                      child: Icon(Icons.storefront_outlined),
                    )
                  : Image.network(cover, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  (service['title'] ?? 'Jasa Mitra').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                AyoText(
                  'Mulai ${_currency.format(price)}',
                  style: TextStyle(
                    color: jobBrownColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: Supabase.instance.client.auth.currentUser?.id == widget.mitraId
                ? null
                : () => _order(service),
            child: const AyoText('Pesan'),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final int rating = int.tryParse((review['rating'] ?? '0').toString()) ?? 0;
    final dynamic rawTags = review['tags'];
    final List<String> tags = rawTags is List
        ? rawTags.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: jobBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ...List<Widget>.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 15,
                  color: jobOrangeColor,
                ),
              ),
              const Spacer(),
              AyoText(
                formatJobDate(review['created_at']),
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF8B7F78)),
              ),
            ],
          ),
          if ((review['review'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            AyoText(
              review['review'].toString(),
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          ],
          if (tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(5).map((tag) => Chip(
                visualDensity: VisualDensity.compact,
                label: AyoText(tag, style: const TextStyle(fontSize: 9)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jobBorderColor),
      ),
      child: AyoText(message, style: const TextStyle(fontSize: 11.5)),
    );
  }
}
