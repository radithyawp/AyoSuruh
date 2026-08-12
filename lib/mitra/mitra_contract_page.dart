import 'package:flutter/material.dart';

import '../l10n/ayo_localization.dart';
import '../widgets/home_shortcut_button.dart';

class MitraContractPage extends StatelessWidget {
  const MitraContractPage({
    super.key,
    required this.contract,
  });

  final Map<String, dynamic> contract;

  static const Color _brown = Color(0xFF8B5A2B);

  @override
  Widget build(BuildContext context) {
    final bool isEnglish = AyoI18n.isEnglish;
    final String title = (isEnglish
            ? contract['title_en'] ?? contract['title']
            : contract['title'])
        ?.toString()
        .trim() ??
        (isEnglish ? 'Ayo Suruh Partner Agreement' : 'Kontrak Kemitraan Ayo Suruh');
    final String version = (contract['version'] ?? '-').toString();
    final String content = (isEnglish
            ? contract['content_en'] ?? contract['content']
            : contract['content'])
        ?.toString()
        .trim() ??
        '';
    final DateTime? effectiveAt = DateTime.tryParse(
      contract['effective_at']?.toString() ?? '',
    )?.toLocal();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    String dateLabel(DateTime date) {
      String two(int value) => value.toString().padLeft(2, '0');
      return '${two(date.day)}/${two(date.month)}/${date.year}';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
        ),
        title: AyoText(
          isEnglish ? 'Partner Contract / MoU' : 'Kontrak / MoU Mitra',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? scheme.surfaceContainerHighest
                  : const Color(0xFFFFE9CA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? scheme.onSurface
                        : _brown,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(
                      label: AyoText(
                        '${isEnglish ? 'Version' : 'Versi'} $version',
                      ),
                    ),
                    if (effectiveAt != null)
                      Chip(
                        label: AyoText(
                          '${isEnglish ? 'Effective' : 'Berlaku'} ${dateLabel(effectiveAt)}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outline),
            ),
            child: SelectableText(
              content.isEmpty
                  ? (isEnglish
                      ? 'Contract content is unavailable. Do not submit the application until the contract can be read.'
                      : 'Isi kontrak belum tersedia. Jangan kirim pengajuan sebelum kontrak dapat dibaca.')
                  : content,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 14),
          AyoText(
            isEnglish
                ? 'Your acceptance is recorded with the contract version and acceptance time. If the active contract changes materially, the app may request your approval again.'
                : 'Persetujuan dicatat berdasarkan versi kontrak dan waktu saat pengajuan dikirim. Jika kontrak aktif berubah secara material, aplikasi dapat meminta persetujuan ulang.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
