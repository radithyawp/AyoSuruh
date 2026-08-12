import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';
import 'package:intl/intl.dart';

import '../jobs/job_helpers.dart';
import 'create_mitra_service_page.dart';
import 'mitra_service_service.dart';
import '../widgets/home_shortcut_button.dart';
import '../widgets/ayo_empty_state.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class MitraServicesPage extends StatefulWidget {
  const MitraServicesPage({super.key});

  @override
  State<MitraServicesPage> createState() => _MitraServicesPageState();
}

class _MitraServicesPageState extends State<MitraServicesPage> {
  final MitraServiceService _service = MitraServiceService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final List<Map<String, dynamic>> items = await _service.fetchMyServices();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateMitraServicePage(existingService: item),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _toggle(Map<String, dynamic> item, bool active) async {
    try {
      await _service.setActive(item['id'].toString(), active);
      await _load();
    } catch (error) {
      _message('Status jasa belum dapat diubah: $error', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const AyoText('Hapus jasa?'),
        content: AyoText(
          '"${(item['title'] ?? 'Jasa').toString()}" tidak akan tampil lagi di pencarian customer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AyoText('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const AyoText('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteService(item['id'].toString());
      await _load();
    } catch (error) {
      _message('Jasa belum dapat dihapus: $error', error: true);
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      AyoSnackBar.error(context, message);
    } else {
      AyoSnackBar.success(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: AppBar(
        backgroundColor: jobBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: AyoText(
          'Jasa Saya',
          style: TextStyle(color: jobBrownColor, fontWeight: FontWeight.w900),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: jobOrangeColor))
          : RefreshIndicator(
              color: jobOrangeColor,
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(20, 54, 20, 120),
                      children: <Widget>[
                        AyoEmptyState(
                          assetPath: 'assets/images/ayos/ayos_idea.png',
                          badgeIcon: Icons.storefront_outlined,
                          title: 'Belum ada jasa yang dipublikasikan',
                          description: _error == null
                              ? 'Tambahkan keahlianmu agar Customer dapat menemukan dan memesan jasa langsung dari katalog.'
                              : 'Jasa belum dapat dimuat. Tarik ke bawah untuk mencoba kembali.\n$_error',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> item = _items[index];
                        final Map<String, dynamic>? category = item['categories'] is Map
                            ? Map<String, dynamic>.from(item['categories'] as Map)
                            : null;
                        final String categoryName =
                            (category?['name'] ?? 'Lainnya').toString();
                        final bool active = item['is_active'] == true;
                        final num price = item['starting_price'] is num
                            ? item['starting_price'] as num
                            : num.tryParse(item['starting_price']?.toString() ?? '') ?? 0;
                        final dynamic rawImages = item['service_images'];
                        final String coverUrl = rawImages is List && rawImages.isNotEmpty
                            ? ((rawImages.first as Map)['image_url'] ?? '').toString()
                            : '';
                        return Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: jobBorderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Container(
                                    width: 54,
                                    height: 54,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: categoryBackground(categoryName),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: coverUrl.isEmpty
                                        ? Icon(
                                            categoryIcon(categoryName),
                                            color: jobBrownColor,
                                          )
                                        : Image.network(
                                            coverUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Icon(
                                              categoryIcon(categoryName),
                                              color: jobBrownColor,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        AyoText(
                                          (item['title'] ?? 'Jasa').toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        AyoText(
                                          '${AyoI18n.t(categoryName)} · ${AyoI18n.t('Mulai')} ${_currency.format(price)}',
                                          style: const TextStyle(
                                            fontSize: 10.8,
                                            color: Color(0xFF756960),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: active,
                                    activeTrackColor: jobOrangeColor,
                                    onChanged: (bool value) => _toggle(item, value),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 11),
                              AyoText(
                                (item['description'] ?? '').toString(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.3,
                                  height: 1.4,
                                  color: Color(0xFF625852),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                                          : active
                                              ? const Color(0xFFE5F3DB)
                                              : const Color(0xFFF0ECE9),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: AyoText(
                                      active ? 'Aktif di pencarian' : 'Disembunyikan',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: AyoI18n.t('Edit'),
                                    onPressed: () => _openForm(item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: AyoI18n.t('Hapus'),
                                    onPressed: () => _delete(item),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: jobOrangeColor,
        foregroundColor: const Color(0xFF553600),
        icon: const Icon(Icons.add_rounded),
        label: const AyoText(
          'Tambah Jasa',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
